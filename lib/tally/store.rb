# frozen_string_literal: true

require "fileutils"
require "json"
require "glib2"
require_relative "counter"
require_relative "lua_config"

module Tally
  # Store is the port of main.lua's readcfg / writecfg / lib.queuewrite and of
  # the directory-bootstrapping do-block above them.
  #
  # Upstream's config file is Lua source — writecfg prints a `return { ... }`
  # table and readcfg load()s it — which is only safe because the file lives
  # inside a Flatpak sandbox. This port writes JSON instead; everything else is
  # a straight port:
  #
  # * the file is $XDG_CONFIG_HOME/tally/tally, written by filling
  #   .../tallynext and renaming it over the destination, so a half-written
  #   file can never clobber a good one;
  # * a leftover tallynext is read in preference to tally, and skipped if it
  #   does not parse;
  # * a `tally` path that exists but is not a directory is deleted rather than
  #   worked around, same reasoning as upstream;
  # * writes are debounced one second deep by #queue_write, with upstream's
  #   counter trick: each call arms a timeout, and only the last one still
  #   pending actually writes.
  #
  # The window geometry is read off the window at write time, as upstream's
  # writecfg does, which is why Store needs to be told which window to watch.
  #
  # Changing the file format is the one place a port can destroy a user's data
  # without anything appearing to go wrong, so two mechanisms guard it:
  #
  # * **Import.** A file that is not JSON is handed to LuaConfig, which reads
  #   upstream's grammar without evaluating it. On success the Lua file is
  #   copied aside to `tally.lua.bak` and the document is rewritten as JSON, so
  #   the import happens exactly once and the original stays on disk.
  # * **Refusal.** #read_document tells three states apart, where the previous
  #   version of this class told two. There is no config (first launch) — write
  #   freely. There is a config and it parsed — write freely. There is a config
  #   and neither reader could make sense of it — #unreadable? is true, #write
  #   refuses, and #queue_write does not arm a timeout. The counters the app
  #   shows are then empty, but the file is not touched, so the user still has
  #   their data and a newer build or a hand edit can recover it.
  class Store
    FILE_NAME = "tally"
    TEMP_NAME = "tallynext"
    BACKUP_NAME = "tally.lua.bak"
    DEBOUNCE_MS = 1000
    DEFAULT_WIDTH = 500
    DEFAULT_HEIGHT = 600

    class << self
      def default = @default ||= new

      # Replaces the process-wide store. The specs use it; the app does not.
      def default=(store)
        @default = store
      end
    end

    # The window whose geometry gets recorded. Nil until MainWindow sets it, in
    # which case the saved geometry is kept as-is rather than overwritten.
    attr_accessor :window

    attr_reader :dir

    def initialize(dir: nil)
      @dir = dir || default_dir
      @queued = 0
      @document = nil
      @saved_counters = nil
      @unreadable = nil
      @imported = nil
    end

    def path = File.join(@dir, FILE_NAME)
    def temp_path = File.join(@dir, TEMP_NAME)
    def backup_path = File.join(@dir, BACKUP_NAME)

    def document = @document || load_document

    def width = integer("width", DEFAULT_WIDTH)
    def height = integer("height", DEFAULT_HEIGHT)
    def maximized? = [true, "true"].include?(document["maximized"])

    # The file that exists but could not be read, or nil when everything on
    # disk was understood. Reading the document is what decides this, so the
    # document is loaded first.
    def unreadable
      document.then { @unreadable }
    end

    def unreadable? = !unreadable.nil?

    # True when this run read a Lua config and rewrote it as JSON. Nothing in
    # the app branches on it; it is here so the import is observable.
    def imported?
      document.then { !@imported.nil? }
    end

    # The counters the last run left behind, in the order they were listed.
    def saved_counters
      @saved_counters ||= Array(document["counters"]).filter_map do |entry|
        if entry.is_a?(Hash)
          Counter.from_h(entry)
        end
      end
    end

    # Upstream's lib.queuewrite: arm a one-second timeout and let the last
    # caller standing do the write, so holding the spin button down does not
    # write once per click. A store that refuses to write never arms one.
    def queue_write
      unless unreadable?
        @queued += 1
        GLib::Timeout.add(DEBOUNCE_MS) do
          tick
          false
        end
      end
      @queued
    end

    # Upstream's writecfg. Also clears the pending-write count, so a queued
    # write that has not fired yet becomes a no-op.
    #
    # Returns false without touching the disk when the config on disk could not
    # be read: overwriting it would turn one unreadable file into no file at
    # all.
    def write
      if unreadable?
        false
      else
        @queued = 0
        prepare
        File.write(temp_path, "#{JSON.pretty_generate(snapshot)}\n")
        File.rename(temp_path, path)
        @document = snapshot
        true
      end
    end

    # Makes the config directory usable: a non-directory in its place is
    # removed, and a missing config file is seeded with an empty document so
    # the first read has something to parse.
    def prepare
      prepare_dir
      unless File.exist?(path)
        File.write(path, "#{JSON.pretty_generate(empty_document)}\n")
      end
      @dir
    end

    def snapshot
      geometry.merge("counters" => Counter.counters.map(&:serialize))
    end

    private

      def prepare_dir
        if File.exist?(@dir) && !File.directory?(@dir)
          File.delete(@dir)
        end
        FileUtils.mkdir_p(@dir)
        @dir
      end

      def tick
        unless @queued.zero?
          @queued -= 1
          if @queued.zero?
            write
          end
        end
      end

      def geometry
        if @window
          {
            "width"     => @window.default_width,
            "height"    => @window.default_height,
            "maximized" => @window.maximized?,
          }
        else
          {
            "width"     => width,
            "height"    => height,
            "maximized" => maximized?,
          }
        end
      end

      def empty_document
        {
          "width"     => DEFAULT_WIDTH,
          "height"    => DEFAULT_HEIGHT,
          "maximized" => false,
          "counters"  => [],
        }
      end

      # The directory is made before the read, but the empty seed file is
      # written only once the read has decided nothing was there to lose.
      def load_document
        prepare_dir
        @document = read_document
        if @unreadable.nil?
          prepare
        end
        @document
      end

      # tallynext first, exactly as readcfg does: if the previous run died
      # between the write and the rename, the newer data is in the temp file.
      #
      # Each candidate comes back as one of three things: nil when the file is
      # not there, a document when it parsed, or :unreadable when it is there
      # and neither reader could read it. The first candidate that parsed wins;
      # if none did but one was present, this run is read-only.
      def read_document
        [temp_path, path].map { |candidate| [candidate, parse(candidate)] }
          .then do |attempts|
            attempts.find { |_candidate, parsed| parsed.is_a?(Hash) }
              .then do |success|
                if success
                  success.last
                else
                  refuse(attempts)
                end
              end
          end
      end

      # Nothing parsed. If a file was there, name it and give up on writing;
      # otherwise this is a first launch and the empty document is the truth.
      def refuse(attempts)
        attempts.find { |_candidate, parsed| parsed == :unreadable }
          .then do |failure|
            if failure
              @unreadable = failure.first
            end
            empty_document
          end
      end

      # JSON first, since that is what this port writes, then upstream's Lua.
      # A Lua file that reads is imported on the spot.
      def parse(candidate)
        if File.file?(candidate)
          File.read(candidate, encoding: "UTF-8").then do |text|
            json(text) || import(candidate, text) || :unreadable
          end
        end
      rescue SystemCallError
        nil
      end

      def json(text)
        hashify(JSON.parse(text))
      rescue JSON::ParserError
        nil
      end

      # Upstream's config, read once and rewritten as JSON. The Lua file is
      # copied to tally.lua.bak rather than deleted, so a user who downgrades
      # to upstream — or who wants to check the import — still has it. A
      # failure to write the backup or the JSON leaves the document loaded and
      # the original untouched, which is the same position as not importing.
      def import(candidate, text)
        LuaConfig.parse(text).tap do |document|
          @imported = candidate
          @document = document
          @saved_counters = nil
          back_up(candidate)
          File.write(temp_path, "#{JSON.pretty_generate(document)}\n")
          File.rename(temp_path, candidate)
        end
      rescue LuaConfig::Error
        nil
      rescue SystemCallError
        @document
      end

      def back_up(candidate)
        unless File.exist?(backup_path)
          FileUtils.cp(candidate, backup_path)
        end
        backup_path
      end

      def hashify(parsed)
        if parsed.is_a?(Hash)
          parsed
        end
      end

      def integer(key, fallback)
        document[key].to_i.then do |number|
          if number.positive?
            number
          else
            fallback
          end
        end
      end

      def default_dir
        File.join(
          ENV.fetch("XDG_CONFIG_HOME") { File.expand_path("~/.config") },
          "tally",
        )
      end
  end
end
