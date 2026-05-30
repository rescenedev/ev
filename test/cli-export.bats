#!/usr/bin/env bats

setup() {
  EV="${BATS_TEST_DIRNAME}/../ev"
  ROOT="$(mktemp -d)"
  printf 'alpha beta\n'        > "$ROOT/note.txt"
  printf 'uses ripgrep here\n' > "$ROOT/readme.txt"
}
teardown() { rm -rf "$ROOT"; }

_make_hwpx() {
  local out="$1" body="$2"
  local d="$BATS_TEST_TMPDIR/hwpx.$$"
  mkdir -p "$d/Contents"
  printf '<hml><hp:p><hp:t>%s</hp:t></hp:p></hml>' "$body" > "$d/Contents/section0.xml"
  ( cd "$d" && zip -qr "$out" . )
  rm -rf "$d"
}

@test "ev -l lists files as paths" {
  run "$EV" -l "$ROOT"
  [[ "$output" == *"note.txt"* ]]
  [[ "$output" == *"readme.txt"* ]]
}

@test "ev -g finds content matches" {
  run "$EV" -g "ripgrep" "$ROOT"
  [[ "$output" == *"readme.txt"* ]]
}

@test "ev -g --json emits JSON with file field" {
  run "$EV" -g "ripgrep" "$ROOT" --json
  [[ "$output" == '['* ]]
  [[ "$output" == *'"file":'* ]]
  [[ "$output" == *"readme.txt"* ]]
}

@test "ev -g --format md emits markdown" {
  run "$EV" -g "ripgrep" "$ROOT" --format md
  [[ "$output" == *'- `'* ]]
  [[ "$output" == *"readme.txt"* ]]
}

@test "ev -x extracts hwpx text" {
  _make_hwpx "$ROOT/doc.hwpx" "추출시이엘아이"
  run "$EV" -x "$ROOT/doc.hwpx"
  [[ "$output" == *"추출시이엘아이"* ]]
}

@test "ev --to-txt converts hwpx to a .txt sidecar" {
  _make_hwpx "$ROOT/doc.hwpx" "변환된본문"
  OUT="$(mktemp -d)"
  run "$EV" --to-txt "$ROOT" "$OUT"
  [ "$status" -eq 0 ]
  [ -f "$OUT/doc.hwpx.txt" ]
  run cat "$OUT/doc.hwpx.txt"
  [[ "$output" == *"변환된본문"* ]]
  rm -rf "$OUT"
}

@test "ev -g without query exits non-zero" {
  run "$EV" -g
  [ "$status" -ne 0 ]
}
