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
