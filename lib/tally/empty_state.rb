# frozen_string_literal: true

require "adwaita"
require_relative "locale"

module Tally
  # EmptyState is the port of main.lua's self.statuspage.
  #
  # The Adw.StatusPage shown in place of the list while there are no counters:
  # the app's own tally-symbolic icon, a title, and a pill-shaped
  # suggested-action button opening the same new-counter dialog the header
  # bar's plus button does. Upstream gives the button wide side margins so it
  # does not stretch to the status page's full width.
  class EmptyState < Adwaita::StatusPage
    include Gettext

    def initialize(&on_create)
      super()
      @on_create = on_create
      self.title = _("No Counters")
      self.icon_name = "tally-symbolic"
    end

    def build
      tap do |page|
        page.child = create_button
        create_button.signal_connect("clicked") { @on_create&.call }
      end
    end

    def create_button
      @create_button ||= Gtk::Button.new.tap do |button|
        button.label = _("Create Counter")
        button.add_css_class("suggested-action")
        button.add_css_class("pill")
        button.margin_start = 40
        button.margin_end = 40
      end
    end
  end
end
