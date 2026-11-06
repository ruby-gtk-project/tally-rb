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
#
# One hole neither side's Makefile closes: the strings in data/*.desktop and
# data/*.metainfo.xml (Name, Comment, Keywords, <name>, <summary>) reach no
# .pot/.po catalogue at all on either side. Upstream's Makefile only runs
# xgettext over *.lua/*.c, and neither project's data files are templates —
# they are finished files with a translation hand-duplicated onto each key
# (`Name[fr]=…`) that a translator touches directly, bypassing po/ entirely,
# invisible to `pot:check`, and never extended to data/*.metainfo.xml, which
# upstream and the port both ship with zero translations.
#
# This is parity (both sides have the same hole) but not correctness, so this
# round goes beyond parity and closes it: data/*.desktop and
# data/*.metainfo.xml become generated files, built from committed
# data/*.desktop.in and data/*.metainfo.xml.in templates plus po/*.po, the
# same way locale/ would be if Tally::Locale compiled .mo files. `rake pot`
# now also extracts from the templates (via `xgettext -L Desktop` and
# `xgettext --its=metainfo.its`, joined onto the Ruby extraction), `rake po`
# still just merges po/*.po against that one pot, and the new `rake data`
# task runs `msgfmt --desktop`/`msgfmt --xml` to rebuild the real data files.
# `rake data:check` is `pot:check`'s counterpart: it fails when a committed
# data file no longer matches what its template and the catalogues produce.
#
# This finds translations for free: data/*.metainfo.xml had none before (its
# <name>/<summary> were never wired to po/ at all), and now picks up
# whatever po/*.po already has for the identical desktop-entry strings.
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

  # data/*.desktop.in and data/*.metainfo.xml.in are the templates; stripping
  # the trailing ".in" is how each one's generated, real-file counterpart is
  # named — data/foo.desktop.in builds data/foo.desktop.
  DATA_SUFFIX = /\.in\z/

  class << self
    # lib/ and exe/, which is every file that can hold a call site. exe/ is
    # listed with a bare glob because its launcher has no extension.
    def sources = Dir["lib/**/*.rb"].sort + Dir["exe/*"].sort

    def desktop_templates = Dir["data/*.desktop.in"].sort

    def metainfo_templates = Dir["data/*.metainfo.xml.in"].sort

    def data_templates = desktop_templates + metainfo_templates

    def data_output(template) = template.sub(DATA_SUFFIX, "")

    def catalogues = Dir["po/*.po"].sort

    def linguas = catalogues.map { |path| File.basename(path, ".po") }

    # msgfmt's Desktop Entry and XML modes both take `-d DIRECTORY` and read
    # every locale named in `<directory>/LINGUAS`, not every `*.po` file that
    # happens to be there — pass a bare `-d po` with no LINGUAS and it merges
    # nothing, silently. po/LINGUAS is therefore generated, not hand-kept: it
    # would drift the moment a catalogue is added or removed otherwise.
    def write_linguas
      File.write("po/LINGUAS", "#{linguas.join("\n")}\n")
    end

    # The ITS (Internationalization Tag Set) rule file that tells xgettext
    # and msgfmt which elements of a *.metainfo.xml are translatable
    # (<name>, <summary>, …) and which are not (<id>, <url>, …). GNU gettext
    # ships one; msgfmt --xml locates it on its own by filename pattern
    # (*.metainfo.xml), but xgettext extraction needs the path explicitly, so
    # it is found once here relative to wherever this devShell put msgfmt.
    def its_file
      File.join(
        File.dirname(File.dirname(which("msgfmt"))),
        "share",
        "gettext-1.0",
        "its",
        "metainfo.its",
      )
    end

    def which(name)
      ENV.fetch("PATH", "").split(File::PATH_SEPARATOR)
        .map { |dir| File.join(dir, name) }
        .find { |path| File.executable?(path) }
    end

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
        "--no-wrap",
        "--output=#{into}",
        *sources,
      ]
    end

    def version
      Module.new.tap { |mod| Kernel.load("lib/tally/rb/version.rb", mod) }
        .then { |mod| mod::Tally::Rb::Version::VERSION }
    end

    # Joined onto the pot that `command` above just wrote. `--desktop` is a
    # msgfmt mode, not a language xgettext understands by that name — the
    # language is `Desktop`, and it recognises Name/Comment/Keywords (and a
    # few others this project does not use) as translatable by default, so
    # no --keyword flags are needed here either.
    def desktop_command(into)
      [
        "xgettext",
        "--join-existing",
        "--language=Desktop",
        "--package-name=#{PACKAGE}",
        "--package-version=#{version}",
        "--msgid-bugs-address=#{BUGS_TO}",
        "--no-wrap",
        "--output=#{into}",
        *desktop_templates,
      ]
    end

    # *.metainfo.xml.in does not end in *.metainfo.xml, so xgettext's own
    # filename-based ITS lookup (the one msgfmt's merge step relies on below)
    # never fires on the template; the rule file is named explicitly instead.
    def metainfo_command(into)
      [
        "xgettext",
        "--join-existing",
        "--its=#{its_file}",
        "--package-name=#{PACKAGE}",
        "--package-version=#{version}",
        "--msgid-bugs-address=#{BUGS_TO}",
        "--no-wrap",
        "--output=#{into}",
        *metainfo_templates,
      ]
    end

    def extract(into)
      into.tap do |target|
        unless available?
          abort("rxgettext/xgettext are not on PATH. Run this inside `nix develop`, or install the gettext gem and GNU gettext.")
        end
        system(UNBUNDLED, *command(target), exception: true)
        if desktop_templates.any?
          system(UNBUNDLED, *desktop_command(target), exception: true)
        end
        if metainfo_templates.any?
          system(UNBUNDLED, *metainfo_command(target), exception: true)
        end
        File.write(target, File.read(target).gsub(DATE_LINES, ""))
      end
    end

    def available? = %w[rxgettext xgettext msgfmt].all? { |tool| which(tool) }

    # Rebuilds every data/*.desktop and data/*.metainfo.xml from its .in
    # template and po/*.po. msgfmt's Desktop Entry and XML modes each merge
    # one template at a time but every locale in po/LINGUAS at once, which is
    # why `write_linguas` runs first: without it msgfmt merges nothing and
    # warns "po/LINGUAS does not exist" instead of failing, so a stale or
    # missing LINGUAS file would silently ship untranslated data files.
    def build_data
      unless which("msgfmt")
        abort("msgfmt is not on PATH. Run this inside `nix develop`.")
      end
      write_linguas
      desktop_templates.each { |template| build_desktop(template) }
      metainfo_templates.each { |template| build_metainfo(template) }
    end

    def build_desktop(template)
      system(

        UNBUNDLED,
        "msgfmt",
        "--desktop",
        "-d",

        "po",
        "--template=#{template}",
        "--output-file=#{data_output(template)}",
        exception: true,

      )
    end

    # Unlike desktop files, msgfmt --xml locates the ITS rule file itself —
    # but only when the *output* filename matches "*.metainfo.xml", which is
    # exactly what `data_output` produces by stripping the template's ".in".
    def build_metainfo(template)
      system(

        UNBUNDLED,
        "msgfmt",
        "--xml",
        "-d",

        "po",
        "--template=#{template}",
        "--output-file=#{data_output(template)}",
        exception: true,

      )
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

