# rg / fd 실행 argv 조립. source 전용. 토큰을 한 줄에 하나씩 출력(공백 안전).

# 사용법: ev_rg_cmd <root> <hidden:0|1> <query> [extractor]
# extractor 가 주어지면 rg --pre 로 hwpx 등을 평문 추출해 검색한다.
ev_rg_cmd() {
  local root="$1" hidden="$2" query="$3" extractor="${4:-}"
  printf '%s\n' rg --column --line-number --no-heading --color=always --smart-case
  if [ -n "$extractor" ]; then
    printf '%s\n' --pre "$extractor" --pre-glob '*.hwpx'
  fi
  if [ "$hidden" = 1 ]; then
    printf '%s\n' --hidden --no-ignore
  fi
  printf '%s\n' -- "$query" "$root"
}

# 사용법: ev_fd_cmd <root> <hidden:0|1> [pattern]
# pattern 생략 시 '.' (모든 파일). 주어지면 파일명 패턴으로 사용.
ev_fd_cmd() {
  local root="$1" hidden="$2" pattern="${3:-.}"
  printf '%s\n' fd --type f --color=always
  if [ "$hidden" = 1 ]; then
    printf '%s\n' --hidden --no-ignore
  fi
  printf '%s\n' "$pattern" "$root"
}
