# `ev` TUI 검색 도구 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** macOS 터미널에서 `rg`/`fzf`/`fd`를 묶어, 입력 즉시 결과가 갱신되고 파일명↔내용 검색을 단축키로 토글하는 단일 zsh 스크립트 `ev`를 만든다.

**Architecture:** `fzf`를 메인 루프로 두고, 검색·미리보기·열기·토글 로직은 `ev`의 숨은 서브커맨드(`__search` 등)로 분리한다. fzf는 `--bind`의 `transform`/`reload`/`become` 액션으로 이 서브커맨드를 호출하며, 현재 쿼리는 fzf가 자식 프로세스에 내보내는 `FZF_QUERY` 환경변수로 전달한다. 순수 로직(의존성 점검, 에디터·미리보기·검색 명령 조립)은 `lib/*.sh` 헬퍼 함수로 떼어내 bats로 단위 테스트한다.

**Tech Stack:** zsh, ripgrep(rg), fzf(0.73+), fd, bat(선택), bats(테스트)

---

## File Structure

```
ev                 # 메인 실행 스크립트 (chmod +x). 인자 파싱 + 서브커맨드 디스패치 + fzf 실행
lib/deps.sh        # 의존성 점검 / 설치 명령 조립
lib/editor.sh      # 에디터별 "줄 점프" 명령 조립
lib/preview.sh     # 미리보기 명령 조립 (bat 있으면 bat, 없으면 cat)
lib/search.sh      # rg / fd 명령(argv) 조립
test/deps.bats
test/editor.bats
test/preview.bats
test/search.bats
test/cli.bats       # 서브커맨드 비대화형 동작 통합 테스트
docs/MANUAL-CHECKLIST.md   # 대화형 fzf 수동 점검 체크리스트
README.md
```

각 `lib/*.sh`는 함수만 정의하고 즉시 실행 코드는 두지 않는다(= `source` 가능). `ev`가 이들을 source 한다.

fzf 바인딩 설계(참고):
- `start` / `change` → `transform(ev __on-change)`: 내용 모드면 `reload(ev __search)`, 파일명 모드면 no-op.
- `ctrl-f` → `transform(ev __toggle-mode)`: 상태 파일을 뒤집고 프롬프트/검색활성/리로드 액션을 출력.
- `ctrl-h` → `transform(ev __toggle-hidden)`: 숨김 포함 토글 후 현재 모드에 맞는 reload 출력.
- `enter` → `become(ev __open {1} {2})`.
- `ctrl-y` → `execute-silent(printf %s {1} | pbcopy)`.
- `?` → `toggle-preview`, `esc` → `abort`.
- 쿼리는 `FZF_QUERY` 환경변수로 서브커맨드에 전달(플레이스홀더 확장 의존 제거).
- 상태(모드/숨김)는 `mktemp -d`로 만든 디렉터리의 파일 `mode`(`content`|`files`), `hidden`(`0`|`1`)에 저장. `EV_STATE`, `EV_ROOT` 환경변수로 서브커맨드에 전달.

---

## Task 0: 프로젝트 스캐폴딩 & 개발 의존성

**Files:**
- Create: `lib/.gitkeep` (임시), `test/.gitkeep` (임시) — 이후 실제 파일로 대체
- Create: `.gitignore`

- [ ] **Step 1: bats 설치 (테스트 러너)**

Run: `command -v bats || brew install bats-core`
Expected: `bats` 경로 출력 (이미 있으면) 또는 설치 완료 후 사용 가능.

- [ ] **Step 2: 검증**

Run: `bats --version`
Expected: `Bats 1.x.x` 형태 출력.

- [ ] **Step 3: .gitignore 작성**

```gitignore
# macOS
.DS_Store
# 임시 상태 디렉터리는 mktemp로 생성되므로 추적 안 함
```

- [ ] **Step 4: 커밋**

```bash
git add .gitignore
git commit -m "chore: add gitignore and bats dev dependency"
```

---

## Task 1: 의존성 점검 & 설치 명령 (`lib/deps.sh`)

**Files:**
- Create: `lib/deps.sh`
- Test: `test/deps.bats`

- [ ] **Step 1: 실패하는 테스트 작성**

