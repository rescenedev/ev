#!/usr/bin/env bats

setup() {
  EV="${BATS_TEST_DIRNAME}/../ev"
  STATE="$(mktemp -d)"
  ROOT="$(mktemp -d)"
  printf 'alpha beta\n' > "$ROOT/note.txt"
  export EV_STATE="$STATE" EV_ROOT="$ROOT"
}

teardown() { rm -rf "$STATE" "$ROOT"; }

@test "init defaults to files mode (file list shown first), hidden off" {
  run "$EV" __init
  [ "$status" -eq 0 ]
  [ "$(cat "$STATE/mode")" = "files" ]
  [ "$(cat "$STATE/hidden")" = "0" ]
}

@test "init accepts an explicit starting mode" {
  run "$EV" __init content
  [ "$(cat "$STATE/mode")" = "content" ]
}

@test "toggle-mode flips content -> files and emits enable-search + reload" {
  "$EV" __init content
  run "$EV" __toggle-mode
  [ "$status" -eq 0 ]
  [ "$(cat "$STATE/mode")" = "files" ]
  [[ "$output" == *"enable-search"* ]]
  [[ "$output" == *"reload"* ]]
}

@test "toggle-mode flips files -> content and emits disable-search" {
  "$EV" __init files
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
  "$EV" __init content
  FZF_QUERY="alpha" run "$EV" __on-change
  [[ "$output" == *"reload"* ]]
}

@test "on-change is a no-op in files mode" {
  "$EV" __init files
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
