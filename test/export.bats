#!/usr/bin/env bats

setup() {
  source "${BATS_TEST_DIRNAME}/../lib/export.sh"
}

# 입력 라인: 'path' (파일명) 또는 'path:line:col:text' (내용 매치)
LINES='src/a.txt
src/b.txt:12:3:hello world
docs/c.md:4:1:title'

@test "ev_export_paths emits unique file paths only" {
  run bash -c "printf '%s\n' 'src/a.txt' 'src/b.txt:12:3:hi' 'src/b.txt:20:1:bye' | { source '${BATS_TEST_DIRNAME}/../lib/export.sh'; ev_export_paths; }"
  [ "${lines[0]}" = "src/a.txt" ]
  [ "${lines[1]}" = "src/b.txt" ]
  [ "${#lines[@]}" -eq 2 ]
}

@test "ev_export_md renders content matches and paths" {
  run bash -c "printf '%s\n' 'a.txt' 'b.txt:12:3:hello' | { source '${BATS_TEST_DIRNAME}/../lib/export.sh'; ev_export_md; }"
  [[ "$output" == *'- `a.txt`'* ]]
  [[ "$output" == *'- `b.txt:12` — hello'* ]]
}

@test "ev_export_csv has header and rows" {
  run bash -c "printf '%s\n' 'b.txt:12:3:hi,there' | { source '${BATS_TEST_DIRNAME}/../lib/export.sh'; ev_export_csv; }"
  [ "${lines[0]}" = "file,line,text" ]
  [[ "$output" == *'"b.txt",12,"hi,there"'* ]]
}

@test "ev_export_json emits valid-ish array with fields" {
  run bash -c "printf '%s\n' 'b.txt:12:3:hello' | { source '${BATS_TEST_DIRNAME}/../lib/export.sh'; ev_export_json; }"
  [[ "$output" == *'"file":"b.txt"'* ]]
  [[ "$output" == *'"line":12'* ]]
  [[ "$output" == *'"text":"hello"'* ]]
  [[ "$output" == '['* ]]
  [[ "$output" == *']' ]]
}

@test "ev_format dispatches by name" {
  run bash -c "printf '%s\n' 'a.txt:1:1:x' | { source '${BATS_TEST_DIRNAME}/../lib/export.sh'; ev_format paths; }"
  [ "$output" = "a.txt" ]
}

@test "ev_strip_ansi removes color codes" {
  run bash -c "printf 'a\033[31mb\033[0mc\n' | { source '${BATS_TEST_DIRNAME}/../lib/export.sh'; ev_strip_ansi; }"
  [ "$output" = "abc" ]
}
