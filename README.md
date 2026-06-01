<div align="center">

# ⚡ ev

**터미널에서 즉시 뜨는 파일 검색 — macOS용 Everything**

타이핑하는 순간 파일명과 파일 *내용*을 동시에 뒤진다.
`.hwpx` 한글 문서 속까지.

<sub>`ripgrep` · `fzf` · `fd` 위에 얹은 얇은 zsh 래퍼 — 바퀴를 다시 만들지 않았다.</sub>

</div>

---

```
search> 유동성
 1. 규정변경예고 공고문_금융투자업규정 일부개정고시안.hwpx:20:14:증권사의 유동성 리스크 관리…  │  ┌── preview ──────────────┐
 README.md:8:이 도구는 유동성 있게…                                                              │  │ 증권사의 유동성 리스크   │
 lib/search.sh                                                                                    │  │ 관리 역량 및 위기 대응…  │
                                                                                                  │  └─────────────────────────┘
Ctrl-F: 범위  Ctrl-H: 숨김  Enter: 열기  Ctrl-O: Finder  Ctrl-Y: 복사  ?: 미리보기
```

## 왜 ev?

- **즉시성** — 입력할 때마다 `rg`/`fd`가 다시 돌며 결과가 실시간으로 갱신된다. 엔터 칠 필요 없음.
- **이름 + 내용 한 번에** — 파일명 매칭과 파일 내용 매칭을 합쳐 보여준다. 따로 도구를 바꿀 필요 없음.
- **한글 문서(.hwpx) 관통** — zip+XML을 풀어 본문을 추출, 한글 앱 없이도 **내용 검색·미리보기·읽기**가 된다.
- **가볍다** — 컴파일 없는 단일 스크립트. 의존성은 전부 `brew` 한 줄. 없으면 **자동 설치**.

## 설치

### Homebrew (권장)

```bash
brew tap seongilp/ev      # 한 번만
brew install ev           # 이후엔 그냥 ev
brew upgrade ev           # 업데이트
```

`rg`/`fzf`/`fd`는 의존성으로 함께 설치되고, `bat`(미리보기 하이라이트)·`poppler`(PDF 추출)는 권장 의존성으로 같이 깔린다.
최신 `main`을 쓰려면 `brew install --HEAD seongilp/ev/ev`.

### 설치 스크립트

```bash
curl -fsSL https://seongilp.github.io/ev/install.sh | bash
```

`~/.ev`에 받아 `~/.local/bin/ev`로 링크한다. `rg/fzf/fd`는 첫 실행 시 자동 설치.
설치 위치는 `EV_INSTALL_DIR` / `EV_BIN_DIR`로 바꿀 수 있다.

<details><summary>직접 clone 하려면</summary>

```bash
git clone https://github.com/seongilp/ev && cd ev && ./ev
sudo ln -s "$PWD/ev" /usr/local/bin/ev          # 또는
mkdir -p ~/.local/bin && ln -s "$PWD/ev" ~/.local/bin/ev
```
</details>

## 사용법

```bash
ev            # 현재 폴더 검색
ev ~/work     # 특정 폴더 검색
ev .          # 현재 폴더 (명시)
```

실행하면 **현재 폴더 하위 파일 목록**이 바로 뜬다. 타이핑하면 파일명(fd)과 내용(rg)을
동시에 검색해 결과를 합쳐 보여준다 — 내용 매치는 `파일:줄:열:내용`, 파일명 매치는 경로만.
엔터를 칠 필요 없이 **한 글자 입력할 때마다** 검색이 다시 돈다.

### 화면 구성

```
search> 유동성                    ← 여기에 타이핑 (프롬프트가 현재 검색 범위를 알려줌)
 파일1:줄:열:매칭내용  │  ┌ preview ┐   ← 왼쪽: 결과, 오른쪽: 미리보기(매칭 줄 강조)
 파일2 (파일명 매치)   │  │  …      │
 …                     │  └─────────┘
Ctrl-F: 범위  Ctrl-H: 숨김  Enter: 열기  …   ← 하단: 단축키 힌트
```

