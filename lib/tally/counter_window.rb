# frozen_string_literal: true

require "adwaita"
require_relative "colors"
require_relative "counter"
require_relative "locale"

module Tally
  # CounterWindow is the port of counter.lua's counter:popout.
  #
  # A second window showing one counter at 300% type with two circular
  # buttons, wrapped in a WindowHandle so the whole face can be used to drag
  # the window around. It carries the counter's colour class on the
  # ToolbarView, which is what the "toolbarview.red" half of the stylesheet
  # paints, and a win.close action for Ctrl+W.
  #
  # Upstream reassigns the counter's spinbtn notify::value handler here, which
  # silently unhooks the list row's own handler — the row's count label stops
  # updating and edits stop being saved for as long as the pop-out exists. This
  # port routes both windows through the Counter instead: the buttons move
  # Counter#value, and both the row and this window listen for the change.
  class CounterWindow < Adwaita::ApplicationWindow
    include Gettext

    DEFAULT_WIDTH = 400
    DEFAULT_HEIGHT = 300
    MIN_WIDTH = 360
    MIN_HEIGHT = 294
    LABEL_WIDTH = 240

    def initialize(application, counter:, store: nil, name_entry: nil, devel: false, &on_close)
      super(application)
      @counter = counter
      @store = store
      @name_entry = name_entry
      @on_close = on_close
      self.title = formatted_title
      self.hide_on_close = true
      set_default_size(DEFAULT_WIDTH, DEFAULT_HEIGHT)
      set_size_request(MIN_WIDTH, MIN_HEIGHT)
      if devel
        add_css_class("devel")
      end
    end

    attr_reader :counter

    def build
      tap do |window|
        window.content = toolbar_view

        toolbar_view.tap do |view|
          view.add_top_bar(header_bar)
          view.content = window_handle
          if Colors.accent?(counter.color)
            view.add_css_class(counter.color_key)
          end
        end

        window_handle.tap do |handle|
          handle.child = content_box

          content_box.tap do |box|
            box.append(number_box)

            number_box.tap do |numbers|
              numbers.append(count_label)
              numbers.append(button_box)

              button_box.tap do |buttons|
                buttons.append(decrement_button)
                buttons.append(increment_button)
              end
            end
          end
        end

        window.signal_connect("close-request") { dismiss }
        window.add_action(close_action)
        connect
      end
    end

    def toolbar_view
      @toolbar_view ||= Adwaita::ToolbarView.new.tap do |view|
        view.width_request = 300
      end
    end

    def header_bar
      @header_bar ||= Adwaita::HeaderBar.new.tap do |bar|
        bar.title_widget = title_label
      end
    end

    # Bound bidirectionally to the counter's name entry, as upstream does, so
    # typing in the list row retitles this window as the letters land.
    def title_label
      @title_label ||= Adwaita::WindowTitle.new(counter.name, _("Tally")).tap do |label|
        @name_entry&.bind_property(
          "text",
          label,
          "title",
          :bidirectional,
        )
      end
    end

    def window_handle = @window_handle ||= Gtk::WindowHandle.new

    def count_label
      @count_label ||= Gtk::Label.new(counter.value.to_s).tap do |label|
        label.width_request = LABEL_WIDTH
        label.halign = :center
        label.add_css_class("numeric")
      end
    end

    def decrement_button
      @decrement_button ||= circular_button("minus-symbolic", _("Decrement by 1")).tap do |button|
        button.sensitive = counter.value > Counter::MIN_VALUE
      end
    end

    def increment_button
      @increment_button ||= circular_button("plus-symbolic", _("Increment by 1")).tap do |button|
        button.sensitive = counter.value < Counter::MAX_VALUE
      end
    end

    def button_box
      @button_box ||= Gtk::Box.new(:horizontal, 48).tap do |box|
        box.valign = :center
        box.halign = :center
      end
    end

    # The "popout" class is what scales the type to 300% and the buttons to
    # 68px; it sits on this box so the header bar keeps its normal size.
    def number_box
      @number_box ||= Gtk::Box.new(:vertical, 24).tap do |box|
        box.valign = :center
        box.add_css_class("popout")
      end
    end

    def content_box
      @content_box ||= Gtk::Box.new(:vertical, 36).tap do |box|
        box.margin_top = 24
        box.margin_bottom = 24
        box.margin_start = 24
        box.margin_end = 24
        box.valign = :center
        box.halign = :center
      end
    end

    def close_action
      @close_action ||= Gio::SimpleAction.new("close", nil).tap do |action|
        action.signal_connect("activate") { close }
        action.enabled = true
      end
    end

    private

      def connect
        decrement_button.signal_connect("clicked") { step(-1) }
        increment_button.signal_connect("clicked") { step(1) }
        counter.on_change { |_counter, what| changed(what) }
        counter.on_color_change { |_counter, previous| recolor(previous) }
      end

      def step(delta)
        counter.value = counter.value + delta
        @store&.queue_write
      end

      def changed(what)
        case what
        when :value then refresh_value
        when :name then refresh_title
        end
      end

      def refresh_value
        count_label.label = counter.value.to_s
        decrement_button.sensitive = counter.value > Counter::MIN_VALUE
        increment_button.sensitive = counter.value < Counter::MAX_VALUE
      end

      def refresh_title
        self.title = formatted_title
      end

      def recolor(previous)
        if Colors.accent?(previous)
          toolbar_view.remove_css_class(previous)
        end
        if Colors.accent?(counter.color)
          toolbar_view.add_css_class(counter.color_key)
        end
      end

      # Upstream destroys the window in its close-request handler and drops its
      # reference, so a reopened pop-out is a fresh window rather than a hidden
      # one being shown again.
      def dismiss
        @on_close&.call(self)
        destroy
        false
      end

      def formatted_title = "#{counter.name} — #{_("Tally")}"

      def circular_button(icon_name, tooltip)
        Gtk::Button.new.tap do |button|
          button.icon_name = icon_name
          button.tooltip_text = tooltip
          button.add_css_class("circular")
        end
      end
  end
end
