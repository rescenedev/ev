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

@test "ev_fd_cmd uses query as filename pattern when given" {
  run ev_fd_cmd /r 0 "needle"
  [ "${lines[${#lines[@]}-2]}" = "needle" ]
  [ "${lines[${#lines[@]}-1]}" = "/r" ]
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