`test/deps.bats`:
```bash
#!/usr/bin/env bats

setup() {
  source "${BATS_TEST_DIRNAME}/../lib/deps.sh"
}

@test "ev_missing_deps lists only commands that are absent" {
  run ev_missing_deps ls __definitely_missing_cmd_xyz__ cat
  [ "$status" -eq 0 ]
  [ "$output" = "__definitely_missing_cmd_xyz__" ]
}

@test "ev_missing_deps prints nothing when all present" {
  run ev_missing_deps ls cat
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "ev_install_cmd builds a brew install line" {
  run ev_install_cmd ripgrep fzf
  [ "$status" -eq 0 ]
  [ "$output" = "brew install ripgrep fzf" ]
}

@test "ev_install_cmd prints nothing for empty input" {
  run ev_install_cmd
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
```

- [ ] **Step 2: 실패 확인**

Run: `bats test/deps.bats`
Expected: FAIL — `ev_missing_deps: command not found` 류.

- [ ] **Step 3: 최소 구현**

`lib/deps.sh`:
```bash
# 의존성 점검 및 설치 명령 조립. source 전용.

# 인자로 받은 명령들 중 PATH에 없는 것만 한 줄씩 출력.
ev_missing_deps() {
  local c
  for c in "$@"; do
    command -v "$c" >/dev/null 2>&1 || printf '%s\n' "$c"
  done
}

# 인자로 받은 패키지들을 brew install 한 줄로 조립. 인자 없으면 아무것도 출력 안 함.
ev_install_cmd() {
  [ "$#" -eq 0 ] && return 0
  printf 'brew install %s\n' "$*"
}
```

- [ ] **Step 4: 통과 확인**

Run: `bats test/deps.bats`
Expected: 4 tests PASS.

- [ ] **Step 5: 커밋**

```bash
git add lib/deps.sh test/deps.bats
git commit -m "feat: add dependency check and install command helpers"
```

---

## Task 2: 에디터 줄 점프 명령 (`lib/editor.sh`)

**Files:**
- Create: `lib/editor.sh`
- Test: `test/editor.bats`

- [ ] **Step 1: 실패하는 테스트 작성**

`test/editor.bats`:
```bash
#!/usr/bin/env bats

setup() {
  source "${BATS_TEST_DIRNAME}/../lib/editor.sh"
}

@test "vim uses +line syntax" {
  run ev_editor_cmd vim /tmp/a.txt 42
  [ "$output" = "vim +42 /tmp/a.txt" ]
}

@test "nvim uses +line syntax" {
  run ev_editor_cmd nvim /tmp/a.txt 7
  [ "$output" = "nvim +7 /tmp/a.txt" ]
}

@test "vscode uses -g file:line syntax" {
  run ev_editor_cmd code /tmp/a.txt 99
  [ "$output" = "code -g /tmp/a.txt:99" ]
}

@test "full path editor is matched by basename" {
  run ev_editor_cmd /usr/local/bin/nvim /tmp/a.txt 3
  [ "$output" = "/usr/local/bin/nvim +3 /tmp/a.txt" ]
}

@test "no line number falls back to editor + file" {
  run ev_editor_cmd vim /tmp/a.txt ""
  [ "$output" = "vim /tmp/a.txt" ]
}

@test "unknown editor falls back to editor + file" {
  run ev_editor_cmd weirdedit /tmp/a.txt 5
  [ "$output" = "weirdedit /tmp/a.txt" ]
}
```

- [ ] **Step 2: 실패 확인**

Run: `bats test/editor.bats`
Expected: FAIL — `ev_editor_cmd: command not found`.

- [ ] **Step 3: 최소 구현**

`lib/editor.sh`:
```bash
# 에디터별 "줄로 점프" 실행 명령을 조립. source 전용.
# 사용법: ev_editor_cmd <editor> <file> <line>
ev_editor_cmd() {
  local editor="$1" file="$2" line="${3:-}" base
  base="$(basename "$editor")"
  if [ -z "$line" ]; then
    printf '%s %s\n' "$editor" "$file"
    return 0
  fi
  case "$base" in
    code|code-insiders|cursor)
      printf '%s -g %s:%s\n' "$editor" "$file" "$line" ;;
    vi|vim|nvim|view|nano|emacs|emacsclient)
      printf '%s +%s %s\n' "$editor" "$line" "$file" ;;
    *)
      printf '%s %s\n' "$editor" "$file" ;;
  esac
}
```

