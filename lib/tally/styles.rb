# frozen_string_literal: true

require "adwaita"

module Tally
  # Styles is the port of main.lua's "SECTION: Styles".
  #
  # Upstream builds two CssProviders — base + light and base + dark — adds the
  # one matching Adw.StyleManager's `dark` property to the default display at
  # priority 1000000, and swaps them whenever that property changes. The light
  # and dark sheets are the row/toolbar tints, which cannot be written once
  # with colour functions because the light variant mixes towards black while
  # the dark variant mixes towards white; the base sheet is the colour-selector
  # check buttons and the pop-out window's oversized type.
  #
  # The CSS below is upstream's, unchanged.
  class Styles
    PRIORITY = 1_000_000

    BASE = <<~CSS
      .colorselector checkbutton {
        padding: 0;
        min-height: 28px;
        min-width: 28px;
        padding: 1px;
        background-clip: content-box;
        border-radius: 9999px;
        box-shadow: inset 0 0 0 1px @borders;
        background: linear-gradient(-45deg, black 49.99%, white 50.01%);
      }
      .colorselector checkbutton:checked {
        box-shadow: inset 0 0 0 2px @accent_bg_color;
      }
      .colorselector checkbutton radio, .colorselector checkbutton check {
        -gtk-icon-source: none;
        border: none;
        box-shadow: none;
        min-width: 8px;
        min-height: 8px;
        transform: translate(19px, 10px);
        padding: 2px;
      }
      .colorselector checkbutton radio:checked, .colorselector checkbutton check:checked {
        -gtk-icon-source: -gtk-icontheme("check-mark-symbolic");
        background-color: @accent_bg_color;
        color: @accent_fg_color;
      }
      .colorselector checkbutton.red {
        background: none;
        background-color: var(--red-3);
      }
      .colorselector checkbutton.orange {
        background: none;
        background-color: var(--orange-3);
      }
      .colorselector checkbutton.yellow {
        background: none;
        background-color: var(--yellow-3);
      }
      .colorselector checkbutton.green {
        background: none;
        background-color: var(--green-3);
      }
      .colorselector checkbutton.blue {
        background: none;
        background-color: var(--blue-3);
      }
      .colorselector checkbutton.purple {
        background: none;
        background-color: var(--purple-3);
      }
      .popout {
        font-size: 300%;
      }
      .popout .circular {
        min-height: 68px;
        min-width: 68px;
        -gtk-icon-size: 32px;
      }
    CSS

    LIGHT = <<~CSS
      list.tally-list row.red, toolbarview.red {
        background-color: color-mix(in srgb, var(--red-1) 10%, transparent);
        color: color-mix(in srgb, var(--red-5) 90%, black);
      }
      list.tally-list row.red:hover {
        background-color: color-mix(in srgb, var(--red-2) 10%, transparent);
        color: color-mix(in srgb, var(--red-5) 90%, black);
      }
      list.tally-list row.orange, toolbarview.orange {
        background-color: color-mix(in srgb, var(--orange-1) 20%, transparent);
        color: color-mix(in srgb, var(--orange-5) 70%, black);
      }
      list.tally-list row.orange:hover {
        background-color: color-mix(in srgb, var(--orange-2) 20%, transparent);
        color: color-mix(in srgb, var(--orange-5) 70%, black);
      }
      list.tally-list row.yellow, toolbarview.yellow {
        background-color: color-mix(in srgb, var(--yellow-1) 30%, transparent);
        color: color-mix(in srgb, var(--yellow-5) 40%, black);
      }
      list.tally-list row.yellow:hover {
        background-color: color-mix(in srgb, var(--yellow-2) 30%, transparent);
        color: color-mix(in srgb, var(--yellow-5) 40%, black);
      }
      list.tally-list row.green, toolbarview.green {
        background-color: color-mix(in srgb, var(--green-1) 25%, transparent);
        color: color-mix(in srgb, var(--green-5) 55%, black);
      }
      list.tally-list row.green:hover {
        background-color: color-mix(in srgb, var(--green-2) 25%, transparent);
        color: color-mix(in srgb, var(--green-5) 55%, black);
      }
      list.tally-list row.blue, toolbarview.blue {
        background-color: color-mix(in srgb, var(--blue-1) 20%, transparent);
        color: color-mix(in srgb, var(--blue-5) 70%, black);
      }
      list.tally-list row.blue:hover {
        background-color: color-mix(in srgb, var(--blue-2) 20%, transparent);
        color: color-mix(in srgb, var(--blue-5) 70%, black);
      }
      list.tally-list row.purple, toolbarview.purple {
        background-color: color-mix(in srgb, var(--purple-1) 20%, transparent);
        color: var(--purple-5);
      }
      list.tally-list row.purple:hover {
        background-color: color-mix(in srgb, var(--purple-2) 20%, transparent);
        color: var(--purple-5);
      }
      .colorselector checkbutton.system {
        background: none;
        background-color: white;
      }
    CSS

    DARK = <<~CSS
      list.tally-list row.red, toolbarview.red {
        background-color: color-mix(in srgb, var(--red-5) 90%, transparent);
        color: white;
      }
      list.tally-list row.red:hover {
        background-color: color-mix(in srgb, var(--red-4) 90%, transparent);
        color: white;
      }
      list.tally-list row.orange, toolbarview.orange {
        background-color: color-mix(in srgb, var(--orange-5) 55%, transparent);
        color: white;
      }
      list.tally-list row.orange:hover {
        background-color: color-mix(in srgb, var(--orange-4) 55%, transparent);
        color: white;
      }
      list.tally-list row.yellow, toolbarview.yellow {
        background-color: color-mix(in srgb, var(--yellow-5) 25%, transparent);
        color: white;
      }
      list.tally-list row.yellow:hover {
        background-color: color-mix(in srgb, var(--yellow-4) 25%, transparent);
        color: white;
      }
      list.tally-list row.green, toolbarview.green {
        background-color: color-mix(in srgb, var(--green-5) 40%, transparent);
        color: white;
      }
      list.tally-list row.green:hover {
        background-color: color-mix(in srgb, var(--green-4) 40%, transparent);
        color: white;
      }
      list.tally-list row.blue, toolbarview.blue {
        background-color: color-mix(in srgb, var(--blue-5) 70%, transparent);
        color: white;
      }
      list.tally-list row.blue:hover {
        background-color: color-mix(in srgb, var(--blue-4) 70%, transparent);
        color: white;
      }
      list.tally-list row.purple, toolbarview.purple {
        background-color: var(--purple-5);
        color: white;
      }
      list.tally-list row.purple:hover {
        background-color: var(--purple-4);
        color: white;
      }
      .colorselector checkbox.system {
        background: none;
        background-color: black;
      }
    CSS

    def self.install = new.install

    # Adds the provider for the current colour scheme and keeps watching, the
    # way upstream's styleman.on_notify.dark does.
    def install
      if style_manager.dark?
        add(dark_provider)
      else
        add(light_provider)
      end
      style_manager.signal_connect("notify::dark") { refresh }
      self
    end

    def style_manager = @style_manager ||= Adwaita::StyleManager.default
    def display = @display ||= Gdk::Display.default
    def light_provider = @light_provider ||= provider(BASE + LIGHT)
    def dark_provider = @dark_provider ||= provider(BASE + DARK)

    private

      def refresh
        if style_manager.dark?
          swap(light_provider, dark_provider)
        else
          swap(dark_provider, light_provider)
        end
      end

      def swap(outgoing, incoming)
        Gtk::StyleContext.remove_provider_for_display(display, outgoing)
        add(incoming)
      end

      def add(incoming)
        Gtk::StyleContext.add_provider_for_display(
          display,
          incoming,
          PRIORITY,
        )
      end

      # Either name, depending on the gtk4 gem's vintage. FINDINGS.md B3.
      def provider(css)
        Gtk::CssProvider.new.tap do |css_provider|
          if css_provider.respond_to?(:load_from_string)
            css_provider.load_from_string(css)
          else
            css_provider.load_from_data(css)
          end
        end
      end
  end
end
