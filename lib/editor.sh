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
