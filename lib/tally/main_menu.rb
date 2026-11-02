# frozen_string_literal: true

require "adwaita"
require_relative "locale"

module Tally
  # MainMenu is the port of main.lua's tallymenu.
  #
  # The two-item Gio.Menu behind the header bar's menu button. Both items are
  # window actions, added by MainWindow: win.shortcuts opens the shortcuts
  # dialog and win.about the about dialog. There is no quit item — Ctrl+Q is
  # bound to app.quit, but upstream never lists it in the menu.
  class MainMenu
    include Gettext

    ITEMS = {
      "Keyboard Shortcuts" => "win.shortcuts",
      "About Tally"        => "win.about",
    }.freeze

    def self.build = new.build

    def build
      model.tap do |menu|
        ITEMS.each { |label, action| menu.append(_(label), action) }
      end
    end

    def model = @model ||= Gio::Menu.new
  end
end
