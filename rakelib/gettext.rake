# frozen_string_literal: true

require "fileutils"

# Translation catalogue tasks — the port of upstream's Makefile gettext rules.
#
# Upstream's Makefile has three:
#
#   po/MESSAGES.pot: $(LSRCS) $(CSRCS)   xgettext --from-code utf-8 -o $@ $^
#   po/%.po: $(POTFILE)                  msginit if absent, then msgmerge -U
#   locale/%/LC_MESSAGES/messages.mo     msgfmt
#
# The first two carry over as `rake pot` and `rake po`. The third does not:
# Tally::Locale reads po/*.po directly at startup rather than compiled .mo
# files, so there is nothing to compile.
#
# This file exists because its absence is self-concealing. With no extraction
# task, a `_("…")` added to the port is never compared against the catalogues,
# and a label that can never be translated looks exactly like one that can.
# `rake pot:check` is the CI half: it fails when the committed pot no longer
# matches the source.
module TallyGettext
  POT_FILE = "po/MESSAGES.pot"
  CHECK_FILE = "po/.MESSAGES.pot.check"
  PACKAGE = "tally-rb"
  BUGS_TO = "https://github.com/ruby-gtk-project/tally-rb/issues"

  # Both of rxgettext's date headers are timestamps, so leaving them in would
  # make every run of `rake pot` a diff and `rake pot:check` useless. Dropping
  # the lines is the usual remedy and costs nothing: a template's revision date
  # is meaningless, and msgmerge supplies each catalogue's own.
  DATE_LINES = /^"(?:POT-Creation-Date|PO-Revision-Date):.*\n/

  # rxgettext is not in this project's bundle and does not need to be — it
  # is a tool, not a dependency, and the devShell puts it on PATH. But rake
  # runs inside the bundle, and three environment variables make the child
  # process join it: RUBYOPT carries `-rbundler/setup`, BUNDLE_GEMFILE names
  # the bundle, and BUNDLER_SETUP is re-required by rubygems itself before
  # the script even starts. Inheriting any of them makes rxgettext fail with
  # "can't find executable rxgettext for gem gettext" or with a platform
  # complaint about this repository's own Gemfile.lock, so all three are
  # cleared. GEM_PATH is deliberately kept: that is where the gem lives.
  UNBUNDLED = {
    "RUBYOPT"         => nil,
    "BUNDLER_SETUP"   => nil,
    "BUNDLE_GEMFILE"  => nil,
    "BUNDLE_BIN_PATH" => nil,
  }.freeze

  class << self
    # lib/ and exe/, which is every file that can hold a call site. exe/ is
    # listed with a bare glob because its launcher has no extension.
    def sources = Dir["lib/**/*.rb"].sort + Dir["exe/*"].sort

    def catalogues = Dir["po/*.po"].sort

    # rxgettext, from the gettext gem, and not GNU xgettext: GNU gettext 1.0
    # lists Ruby among its languages but only shells out to rxgettext for it,
    # so `xgettext --language=Ruby` without the gem installed fails with
    # "rxgettext subprocess failed". Calling rxgettext directly is the same
    # extraction with one less layer. Its RubyParser already treats `_` and
    # `N_` as keywords, which is why no --keyword flag appears here; there is
    # no such option to pass.
    def command(into)
      [
        "rxgettext",
        "--add-comments=TRANSLATORS:",
        "--package-name=#{PACKAGE}",
        "--package-version=#{version}",
        "--msgid-bugs-address=#{BUGS_TO}",
        "--sort-by-file",
        "--output=#{into}",
        *sources,
      ]
    end

    def version
      Module.new.tap { |mod| Kernel.load("lib/tally/rb/version.rb", mod) }
        .then { |mod| mod::Tally::Rb::Version::VERSION }
    end


    def extract(into)
      into.tap do |target|
        unless available?
          abort("rxgettext is not on PATH. Run this inside `nix develop`, or install the gettext gem.")
        end
        system(UNBUNDLED, *command(target), exception: true)
        File.write(target, File.read(target).gsub(DATE_LINES, ""))
      end
    end

    def available?
      ENV.fetch("PATH", "").split(File::PATH_SEPARATOR)
        .any? { |dir| File.executable?(File.join(dir, "rxgettext")) }
    end

    # One less than the msgid count, because the header entry is an empty
    # msgid of its own.
    def msgid_count(path) = File.read(path).scan(/^msgid "/).length - 1
  end
end

desc "Extract translatable strings from lib/ and exe/ into po/MESSAGES.pot"
task :pot do
  TallyGettext.extract(TallyGettext::POT_FILE).then do |path|
    puts "wrote #{path} — #{TallyGettext.msgid_count(path)} msgids"
  end
end

# The scratch file goes next to the real one, not in /tmp: rxgettext writes its
# `#:` references relative to the output file's directory, so extracting
# somewhere else produces a different — and much longer — set of paths and the
# comparison fails for a reason that has nothing to do with the strings.
desc "Fail unless po/MESSAGES.pot is up to date with the source"
task "pot:check" do
  TallyGettext::CHECK_FILE.then do |scratch|
    TallyGettext.extract(scratch)
    if File.read(scratch) == File.read(TallyGettext::POT_FILE)
      puts "#{TallyGettext::POT_FILE} is up to date."
    else
      warn("#{TallyGettext::POT_FILE} is out of date. Run `rake pot` and commit the result.")
      warn(`diff -u #{TallyGettext::POT_FILE} #{scratch}`)
      abort
    end
  ensure
    FileUtils.rm_f(scratch)
  end
end

desc "msgmerge -U every catalogue in po/ against po/MESSAGES.pot"
task po: :pot do
  TallyGettext.catalogues.each do |catalogue|
    system(
      "msgmerge",
      "--update",
      "--backup=none",
      catalogue,
      TallyGettext::POT_FILE,
      exception: true,
    )
  end
end

# The third of upstream's Makefile rules — `msgfmt -o locale/%/LC_MESSAGES/
# messages.mo` — does not carry over as a build step, because Tally::Locale
# reads po/*.po directly and there is no .mo to compile. What does carry over
# is the *validation* msgfmt does on the way: a catalogue with a broken escape,
# a format specifier the msgid does not have, or a malformed header is a
# catalogue that would have failed upstream's build and passes silently here.
#
# Templates are excluded deliberately. po/MESSAGES.pot carries rxgettext's
# placeholder plural-forms line, which msgfmt rejects as an invalid nplurals
# value; that is correct for a template and tells us nothing about the
# translations.
desc "Validate every catalogue in po/ with msgfmt -c"
task "po:lint" do
  TallyGettext.catalogues.then do |catalogues|
    if catalogues.empty?
      abort("no catalogues in po/ — something has gone wrong with the checkout.")
    end
    catalogues.each do |catalogue|
      system(
        "msgfmt",
        "--check",
        "--check-format",
        "--output-file=#{File::NULL}",
        catalogue,
        exception: true,
      )
      puts "#{catalogue} is valid."
    end
  end
end
