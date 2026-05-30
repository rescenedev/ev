# 파일이 텍스트면 0, 바이너리면 1 반환. (grep -I: 바이너리는 매치 없음 취급)
# 빈 파일은 텍스트로 본다. hwp/pdf/이미지 등은 바이너리로 판정됨.
ev_is_text() {
  local file="$1"
  [ -f "$file" ] || return 1
  [ -s "$file" ] || return 0
  LC_ALL=C grep -Iq '' "$file" 2>/dev/null
}

# 에디터별 "줄로 점프" 실행 명령을 조립. source 전용.
# 사용법: ev_editor_cmd <editor> <file> <line>
ev_editor_cmd() {
  local editor="$1" file="$2" line="${3:-}" base
  base="$(basename "$editor")"
  if [ -z "$line" ]; then
    printf '%s %s\n' "$editor" "$file"
    return 0
  fi
  case "$base" in
    code|code-insiders|cursor)
      printf '%s -g %s:%s\n' "$editor" "$file" "$line" ;;
    vi|vim|nvim|view|nano|emacs|emacsclient)
      printf '%s +%s %s\n' "$editor" "$line" "$file" ;;
    *)
      printf '%s %s\n' "$editor" "$file" ;;
  esac
}
