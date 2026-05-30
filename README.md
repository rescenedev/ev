# ev

macOS 터미널용 Everything 스타일 즉시 검색 도구. `rg` + `fzf` + `fd` 래퍼.

## 설치

```bash
git clone <repo> && cd everything
./ev          # rg/fzf/fd 없으면 자동 설치 (brew)
```

`ev`를 PATH에 두려면: `ln -s "$PWD/ev" /usr/local/bin/ev`

## 사용법

```bash
ev            # 현재 폴더 검색
ev ~/work     # 특정 폴더 검색
```

실행하면 **현재 폴더 하위의 파일 목록**부터 보여준다.
타이핑하면 **파일명(fd)과 파일 내용(rg)을 동시에 검색**해 결과를 합쳐 보여준다.
내용 매치는 `파일:줄:열:내용` 형태로 나오고, 파일명 매치는 경로만 나온다.

| 키 | 동작 |
|---|---|
| 타이핑 | 즉시 검색 (파일명 + 내용 동시) |
| `Ctrl-F` | 검색 범위 순환: 전체(`search>`) → 파일명만(`name>`) → 내용만(`text>`) |
| `Ctrl-H` | 숨김파일/.gitignore 포함 토글 |
| `Enter` | 텍스트는 `$EDITOR`(해당 줄), hwpx는 추출 텍스트를 pager로, 그 외(pdf/이미지 등)는 macOS 기본 앱(`open`) |
| `Ctrl-O` | 선택 파일을 Finder에서 열기(위치 표시, `open -R`) |
| `Ctrl-Y` | 경로 클립보드 복사 |
| `?` | 미리보기 토글 |
| `Esc` | 종료 |

> 터미널 TUI는 `Cmd` 키 조합을 받지 못하므로 Finder 열기는 `Ctrl-O`로 제공한다.

## HWPX 지원

`.hwpx`(zip+XML) 파일은 본문 텍스트를 추출해 **내용 검색**과 **미리보기**가 된다.
`rg --pre` 전처리기(`libexec/ev-extract`)로 hwpx만 평문 변환해 검색하므로 별도 인덱스가 없다.
한글 앱이 없어도 `Enter`로 추출 텍스트를 pager로 읽을 수 있다.
(구버전 바이너리 `.hwp`는 미지원 — 별도 파서 필요.)

## 환경변수

- `EDITOR` — 열 때 사용할 에디터 (기본 `vi`)
- `EV_AUTO_INSTALL=0` — 의존성 자동 설치 끄기(안내만)

## 의존성

- 필수: ripgrep, fzf(0.73+), fd
- 선택: bat (미리보기 하이라이트; 없으면 cat)
- 내장: unzip, perl (hwpx 텍스트 추출; macOS 기본 제공)
- 개발: bats-core (테스트)

## 테스트

```bash
bats test/
```
