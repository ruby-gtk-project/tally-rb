# frozen_string_literal: true

# The one target that has to pass before a report is written.
#
# Round 1 of this port reported "105 driven checks across 34 steps, both green"
# through two commits of behaviour, including the commit that took the driver
# to 214 checks. The sentence read as the output of a run; no run had happened.
# The remedy is not a resolution to be careful — it is a target that runs
# everything a report quotes, so that quoting a number means having run it.
#
# `rake check` runs the display-free half: the specs, the catalogue lint and
# the extraction check. The driver is deliberately *not* in it, because it
# needs a display and a Nix shell; it is named in the output instead, with the
# command to run, so leaving it out is a decision and not an omission.

RSPEC_RUNNER = <<~RUBY
  require "rspec/core"
  exit(RSpec::Core::Runner.run(["--format", "progress", "--require", "spec_helper", "spec"]))
RUBY

unless Rake::Task.task_defined?("spec")
  desc "Run the RSpec suite"
  task :spec do
    # The same unbundling rxgettext needs: rspec comes from the dev shell, not
    # from this project's bundle, so the three Bundler variables rake exports
    # have to be cleared or the child process fails resolving a Gemfile it has
    # nothing to do with.
    system(TallyGettext::UNBUNDLED, "ruby", "-e", RSPEC_RUNNER, exception: true)
  end
end

desc "Run the specs, the catalogue lint and the extraction check"
task check: [:spec, "po:lint", "pot:check", "data:check"] do
  puts
  puts "check passed. The widget half needs a display and is not in this target:"
  puts "  nix develop --command xvfb-run -a ruby test/drive_tally.rb"
end
