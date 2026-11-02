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
  # same titles and the same five items.
  #
  # Each upstream Gtk.ShortcutsShortcut carries three things, and all three are
  # kept:
  #
  # * the title, translated;
  # * the action_name, which is what makes the row activatable rather than a
  #   picture of a shortcut — it is listed per item below;
  # * the accelerator, which is *not* written out here. Application::ACCELS is
  #   the single source: the same table that app.set_accels_for_action is
  #   driven from supplies the strings this dialog displays, so an accelerator
  #   can never be changed in one place and advertised from the other.
  #
  # One deviation, named because it is the kind of thing that otherwise reads
  # as a typo: upstream's About item declares action_name = "app.about", but
  # upstream registers the action on the *window* (win.about) and sets its
  # accelerator for win.about too, so "app.about" names an action that does not
  # exist and the row is inert. ACTIONS below records upstream's literal value
  # and ALIASES resolves it to the action the port actually registers, so the
  # row works and the mismatch stays visible. FINDINGS.md U3.
  #
  # Upstream also builds a new window per activation and makes it modal and
  # transient for the main window; Adw.ShortcutsDialog is presented against a
  # parent instead, so one instance is enough.
  class ShortcutsDialog < Adwaita::ShortcutsDialog
    include Gettext

    # Upstream's two groups, each item as [title, action_name] exactly as its
    # Gtk.ShortcutsShortcut spells them.
    SECTIONS = {
      N_("Main Window")    => [
        [N_("Quit Application"), "app.quit"],
        [N_("Keyboard Shortcuts"), "win.shortcuts"],
        [N_("About Tally"), "app.about"],
      ],
      N_("Counter Window") => [
        [N_("Quit Application"), "app.quit"],
        [N_("Close Window"), "win.close"],
      ],
    }.freeze

    # Upstream action names that name no registered action, mapped to the one
    # the port registers and sets the accelerator for.
    ALIASES = {
      "app.about" => "win.about",
    }.freeze

    def self.build(...) = new(...).build

    # `accels` defaults to Application::ACCELS, resolved on first use rather
    # than at load time so this file does not have to require application.rb
    # back — main_window.rb is reached from there.
    def initialize(accels: nil)
      super()
      @accels = accels
      self.title = _("Keyboard Shortcuts")
    end

    def accels = @accels ||= Application::ACCELS

    def build
      tap do |dialog|
        SECTIONS.each { |title, items| dialog.add(section(title, items)) }
      end
    end

    # The accelerator Application binds for an action, in the
    # "<Ctrl><Shift>question" form Gtk.ShortcutsShortcut and
    # Adw.ShortcutsItem both take. Nil when nothing is bound, which an item
    # shows as no accelerator rather than a wrong one.
    def accelerator_for(action) = Array(accels[resolve(action)]).first

    def resolve(action) = ALIASES.fetch(action, action)

    private

      def section(title, items)
        Adwaita::ShortcutsSection.new.tap do |group|
          group.title = _(title)
          items.each { |label, action| group.add(item(label, action)) }
        end
      end

      # Positional, not keyword, arguments. FINDINGS.md B8.
      def item(label, action)
        Adwaita::ShortcutsItem.new(_(label), accelerator_for(action).to_s).tap do |shortcut|
          shortcut.action_name = resolve(action)
        end
      end
  end
end