# The build step data/*.desktop and data/*.metainfo.xml never had: upstream's
# Makefile has no rule for them at all, and before this round neither did
# this port — they were finished files with a translation hand-duplicated
# onto each key. `rake data` makes them generated, the same way `rake po`
# makes po/*.po generated from po/MESSAGES.pot.
desc "Rebuild data/*.desktop and data/*.metainfo.xml from their .in templates and po/*.po"
task data: :po do
  TallyGettext.build_data
  TallyGettext.data_templates.each { |template| puts "wrote #{TallyGettext.data_output(template)}" }
end

# Same shape as pot:check: rebuild into a scratch copy of data/ and diff
# against what is committed, rather than overwrite the real files and ask
# `git diff` to notice. The scratch build runs against the *committed*
# po/*.po — it does not run `rake po` first — so this also catches a catalogue
# that was hand-edited without the matching data file being regenerated.
desc "Fail unless data/*.desktop and data/*.metainfo.xml match their templates and po/*.po"
task "data:check" do
  TallyGettext.data_templates.then do |templates|
    if templates.empty?
      abort("no *.desktop.in/*.metainfo.xml.in templates in data/ — something has gone wrong with the checkout.")
    end
    TallyGettext.write_linguas
    scratch_dir = "tmp/data-check"
    FileUtils.rm_rf(scratch_dir)
    FileUtils.mkdir_p(scratch_dir)
    templates.each do |template|
      FileUtils.cp(template, File.join(scratch_dir, File.basename(template)))
    end
    stale = templates.reject do |template|
      scratch_template = File.join(scratch_dir, File.basename(template))
      scratch_output = TallyGettext.data_output(scratch_template)
      if template.end_with?(".desktop.in")
        TallyGettext.build_desktop(scratch_template)
      else
        TallyGettext.build_metainfo(scratch_template)
      end
      File.read(scratch_output) == File.read(TallyGettext.data_output(template))
    end
    if stale.empty?
      puts "data/*.desktop and data/*.metainfo.xml are up to date."
    else
      warn("out of date: #{stale.map { |t| TallyGettext.data_output(t) }.join(", ")}")
      warn("Run `rake data` and commit the result.")
      abort
    end
  ensure
    if scratch_dir
      FileUtils.rm_rf(scratch_dir)
    end
  end
end
