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

@test "ev_rg_cmd adds preprocessor flags when an extractor is given" {
  run ev_rg_cmd /r 0 "q" /path/to/ev-extract
  [[ "$output" == *"--pre"* ]]
  [[ "$output" == *"/path/to/ev-extract"* ]]
  [[ "$output" == *"--pre-glob"* ]]
  [[ "$output" == *"*.hwpx"* ]]
  [[ "$output" == *"*.docx"* ]]
  [[ "$output" == *"*.pdf"* ]]
}

@test "ev_rg_cmd omits preprocessor flags when no extractor" {
  run ev_rg_cmd /r 0 "q"
  [[ "$output" != *"--pre"* ]]
}

@test "ev_query_exts extracts *.ext tokens (lowercased)" {
  run ev_query_exts "*.PDF 유동성"
  [ "$output" = "pdf" ]
}

@test "ev_query_exts handles multiple globs and none" {
  run ev_query_exts "*.pdf *.docx 보고서"
  [ "$output" = "pdf docx" ]
  run ev_query_exts "그냥검색어"
  [ -z "$output" ]
}

@test "ev_query_terms strips glob tokens, keeps the rest" {
  run ev_query_terms "*.pdf 유동성"
  [ "$output" = "유동성" ]
  run ev_query_terms "*.pdf"
  [ -z "$output" ]
}

@test "ev_fd_cmd adds --extension when EV_EXTS set" {
  export EV_EXTS="pdf docx"
  run ev_fd_cmd /r 0
  unset EV_EXTS
  [[ "$output" == *"--extension"* ]]
  [[ "$output" == *"pdf"* ]]
  [[ "$output" == *"docx"* ]]
}

@test "ev_rg_cmd adds -g globs when EV_EXTS set" {
  export EV_EXTS="pdf"
  run ev_rg_cmd /r 0 "q"
  unset EV_EXTS
  [[ "$output" == *"-g"* ]]
  [[ "$output" == *"*.pdf"* ]]
}

@test "ev_fd_cmd lists files under root" {
  run ev_fd_cmd /r 0
  [ "${lines[0]}" = "fd" ]
  [ "${lines[${#lines[@]}-1]}" = "/r" ]
}

@test "ev_fd_cmd uses query as filename pattern when given" {
  run ev_fd_cmd /r 0 "needle"
  [ "${lines[${#lines[@]}-2]}" = "needle" ]
  [ "${lines[${#lines[@]}-1]}" = "/r" ]
}

@test "ev_fd_cmd excludes binary artifacts like .so" {
  run ev_fd_cmd /r 0
  [[ "$output" == *"--exclude"* ]]
  [[ "$output" == *"*.so"* ]]
}

@test "fd command actually skips .so files (integration)" {
  printf 'x' > "$TMP/lib.so"
  local cmd=()
  while IFS= read -r tok; do cmd+=("$tok"); done < <(ev_fd_cmd "$TMP" 0)
  run "${cmd[@]}"
  [[ "$output" != *"lib.so"* ]]
  [[ "$output" == *"a.txt"* ]]
}

@test "rg command actually finds matches in temp dir (integration)" {
  local cmd=()
  while IFS= read -r tok; do cmd+=("$tok"); done < <(ev_rg_cmd "$TMP" 0 "hello")
  run "${cmd[@]}"
  [ "$status" -eq 0 ]                # rg는 매치가 있을 때만 0 종료
  [[ "$output" == *"a.txt"* ]]
  # --color=always 라 매치어("hello")는 ANSI 코드로 감싸여 분리됨 → 매치 뒤 "world"로 확인
  [[ "$output" == *"world"* ]]
}

@test "fd command actually lists files in temp dir (integration)" {
  local cmd=()
  while IFS= read -r tok; do cmd+=("$tok"); done < <(ev_fd_cmd "$TMP" 0)
  run "${cmd[@]}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"a.txt"* ]]
  [[ "$output" == *"b.txt"* ]]
}
