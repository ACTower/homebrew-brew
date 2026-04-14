# ACTower Homebrew Tap

Official Homebrew tap for [ACTower](https://actower.io) — a control tower for supervising multiple AI coding agents.

## Install

```sh
brew tap actower/brew
brew install actower
```

Then run first-time setup:

```sh
actower setup
```

## Usage

```sh
actower monitor      # Terminal dashboard — watch all agent panes
actower responder    # Approval queue — auto-approve safe actions
actower web          # Browser-based UI (paid license required)
actower doctor       # Verify installation health
actower help         # All commands
```

### Typical workflow

```sh
actower setup                                        # first-time only
actower monitor --all --classify --active --alert-done
actower responder --auto --alert
actower web                                          # opens http://127.0.0.1:3000
```

## Requirements

Homebrew installs these automatically as dependencies:

| Dependency | Why |
|---|---|
| `bash` 4+ | macOS ships bash 3.2; actower requires 4+ |
| `tmux` | Required for monitor and responder commands |
| `python@3.11` | Web UI and classifier modules are built against Python 3.11 |

## Web UI setup

`actower setup` creates a Python 3.11 venv at `~/.actower/.venv` with `fastapi` and `uvicorn`. If you skipped setup, create it manually:

```sh
python3.11 -m venv ~/.actower/.venv
~/.actower/.venv/bin/pip install fastapi uvicorn
```

## License

ACTower is commercial software. See [actower.io/pricing](https://actower.io/pricing) for plans.

A free tier is available with limited panes. Activate a paid license with:

```sh
actower login <your-license-key>
```

Get your key at [actower.io/account](https://actower.io/account).
