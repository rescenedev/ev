#!/usr/bin/env bats

setup() {
  source "${BATS_TEST_DIRNAME}/../lib/extract.sh"
}

# 최소 hwpx(zip) 샘플 생성: Contents/section0.xml 에 본문 텍스트
_make_hwpx() {
  local out="$1" body="$2"
  local d="$BATS_TEST_TMPDIR/src.$$"
  mkdir -p "$d/Contents"
  printf '<hml><hp:p><hp:t>%s</hp:t></hp:p></hml>' "$body" > "$d/Contents/section0.xml"
  ( cd "$d" && zip -qr "$out" . )
  rm -rf "$d"
}

@test "ev_extract_text pulls body text from an hwpx" {
  local f="$BATS_TEST_TMPDIR/sample.hwpx"
  _make_hwpx "$f" "안녕하세요 검색테스트"
  run ev_extract_text "$f"
  [[ "$output" == *"안녕하세요 검색테스트"* ]]
}

@test "ev_extract_text strips form-control noise tokens" {
  local f="$BATS_TEST_TMPDIR/noisy.hwpx"
  _make_hwpx "$f" "Clickhere:set:45:Direction:wstring:3:기관명 HelpState:wstring:0:금융위원회"
  run ev_extract_text "$f"
  [[ "$output" == *"기관명"* ]]
  [[ "$output" == *"금융위원회"* ]]
  [[ "$output" != *"Clickhere:set:45"* ]]
  [[ "$output" != *"HelpState:wstring"* ]]
}

@test "ev_extract_text passes through non-hwpx files unchanged" {
  local f="$BATS_TEST_TMPDIR/plain.txt"
  printf 'just plain text\n' > "$f"
  run ev_extract_text "$f"
  [[ "$output" == *"just plain text"* ]]
}
