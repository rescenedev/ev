#!/usr/bin/env bats

setup() {
  EV="${BATS_TEST_DIRNAME}/../ev"
  STATE="$(mktemp -d)"
  ROOT="$(mktemp -d)"
  printf 'alpha beta\n'        > "$ROOT/note.txt"
  printf 'plain text\n'        > "$ROOT/ripgrep-config.txt"  # 파일명에 ripgrep
  printf 'uses ripgrep here\n' > "$ROOT/readme.txt"          # 내용에 ripgrep
  export EV_STATE="$STATE" EV_ROOT="$ROOT"
}

teardown() { rm -rf "$STATE" "$ROOT"; }

# 최소 hwpx(zip) 샘플 생성
_make_hwpx() {
  local out="$1" body="$2"
  local d="$BATS_TEST_TMPDIR/hwpx.$$"
  mkdir -p "$d/Contents"
  printf '<hml><hp:p><hp:t>%s</hp:t></hp:p></hml>' "$body" > "$d/Contents/section0.xml"
  ( cd "$d" && zip -qr "$out" . )
  rm -rf "$d"
}

# 최소 docx(zip) 샘플 생성
_make_docx() {
  local out="$1" body="$2"
  local d="$BATS_TEST_TMPDIR/docx.$$"
  mkdir -p "$d/word"
  printf '<w:document><w:body><w:p><w:r><w:t>%s</w:t></w:r></w:p></w:body></w:document>' "$body" > "$d/word/document.xml"
  ( cd "$d" && zip -qr "$out" . )
  rm -rf "$d"
}

# 최소 pptx(zip) 샘플 생성
_make_pptx() {
  local out="$1" body="$2"
  local d="$BATS_TEST_TMPDIR/pptx.$$"
  mkdir -p "$d/ppt/slides"
  printf '<p:sld><a:t>%s</a:t></p:sld>' "$body" > "$d/ppt/slides/slide1.xml"
  ( cd "$d" && zip -qr "$out" . )
  rm -rf "$d"
}

@test "init creates hidden state defaulting to off" {
  run "$EV" __init
  [ "$status" -eq 0 ]
  [ "$(cat "$STATE/hidden")" = "0" ]
}

@test "init defaults search scope to both" {
  "$EV" __init
  [ "$(cat "$STATE/scope")" = "both" ]
}

@test "cycle-scope goes both -> files -> content -> both" {
  "$EV" __init
  run "$EV" __cycle-scope
  [ "$(cat "$STATE/scope")" = "files" ];   [[ "$output" == *"name>"* ]]
  run "$EV" __cycle-scope
  [ "$(cat "$STATE/scope")" = "content" ]; [[ "$output" == *"text>"* ]]
  run "$EV" __cycle-scope
  [ "$(cat "$STATE/scope")" = "both" ];    [[ "$output" == *"search>"* ]]
}

@test "files scope returns only filename matches" {
  "$EV" __init; printf 'files\n' > "$STATE/scope"
  FZF_QUERY="ripgrep" run "$EV" __search
  [[ "$output" == *"ripgrep-config.txt"* ]]   # 파일명 매치
  [[ "$output" != *"readme.txt"* ]]           # 내용 매치 제외
}

@test "content scope returns only content matches" {
  "$EV" __init; printf 'content\n' > "$STATE/scope"
  FZF_QUERY="ripgrep" run "$EV" __search
  [[ "$output" == *"readme.txt"* ]]           # 내용 매치
  [[ "$output" != *"ripgrep-config.txt"* ]]   # 파일명 전용 제외
}

@test "empty query lists files" {
  "$EV" __init
  FZF_QUERY="" run "$EV" __search
  [[ "$output" == *"note.txt"* ]]
  [[ "$output" == *"readme.txt"* ]]
}

@test "query matches filenames (fd)" {
  "$EV" __init
  FZF_QUERY="ripgrep" run "$EV" __search
  [[ "$output" == *"ripgrep-config.txt"* ]]
}

