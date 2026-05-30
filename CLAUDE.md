# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

`ev` is a macOS/zsh terminal file searcher (Windows "Everything" style). It is a thin wrapper over `rg` + `fzf` + `fd` with text extraction for office documents. No build step; it is a single zsh script plus sourced helpers.

## Commands

```bash
bats test/                       # full suite (77 tests)
bats test/cli.bats               # one file
bats test/cli.bats -f "open"     # one test by name substring
zsh -n ev                        # syntax-check the main script
./ev [dir]                       # run the interactive TUI (needs a real TTY)
./ev -g <query> [dir]            # non-interactive content search (composable)
```

Interactive `fzf` cannot run without a TTY, so it is **not** covered by automated tests. After changing TUI bindings, verify against `docs/MANUAL-CHECKLIST.md` by hand.

## Architecture

**Single entry, sub-command dispatch.** `ev` ends with a `case "$1"` dispatcher:
- No/`*` arg → `_ev_main` launches `fzf` (interactive TUI).
- `__search`, `__preview`, `__open`, `__toggle-hidden`, `__cycle-scope`, `__export-results`, `__copy-paths`, `__zip-files`, `__init` → hidden sub-commands **invoked by fzf key bindings** (`reload`/`transform`/`become`/`execute-silent`), not by users.
- `-l/-g/-x/--to-txt` → non-interactive CLI for piping/export.

**fzf ↔ sub-command contract** (the core mechanism, read `_ev_main`):
- The current query reaches sub-commands via the `FZF_QUERY` env var — **not** `{}`/`{q}` placeholders (avoids placeholder-expansion fragility).
- UI state lives in files under a per-run `EV_STATE="$(mktemp -d)"` dir: `mode` is unused legacy, actual state is `scope` (`both|files|content`) and `hidden` (`0|1`). Bindings call `ev __cycle-scope` / `ev __toggle-hidden` which flip the state file and emit fzf actions on stdout for `transform(...)`.
- `EV_ROOT` (absolute search root) and `EV_EXTRACTOR` (`libexec/ev-extract`) are exported into the environment for sub-commands.

**`lib/*.sh` are pure, sourced, bats-tested helpers.** Search builders (`ev_rg_cmd`, `ev_fd_cmd` in `lib/search.sh`) print the command **argv one token per line**; the caller pipes that into `_ev_run_argv` which reads tokens and `exec`s them. This keeps quoting safe and the builders unit-testable. `ev_query_exts`/`ev_query_terms` split a query like `*.pdf 유동성` into an extension filter (`EV_EXTS`, applied as fd `--extension` / rg `-g`) plus the real terms.

**Document text extraction** (`lib/extract.sh`, `ev_extract_text`): dispatch by extension. `hwpx/docx/pptx/xlsx` are zip+XML — unzipped and tag-stripped by the shared `_ev_extract_zip_xml <file> <entry-regex>` (entry regexes differ per format). `pdf` uses `pdftotext` (optional). Content search wires this into ripgrep via `rg --pre "$EV_EXTRACTOR" --pre-glob '*.hwpx' ...`; `libexec/ev-extract` is a standalone executable wrapper because `rg --pre` takes a single program with no args. Results show the **original** file path/line — no index or cache.

**Landing page** (`site/`) is static HTML/CSS/JS deployed to GitHub Pages by `.github/workflows/pages.yml` (Pages source = "GitHub Actions"). The workflow copies `install.sh` into `site/` so `curl -fsSL https://seongilp.github.io/ev/install.sh | bash` works.

## Conventions and gotchas

- **`lib/*.sh` must run under both zsh (runtime) and bash (bats tests).** Do not use zsh-only word-splitting like `${=VAR}`. Split space-lists with `printf '%s\n' "$VAR" | tr ' ' '\n' | while IFS= read -r x`, and **always include the trailing `\n`** — omitting it silently drops the last token (a real bug that hit `EV_EXTS`/`EV_EXCLUDE_GLOBS`).
- **bats `@test` titles must be ASCII.** Korean in a test title breaks bats' function-name generation (the test silently doesn't run); Korean inside the test body is fine.
- Builders use `--color=always` (for the TUI). The CLI/export path strips ANSI with `ev_strip_ansi` (`lib/export.sh`) before formatting.
- TDD is the workflow here: add a failing bats test, then implement. Commit per logical change; conventional-commit style (`feat:`, `fix:`, `docs:`).
- Bump the `?v=N` query string on `site/` asset links when editing `styles.css`/`main.js`, or GitHub Pages serves stale cached copies.
- Dependencies: `rg`/`fzf`(0.73+)/`fd` are required and auto-installed via brew on first run (`EV_AUTO_INSTALL=0` to opt out). `bat` (preview highlight) and `poppler`/`pdftotext` (pdf) are optional. `bats-core` is the test runner.
