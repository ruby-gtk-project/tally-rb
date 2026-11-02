# frozen_string_literal: true

# Produces data/screenshot.png — the picture README.md shows, which is this
# port's answer to upstream's tally.png.
#
# It is a script rather than a checked-in-and-forgotten PNG because a
# screenshot rots: the window it shows is a build of the app from the day
# someone happened to take it, and nothing says when that stopped being what
# the app looks like. Re-running this regenerates it from the current code.
#
#   nix develop --command xvfb-run -a ruby test/shoot_screenshot.rb
#
# The state in the picture is seeded through the config file rather than by
# driving the dialog, because the window reads store.saved_counters when it
# builds and that is the one path that puts counters on screen with values and
# colours already set.

require "fileutils"
require "json"
require "tmpdir"

# A scratch config directory, so a run never reads or writes the real one.
ENV["XDG_CONFIG_HOME"] = Dir.mktmpdir("tally-shoot")

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "tally"
require_relative "gtk_driver"

SHOT_DIR = File.expand_path("../data", __dir__)
SHOT_NAME = "screenshot"

# Three counters, in the three states the list can show: one plain, and two
# carrying a colour, which is what makes the coloured rows visible in the
# picture.
DOCUMENT = {
  "width"    => 540,
  "height"   => 420,
  "counters" => [
    {"name" => "Cups of coffee", "value" => 3, "color" => "orange"},
    {"name" => "Glasses of water", "value" => 6, "color" => "blue"},
    {"name" => "Pull-ups", "value" => 12, "color" => nil},
  ],
}.freeze

Tally::Store.default.then do |store|
  FileUtils.mkdir_p(store.dir)
  File.write(store.path, JSON.pretty_generate(DOCUMENT))
end

Tally::Counter.clear

GtkDriver.drive(Tally::Application.new, shots: SHOT_DIR) do |d, app|
  d.window { app.window }

  d.step("the window builds with the seeded counters") do
    d.check("three rows") { app.window.rows.length == 3 }
    d.check("the list is the content") do
      app.window.toolbar_view.content.equal?(app.window.counter_list)
    end
    d.check("the values came off disk") do
      app.window.rows.map { |row| row.counter.value } == [3, 6, 12]
    end
  end

  # A tick later than the build: a window whose content changed in this tick
  # has not been laid out again yet, and Gtk::WidgetPaintable then produces no
  # render node at all rather than a stale picture.
  d.step("the window renders into #{File.join("data", "#{SHOT_NAME}.png")}") do
    d.check("the shot was written") { !d.shot(SHOT_NAME).nil? }
  end
end