- [ ] **Step 4: 통과 확인**

Run: `bats test/editor.bats`
Expected: 6 tests PASS.

- [ ] **Step 5: 커밋**

```bash
git add lib/editor.sh test/editor.bats
git commit -m "feat: add editor line-jump command builder"
```

---

## Task 3: 미리보기 명령 (`lib/preview.sh`)

**Files:**
- Create: `lib/preview.sh`
- Test: `test/preview.bats`

- [ ] **Step 1: 실패하는 테스트 작성**

`test/preview.bats`:
```bash
#!/usr/bin/env bats

setup() {
  source "${BATS_TEST_DIRNAME}/../lib/preview.sh"
}

@test "uses bat with highlight when bat is the tool and line given" {
  ev_preview_tool() { printf 'bat\n'; }   # 강제 bat 분기
  run ev_preview_cmd /tmp/a.txt 42
  [ "$output" = "bat --style=numbers --color=always --highlight-line 42 -- /tmp/a.txt" ]
}

@test "uses bat without highlight when no line" {
  ev_preview_tool() { printf 'bat\n'; }
  run ev_preview_cmd /tmp/a.txt ""
  [ "$output" = "bat --style=numbers --color=always -- /tmp/a.txt" ]
}

@test "falls back to cat -n when bat absent" {
  ev_preview_tool() { printf 'cat\n'; }   # 강제 cat 분기
  run ev_preview_cmd /tmp/a.txt 42
  [ "$output" = "cat -n /tmp/a.txt" ]
}
```

- [ ] **Step 2: 실패 확인**

Run: `bats test/preview.bats`
Expected: FAIL — `ev_preview_cmd: command not found`.

- [ ] **Step 3: 최소 구현**

`lib/preview.sh`:
```bash
# 미리보기 명령 조립. source 전용.

# bat가 PATH에 있으면 'bat', 없으면 'cat' 출력. (테스트에서 재정의해 분기 강제 가능)
ev_preview_tool() {
  command -v bat >/dev/null 2>&1 && printf 'bat\n' || printf 'cat\n'
}

# 사용법: ev_preview_cmd <file> <line>
ev_preview_cmd() {
  local file="$1" line="${2:-}" tool
  tool="$(ev_preview_tool)"
  if [ "$tool" = bat ]; then
    if [ -n "$line" ]; then
      printf 'bat --style=numbers --color=always --highlight-line %s -- %s\n' "$line" "$file"
    else
      printf 'bat --style=numbers --color=always -- %s\n' "$file"
    fi
  else
    printf 'cat -n %s\n' "$file"
  fi
}
```

- [ ] **Step 4: 통과 확인**

Run: `bats test/preview.bats`
Expected: 3 tests PASS.

- [ ] **Step 5: 커밋**

```bash
git add lib/preview.sh test/preview.bats
git commit -m "feat: add preview command builder with cat fallback"
```

---

## Task 4: 검색 명령 조립 (`lib/search.sh`)

**Files:**
- Create: `lib/search.sh`
- Test: `test/search.bats`

`ev_rg_cmd` / `ev_fd_cmd`는 실행할 argv를 한 줄에 한 토큰씩 출력한다(공백 안전). 호출부는 이를 배열로 읽어 실행한다.

- [ ] **Step 1: 실패하는 테스트 작성**

