# 미리보기 명령 조립. source 전용.

# bat가 PATH에 있으면 'bat', 없으면 'cat' 출력. (테스트에서 재정의해 분기 강제 가능)
ev_preview_tool() {
  command -v bat >/dev/null 2>&1 && printf 'bat\n' || printf 'cat\n'
}

# 바이너리 파일용: 깨진 내용 대신 파일 정보를 보여준다.
# 사용법: ev_file_info <file>
ev_file_info() {
  local file="$1"
  printf '── 바이너리 파일 (미리보기 불가) ──\n\n'
  printf '%s\n\n' "$file"
  printf '유형: %s\n' "$(file -b "$file" 2>/dev/null)"
  printf '크기: %s\n' "$(ls -lh "$file" 2>/dev/null | awk '{print $5}')"
  printf '\nEnter: 기본 앱으로 열기    Ctrl-O: Finder에서 보기\n'
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
