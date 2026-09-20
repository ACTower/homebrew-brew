# typed: false
# frozen_string_literal: true

class Actower < Formula
  # ── Release config ────────────────────────────────────────────────────────
  # The three release lines below (STAGE, VERSION, sha256) are rewritten by
  # actower/scripts/deploy.sh on `--stage prod`, which also commits and pushes
  # this file. Keep their exact `NAME   = "..."` / `sha256 "..."` shape — the
  # deploy script matches on it and refuses to continue if a pattern misses.
  # Manual fallback:
  #   curl -L "https://#{S3_BUCKET}.s3.us-west-2.amazonaws.com/#{STAGE}/v#{VERSION}/actower-#{VERSION}.tar.gz" \
  #     -o actower-#{VERSION}.tar.gz && shasum -a 256 actower-#{VERSION}.tar.gz
  S3_BUCKET = "actower-releases"
  S3_REGION = "us-west-2"
  STAGE     = "prod" # dev|qa never touch this formula; brew users get prod only
  VERSION   = "1.2.15"
  # ─────────────────────────────────────────────────────────────────────────

  desc "Control tower for AI coding agents — monitor, approve, and audit"
  homepage "https://actower.io"

  url "https://#{S3_BUCKET}.s3.#{S3_REGION}.amazonaws.com/#{STAGE}/v#{VERSION}/actower-#{VERSION}.tar.gz"
  version VERSION
  sha256 "bd805e598978975853adb1416c8db4af9d4ce291aff3f939a9db2fed5bee860f"

  # ACTower is commercial software; the source is not open.
  license :cannot_represent

  # macOS ships bash 3.2 (held back due to GPLv3); actower-core.bash requires bash 4+.
  # Homebrew bash installs to /opt/homebrew/bin/bash (Apple Silicon) or
  # /usr/local/bin/bash (Intel) — both are checked first by bin/actower's find_bash4().
  depends_on "bash"

  # PyArmor-obfuscated Python libs (classify_question, web server, adapters, etc.)
  # are ABI-locked to the Python minor version used at build time (3.11).
  # Python 3.12+ and 3.10- will NOT work for those modules.
  depends_on "python@3.11"

  # tmux is required for the monitor and responder commands.
  depends_on "tmux"

  def install
    # Install all support files under libexec/ to avoid collisions with
    # other Homebrew formulas that also install into lib/ or share/.
    libexec.install Dir["bin", "libexec", "lib", "share"]

    # Symlink the POSIX launcher into bin/. The launcher already contains
    # a resolve_symlink() helper that was written for Homebrew compatibility —
    # it resolves the symlink before computing sibling directory paths, so
    # libexec/ and lib/ are always found correctly regardless of the symlink.
    bin.install_symlink libexec/"bin/actower"
  end

  # Post-install runs inside Homebrew's sandbox with an ISOLATED, temporary
  # $HOME — nothing written under ~/.actower from here ever reaches the user.
  # That is why the install-marker write that lived here in v1.2.14/v1.2.15
  # never landed (Settings read "Installed via: Unknown" on brew-only
  # machines), and why the venv cannot be created here either. Both are done
  # by the CLI itself, in the user's own shell, the first time it runs:
  #   - install marker: actower-core.bash first-run helper (v1.2.15)
  #   - ~/.actower/.venv: actower web / desktop / setup self-heal (v1.2.16)
  # Keep this block free of anything that needs the real home directory.
  #
  # Homebrew 7 deprecates `def post_install` in favour of the declarative
  # `post_install_steps` DSL; this is the same LaunchAgent kickstart as before
  # (Item 19), expressed as a step.
  post_install_steps do
    on_macos do
      # Restart the io.actower.web LaunchAgent so `brew upgrade actower` picks
      # up the new code instead of the running backend serving pre-upgrade
      # code from memory. Mirrors install.sh's kickstart on curl upgrades.
      #
      # `kickstart -k` on a service that is not loaded (fresh install, or a
      # user who runs `actower web`/`actower desktop` in a foreground
      # terminal) exits non-zero — that is the expected no-op, so the step
      # must not fail the install and must not print launchctl's complaint.
      #
      # Steps are declarative and serialised, so the uid cannot be computed
      # in Ruby here (the DSL has no uid token); `id -u` inside /bin/sh
      # resolves it at run time for whoever is running brew.
      run "/bin/sh",
          args:         ["-c", "/bin/launchctl kickstart -k gui/$(id -u)/io.actower.web"],
          must_succeed: false,
          print_stderr: false
    end
  end

  def caveats
    <<~EOS
      Launch ACTower:
        actower desktop      # desktop app (macOS)
        actower web          # browser-based UI, any platform

      The first launch sets up ACTower's Python environment (~/.actower/.venv,
      python3.11 + web dependencies). It takes about a minute and prints its
      progress; every later launch is instant.

      Quick start:
        actower doctor       # verify installation health
        actower monitor      # terminal dashboard
        actower help         # all commands
    EOS
  end

  test do
    # actower --version is fully supported and exits 0.
    assert_match "Agent Control Tower v#{version}", shell_output("#{bin}/actower --version")
  end
end