`test/search.bats`:
```bash
#!/usr/bin/env bats

setup() {
  source "${BATS_TEST_DIRNAME}/../lib/search.sh"
  TMP="$(mktemp -d)"
  printf 'hello world\nsecond line\n' > "$TMP/a.txt"
  printf 'nothing here\n' > "$TMP/b.txt"
}

teardown() { rm -rf "$TMP"; }

@test "ev_rg_cmd emits one token per line including query and root" {
  run ev_rg_cmd /search/root 0 "needle"
  [ "${lines[0]}" = "rg" ]
  # 마지막 두 토큰은 쿼리와 루트
  [ "${lines[${#lines[@]}-2]}" = "needle" ]
  [ "${lines[${#lines[@]}-1]}" = "/search/root" ]
}

@test "ev_rg_cmd adds hidden/no-ignore flags when hidden=1" {
  run ev_rg_cmd /r 1 "q"
  [[ "$output" == *"--hidden"* ]]
  [[ "$output" == *"--no-ignore"* ]]
}

@test "ev_rg_cmd has no hidden flags when hidden=0" {
  run ev_rg_cmd /r 0 "q"
  [[ "$output" != *"--hidden"* ]]
}

@test "ev_fd_cmd lists files under root" {
  run ev_fd_cmd /r 0
  [ "${lines[0]}" = "fd" ]
  [ "${lines[${#lines[@]}-1]}" = "/r" ]
}

@test "rg command actually finds matches in temp dir (integration)" {
  local cmd=()
  while IFS= read -r tok; do cmd+=("$tok"); done < <(ev_rg_cmd "$TMP" 0 "hello")
  run "${cmd[@]}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"a.txt"* ]]
  [[ "$output" == *"hello world"* ]]
}

@test "fd command actually lists files in temp dir (integration)" {
  local cmd=()
  while IFS= read -r tok; do cmd+=("$tok"); done < <(ev_fd_cmd "$TMP" 0)
  run "${cmd[@]}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"a.txt"* ]]
  [[ "$output" == *"b.txt"* ]]
}
```

- [ ] **Step 2: 실패 확인**

Run: `bats test/search.bats`
Expected: FAIL — `ev_rg_cmd: command not found`.

- [ ] **Step 3: 최소 구현**

`lib/search.sh`:
```bash
# rg / fd 실행 argv 조립. source 전용. 토큰을 한 줄에 하나씩 출력(공백 안전).

# 사용법: ev_rg_cmd <root> <hidden:0|1> <query>
ev_rg_cmd() {
  local root="$1" hidden="$2" query="$3"
  printf '%s\n' rg --column --line-number --no-heading --color=always --smart-case
  if [ "$hidden" = 1 ]; then
    printf '%s\n' --hidden --no-ignore
  fi
  printf '%s\n' -- "$query" "$root"
}

# 사용법: ev_fd_cmd <root> <hidden:0|1>
ev_fd_cmd() {
  local root="$1" hidden="$2"
  printf '%s\n' fd --type f --color=always
  if [ "$hidden" = 1 ]; then
    printf '%s\n' --hidden --no-ignore
  fi
  printf '%s\n' . "$root"
}
```

- [ ] **Step 4: 통과 확인**

Run: `bats test/search.bats`
Expected: 6 tests PASS.

- [ ] **Step 5: 커밋**

```bash
git add lib/search.sh test/search.bats
git commit -m "feat: add rg/fd command builders"
```

---

## Task 5: 메인 스크립트 `ev` (서브커맨드 + fzf 실행)

**Files:**
- Create: `ev`
- Test: `test/cli.bats`

대화형 fzf 자체는 자동 테스트하지 않는다. 대신 **비대화형 서브커맨드**(상태 토글, 검색 실행, 열기 명령 출력)를 테스트한다. `EV_DRY_RUN=1`이면 `__open`은 에디터를 실행하지 않고 조립된 명령만 출력한다.

- [ ] **Step 1: 실패하는 테스트 작성**

