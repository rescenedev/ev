# 미리보기 명령 조립. source 전용.

# bat가 PATH에 있으면 'bat', 없으면 'cat' 출력. (테스트에서 재정의해 분기 강제 가능)
ev_preview_tool() {
  command -v bat >/dev/null 2>&1 && printf 'bat\n' || printf 'cat\n'
}

# 사용법: ev_preview_cmd <file> <line>
ev_preview_cmd() {
  local file="$1" line="${2:-}" tool
  tool="$(ev_preview_tool)"
  if [ "$tool" = bat ]; then
    if [ -n "$line" ]; then
      printf 'bat --style=numbers --color=always --highlight-line %s -- %s\n' "$line" "$file"
    else
      printf 'bat --style=numbers --color=always -- %s\n' "$file"
    fi
  else
    printf 'cat -n %s\n' "$file"
  fi
}
