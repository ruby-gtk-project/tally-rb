# frozen_string_literal: true

require "adwaita"
require_relative "color_selector"
require_relative "colors"
require_relative "locale"

module Tally
  # NewCounterDialog is the port of main.lua's window:tallydialog.
  #
  # An Adw.Dialog with a header bar, a name Entry, a radio ColorSelector and a
  # create button whose child is an Adw.ButtonContent. The create button starts
  # insensitive and stays that way while the name is empty, and the entry wears
  # the "error" class for as long as it is — but only after the first
  # keystroke, so an untouched dialog does not open already complaining.
  #
  # Upstream builds this dialog afresh on every activation and the state dies
  # with it; this port keeps one instance per window and resets it on open, so
  # the second counter is created from the same blank form as the first.
  class NewCounterDialog < Adwaita::Dialog
    include Gettext

    SPACING = 12

    # The block is called with the name and the chosen colour (nil for "no
    # colour") once the dialog is satisfied with them.
    def initialize(&on_create)
      super()
      @on_create = on_create
      self.title = _("New Counter")
    end

    def build
      tap do |dialog|
        dialog.child = toolbar_view

        toolbar_view.tap do |view|
          view.add_top_bar(header_bar)
          view.content = content_box

          content_box.tap do |box|
            box.append(name_entry)
            box.append(color_selector.build)
            box.append(create_button)
          end
        end

        name_entry.signal_connect("changed") { validate }
        create_button.signal_connect("clicked") { create }
      end
    end

    # Opens the dialog on a blank form, with the name focused.
    def open(parent)
      tap do
        name_entry.text = ""
        name_entry.remove_css_class("error")
        create_button.sensitive = false
        color_selector.check(Colors::SYSTEM).active = true
        present(parent)
        name_entry.grab_focus
      end
    end

    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new
    def header_bar = @header_bar ||= Adwaita::HeaderBar.new

    def content_box
      @content_box ||= Gtk::Box.new(:vertical, SPACING).tap do |box|
        box.margin_top = 12
        box.margin_bottom = 12
        box.margin_start = 12
        box.margin_end = 12
      end
    end

    def name_entry
      @name_entry ||= Gtk::Entry.new.tap do |entry|
        entry.placeholder_text = _("Name")
        entry.halign = :fill
      end
    end

    def color_selector = @color_selector ||= ColorSelector.new(mode: :radio)

    def create_button
      @create_button ||= Gtk::Button.new.tap do |button|
        button.child = button_content
        button.tooltip_text = _("Add this counter to the list")
        button.halign = :center
        button.sensitive = false
        button.add_css_class("suggested-action")
      end
    end

    def button_content
      @button_content ||= Adwaita::ButtonContent.new.tap do |content|
        content.icon_name = "plus-large-symbolic"
        content.label = _("Add to List")
      end
    end

    private

      def validate
        if blank?
          name_entry.add_css_class("error")
          create_button.sensitive = false
        else
          name_entry.remove_css_class("error")
          create_button.sensitive = true
        end
      end

      def create
        unless blank?
          @on_create&.call(name_entry.text, color_selector.selected_color)
          close
        end
      end

      def blank? = name_entry.text.to_s.strip.empty?
  end
end