`test/cli.bats`:
```bash
#!/usr/bin/env bats

setup() {
  EV="${BATS_TEST_DIRNAME}/../ev"
  STATE="$(mktemp -d)"
  ROOT="$(mktemp -d)"
  printf 'alpha beta\n' > "$ROOT/note.txt"
  export EV_STATE="$STATE" EV_ROOT="$ROOT"
}

teardown() { rm -rf "$STATE" "$ROOT"; }

@test "init creates state files defaulting to content mode, hidden off" {
  run "$EV" __init
  [ "$status" -eq 0 ]
  [ "$(cat "$STATE/mode")" = "content" ]
  [ "$(cat "$STATE/hidden")" = "0" ]
}

@test "toggle-mode flips content -> files and emits enable-search + reload" {
  "$EV" __init
  run "$EV" __toggle-mode
  [ "$status" -eq 0 ]
  [ "$(cat "$STATE/mode")" = "files" ]
  [[ "$output" == *"enable-search"* ]]
  [[ "$output" == *"reload"* ]]
}

@test "toggle-mode flips files -> content and emits disable-search" {
  "$EV" __init
  "$EV" __toggle-mode            # -> files
  run "$EV" __toggle-mode        # -> content
  [ "$(cat "$STATE/mode")" = "content" ]
  [[ "$output" == *"disable-search"* ]]
}

@test "toggle-hidden flips 0 -> 1" {
  "$EV" __init
  run "$EV" __toggle-hidden
  [ "$(cat "$STATE/hidden")" = "1" ]
  [[ "$output" == *"reload"* ]]
}

@test "on-change emits reload in content mode" {
  "$EV" __init
  FZF_QUERY="alpha" run "$EV" __on-change
  [[ "$output" == *"reload"* ]]
}

@test "on-change is a no-op in files mode" {
  "$EV" __init
  "$EV" __toggle-mode            # -> files
  FZF_QUERY="alpha" run "$EV" __on-change
  [ -z "$output" ]
}

@test "search returns rg matches in content mode" {
  "$EV" __init
  FZF_QUERY="alpha" run "$EV" __search
  [[ "$output" == *"note.txt"* ]]
}

@test "search returns nothing for empty query" {
  "$EV" __init
  FZF_QUERY="" run "$EV" __search
  [ -z "$output" ]
}

@test "open builds an editor command in dry-run" {
  EDITOR=vim EV_DRY_RUN=1 run "$EV" __open "$ROOT/note.txt" 1
  [ "$output" = "vim +1 $ROOT/note.txt" ]
}

@test "open falls back to vi when EDITOR unset" {
  unset EDITOR
  EV_DRY_RUN=1 run "$EV" __open "$ROOT/note.txt" 2
  [ "$output" = "vi +2 $ROOT/note.txt" ]
}
```

- [ ] **Step 2: 실패 확인**

Run: `bats test/cli.bats`
Expected: FAIL — `ev` 파일 없음 / 실행 불가.

- [ ] **Step 3: 최소 구현**

