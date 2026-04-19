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
  STAGE     = "qa" for production releases
  VERSION   = "0.3.11"
  # ─────────────────────────────────────────────────────────────────────────

  desc "Control tower for AI coding agents — monitor, approve, and audit"
  homepage "https://actower.io"

  url "https://#{S3_BUCKET}.s3.#{S3_REGION}.amazonaws.com/#{STAGE}/v#{VERSION}/actower-#{VERSION}.tar.gz"
  sha256 "432ccdb710944d442cce5b412808b5e123f1bede67dd0135d39703d66599d54e"
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
