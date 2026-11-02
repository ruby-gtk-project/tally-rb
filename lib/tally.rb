# frozen_string_literal: true

require_relative "tally/rb/version"

# Backends and models, which the widgets below are built on.
require_relative "tally/locale"
require_relative "tally/colors"
require_relative "tally/counter"
require_relative "tally/store"
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