`ev`:
```bash
#!/usr/bin/env zsh
# ev — Everything 스타일 TUI 검색 (rg + fzf + fd)
set -euo pipefail

EV_HOME="${0:A:h}"
source "$EV_HOME/lib/deps.sh"
source "$EV_HOME/lib/editor.sh"
source "$EV_HOME/lib/preview.sh"
source "$EV_HOME/lib/search.sh"

# ── 상태 헬퍼 ────────────────────────────────────────────────
_ev_mode()   { cat "$EV_STATE/mode"; }
_ev_hidden() { cat "$EV_STATE/hidden"; }

# 현재 모드에 맞는 reload 액션 문자열 생성
_ev_reload_action() {
  if [ "$(_ev_mode)" = files ]; then
    printf 'reload(%s __list-files)' "$EV_HOME/ev"
  else
    printf 'reload(%s __search)' "$EV_HOME/ev"
  fi
}

# ── 서브커맨드 ───────────────────────────────────────────────
_ev_init() {
  printf 'content\n' > "$EV_STATE/mode"
  printf '0\n'       > "$EV_STATE/hidden"
}

_ev_run_argv() {            # stdin: 토큰(줄당 1개) → 실행
  local cmd=()
  local tok
  while IFS= read -r tok; do cmd+=("$tok"); done
  [ "${#cmd[@]}" -eq 0 ] && return 0
  "${cmd[@]}"
}

_ev_search() {              # 내용 모드 검색 (FZF_QUERY 사용)
  local q="${FZF_QUERY:-}"
  [ -z "$q" ] && return 0
  ev_rg_cmd "$EV_ROOT" "$(_ev_hidden)" "$q" | _ev_run_argv || true
}

_ev_list_files() {          # 파일명 모드 전체 목록 (fzf가 fuzzy 필터)
  ev_fd_cmd "$EV_ROOT" "$(_ev_hidden)" | _ev_run_argv || true
}

_ev_on_change() {           # change 이벤트: 내용 모드만 reload
  [ "$(_ev_mode)" = content ] || return 0
  printf 'reload(%s __search)' "$EV_HOME/ev"
}

_ev_toggle_mode() {
  if [ "$(_ev_mode)" = content ]; then
    printf 'files\n' > "$EV_STATE/mode"
    printf 'enable-search+change-prompt(files> )+%s' "$(_ev_reload_action)"
  else
    printf 'content\n' > "$EV_STATE/mode"
    printf 'disable-search+change-prompt(rg> )+%s' "$(_ev_reload_action)"
  fi
}

_ev_toggle_hidden() {
  if [ "$(_ev_hidden)" = 0 ]; then printf '1\n' > "$EV_STATE/hidden"
  else printf '0\n' > "$EV_STATE/hidden"; fi
  printf '%s' "$(_ev_reload_action)"
}

_ev_preview() {             # 인자: file [line]
  local cmd
  cmd="$(ev_preview_cmd "$1" "${2:-}")"
  eval "$cmd" 2>/dev/null || true
}

_ev_open() {                # 인자: file [line]
  local file="$1" line="${2:-}"
  [ -z "$file" ] && return 0
  local editor="${EDITOR:-vi}"
  local cmd
  cmd="$(ev_editor_cmd "$editor" "$file" "$line")"
  if [ "${EV_DRY_RUN:-0}" = 1 ]; then
    printf '%s\n' "$cmd"
    return 0
  fi
  eval "$cmd"
}

# ── 의존성 자동 설치 ─────────────────────────────────────────
_ev_ensure_deps() {
  local missing
  missing="$(ev_missing_deps rg fzf fd | tr '\n' ' ')"
  missing="${missing%% }"
  [ -z "$missing" ] && return 0

  if [ "${EV_AUTO_INSTALL:-1}" = 0 ]; then
    print -u2 "필수 도구 누락: $missing"
    print -u2 "설치: $(ev_install_cmd ${=missing})"
    exit 1
  fi
  if ! command -v brew >/dev/null 2>&1; then
    print -u2 "필수 도구 누락: $missing — Homebrew가 없어 자동 설치할 수 없습니다."
    print -u2 "먼저 Homebrew를 설치하세요: https://brew.sh"
    exit 1
  fi
  print -u2 "필수 도구 자동 설치: brew install $missing"
  if ! brew install ${=missing}; then
    print -u2 "설치 실패. 수동으로 시도하세요: $(ev_install_cmd ${=missing})"
    exit 1
  fi
}

# ── 메인 (대화형 fzf 실행) ──────────────────────────────────
_ev_main() {
  _ev_ensure_deps
  local root="${1:-.}"
  if [ ! -d "$root" ]; then
    print -u2 "디렉터리가 아닙니다: $root"
    exit 1
  fi
  export EV_ROOT="${root:A}"
  export EV_STATE="$(mktemp -d)"
  trap 'rm -rf "$EV_STATE"' EXIT
  _ev_init

  local self="$EV_HOME/ev"
  : | fzf \
    --ansi --disabled --prompt 'rg> ' \
    --delimiter : \
    --preview "$self __preview {1} {2}" \
    --preview-window 'right,55%,border-left,+{2}/3' \
    --bind "start:transform($self __on-change)+reload($self __search)" \
    --bind "change:transform($self __on-change)" \
    --bind "ctrl-f:transform($self __toggle-mode)" \
    --bind "ctrl-h:transform($self __toggle-hidden)" \
    --bind "enter:become($self __open {1} {2})" \
    --bind "ctrl-y:execute-silent(printf %s {1} | pbcopy)" \
    --bind '?:toggle-preview' \
    --bind 'esc:abort' \
    --header 'Ctrl-F: 파일명↔내용  Ctrl-H: 숨김  Enter: 열기  Ctrl-Y: 복사  ?: 미리보기'
}

# ── 디스패치 ─────────────────────────────────────────────────
case "${1:-}" in
  __init)          _ev_init ;;
  __search)        _ev_search ;;
  __list-files)    _ev_list_files ;;
  __on-change)     _ev_on_change ;;
  __toggle-mode)   _ev_toggle_mode ;;
  __toggle-hidden) _ev_toggle_hidden ;;
  __preview)       shift; _ev_preview "$@" ;;
  __open)          shift; _ev_open "$@" ;;
  -h|--help)       print "사용법: ev [검색할_디렉터리]  (기본: 현재 폴더)" ;;
  *)               _ev_main "$@" ;;
esac
```

- [ ] **Step 4: 실행 권한 부여 후 통과 확인**

Run: `chmod +x ev && bats test/cli.bats`
Expected: 10 tests PASS.

