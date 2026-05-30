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
