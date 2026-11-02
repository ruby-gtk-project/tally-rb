# frozen_string_literal: true

require_relative "rb/version"

# The part of Tally that loads without a display.
#
# This file exists because `require "gtk4"` initialises GTK at require time and
# raises Gtk::InitError when there is no display server, so anything that
# reaches a widget class cannot be loaded by a plain `ruby -e` or by a test
# process on a headless machine. The split is along that line and no other:
#
#   require "tally/rb"   the models, the catalogues, the config backend and the
#                        AppStream reader — no gtk4, no adwaita, loadable
#                        anywhere;
#   require "tally"      all of the above plus every widget and the
#                        application, which needs a display.
#
# It is also the file the gem's version constant lives under, which is why
# spec/spec_helper.rb requires it: the specs for the display-free half need
# nothing more, and the ones that drive widgets ask for "tally" themselves.
require_relative "locale"
require_relative "colors"
require_relative "counter"
require_relative "lua_config"
require_relative "store"
require_relative "metainfo"