- [ ] **Step 5: 전체 단위 테스트 재실행**

Run: `bats test/`
Expected: 모든 테스트 PASS (deps 4 + editor 6 + preview 3 + search 6 + cli 10).

- [ ] **Step 6: 커밋**

```bash
git add ev test/cli.bats
git commit -m "feat: add ev main script with subcommands and fzf wiring"
```

---

## Task 6: 수동 점검 체크리스트 & README

**Files:**
- Create: `docs/MANUAL-CHECKLIST.md`
- Create: `README.md`

- [ ] **Step 1: 수동 체크리스트 작성**

`docs/MANUAL-CHECKLIST.md`:
```markdown
# ev 수동 점검 체크리스트 (대화형)

테스트 폴더에서 `./ev` 실행 후:

- [ ] 시작하면 `rg>` 프롬프트(내용 모드)로 뜬다.
- [ ] 글자를 입력하면 결과가 즉시 갱신된다.
- [ ] 우측 미리보기에 매칭 줄이 보인다(bat 설치 시 하이라이트, 없으면 cat).
- [ ] `Ctrl-F`를 누르면 `files>` 프롬프트(파일명 모드)로 바뀌고 파일 목록이 뜬다.
- [ ] 파일명 모드에서 입력하면 fzf fuzzy 필터로 좁혀진다.
- [ ] `Ctrl-F`를 다시 누르면 내용 모드로 돌아온다.
- [ ] `Ctrl-H`로 숨김/.gitignore 포함이 토글된다(점(.)파일 등장/사라짐).
- [ ] 항목 선택 후 `Enter`를 누르면 $EDITOR로 해당 줄에서 열린다.
- [ ] `Ctrl-Y`로 경로가 클립보드에 복사된다(`pbpaste`로 확인).
- [ ] `?`로 미리보기 창이 토글된다.
- [ ] `Esc`로 종료된다.
- [ ] (선택) rg/fzf/fd 중 하나를 PATH에서 가린 뒤 실행하면 자동 설치를 안내/시도한다.
```

- [ ] **Step 2: README 작성**

`README.md`:
```markdown
# ev

macOS 터미널용 Everything 스타일 즉시 검색 도구. `rg` + `fzf` + `fd` 래퍼.

## 설치

```bash
git clone <repo> && cd everything
./ev          # rg/fzf/fd 없으면 자동 설치 (brew)
```

`ev`를 PATH에 두려면: `ln -s "$PWD/ev" /usr/local/bin/ev`

## 사용법

```bash
ev            # 현재 폴더 검색
ev ~/work     # 특정 폴더 검색
```

| 키 | 동작 |
|---|---|
| 타이핑 | 즉시 검색 (내용 모드는 rg 실시간) |
| `Ctrl-F` | 파일명 ↔ 내용 모드 토글 |
| `Ctrl-H` | 숨김파일/.gitignore 포함 토글 |
| `Enter` | `$EDITOR`로 해당 줄에서 열기 |
| `Ctrl-Y` | 경로 클립보드 복사 |
| `?` | 미리보기 토글 |
| `Esc` | 종료 |

## 환경변수

- `EDITOR` — 열 때 사용할 에디터 (기본 `vi`)
- `EV_AUTO_INSTALL=0` — 의존성 자동 설치 끄기(안내만)

## 의존성

- 필수: ripgrep, fzf(0.73+), fd
- 선택: bat (미리보기 하이라이트; 없으면 cat)
- 개발: bats-core (테스트)

## 테스트

```bash
bats test/
```
```

- [ ] **Step 3: 커밋**

```bash
git add docs/MANUAL-CHECKLIST.md README.md
git commit -m "docs: add manual checklist and README"
```

- [ ] **Step 4: 최종 수동 점검**

Run: `./ev .`
`docs/MANUAL-CHECKLIST.md`의 항목을 직접 확인한다.

---

## 완료 기준

- [ ] `bats test/` 전부 통과 (29 tests).
- [ ] `./ev`가 현재 폴더에서 즉시 내용 검색되고 Ctrl-F로 파일명 모드 전환된다.
- [ ] 의존성 누락 시 자동 설치(또는 옵트아웃 안내)가 동작한다.
- [ ] 수동 체크리스트 전 항목 확인.
```
