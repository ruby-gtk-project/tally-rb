# frozen_string_literal: true

require "adwaita"
require_relative "locale"
require_relative "rb/version"

module Tally
  # AboutDialog is the port of main.lua's aboutwin.
  #
  # Upstream builds one Adw.AboutDialog at startup and presents the same
  # instance every time, which is why the title bar's F1 and the menu item
  # share it. The two add_link entries are the translation guide and the tip
  # jar; the release notes are markup, not plain text, and belong to the
  # version named by release_notes_version.
  #
  # The application name, copyright, developer and license are upstream's; the
  # version is this port's gem version, and the port's own repository is named
  # as the issue tracker, since upstream's tracker cannot act on bugs in a
  # reimplementation.
  class AboutDialog < Adwaita::AboutDialog
    include Gettext

    APPLICATION_ICON = "tally-symbolic"
    COPYRIGHT = "Copyright © 2024–2025 Victoria Lacroix"
    DEVELOPER = "Victoria Lacroix"
    ISSUE_URL = "https://github.com/ruby-gtk-project/tally-rb/issues/"
    WEBSITE = "https://www.vlacroix.ca/apps/tally/"
    UPSTREAM_VERSION = "0.7.3"

    LINKS = {
      "Translate this app!" => "https://github.com/vtrlx/tally?tab=readme-ov-file#localization",
      "Support this app!"   => "https://liberapay.com/vtrlx/",
    }.freeze

    RELEASE_NOTES = <<~XML
      <p>In-app icons are now supplied by Tally, fixing a bug where icons would not be shown if not provided by the user's operating system.</p>
    XML

    def self.build = new.build

    def initialize
      super()
      self.application_icon = APPLICATION_ICON
      self.application_name = _("Tally")
      self.copyright = COPYRIGHT
      self.developer_name = DEVELOPER
      self.issue_url = ISSUE_URL
      self.license_type = :gpl_3_0
      self.translator_credits = _("translator-credits")
      self.version = version
      self.release_notes_version = UPSTREAM_VERSION
      self.website = WEBSITE
    end

    def build
      tap do |dialog|
        LINKS.each { |label, url| dialog.add_link(_(label), url) }
        dialog.release_notes = RELEASE_NOTES
      end
    end

    # "0.1.0 (tally 0.7.3)" — both numbers matter: the first says which port
    # this is, the second which upstream release it was written against.
    def version = "#{Rb::Version::VERSION} (tally #{UPSTREAM_VERSION})"
  end
end
