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

```bash
git clone https://github.com/seongilp/ev
cd ev
./ev                 # rg/fzf/fd 없으면 자동으로 brew 설치
```

PATH에 올리기:

```bash
# 시스템 경로(/usr/local/bin)는 쓰기 권한이 필요 → sudo
sudo ln -s "$PWD/ev" /usr/local/bin/ev

# 또는 sudo 없이 사용자 경로에 (PATH에 ~/.local/bin 이 있어야 함)
mkdir -p ~/.local/bin && ln -s "$PWD/ev" ~/.local/bin/ev
```

## 사용법

```bash
ev            # 현재 폴더 검색
ev ~/work     # 특정 폴더 검색
```

실행하면 **현재 폴더 하위 파일 목록**이 바로 뜬다. 타이핑하면 파일명(fd)과 내용(rg)을
동시에 검색해 결과를 합쳐 보여준다 — 내용 매치는 `파일:줄:열:내용`, 파일명 매치는 경로만.

### 키맵

| 키 | 동작 |
|:--|:--|
| `타이핑` | 즉시 검색 (파일명 + 내용 동시) |
| `Ctrl-F` | 검색 범위 순환: 전체 `search>` → 파일명만 `name>` → 내용만 `text>` |
| `Ctrl-H` | 숨김파일 / `.gitignore` 포함 토글 |
| `Enter` | 텍스트 → `$EDITOR`(해당 줄) · hwpx → 추출 텍스트 pager · 그 외 → macOS 기본 앱 |
| `Ctrl-O` | 선택 파일을 **Finder에서 열기** (위치 표시) |
| `Ctrl-Y` | 경로 클립보드 복사 |
| `?` | 미리보기 창 토글 |
| `Esc` | 종료 |

> 터미널 TUI는 `Cmd` 키 조합을 받지 못해서 Finder 열기는 `Ctrl-O`로 제공한다.

## HWPX 한글 문서 검색

`.hwpx`는 사실 zip 안의 XML이다. `ev`는 `ripgrep`의 `--pre` 전처리기
(`libexec/ev-extract`)로 hwpx만 평문으로 변환해 검색한다.

```
검색어 입력
   │
   ├─ 일반 파일 ──────────────→ rg 가 직접 검색
   └─ *.hwpx ──→ ev-extract ──→ unzip + 태그 제거 → rg 가 추출 텍스트 검색
                                                        │
                                              결과는 원본 hwpx 경로로 표시
```

- **별도 인덱스·캐시 없음** — rg가 검색 시점에 추출, 원본 경로 그대로 결과 표시.
- **미리보기**도 추출 텍스트를 렌더. `Enter`로 전체 본문을 pager(less)로 읽기.
- 한글/한컴오피스가 **설치돼 있지 않아도** 내용을 검색하고 읽을 수 있다.
- 구버전 바이너리 `.hwp`는 미지원(별도 파서 필요). 요즘 문서는 대부분 hwpx.

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

---

<div align="center">
<sub>made with <code>rg</code> + <code>fzf</code> + <code>fd</code> · 단일 zsh 스크립트</sub>
</div>
