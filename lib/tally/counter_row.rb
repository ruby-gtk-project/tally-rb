# frozen_string_literal: true

require "adwaita"
require_relative "colors"
require_relative "counter"
require_relative "counter_drag_row"
require_relative "counter_menu"
require_relative "counter_window"
require_relative "locale"

module Tally
  # CounterRow is the port of counter.lua's counter constructor — the widget
  # half of upstream's counter class.
  #
  # An Adw.ExpanderRow with the "spin" class, the counter's colour class, a
  # drag handle and a check button as prefixes, and a count label and spin
  # button as suffixes. The disclosure holds CounterMenu's four rows. The
  # handle is a DragSource and the row itself a DropTarget, which together are
  # the drag-and-drop reordering; the drag preview is a CounterDragRow inside a
  # throwaway boxed list, sized to this row's allocation so the pointer keeps
  # its grip on the same spot.
  #
  # Two prefixes and two suffixes are mutually exclusive: outside select mode
  # the handle and the spin button show, and inside it the check button and the
  # count label do — see #check_mode=, upstream's counter:setcheckmode.
  class CounterRow < Adwaita::ExpanderRow
    include Gettext

    SCROLL_DELAY_MS = 50

    def initialize(counter, store:, list: nil, application: nil, devel: false)
      super()
      @counter = counter
      @store = store
      @list = list
      @application = application
      @devel = devel
      add_css_class("spin")
      self.title = counter.name
      if Colors.accent?(counter.color)
        add_css_class(counter.color_key)
      end
    end

    attr_reader :counter

    def build
      tap do |row|
        row.add_prefix(drag_handle)
        row.add_prefix(check_button)
        row.add_suffix(count_label)
        row.add_suffix(spin_button)

        drag_handle.add_controller(drag_source)
        row.add_controller(drop_target)

        menu.attach
        Counter.bind_row(counter, row)
        connect
        align_suffixes
      end
    end

    def menu
      @menu ||= CounterMenu.new(
        counter: counter,
        row:     self,
        store:   @store,
        list:    @list,
      ) { show_popout }
    end

    def spin_button
      @spin_button ||= Gtk::SpinButton.new(adjustment, 1.0, 0).tap do |spin|
        spin.valign = :center
        spin.value = counter.value
        # The spin button's first child is its GtkText; right-aligning it is
        # what keeps the digits against the stepper rather than adrift.
        spin.first_child.then do |text|
          if text
            text.xalign = 1
          end
        end
      end
    end

    def adjustment
      @adjustment ||= Gtk::Adjustment.new(
        counter.value.to_f,
        Counter::MIN_VALUE.to_f,
        Counter::MAX_VALUE.to_f,
        1.0,
        10.0,
        0.0,
      )
    end

    # Hidden until select mode replaces the spin button with it: the number
    # still has to be readable while the row cannot be edited.
    def count_label
      @count_label ||= Gtk::Label.new(counter.value.to_s).tap do |label|
        label.visible = false
        label.hexpand = false
        label.margin_start = 18
        label.halign = :end
      end
    end

    def check_button
      @check_button ||= Gtk::CheckButton.new.tap do |button|
        button.visible = false
      end
    end

    def drag_handle
      @drag_handle ||= Gtk::Image.new(icon_name: "drag-handle-symbolic").tap do |image|
        image.add_css_class("drag-handle")
      end
    end

    # CAPTURE phase so the handle wins the gesture before the row's own click
    # handling sees it.
    def drag_source
      @drag_source ||= Gtk::DragSource.new.tap do |source|
        source.actions = :move
        source.propagation_phase = :capture
        source.signal_connect("prepare") { |_source, x, y| prepare_drag(x, y) }
        source.signal_connect("drag-begin") { |_source, drag| begin_drag(drag) }
      end
    end

    def drop_target
      @drop_target ||= Gtk::DropTarget.new(Adwaita::ExpanderRow.gtype, :move).tap do |target|
        target.preload = true
        target.signal_connect("drop") { |_target, value, _x, _y| accept_drop(value) }
      end
    end

    # Upstream's counter:setcheckmode. Collapsing the row and disabling its
    # expansion is what stops the menu being reachable while counters are
    # being picked for deletion.
    def check_mode=(enabled)
      counter.checkmode = enabled
      counter.checked = false
      check_button.active = false
      check_button.visible = enabled
      count_label.visible = enabled
      spin_button.visible = !enabled
      drag_handle.visible = !enabled
      if enabled
        self.expanded = false
        self.enable_expansion = false
      else
        self.enable_expansion = true
        self.expanded = false
      end
    end

    def check_mode? = counter.checkmode

    # Upstream's counter:read — push the counter's value back out into the
    # widgets that show it. Nothing upstream calls it: counter.lua defines it
    # directly after the constructor and then never uses it, because every
    # edit upstream travels the other way, from the spin button into the field.
    # It is live here, because this port's edits travel both ways — a pop-out
    # window moves Counter#value and the row has to catch up — so the method
    # upstream left dead is exactly the one the counter's change notification
    # needs, and #refresh_value is its one internal caller.
    def read
      tap do
        unless spin_button.value.to_i == counter.value
          spin_button.value = counter.value
        end
        count_label.label = counter.value.to_s
      end
    end

    # Activating a row in select mode ticks it, so the whole row is a target
    # rather than just the box.
    def toggle_check
      tap do
        if check_mode?
          check_button.active = !check_button.active?
        end
      end
    end

    def popout = @popout ||= build_popout

    def show_popout
      popout.present
    end

    # Closing and destroying rather than hiding: a pop-out that is only hidden
    # keeps the application alive after its counter is gone.
    def close_popout
      @popout.then do |window|
        if window
          @popout = nil
          window.close
          window.destroy
        end
      end
    end

    private

      def build_popout
        CounterWindow.new(
          @application,
          counter:    counter,
          store:      @store,
          name_entry: menu.name_row,
          devel:      @devel,
        ) { @popout = nil }.build
      end

      def connect
        signal_connect("notify::expanded") { expansion_changed }
        spin_button.signal_connect("notify::value") { spun }
        check_button.signal_connect("notify::active") { ticked }
        counter.on_change { |_counter, what| changed(what) }
        counter.on_color_change { |_counter, previous| recolor(previous) }
        counter.on_delete { discard }
      end

      def expansion_changed
        if expanded?
          scroll_later
        end
      end

      def spun
        counter.value = spin_button.value
        count_label.label = counter.value.to_s
        @store&.queue_write
      end

      def ticked
        counter.checked = check_button.active?
        if counter.checked
          add_css_class("checked")
        else
          remove_css_class("checked")
        end
      end

      def changed(what)
        case what
        when :value then refresh_value
        when :name then refresh_name
        end
      end

      def refresh_value = read

      def refresh_name
        self.title = counter.name
        menu.refresh
      end

      def recolor(previous)
        if Colors.accent?(previous)
          remove_css_class(previous)
        end
        if Colors.accent?(counter.color)
          add_css_class(counter.color_key)
        end
      end

      def discard
        close_popout
        parent.then do |list_box|
          if list_box
            list_box.remove(self)
          end
        end
        @list&.refresh_visibility
      end

      # gdk_content_provider_new_for_value is not bound under that name; the
      # Ruby constructor takes the GLib::Value directly
      # (Gdk::ContentProvider#initialize(value: interface(GLib::Value))). The
      # value has to be typed as the gtype #drop_target was created with, or
      # the provider advertises a format the target never accepts and the drop
      # is silently refused.
      def prepare_drag(pointer_x, pointer_y)
        @drag_x = pointer_x
        @drag_y = pointer_y
        Gdk::ContentProvider.new(GLib::Value.new(Adwaita::ExpanderRow.gtype, self))
      end

      def begin_drag(drag)
        drag_icon_for(drag).child = drag_preview
        drag.set_hotspot(@drag_x.to_i, @drag_y.to_i)
      end

      # The preview is a one-row boxed list rather than a bare row, so the
      # rounded frame and separators the real list draws come along with it.
      def drag_preview
        Gtk::ListBox.new.tap do |box|
          box.add_css_class("tally-list")
          box.add_css_class("boxed-list")
          box.set_size_request(allocation.width, allocation.height)
          CounterDragRow.new(counter, expanded: expanded?).build.tap do |row|
            box.append(row)
            box.drag_highlight_row(row)
          end
        end
      end

      def drag_icon_for(drag)
        if Gtk::DragIcon.respond_to?(:get_for_drag)
          Gtk::DragIcon.get_for_drag(drag)
        else
          Gtk::DragIcon.for_drag(drag)
        end
      end

      # GtkDropTarget::drop hands its handler a GValue, and the Ruby bindings
      # pass that through as a GLib::Value rather than unboxing it to the
      # widget inside — so the row has to be taken out of it. Unwrapping first
      # is what makes the type test below mean anything: tested against the
      # GLib::Value it never matched, and every drag-to-reorder was refused
      # without a sound.
      def accept_drop(value)
        dropped(value).then do |row|
          if row.is_a?(Gtk::ListBoxRow)
            reorder(row)
          else
            false
          end
        end
      end

      def dropped(value)
        if value.is_a?(GLib::Value)
          value.value
        else
          value
        end
      end

      # Both orders move together: the list box's children and
      # Counter.counters, which is what the config file is written from. The
      # target index has to be read before the source row is pulled out,
      # because removing it renumbers everything below it.
      def reorder(source_row)
        list_box = parent
        from = source_row.index
        to = index
        if list_box.nil? || from == to
          false
        else
          apply_reorder(list_box, source_row, to)
        end
      end

      def apply_reorder(list_box, source_row, to)
        @drag_x = nil
        @drag_y = nil
        Counter.for_row(source_row).then do |moved|
          list_box.remove(source_row)
          list_box.insert(source_row, to)
          if moved
            Counter.move(moved, to)
          end
        end
        @store&.queue_write
        true
      end

      def scroll_later
        GLib::Timeout.add(SCROLL_DELAY_MS) do
          @list&.scroll_into_view(self)
          false
        end
      end

      # An ExpanderRow's suffix box only hugs the right edge when it is told to
      # expand; without this the count label drifts left once the spin button
      # is hidden.
      def align_suffixes
        child&.last_child.then do |suffixes|
          if suffixes
            suffixes.hexpand = true
          end
        end
      end
  end
end
