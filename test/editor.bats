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

@test "ev_is_text detects a text file" {
  local f="$BATS_TEST_TMPDIR/t.txt"; printf 'hello\nworld\n' > "$f"
  run ev_is_text "$f"
  [ "$status" -eq 0 ]
}

@test "ev_is_text detects a binary file (NUL bytes)" {
  local f="$BATS_TEST_TMPDIR/b.bin"; printf 'PK\003\004\000\000bin' > "$f"
  run ev_is_text "$f"
  [ "$status" -ne 0 ]
}

@test "ev_is_text treats an empty file as text" {
  local f="$BATS_TEST_TMPDIR/empty.txt"; : > "$f"
  run ev_is_text "$f"
  [ "$status" -eq 0 ]
}
