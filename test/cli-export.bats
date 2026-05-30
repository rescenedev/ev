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

@test "__export-results writes a markdown file with content rows" {
  printf '%s\n' 'a.txt:1:1:hello' 'b.txt' > "$ROOT/sel.txt"
  EV_EXPORT_DIR="$ROOT" run "$EV" __export-results "$ROOT/sel.txt"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[OK]"* ]]
  run bash -c "cat $ROOT/ev-export-*.md"
  [[ "$output" == *'- `a.txt:1` — hello'* ]]
  [[ "$output" == *'- `b.txt`'* ]]
}

@test "__copy-paths sends unique paths to the clipboard command" {
  printf '%s\n' 'a.txt:1:1:x' 'a.txt:2:1:y' 'b.txt' > "$ROOT/sel.txt"
  EV_CLIP="cat > $ROOT/clip.txt" run "$EV" __copy-paths "$ROOT/sel.txt"
  [[ "$output" == *"[OK]"* ]]
  run cat "$ROOT/clip.txt"
  [[ "$output" == *"a.txt"* ]]
  [[ "$output" == *"b.txt"* ]]
  # a.txt 는 중복 제거되어 한 번만
  [ "$(grep -c 'a.txt' "$ROOT/clip.txt")" -eq 1 ]
}

@test "__zip-files zips the selected files" {
  printf 'x' > "$ROOT/f1.txt"; printf 'y' > "$ROOT/f2.txt"
  printf '%s\n' "$ROOT/f1.txt:1:1:x" "$ROOT/f2.txt" > "$ROOT/sel.txt"
  EV_EXPORT_DIR="$ROOT" run "$EV" __zip-files "$ROOT/sel.txt"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[OK]"* ]]
  run bash -c "ls $ROOT/ev-files-*.zip"
  [ "$status" -eq 0 ]
}
