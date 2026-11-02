# frozen_string_literal: true

require "adwaita"
require_relative "locale"

module Tally
  # ShortcutsDialog is the port of main.lua's newshortcutwindow.
  #
  # Upstream builds a Gtk.ShortcutsWindow with one ShortcutsSection holding two
  # ShortcutsGroups, "Main Window" and "Counter Window". Gtk.ShortcutsWindow
  # and its whole family were deprecated in GTK 4.18 in favour of
  # Adw.ShortcutsDialog, which has no group level: a dialog holds sections, and
  # sections hold items. The two groups therefore become two sections, with the
  # same titles, the same items and the same accelerators.
  #
  # Upstream also builds a new window per activation and makes it modal and
  # transient for the main window; Adw.ShortcutsDialog is presented against a
  # parent instead, so one instance is enough.
  class ShortcutsDialog < Adwaita::ShortcutsDialog
    include Gettext

    SECTIONS = {
      "Main Window"    => [
        ["Quit Application", "<Ctrl>Q"],
        ["Keyboard Shortcuts", "<Ctrl><Shift>question"],
        ["About Tally", "F1"],
      ],
      "Counter Window" => [
        ["Quit Application", "<Ctrl>Q"],
        ["Close Window", "<Ctrl>W"],
      ],
    }.freeze

    def self.build = new.build

    def initialize
      super()
      self.title = _("Keyboard Shortcuts")
    end

    def build
      tap do |dialog|
        SECTIONS.each { |title, items| dialog.add(section(title, items)) }
      end
    end

    private

      def section(title, items)
        Adwaita::ShortcutsSection.new.tap do |group|
          group.title = _(title)
          items.each { |label, accelerator| group.add(item(label, accelerator)) }
        end
      end

      # Positional, not keyword, arguments — even though the error a no-argument
      # new raises advertises the signatures as "title: utf8, accelerator: utf8".
      def item(label, accelerator) = Adwaita::ShortcutsItem.new(_(label), accelerator)
  end
end
