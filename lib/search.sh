# rg / fd 실행 argv 조립. source 전용. 토큰을 한 줄에 하나씩 출력(공백 안전).

# 사용법: ev_rg_cmd <root> <hidden:0|1> <query> [extractor]
# extractor 가 주어지면 rg --pre 로 hwpx 등을 평문 추출해 검색한다.
ev_rg_cmd() {
  local root="$1" hidden="$2" query="$3" extractor="${4:-}"
  printf '%s\n' rg --column --line-number --no-heading --color=always --smart-case
  if [ -n "$extractor" ]; then
    printf '%s\n' --pre "$extractor" --pre-glob '*.hwpx' --pre-glob '*.docx' --pre-glob '*.pdf'
  fi
  _ev_emit_rg_globs                       # *.확장자 필터 (EV_EXTS)
  if [ "$hidden" = 1 ]; then
    printf '%s\n' --hidden --no-ignore
  fi
  printf '%s\n' -- "$query" "$root"
}

# 검색에서 제외할 바이너리/컴파일 아티팩트 글롭. EV_EXCLUDE_GLOBS로 덮어쓸 수 있다.
: "${EV_EXCLUDE_GLOBS:=*.so *.dylib *.o *.a *.class *.pyc *.pyo *.exe *.dll *.node *.wasm}"

# 쿼리에서 '*.확장자' 토큰만 뽑아 소문자 확장자 목록으로 (공백 구분). 예: "*.PDF 유동성" → "pdf"
ev_query_exts() {
  printf '%s' "$1" | perl -ne 'my @e; while (/(?:^|\s)\*\.([A-Za-z0-9]+)(?=\s|$)/g) { push @e, lc $1 } print "@e";'
}

# 쿼리에서 '*.확장자' 토큰을 제거한 나머지(실제 검색어). 예: "*.pdf 유동성" → "유동성"
ev_query_terms() {
  printf '%s' "$1" | perl -pe 's/(?:^|\s)\*\.[A-Za-z0-9]+(?=\s|$)/ /g; s/^\s+|\s+$//g; s/\s+/ /g;'
}

# EV_EXTS(공백 구분 확장자)를 fd 인자로 출력
_ev_emit_fd_exts() {
  [ -n "${EV_EXTS:-}" ] || return 0
  local e
  printf '%s\n' "$EV_EXTS" | tr ' ' '\n' | while IFS= read -r e; do
    [ -n "$e" ] && printf '%s\n' --extension "$e"
  done
}

# EV_EXTS를 rg 글롭 인자로 출력
_ev_emit_rg_globs() {
  [ -n "${EV_EXTS:-}" ] || return 0
  local e
  printf '%s\n' "$EV_EXTS" | tr ' ' '\n' | while IFS= read -r e; do
    [ -n "$e" ] && printf '%s\n' -g "*.$e"
  done
}

# 사용법: ev_fd_cmd <root> <hidden:0|1> [pattern]
# pattern 생략 시 '.' (모든 파일). 주어지면 파일명 패턴으로 사용.
ev_fd_cmd() {
  local root="$1" hidden="$2" pattern="${3:-.}"
  printf '%s\n' fd --type f --color=always
  # 바이너리 아티팩트 제외 (.so 등). tr+read 로 zsh/bash 모두에서 안전하게 분해.
  local g
  printf '%s\n' "$EV_EXCLUDE_GLOBS" | tr ' ' '\n' | while IFS= read -r g; do
    [ -n "$g" ] && printf '%s\n' --exclude "$g"
  done
  _ev_emit_fd_exts                        # *.확장자 필터 (EV_EXTS)
  if [ "$hidden" = 1 ]; then
    printf '%s\n' --hidden --no-ignore
  fi
  printf '%s\n' "$pattern" "$root"
}
