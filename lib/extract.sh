# hwpx → 평문 텍스트 추출. source 전용.
# hwpx는 zip 안의 XML이므로 Contents/section*.xml 을 풀어 태그를 제거한다.
# hwpx 가 아니면 파일을 그대로 출력한다(rg --pre, 미리보기에서 공용으로 쓰기 위함).

ev_extract_text() {
  local file="$1"
  case "$file" in
    *.hwpx|*.HWPX) ;;
    *) cat -- "$file" 2>/dev/null; return 0 ;;
  esac

  local s
  for s in $(unzip -Z1 "$file" 2>/dev/null | grep -E 'Contents/section[0-9]+\.xml' | sort); do
    unzip -p "$file" "$s" 2>/dev/null
  done \
    | perl -CSD -pe 's/<[^>]+>/\n/g' \
    | perl -CSD -pe 's/Clickhere:set:[0-9]+:Direction:wstring:[0-9]+://g; s/HelpState:wstring:[0-9]+://g; s/^\s+//;' \
    | perl -CSD -ne 'print if /\S/'
}