@test "query matches file contents (rg)" {
  "$EV" __init
  # readme.txt 는 파일명에 ripgrep 이 없으므로, 등장하면 내용 매치로 나온 것
  FZF_QUERY="ripgrep" run "$EV" __search
  [[ "$output" == *"readme.txt"* ]]
}

@test "unified search returns both filename and content hits together" {
  "$EV" __init
  FZF_QUERY="ripgrep" run "$EV" __search
  [[ "$output" == *"ripgrep-config.txt"* ]]   # 파일명 매치 (fd)
  [[ "$output" == *"readme.txt"* ]]           # 내용 매치 (rg)
}

@test "query '*.pdf' filters the listing to pdf files only" {
  : > "$ROOT/doc.pdf"
  "$EV" __init
  FZF_QUERY="*.pdf" run "$EV" __search
  [[ "$output" == *"doc.pdf"* ]]
  [[ "$output" != *"note.txt"* ]]
}

@test "query '*.txt alpha' filters by extension and searches terms" {
  "$EV" __init; printf 'content\n' > "$STATE/scope"
  FZF_QUERY="*.txt alpha" run "$EV" __search
  [[ "$output" == *"note.txt"* ]]    # alpha beta 가 들어있는 txt
}

@test "toggle-hidden flips 0 -> 1 and emits reload" {
  "$EV" __init
  run "$EV" __toggle-hidden
  [ "$(cat "$STATE/hidden")" = "1" ]
  [[ "$output" == *"reload"* ]]
}

@test "open builds an editor command in dry-run" {
  EDITOR=vim EV_DRY_RUN=1 run "$EV" __open "$ROOT/note.txt" 1
  [ "$output" = "vim +1 $ROOT/note.txt" ]
}

@test "open falls back to vi when EDITOR unset" {
  unset EDITOR
  EV_DRY_RUN=1 run "$EV" __open "$ROOT/note.txt" 2
  [ "$output" = "vi +2 $ROOT/note.txt" ]
}

@test "open uses macOS 'open' for non-text (binary) files like hwp" {
  printf 'PK\003\004\000\000hwpbin' > "$ROOT/doc.hwp"
  EDITOR=vim EV_DRY_RUN=1 run "$EV" __open "$ROOT/doc.hwp" ""
  [ "$output" = "open $ROOT/doc.hwp" ]
}

@test "open shows hwpx as extracted text in a pager (dry-run)" {
  _make_hwpx "$ROOT/doc.hwpx" "본문내용"
  EV_DRY_RUN=1 run "$EV" __open "$ROOT/doc.hwpx" ""
  [ "$output" = "pager:$ROOT/doc.hwpx" ]
}

@test "content search finds text inside an hwpx via the extractor" {
  _make_hwpx "$ROOT/spec.hwpx" "금융투자업규정 일부개정"
  "$EV" __init; printf 'content\n' > "$STATE/scope"
  FZF_QUERY="금융투자업규정" run "$EV" __search
  [[ "$output" == *"spec.hwpx"* ]]
}

@test "preview renders hwpx as extracted text" {
  _make_hwpx "$ROOT/p.hwpx" "미리보기확인텍스트"
  run "$EV" __preview "$ROOT/p.hwpx" ""
  [[ "$output" == *"미리보기확인텍스트"* ]]
}

@test "content search finds text inside a pptx via the extractor" {
  _make_pptx "$ROOT/deck.pptx" "분기실적 발표자료"
  "$EV" __init; printf 'content\n' > "$STATE/scope"
  FZF_QUERY="분기실적" run "$EV" __search
  [[ "$output" == *"deck.pptx"* ]]
}

@test "preview renders docx as extracted text" {
  _make_docx "$ROOT/resume.docx" "박성일 국문이력서 본문"
  run "$EV" __preview "$ROOT/resume.docx" ""
  [[ "$output" == *"박성일 국문이력서 본문"* ]]
}

@test "content search finds text inside a docx via the extractor" {
  _make_docx "$ROOT/resume.docx" "경력 프로젝트 리더십"
  "$EV" __init; printf 'content\n' > "$STATE/scope"
  FZF_QUERY="프로젝트" run "$EV" __search
  [[ "$output" == *"resume.docx"* ]]
}
