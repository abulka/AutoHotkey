# AGENTS.md

Guidance for agents/automation working in this repo.

## Docs map

- [`README.md`](README.md) — user-facing install/run instructions (Windows + Linux).
  Add end-user usage here; do not put internals here.
- [`docs/linux-port-internals.md`](docs/linux-port-internals.md) — technical source
  of truth for the Linux lane (environment, architecture, port defects and their
  workarounds, testing/debugging recipes, history). **Read this before touching
  Linux-gated code or when debugging under Linux.**
- `AGENTS.md` — this file: environment facts and repo conventions for agents.

Do not duplicate README sections into the internals doc, or vice versa; link instead.

## Environment

- **Windows**: AutoHotkey **v2** is installed at `C:\Program Files\AutoHotkey`
  (main interpreter: `C:\Program Files\AutoHotkey\v2\AutoHotkey.exe`). It is **not
  on `PATH`**, so `ahk` is not a command here — invoke the full path or
  `AutoHotkey64.exe`.
- **Linux**: the AHK v2 Linux port `v2.0.26-linux.23` runs inside the distrobox
  container `ahk` (`ubuntu:24.04`); use `run_bar_cheat_distrobox.sh`. Details and
  rationale are in `docs/linux-port-internals.md`.
- **WSL**: the WSL **Ubuntu-24.04** distro already has the Linux port installed
  natively (`~/.local/bin/ahk`, v2.0.26-linux.23) plus `xvfb-run`, and this repo
  is visible under `/mnt/c/...`. The Linux lane is therefore testable directly
  there — **no distrobox involved** (distrobox is only for the Silverblue host).

## Project map

| Path | Purpose |
|---|---|
| `bar_cheat.ahk` | The app: single cross-platform source (~2.6k lines, Windows + Linux) |
| `gen_wsl.py` | Generates the diagnostic build `bar_cheat_wsl.ahk` |
| `bar_cheat_wsl.ahk` | **Generated** diagnostic build (injects OnError log + GUI auto-open) — see "Generated files" |
| `bar_web_scraper.py` | Scrapes unit data/images from beyondallreason.info |
| `run_bar_cheat_distrobox.sh` | Linux launcher (distrobox, x11 backend, `/dev/uinput` hint) |
| `bar_cheats.txt` | Cheat/unit data (see "Data model") |
| `bar_units*.txt` | Scraper output; `bar_units_<faction>.txt` are the `--check` baselines |
| `unit_images/` | Unit preview PNG cache (`<code>.png`) |

## Data model

- `bar_cheats.txt` has **scraper-owned managed blocks** (`Armada *` / `Cortex *`
  categories) and a hand-edited `Cheat` category. **Do not hand-edit the managed
  blocks** — regenerate via `bar_web_scraper.py --merge`.
- `bar_units_<faction>.txt` (armada/cortex) are the baselines the scraper diffs
  against in `--check`.

## Generated files

- `bar_cheat_wsl.ahk` is produced by `gen_wsl.py` **and is tracked in git**, so
  after any `bar_cheat.ahk` edit you must **regenerate it and commit it too** —
  otherwise the committed build drifts from the source. Never hand-edit it.
- State/settings files (`bar_cheat.ini`, `bar_cheats_recent.txt`,
  `bar_cheats_favorites.txt`, `bar_treeview_state_*.txt`, `wsl_dbg.log`) are
  gitignored and live next to the script; keep them out of commits.

## Tooling & commands

- Python **3.13**, managed by **uv** (`.python-version`, `uv.lock`). Use
  `uv run python …`; do not pip-install into `.venv`.
- Refresh unit data/images:
  ```bash
  uv run python bar_web_scraper.py --check --faction all                 # dry run
  uv run python bar_web_scraper.py --faction all --merge bar_cheats.txt  # apply
  ```
  Requires network access to beyondallreason.info.
- Regenerate the diagnostic build after editing `bar_cheat.ahk`:
  `python3 gen_wsl.py` (or `uv run python gen_wsl.py`).
- `ahk --check` does **not** parse the script — it only reports install
  integrity. Syntax/load validation and headless testing use the recipes in
  `docs/linux-port-internals.md` (top-sentinel check, `xvfb-run`, diagnostic build).
- No lint/typecheck/test suite is configured in-repo.

## Conventions

- `bar_cheat.ahk` is a **single cross-platform source**; Linux-only behavior is
  gated behind `IsWslPort`. Don't fork per-platform copies.
- Shared functions are edited in place (`DoPaste`, `UpdateAmountArea`,
  `GuiLayout`, `SaveWindowPos`), so re-run a quick **Windows smoke pass** after
  changing shared code — all Linux code is gated, but these paths are not.
- Commit messages: `area: imperative summary` with a lowercase prefix
  (`linux:`, `docs:`, `units:`, …), plus a body explaining *why*.

## Repo

- Remote `git@github.com:abulka/AutoHotkey.git`, default branch `main`.
