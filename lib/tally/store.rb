# frozen_string_literal: true

require "fileutils"
require "json"
require "glib2"
require_relative "counter"

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
  class Store
    FILE_NAME = "tally"
    TEMP_NAME = "tallynext"
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
    end

    def path = File.join(@dir, FILE_NAME)
    def temp_path = File.join(@dir, TEMP_NAME)

    def document = @document || load_document

    def width = integer("width", DEFAULT_WIDTH)
    def height = integer("height", DEFAULT_HEIGHT)
    def maximized? = [true, "true"].include?(document["maximized"])

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
    # write once per click.
    def queue_write
      @queued += 1
      GLib::Timeout.add(DEBOUNCE_MS) do
        tick
        false
      end
      @queued
    end

    # Upstream's writecfg. Also clears the pending-write count, so a queued
    # write that has not fired yet becomes a no-op.
    def write
      @queued = 0
      prepare
      File.write(temp_path, "#{JSON.pretty_generate(snapshot)}\n")
      File.rename(temp_path, path)
      @document = snapshot
    end

    # Makes the config directory usable: a non-directory in its place is
    # removed, and a missing config file is seeded with an empty document so
    # the first read has something to parse.
    def prepare
      if File.exist?(@dir) && !File.directory?(@dir)
        File.delete(@dir)
      end
      FileUtils.mkdir_p(@dir)
      unless File.exist?(path)
        File.write(path, "#{JSON.pretty_generate(empty_document)}\n")
      end
      @dir
    end

    def snapshot
      geometry.merge("counters" => Counter.counters.map(&:serialize))
    end

    private

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

      def load_document
        prepare
        @document = read_document
      end

      # tallynext first, exactly as readcfg does: if the previous run died
      # between the write and the rename, the newer data is in the temp file.
      def read_document
        [temp_path, path].filter_map { |candidate| parse(candidate) }.first || empty_document
      end

      def parse(candidate)
        if File.file?(candidate)
          hashify(JSON.parse(File.read(candidate, encoding: "UTF-8")))
        end
      rescue JSON::ParserError, SystemCallError
        nil
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
