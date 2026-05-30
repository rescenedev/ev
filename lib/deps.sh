# 의존성 점검 및 설치 명령 조립. source 전용.

# 인자로 받은 명령들 중 PATH에 없는 것만 한 줄씩 출력.
ev_missing_deps() {
  local c
  for c in "$@"; do
    command -v "$c" >/dev/null 2>&1 || printf '%s\n' "$c"
  done
}

# 인자로 받은 패키지들을 brew install 한 줄로 조립. 인자 없으면 아무것도 출력 안 함.
ev_install_cmd() {
  [ "$#" -eq 0 ] && return 0
  printf 'brew install %s\n' "$*"
}
