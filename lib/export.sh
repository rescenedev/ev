# 검색 결과 포맷터. source 전용.
# 입력(stdin) 라인은 둘 중 하나:
#   - 'path'                  (파일명 매치, fd)
#   - 'path:line:col:text'    (내용 매치, rg)

# ANSI 색상 코드 제거
ev_strip_ansi() {
  perl -pe 's/\e\[[0-9;]*m//g'
}

# 고유 파일 경로만 (순서 유지)
ev_export_paths() {
  perl -ne 'chomp; if (/^(.+?):\d+:\d+:/) { $p=$1 } else { $p=$_ } next unless length $p; print "$p\n" unless $seen{$p}++;'
}

# 원본 라인 그대로 (path:line:col:text)
ev_export_lines() { cat; }

# Markdown 리스트
ev_export_md() {
  perl -ne 'chomp; next unless length;
    if (/^(.+?):(\d+):\d+:(.*)$/) { print "- `$1:$2` — $3\n" }
    else { print "- `$_`\n" }'
}

# CSV (file,line,text)
ev_export_csv() {
  printf 'file,line,text\n'
  perl -ne 'chomp; next unless length;
    sub cq { my $s=shift; $s =~ s/"/""/g; return "\"$s\"" }
    if (/^(.+?):(\d+):\d+:(.*)$/) { print cq($1).",".$2.",".cq($3)."\n" }
    else { print cq($_).",,\n" }'
}

# JSON 배열
ev_export_json() {
  perl -ne 'BEGIN { print "[\n"; $n=0 }
    chomp; next unless length;
    sub esc { my $s=shift; $s =~ s/\\/\\\\/g; $s =~ s/"/\\"/g; return $s }
    print ",\n" if $n++;
    if (/^(.+?):(\d+):(\d+):(.*)$/) {
      printf "  {\"file\":\"%s\",\"line\":%d,\"col\":%d,\"text\":\"%s\"}", esc($1),$2,$3,esc($4);
    } else {
      printf "  {\"file\":\"%s\"}", esc($_);
    }
    END { print "\n]\n" }'
}

# 포맷 이름으로 디스패치
ev_format() {
  case "${1:-lines}" in
    paths) ev_export_paths ;;
    md)    ev_export_md ;;
    csv)   ev_export_csv ;;
    json)  ev_export_json ;;
    *)     ev_export_lines ;;
  esac
}