- **결과 줄 형식** — 내용 매치는 `경로:줄번호:열번호:매칭한 줄`, 파일명 매치는 `경로`만.
- **오른쪽 미리보기** — `bat`이 있으면 문법 하이라이트, 없으면 `cat`. hwpx 등은 추출한 평문을 보여주고 매칭 줄로 스크롤한다.
- **결과가 안 보이면** — 검색 범위(`Ctrl-F`)나 숨김 토글(`Ctrl-H`)을 확인. `.gitignore`에 걸린 파일은 기본적으로 빠진다.

### 검색어 문법

- **공백으로 단어 나열** — `rg`의 스마트 케이스가 적용된다(소문자면 대소문자 무시, 대문자가 섞이면 구분).
- **확장자 필터 `*.확장자`** — 검색어에 `*.pdf` 같은 토큰을 섞으면 그 확장자만 대상으로 좁힌다. 여러 개도 가능.

  ```
  *.hwpx 유동성          → hwpx 파일에서만 "유동성" 검색
  *.hwpx *.pdf 금융      → hwpx·pdf 두 종류에서 "금융" 검색
  *.md                   → 검색어 없이 확장자만 주면 .md 파일 목록
  ```

  > ⚠️ 확장자 필터(`*.확장자`)는 **대화형 TUI 검색창 전용**이다. 비대화형 `ev -g`에는 적용되지 않는다(아래 [비대화형](#비대화형--export) 참고).

### 검색 범위 (`Ctrl-F`로 순환)

| 프롬프트 | 범위 | 동작 |
|:--|:--|:--|
| `search>` | **전체** (기본) | 파일명(fd) + 내용(rg) 동시 |
| `name>`   | **파일명만** | fd로 경로만 매칭 |
| `text>`   | **내용만** | rg로 파일 내용만 매칭 (hwpx 등 추출 포함) |

`Ctrl-F`를 누를 때마다 `전체 → 파일명 → 내용 → 전체` 순으로 돌고, 프롬프트 글자가 현재 범위를 알려준다.

### 다중 선택 → 내보내기 워크플로

1. `Tab`으로 여러 결과를 마킹(`Ctrl-A`로 전체 토글).
2. 마킹한 것들(없으면 현재 줄)을 대상으로:
   - `Ctrl-E` → **Markdown 보고서**로 내보내기
   - `Ctrl-Y` → **경로를 클립보드 복사**
   - `Ctrl-G` → **zip으로 묶기**
3. `Ctrl-E`/`Ctrl-G` 결과는 `$EV_EXPORT_DIR`(기본 `~`)에 `ev-export-<시각>.md` / `ev-files-<시각>.zip`로 저장된다.

### 키맵

| 키 | 동작 |
|:--|:--|
| `타이핑` | 즉시 검색 (파일명 + 내용 동시) |
| `Ctrl-F` | 검색 범위 순환: 전체 `search>` → 파일명만 `name>` → 내용만 `text>` |
| `Ctrl-H` | 숨김파일 / `.gitignore` 포함 토글 |
| `Enter` | 텍스트 → `$EDITOR`(해당 줄) · hwpx → 추출 텍스트 pager · 그 외 → macOS 기본 앱 |
| `Ctrl-O` | 선택 파일을 **Finder에서 열기** (위치 표시) |
| `Tab` | 항목 마킹(다중 선택) · `Shift-Tab` 해제 · `Ctrl-A` 전체 토글 |
| `Ctrl-E` | 선택(없으면 현재) 결과를 **Markdown으로 내보내기** |
| `Ctrl-Y` | 선택(없으면 현재) 경로 클립보드 복사 |
| `Ctrl-G` | 선택(없으면 현재) 파일을 **zip으로 모으기** |
| `?` | 미리보기 창 토글 |
| `Esc` | 검색어 지우기 (비우면 파일 목록으로 복귀) |
| `Ctrl-C` | 종료 |

> 터미널 TUI는 `Cmd` 키 조합을 받지 못해서 Finder 열기는 `Ctrl-O`로 제공한다.
> `Ctrl-E`/`Ctrl-G` 결과는 `$EV_EXPORT_DIR`(기본 `~`)에 `ev-export-<시각>.md` / `ev-files-<시각>.zip`로 저장된다.

## 비대화형 / Export

TUI 없이 파이프·스크립트로 쓰는 모드. fzf를 띄우지 않으므로 cron·CI·다른 명령과 조합하기 좋다.

| 명령 | 하는 일 | 기본 포맷 |
|:--|:--|:--|
| `ev -l [디렉터리]` | 파일 목록 출력 (검색어 없음) | `paths` |
| `ev -g <검색어> [디렉터리]` | 내용 검색 (hwpx/docx/pptx/xlsx/pdf 포함) | `lines` |
| `ev -x <파일>` | 파일 한 개의 평문 추출 | (원문 텍스트) |
| `ev --to-txt <디렉터리> [출력]` | 폴더 내 **hwpx/docx**를 일괄 `.txt`로 변환 | (파일 생성) |
| `ev -h` / `--help` | 도움말 | |

> ⚠️ `-g`/`-l`은 검색어를 **그대로 `rg`/`fd`에 넘긴다**. 대화형의 `*.확장자` 필터 문법은 여기선 안 먹는다 — 확장자로 좁히려면 디렉터리를 직접 지정하거나 결과를 `grep`으로 거른다.
> `-l`은 패턴 인자를 받지 않고 디렉터리 전체를 나열한다(파일명으로 좁히려면 `ev -l DIR | rg 패턴`).

### 출력 포맷

`--format paths|lines|md|csv|json` (또는 `--json` 단축). `-l`은 기본 `paths`, `-g`는 기본 `lines`.

```bash
$ ev -g 유동성 . --format md
- `./b.txt:2` — 유동성
- `./a.md:1` — 유동성 리스크 관리

$ ev -g 유동성 . --format csv
file,line,text
"./b.txt",2,"유동성"
"./a.md",1,"유동성 리스크 관리"

$ ev -g 유동성 . --json
[
  {"file":"./b.txt","line":2,"col":1,"text":"유동성"},
  {"file":"./a.md","line":1,"col":1,"text":"유동성 리스크 관리"}
]
```

- `paths` — 고유 파일 경로만 (중복 제거, 순서 유지)
- `lines` — `경로:줄:열:내용` 원본 그대로
- `md` — Markdown 리스트 (`` - `경로:줄` — 내용 ``)
- `csv` — `file,line,text` 헤더 + 따옴표 이스케이프
- `json` — 객체 배열 (`file`/`line`/`col`/`text`; `-l`은 `file`만)

### 자주 쓰는 레시피

```bash
# 폴더의 한글 문서에서 키워드 찾아 Markdown 보고서로
ev -g 유동성 ~/docs --format md > report.md

# JSON으로 뽑아 jq로 후처리 (매칭된 파일 목록만)
ev -g 금융투자 ~/docs --json | jq -r '.[].file' | sort -u

# 파일 목록을 다른 명령으로 파이프
ev -l ~/work | fzf            # 직접 fzf에 넣기
ev -l ~/work | wc -l          # 개수 세기

# hwpx 한 개를 평문으로 읽기 / 페이저로 보기
ev -x 보고서.hwpx | less

# 폴더 전체 hwpx·docx를 .txt로 변환 (원본 옆 또는 지정 폴더에)
ev --to-txt ~/docs                # 원본과 같은 위치에 *.txt 생성
ev --to-txt ~/docs ~/docs-txt     # ~/docs-txt 아래에 모아서 생성
```

## 문서 내용 검색 (HWPX · DOCX · PPTX · XLSX · PDF)

`.hwpx`/`.docx`/`.pptx`/`.xlsx`는 사실 zip 안의 XML이고, `.pdf`는 `pdftotext`로 푼다.
`ev`는 `ripgrep`의 `--pre` 전처리기(`libexec/ev-extract`)로 이들만 평문으로 변환해 검색·미리보기한다.

```
검색어 입력
   │
   ├─ 일반 파일 ─────────────────────────────→ rg 가 직접 검색
   └─ *.hwpx/docx/pptx/xlsx/pdf ──→ ev-extract ──→ 평문 변환 → rg 가 추출 텍스트 검색
                                                                  │
                                                    결과는 원본 파일 경로로 표시
```

추출 방식: hwpx=`Contents/section*.xml` · docx=`word/document.xml` ·
pptx=`ppt/slides/slide*.xml` · xlsx=`xl/sharedStrings.xml`+시트 · pdf=`pdftotext`.

- **별도 인덱스·캐시 없음** — rg가 검색 시점에 추출, 원본 경로 그대로 결과 표시.
- **미리보기**에 추출 텍스트를 렌더하고 매칭 줄을 강조한다.
- 한글/한컴오피스, MS Office가 **없어도** 내용을 검색하고 미리보기로 읽을 수 있다.
- `Enter` — hwpx는 추출 텍스트를 pager로, 나머지는 macOS 기본 앱으로 연다.
- pdf 본문은 `pdftotext`(poppler) 필요. 구버전 바이너리 `.hwp`는 미지원.

## 동작 원리

`fzf`가 메인 루프를 돌고, 검색·미리보기·열기·범위전환은 `ev`의 숨은 서브커맨드가 맡는다.
fzf는 `--bind`의 `reload`/`transform`/`become` 액션으로 이 서브커맨드를 호출하고,
현재 쿼리는 `FZF_QUERY` 환경변수로 전달된다.

```
ev (zsh)
├─ lib/deps.sh      의존성 점검 / 자동 설치
├─ lib/search.sh    rg · fd 명령 조립 (+ hwpx 전처리기 연결)
├─ lib/extract.sh   hwpx → 평문 텍스트
├─ lib/editor.sh    에디터 줄 점프 · 텍스트/바이너리 판별
├─ lib/preview.sh   미리보기 명령 (bat → cat 폴백)
└─ libexec/ev-extract   rg --pre 전처리기
```

## 환경변수

| 변수 | 의미 |
|:--|:--|
| `EDITOR` | 열 때 사용할 에디터 (기본 `vi`) |
| `EV_AUTO_INSTALL=0` | 의존성 자동 설치 끄기 (안내만) |
| `EV_EXPORT_DIR` | `Ctrl-E`/`Ctrl-G` 내보내기 저장 위치 (기본 `~`) |
| `EV_EXCLUDE_GLOBS` | 검색에서 제외할 글롭 (기본: `*.so *.dylib *.o *.a *.class *.pyc *.pyo *.exe *.dll *.node *.wasm`) |

바이너리/컴파일 아티팩트(`.so` 등)는 기본적으로 검색 결과에서 제외된다.
미리보기에서 바이너리 파일은 본문 대신 파일 유형·크기 정보를 보여준다.

## 의존성

- **필수** — ripgrep, fzf (0.73+), fd
- **선택** — bat (미리보기 문법 하이라이트; 없으면 `cat`)
- **내장** — unzip, perl (hwpx 추출; macOS 기본 제공)
- **개발** — bats-core (테스트)

## 테스트

```bash
bats test/      # 44 tests
```

순수 헬퍼 함수와 rg/fd/추출 동작은 bats로, 대화형 fzf 화면은
[`docs/MANUAL-CHECKLIST.md`](docs/MANUAL-CHECKLIST.md) 수동 점검으로 검증한다.

## 랜딩 페이지

`site/` 의 정적 페이지(Terminal CLI 테마)를 GitHub Actions로 GitHub Pages에 배포한다.
Settings → Pages → Source를 **GitHub Actions**로 설정하면 `main` 푸시 시 자동 배포된다.

---

<div align="center">
<sub>built with <a href="https://claude.com/claude-code">Claude</a> · <code>rg</code> + <code>fzf</code> + <code>fd</code> · 단일 zsh 스크립트</sub>
</div>
