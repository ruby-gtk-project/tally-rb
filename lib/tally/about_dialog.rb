# frozen_string_literal: true

require "adwaita"
require_relative "locale"
require_relative "metainfo"
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
  #
  # Two properties are read rather than written. application_icon is the
  # application id, as upstream's `application_icon = app_id` is — the icon is
  # shipped under data/icons/hicolor/scalable/apps and Icons puts that
  # directory on the theme search path. release_notes and
  # release_notes_version come from Metainfo, so the notes shown are the ones
  # the AppStream file declares rather than a second hand-maintained copy.
  class AboutDialog < Adwaita::AboutDialog
    include Gettext

    COPYRIGHT = "Copyright © 2024–2025 Victoria Lacroix"
    DEVELOPER = "Victoria Lacroix"
    ISSUE_URL = "https://github.com/ruby-gtk-project/tally-rb/issues/"
    WEBSITE = "https://www.vlacroix.ca/apps/tally/"

    LINKS = {
      N_("Translate this app!") => "https://github.com/vtrlx/tally?tab=readme-ov-file#localization",
      N_("Support this app!")   => "https://liberapay.com/vtrlx/",
    }.freeze

    def self.build(...) = new(...).build

    def initialize(application_id: Metainfo::APP_ID, metainfo: Metainfo.default)
      super()
      @metainfo = metainfo
      self.application_icon = application_id
      self.application_name = _("Tally")
      self.copyright = COPYRIGHT
      self.developer_name = DEVELOPER
      self.issue_url = ISSUE_URL
      self.license_type = :gpl_3_0
      self.translator_credits = _("translator-credits")
      self.version = version
      self.release_notes_version = upstream_version
      self.website = WEBSITE
    end

    attr_reader :metainfo

    def build
      tap do |dialog|
        LINKS.each { |label, url| dialog.add_link(_(label), url) }
        release_notes.then do |notes|
          if notes
            dialog.release_notes = notes
          end
        end
      end
    end

    # The newest release the AppStream file declares — upstream's
    # lib.get_app_ver(), which the Makefile sets from the same VERSION the
    # metainfo file's top <release> carries.
    def upstream_version = metainfo.version

    def release_notes = metainfo.release_notes(upstream_version)

    # "0.1.0 (tally 0.7.3)" — both numbers matter: the first says which port
    # this is, the second which upstream release it was written against.
    def version = "#{Rb::Version::VERSION} (tally #{upstream_version})"
  end
end
