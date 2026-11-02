# frozen_string_literal: true

module Tally
  # Metainfo is the reader for the AppStream file ported from upstream's
  # ca.vlacroix.Tally.metainfo.xml.
  #
  # It exists for one reason: the About dialog has to show the release notes
  # for the version it reports, and upstream keeps those notes in two places —
  # the <releases> history in the metainfo file and a heredoc assigned to
  # aboutwin.release_notes in main.lua. Upstream can get away with the
  # duplication because both are edited in the same commit by the same person;
  # a port cannot, because the heredoc is the copy that silently goes stale.
  # So the metainfo file is the single source here and the dialog reads it.
  #
  # The parser is deliberately small. AppStream is XML, but this is *our* XML:
  # the file is shipped by the gem, its shape is fixed, and REXML is no longer
  # a default gem on Ruby 3.4. So the <release> elements are matched directly
  # and their <description> body is handed back as the markup it already is —
  # Adw.AboutDialog's release_notes property wants exactly that subset
  # (<p>, <ul>, <ol>, <li>, <em>, <code>), which is what upstream's heredoc is.
  class Metainfo
    DIR = File.expand_path("../../data", __dir__)
    APP_ID = "org.rubygtkproject.Tally"

    # The attribute list and the body are captured separately so version and
    # date both come out of the same match.
    RELEASE = %r{<release\s+(?<attributes>[^>]*?)/?>(?<body>.*?)</release>}m
    VERSION = /\bversion="([^"]*)"/
    DATE = /\bdate="([^"]*)"/
    DESCRIPTION = %r{<description>(?<body>.*?)</description>}m

    # One entry of the <releases> history.
    Release = Struct.new(:version, :date, :notes)

    class << self
      def default = @default ||= new

      # Replaces the process-wide reader. The specs use it; the app does not.
      def default=(metainfo)
        @default = metainfo
      end
    end

    def initialize(path: nil)
      @path = path || File.join(DIR, "#{APP_ID}.metainfo.xml")
    end

    attr_reader :path

    # The releases in the order the file lists them, which is newest first.
    def releases
      @releases ||= source.to_s.scan(RELEASE).map { |attributes, body| release_from(attributes, body) }
    end

    def latest = releases.first

    def version = latest&.version

    def release_notes(for_version = nil)
      if for_version
        releases.find { |release| release.version == for_version }&.notes
      else
        latest&.notes
      end
    end

    private

      def source
        if File.file?(@path)
          File.read(@path, encoding: "UTF-8")
        end
      end

      def release_from(attributes, body)
        Release.new(attributes[VERSION, 1], attributes[DATE, 1], notes_in(body))
      end

      # The <description> body, with the file's indentation removed so the
      # markup Adwaita is handed looks like upstream's heredoc rather than a
      # tab-indented block.
      def notes_in(body)
        body[DESCRIPTION, :body].to_s
          .lines
          .map(&:strip)
          .reject(&:empty?)
          .join("\n")
          .then { |markup| markup.empty? ? nil : "#{markup}\n" }
      end
  end
end
