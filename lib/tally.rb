# frozen_string_literal: true

# Backends and models, which the widgets below are built on. tally/rb is the
# display-free half of the library — the models, the catalogues, the config
# backend, the AppStream reader and the version — and it is separate because
# requiring gtk4 initialises GTK and fails outright without a display, which
# the specs for that half should not have to care about.
require_relative "tally/rb"
require_relative "tally/icons"
require_relative "tally/styles"

# Widgets, in dependency order: the pieces of a row, then the row, then the
# list, then the window, then the dialogs it opens.
require_relative "tally/color_selector"
require_relative "tally/counter_menu"
require_relative "tally/counter_drag_row"
require_relative "tally/counter_window"
require_relative "tally/counter_row"
require_relative "tally/counter_list"
require_relative "tally/search_bar"
require_relative "tally/empty_state"
require_relative "tally/main_menu"
require_relative "tally/about_dialog"
require_relative "tally/shortcuts_dialog"
require_relative "tally/new_counter_dialog"
require_relative "tally/main_window"
require_relative "tally/application"
