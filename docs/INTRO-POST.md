# ev — 맥 터미널에서 즉시 뜨는 파일 검색기 (한글 hwpx 내용까지 관통)

윈도우의 **Everything** 같은 "타이핑하는 순간 결과가 뜨는" 검색이 맥엔 마땅한 게 없어서
직접 만들었습니다. `ripgrep` + `fzf` + `fd` 위에 얹은 얇은 zsh 래퍼라 가볍고,
**파일명과 파일 내용을 동시에** 뒤집니다. 특히 **`.hwpx` 한글 문서 본문까지** 검색·미리보기됩니다.

## 뭐가 좋냐면

- ⚡ **즉시성** — 한 글자 칠 때마다 검색이 다시 돕니다. 엔터 필요 없음.
- 🔎 **이름 + 내용 한 번에** — 파일명 매치와 내용 매치를 합쳐서 보여줍니다. 도구를 갈아탈 필요가 없어요.
- 📄 **한글 문서(.hwpx)를 관통** — 한컴오피스 없이도 hwpx 본문을 **검색·미리보기·읽기** 가능.
  docx / pptx / xlsx / pdf 도 됩니다. (별도 인덱스·캐시 없이 검색 시점에 추출)
- 🪶 **가볍다** — 컴파일 없는 단일 zsh 스크립트.

## 설치 (Homebrew)

```bash
brew tap seongilp/ev
brew install ev
```

## 써보기

```bash
ev            # 현재 폴더에서 TUI 검색
ev ~/work     # 특정 폴더
```

실행하면 파일 목록이 바로 뜨고, 타이핑하면 파일명(fd) + 내용(rg)을 동시에 검색합니다.

- `Ctrl-F` 검색 범위 순환 (전체 → 파일명만 → 내용만)
- `Ctrl-H` 숨김파일/.gitignore 포함 토글
- `Enter` 열기 (텍스트는 에디터 해당 줄로, hwpx는 추출 텍스트로)
- `Ctrl-O` Finder에서 위치 보기 · `Ctrl-Y` 경로 복사 · `Ctrl-E` 결과 Markdown 내보내기

검색창에 `*.hwpx 유동성` 처럼 치면 hwpx 파일에서만 "유동성"을 찾는 확장자 필터도 됩니다.

파이프/스크립트용 비대화형 모드도 있습니다:

```bash
ev -g 유동성 ~/docs --format md > report.md   # 한글 문서까지 뒤져 보고서로
ev -l ~/work --json | jq .                     # 파일 목록 JSON
ev -x 보고서.hwpx | less                        # hwpx 평문 추출
```

## 링크

- GitHub: https://github.com/seongilp/ev
- 설치 tap: https://github.com/seongilp/homebrew-ev

필수: `ripgrep` / `fzf` / `fd` (brew로 함께 설치). 선택: `bat`(미리보기 하이라이트) · `poppler`(PDF).
macOS / zsh 환경에서 만들고 테스트했습니다. 피드백 환영합니다 🙏
