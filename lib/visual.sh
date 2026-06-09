# 비주얼(인라인 이미지) 미리보기 헬퍼. source 전용.
# zsh(런타임)·bash(bats) 양쪽에서 동작해야 함 — zsh-only 문법 금지.

# 인라인 이미지(kitty graphics protocol)를 지원하는 터미널인지 판정.
# Ghostty / kitty / WezTerm 계열만 지원. (iTerm2는 kitty protocol 미지원 → 제외)
ev_graphics_supported() {
  [ -n "${KITTY_WINDOW_ID:-}" ] && return 0
  [ -n "${GHOSTTY_RESOURCES_DIR:-}" ] && return 0
  case "${TERM_PROGRAM:-}" in ghostty|WezTerm) return 0 ;; esac
  case "${TERM:-}" in xterm-ghostty|xterm-kitty) return 0 ;; esac
  return 1
}

# 이미지 렌더러 경로. chafa가 있으면 'chafa', 없으면 빈 출력.
ev_visual_renderer() {
  command -v chafa >/dev/null 2>&1 && printf 'chafa\n'
}

# 캐시 PNG 경로 산출. 키 = 파일 절대경로 + mtime 해시 → 파일이 바뀌면 경로도 바뀐다.
# 사용법: ev_thumb_path <file> <dir>
ev_thumb_path() {
  local file="$1" dir="$2" mtime key
  mtime="$(stat -f %m "$file" 2>/dev/null || stat -c %Y "$file" 2>/dev/null || printf 0)"
  key="$(printf '%s:%s' "$file" "$mtime" | cksum | awk '{print $1}')"
  printf '%s/%s.png\n' "$dir" "$key"
}

# 화면에 그려둔 모든 kitty 이미지를 삭제하는 escape 출력 (미리보기 전환 시 잔상 제거).
ev_clear_images() {
  printf '\033_Ga=d,d=A\033\\'
}

# chafa 렌더 명령 문자열을 stdout으로 출력 (호출부에서 eval).
# 사용법: ev_render_image_cmd <png> <cols> <lines>
ev_render_image_cmd() {
  local png="$1" cols="$2" lines="$3"
  printf 'chafa -f kitty -s %sx%s -- %s\n' "$cols" "$lines" "$png"
}

# QLThumbnailGenerator 헬퍼 바이너리의 캐시 경로 (컴파일은 하지 않음).
ev_qlthumb_bin() {
  local cache="${XDG_CACHE_HOME:-$HOME/.cache}/ev"
  printf '%s/ev-qlthumb\n' "$cache"
}

# 필요 시 헬퍼를 컴파일하고 바이너리 경로를 출력. swiftc 부재/컴파일 실패 시 비0 반환.
# 바이너리가 없거나 소스보다 오래됐을 때만 재컴파일.
ev_ensure_qlthumb() {
  local src="${EV_HOME:-.}/libexec/ev-qlthumb.swift" bin
  bin="$(ev_qlthumb_bin)"
  command -v swiftc >/dev/null 2>&1 || return 1
  [ -f "$src" ] || return 1
  if [ ! -x "$bin" ] || [ "$src" -nt "$bin" ]; then
    mkdir -p "$(dirname "$bin")" || return 1
    swiftc -O "$src" -o "$bin" >/dev/null 2>&1 || return 1
  fi
  printf '%s\n' "$bin"
}

# 썸네일 PNG 생성. 캐시 히트면 즉시 성공. 생성 실패 시 비0 반환.
# 사용법: ev_make_thumb <file> <out_png>
ev_make_thumb() {
  local file="$1" out="$2" bin
  if [ -f "$out" ]; then return 0; fi
  bin="$(ev_ensure_qlthumb)" || return 1
  "$bin" "$file" "$out" 1200 >/dev/null 2>&1 || return 1
  [ -f "$out" ]
}
