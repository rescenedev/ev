# office 문서(zip+XML) → 평문 텍스트 추출. source 전용.
# hwpx/docx는 zip 안의 XML이므로 본문 XML을 풀어 태그를 제거한다.
# 지원 외 파일은 그대로 출력한다(rg --pre, 미리보기에서 공용으로 쓰기 위함).

# zip 안에서 entry_re 에 매칭되는 XML 엔트리들을 풀어 평문화.
_ev_extract_zip_xml() {
  local file="$1" entry_re="$2"
  local s
  for s in $(unzip -Z1 "$file" 2>/dev/null | grep -E "$entry_re" | sort); do
    unzip -p "$file" "$s" 2>/dev/null
  done \
    | perl -CSD -pe 's/<[^>]+>/\n/g' \
    | perl -CSD -pe 's/Clickhere:set:[0-9]+:Direction:wstring:[0-9]+://g; s/HelpState:wstring:[0-9]+://g; s/^\s+//;' \
    | perl -CSD -ne 'print if /\S/'
}

ev_extract_text() {
  local file="$1"
  case "$file" in
    *.hwpx|*.HWPX) _ev_extract_zip_xml "$file" 'Contents/section[0-9]+\.xml' ;;
    *.docx|*.DOCX) _ev_extract_zip_xml "$file" 'word/document\.xml' ;;
    *)             cat -- "$file" 2>/dev/null; return 0 ;;
  esac
}
