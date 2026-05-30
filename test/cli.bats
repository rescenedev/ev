#!/usr/bin/env bats

setup() {
  EV="${BATS_TEST_DIRNAME}/../ev"
  STATE="$(mktemp -d)"
  ROOT="$(mktemp -d)"
  printf 'alpha beta\n'        > "$ROOT/note.txt"
  printf 'plain text\n'        > "$ROOT/ripgrep-config.txt"  # 파일명에 ripgrep
  printf 'uses ripgrep here\n' > "$ROOT/readme.txt"          # 내용에 ripgrep
  export EV_STATE="$STATE" EV_ROOT="$ROOT"
}

teardown() { rm -rf "$STATE" "$ROOT"; }

@test "init creates hidden state defaulting to off" {
  run "$EV" __init
  [ "$status" -eq 0 ]
  [ "$(cat "$STATE/hidden")" = "0" ]
}

@test "empty query lists files" {
  "$EV" __init
  FZF_QUERY="" run "$EV" __search
  [[ "$output" == *"note.txt"* ]]
  [[ "$output" == *"readme.txt"* ]]
}

@test "query matches filenames (fd)" {
  "$EV" __init
  FZF_QUERY="ripgrep" run "$EV" __search
  [[ "$output" == *"ripgrep-config.txt"* ]]
}

@test "query matches file contents (rg)" {
  "$EV" __init
  # readme.txt 는 파일명에 ripgrep 이 없으므로, 등장하면 내용 매치로 나온 것
  FZF_QUERY="ripgrep" run "$EV" __search
  [[ "$output" == *"readme.txt"* ]]
}

@test "unified search returns both filename and content hits together" {
  "$EV" __init
  FZF_QUERY="ripgrep" run "$EV" __search
  [[ "$output" == *"ripgrep-config.txt"* ]]   # 파일명 매치 (fd)
  [[ "$output" == *"readme.txt"* ]]           # 내용 매치 (rg)
}

@test "toggle-hidden flips 0 -> 1 and emits reload" {
  "$EV" __init
  run "$EV" __toggle-hidden
  [ "$(cat "$STATE/hidden")" = "1" ]
  [[ "$output" == *"reload"* ]]
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
