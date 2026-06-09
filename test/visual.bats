#!/usr/bin/env bats

setup() {
  source "${BATS_TEST_DIRNAME}/../lib/visual.sh"
}

# ── ev_graphics_supported ────────────────────────────────────
@test "graphics supported for ghostty TERM_PROGRAM" {
  TERM_PROGRAM=ghostty TERM= KITTY_WINDOW_ID= GHOSTTY_RESOURCES_DIR= run ev_graphics_supported
  [ "$status" -eq 0 ]
}

@test "graphics supported for xterm-kitty TERM" {
  TERM_PROGRAM= TERM=xterm-kitty KITTY_WINDOW_ID= GHOSTTY_RESOURCES_DIR= run ev_graphics_supported
  [ "$status" -eq 0 ]
}

@test "graphics supported when KITTY_WINDOW_ID set" {
  TERM_PROGRAM= TERM= KITTY_WINDOW_ID=1 GHOSTTY_RESOURCES_DIR= run ev_graphics_supported
  [ "$status" -eq 0 ]
}

@test "graphics not supported for plain xterm" {
  TERM_PROGRAM= TERM=xterm-256color KITTY_WINDOW_ID= GHOSTTY_RESOURCES_DIR= run ev_graphics_supported
  [ "$status" -ne 0 ]
}

# ── ev_visual_renderer ───────────────────────────────────────
@test "visual renderer prints chafa when present" {
  command -v chafa >/dev/null 2>&1 || skip "chafa not installed"
  run ev_visual_renderer
  [ "$output" = "chafa" ]
}

# ── ev_clear_images ──────────────────────────────────────────
@test "clear images emits kitty delete-all escape" {
  run ev_clear_images
  [[ "$output" == *"a=d"* ]]
}

# ── ev_render_image_cmd ──────────────────────────────────────
@test "render image cmd includes format size and path" {
  run ev_render_image_cmd /tmp/x.png 80 40
  [ "$output" = "chafa -f kitty -s 80x40 -- /tmp/x.png" ]
}

# ── ev_thumb_path ────────────────────────────────────────────
@test "thumb path is deterministic and ends with png" {
  local f="$BATS_TEST_TMPDIR/a.txt"; printf hi > "$f"
  run ev_thumb_path "$f" /tmp/thumbs
  local p1="$output"
  run ev_thumb_path "$f" /tmp/thumbs
  [ "$output" = "$p1" ]
  [[ "$output" == /tmp/thumbs/*.png ]]
}

@test "thumb path changes when mtime changes" {
  local f="$BATS_TEST_TMPDIR/a.txt"; printf hi > "$f"
  run ev_thumb_path "$f" /tmp/thumbs; local p1="$output"
  touch -t 200001010000 "$f"
  run ev_thumb_path "$f" /tmp/thumbs
  [ "$output" != "$p1" ]
}

# ── ev_qlthumb_bin ───────────────────────────────────────────
@test "qlthumb bin uses XDG_CACHE_HOME when set" {
  XDG_CACHE_HOME=/tmp/xc run ev_qlthumb_bin
  [ "$output" = "/tmp/xc/ev/ev-qlthumb" ]
}

@test "qlthumb bin falls back to HOME cache" {
  XDG_CACHE_HOME= HOME=/tmp/hh run ev_qlthumb_bin
  [ "$output" = "/tmp/hh/.cache/ev/ev-qlthumb" ]
}
