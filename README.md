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

| 키 | 동작 |
|---|---|
| 타이핑 | 즉시 검색 (내용 모드는 rg 실시간) |
| `Ctrl-F` | 파일명 ↔ 내용 모드 토글 |
| `Ctrl-H` | 숨김파일/.gitignore 포함 토글 |
| `Enter` | `$EDITOR`로 해당 줄에서 열기 |
| `Ctrl-Y` | 경로 클립보드 복사 |
| `?` | 미리보기 토글 |
| `Esc` | 종료 |

## 환경변수

- `EDITOR` — 열 때 사용할 에디터 (기본 `vi`)
- `EV_AUTO_INSTALL=0` — 의존성 자동 설치 끄기(안내만)

## 의존성

- 필수: ripgrep, fzf(0.73+), fd
- 선택: bat (미리보기 하이라이트; 없으면 cat)
- 개발: bats-core (테스트)

## 테스트

```bash
bats test/
```
