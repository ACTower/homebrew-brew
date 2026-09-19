# typed: false
# frozen_string_literal: true

class Actower < Formula
  # ── Release config ────────────────────────────────────────────────────────
  # To release a new version:
  #   1. Upload the tarball to S3 (scripts/release.sh)
  #   2. Update VERSION (and STAGE if promoting to prod)
  #   3. Recalculate sha256:
  #        curl -L "https://#{S3_BUCKET}.s3.us-west-2.amazonaws.com/#{STAGE}/v#{VERSION}/actower-#{VERSION}.tar.gz" \
  #          -o actower-#{VERSION}.tar.gz && shasum -a 256 actower-#{VERSION}.tar.gz
  #   4. Update sha256 below
  S3_BUCKET = "actower-releases"
  S3_REGION = "us-west-2"
  STAGE     = "prod"    # Switch to "prod" for production releases
  VERSION   = "1.2.15"
  # ─────────────────────────────────────────────────────────────────────────

  desc "Control tower for AI coding agents — monitor, approve, and audit"
  homepage "https://actower.io"

  url "https://#{S3_BUCKET}.s3.#{S3_REGION}.amazonaws.com/#{STAGE}/v#{VERSION}/actower-#{VERSION}.tar.gz"
  sha256 "bd805e598978975853adb1416c8db4af9d4ce291aff3f939a9db2fed5bee860f"
  version VERSION

  # ACTower is commercial software; the source is not open.
  license :cannot_represent

  # macOS ships bash 3.2 (held back due to GPLv3); actower-core.bash requires bash 4+.
  # Homebrew bash installs to /opt/homebrew/bin/bash (Apple Silicon) or
  # /usr/local/bin/bash (Intel) — both are checked first by bin/actower's find_bash4().
  depends_on "bash"

  # tmux is required for the monitor and responder commands.
  depends_on "tmux"

  # PyArmor-obfuscated Python libs (classify_question, web server, adapters, etc.)
  # are ABI-locked to the Python minor version used at build time (3.11).
  # Python 3.12+ and 3.10- will NOT work for those modules.
  depends_on "python@3.11"

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

  def post_install
    # ── Install marker (Phase B of install-method-awareness, v1.2.14+) ──
    # Mirrors install.sh's marker write on curl installs. Records that this
    # install was performed via brew so `actower`'s shadow-active-install
    # helper can route bare invocations transparently into the marker's
    # binary (fixes the curl-vs-brew PATH shadowing surprise Item 4b flagged).
    #
    # ~/.actower/install-marker.json is the SAME path install.sh writes to
    # on curl installs — last-write-wins semantics, whichever install
    # happened most recently owns the marker.
    #
    # Fail-soft by design: a marker that can't be written costs diagnostic
    # quality, never a working install. quiet_system returns true/false and
    # suppresses stdout/stderr — non-zero exit is a silent no-op.
    #
    # No-op before v1.2.14: install_marker.py first shipped in libexec/lib
    # in the v1.2.14 tarball, so an older tarball's post_install falls
    # through as a silent ImportError with no marker written.
    if OS.mac? && (libexec/"lib/install_marker.py").exist?
      marker_home = "#{ENV["HOME"]}/.actower"
      FileUtils.mkdir_p(marker_home, mode: 0o700)

      python = Formula["python@3.11"].opt_bin/"python3.11"
      quiet_system python, "-c",
        "import sys; sys.path.insert(0, sys.argv[1]); " \
        "from install_marker import write_marker; " \
        "write_marker(path=sys.argv[2], method='brew', " \
        "version=sys.argv[3], cli_path=sys.argv[4])",
        "#{libexec}/lib",
        "#{marker_home}/install-marker.json",
        VERSION,
        "#{bin}/actower"
    end

    # Kickstart the io.actower.web LaunchAgent when it's already loaded, so
    # `brew upgrade actower` immediately picks up the new binary/assets instead
    # of the running backend continuing to serve pre-upgrade code in memory.
    # Mirrors the same kickstart install.sh runs on curl upgrades (Item 19).
    #
    # Silent no-op on:
    #   - non-macOS (Linuxbrew) — launchctl is macOS-only
    #   - fresh installs where the LaunchAgent isn't set up yet
    #   - users running `actower web`/`actower desktop` in a foreground terminal
    #     (that process is theirs to restart)
    return unless OS.mac?

    uid = Process.uid
    launchctl = "/bin/launchctl"

    # `launchctl print` returns 0 when the service is loaded, non-zero when
    # defined-but-unloaded or absent. Preferred over `launchctl list | grep`
    # because print cleanly distinguishes loaded from defined-but-unloaded.
    # Use quiet_system (not system) — Homebrew's Formula#system raises
    # ErrorDuringExecution on non-zero exit, which would fail the whole
    # post_install step on the common fresh-install case. quiet_system
    # returns true/false and suppresses stdout/stderr.
    return unless quiet_system launchctl, "print", "gui/#{uid}/io.actower.web"

    # -k forces the restart even if the service is currently running. Silent
    # no-fail: a kickstart failure must never break `brew upgrade actower`.
    ohai "Restarting Web UI service to load new code..."
    if quiet_system launchctl, "kickstart", "-k", "gui/#{uid}/io.actower.web"
      ohai "Web UI service restarted"
    else
      opoo "Web UI restart failed — run manually if you use the desktop app: " \
           "launchctl kickstart -k gui/#{uid}/io.actower.web"
    end
  end

  def caveats
    <<~EOS
      Run first-time setup to create config and verify dependencies:
        actower setup

      To enable the web UI (actower web), setup also creates a Python 3.11
      venv at ~/.actower/.venv with fastapi and uvicorn. If setup was
      skipped, create it manually:
        python3.11 -m venv ~/.actower/.venv
        ~/.actower/.venv/bin/pip install fastapi uvicorn

      Quick start:
        actower doctor       # verify installation health
        actower monitor      # terminal dashboard
        actower web          # browser-based UI (paid license)
        actower help         # all commands
    EOS
  end

  test do
    # actower --version is fully supported and exits 0.
    assert_match "Agent Control Tower v#{version}", shell_output("#{bin}/actower --version")
  end
end
