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

# 최소 docx(zip) 샘플 생성: word/document.xml 에 본문 텍스트
_make_docx() {
  local out="$1" body="$2"
  local d="$BATS_TEST_TMPDIR/docx.$$"
  mkdir -p "$d/word"
  printf '<w:document><w:body><w:p><w:r><w:t>%s</w:t></w:r></w:p></w:body></w:document>' "$body" > "$d/word/document.xml"
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

@test "ev_extract_text pulls body text from a docx" {
  local f="$BATS_TEST_TMPDIR/sample.docx"
  _make_docx "$f" "이력서 본문 추출테스트"
  run ev_extract_text "$f"
  [[ "$output" == *"이력서 본문 추출테스트"* ]]
}

# 최소 PDF(텍스트 포함) 생성
_make_pdf() {
  local out="$1" body="$2"
  printf '%s\n' \
'%PDF-1.4' \
'1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj' \
'2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj' \
'3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 300 200]/Contents 4 0 R/Resources<</Font<</F1 5 0 R>>>>>>endobj' \
'4 0 obj<</Length 60>>stream' \
"BT /F1 24 Tf 20 100 Td ($body) Tj ET" \
'endstream endobj' \
'5 0 obj<</Type/Font/Subtype/Type1/BaseFont/Helvetica>>endobj' \
'trailer<</Root 1 0 R>>' \
'%%EOF' > "$out"
}

@test "ev_extract_text pulls text from a pdf (needs pdftotext)" {
  command -v pdftotext >/dev/null 2>&1 || skip "pdftotext 미설치"
  local f="$BATS_TEST_TMPDIR/sample.pdf"
  _make_pdf "$f" "PDFSEARCHABLE"
  run ev_extract_text "$f"
  [[ "$output" == *"PDFSEARCHABLE"* ]]
}

_make_pptx() {
  local out="$1" body="$2"
  local d="$BATS_TEST_TMPDIR/pptx.$$"
  mkdir -p "$d/ppt/slides"
  printf '<p:sld><p:txBody><a:p><a:r><a:t>%s</a:t></a:r></a:p></p:txBody></p:sld>' "$body" > "$d/ppt/slides/slide1.xml"
  ( cd "$d" && zip -qr "$out" . )
  rm -rf "$d"
}

_make_xlsx() {
  local out="$1" body="$2"
  local d="$BATS_TEST_TMPDIR/xlsx.$$"
  mkdir -p "$d/xl"
  printf '<sst><si><t>%s</t></si></sst>' "$body" > "$d/xl/sharedStrings.xml"
  ( cd "$d" && zip -qr "$out" . )
  rm -rf "$d"
}

@test "ev_extract_text pulls text from a pptx" {
  local f="$BATS_TEST_TMPDIR/deck.pptx"
  _make_pptx "$f" "슬라이드 본문 검색"
  run ev_extract_text "$f"
  [[ "$output" == *"슬라이드 본문 검색"* ]]
}

@test "ev_extract_text pulls text from an xlsx (shared strings)" {
  local f="$BATS_TEST_TMPDIR/sheet.xlsx"
  _make_xlsx "$f" "셀값검색대상"
  run ev_extract_text "$f"
  [[ "$output" == *"셀값검색대상"* ]]
}

@test "ev_extract_text passes through non-hwpx files unchanged" {
  local f="$BATS_TEST_TMPDIR/plain.txt"
  printf 'just plain text\n' > "$f"
  run ev_extract_text "$f"
  [[ "$output" == *"just plain text"* ]]
}
