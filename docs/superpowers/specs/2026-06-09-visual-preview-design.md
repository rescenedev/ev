# 비주얼 미리보기 (인라인 이미지) 설계

## 배경 / 목적

`ev`는 office 문서(hwpx/docx/pptx/xlsx)와 pdf를 **텍스트로 추출해** 미리보기 창에 보여준다.
사용자는 Finder의 Quick Look처럼 **문서를 시각적으로** 보고 싶어한다.

Ghostty가 kitty graphics protocol을 지원하므로, fzf preview 창 안에 문서 첫 페이지를
이미지로 렌더링할 수 있다. 단 기존 "텍스트 검색 → 원본 라인 표시" 철학은 유지하고,
비주얼은 **키 토글로 켜는 부가 모드**로 둔다.

## 사전 조사 결과 (검증됨)

- Ghostty (`TERM=xterm-ghostty`, `TERM_PROGRAM=ghostty`) → kitty graphics protocol 지원.
- `qlmanage -t`(macOS Quick Look 엔진)로 **pdf 썸네일 PNG 생성 성공**. docx/pptx/xlsx도
  macOS 기본 QL 제너레이터가 있어 동일하게 가능.
- **hwpx는 Quick Look 플러그인이 없어 `qlmanage`가 썸네일을 생성하지 못함** (한컴 QL 미설치).
  → hwpx는 비주얼 불가, 텍스트 추출로 폴백.
- `pdftoppm`(poppler), `sips` 사용 가능. `chafa`는 미설치 → 신규 의존성으로 추가.

## 동작

1. 기본 미리보기는 현재처럼 **텍스트 추출**(`_ev_preview_extracted` / `bat`).
2. fzf에서 **`Ctrl-V`** 로 비주얼 ↔ 텍스트 토글.
3. 비주얼 모드일 때, 아래 조건을 모두 만족하면 이미지로 렌더:
   - 그래픽 지원 터미널(`ev_graphics_supported`)
   - 렌더러 존재(`chafa`)
   - 렌더 가능 포맷(`ev_visual_previewable`)
4. 하나라도 불만족이면 **텍스트로 폴백 + 짧은 힌트**(예: `[hint] 비주얼 미리보기: brew install chafa`,
   hwpx의 경우 `[hint] hwpx는 비주얼 미리보기를 지원하지 않습니다`).

## 파이프라인

```
문서(pdf/docx/pptx/xlsx) → qlmanage -t → PNG(캐시) → chafa -f kitty → fzf preview 창
이미지 파일(png/jpg/gif/...) → (썸네일 불필요)            → chafa -f kitty → fzf preview 창
hwpx                                                    → 텍스트 추출 폴백
```

- 썸네일 캐시: `$EV_STATE/thumbs/` (per-run mktemp 디렉터리, 종료 시 자동 삭제).
  키 = 파일 절대경로 + mtime 해시. 두 번째 preview부터 즉시 표시.
- 이미지 크기: fzf가 preview 프로세스에 export 하는 `FZF_PREVIEW_COLUMNS`/`FZF_PREVIEW_LINES` 사용.

## 신규 파일: `lib/visual.sh`

source 전용. zsh(런타임)·bash(bats) 양쪽에서 동작해야 함(zsh-only 문법 금지).

| 함수 | 역할 | 입력 | 출력/반환 | 테스트 |
|---|---|---|---|---|
| `ev_graphics_supported` | 그래픽 지원 터미널 감지 | env(`TERM`,`TERM_PROGRAM`,`KITTY_WINDOW_ID`,`GHOSTTY_*`) | exit 0/1 | env 스텁 |
| `ev_visual_renderer` | 렌더러 경로 | PATH | `chafa` 또는 빈 문자열 | PATH 스텁 |
| `ev_visual_previewable` | 확장자가 렌더 가능한지 | file | exit 0/1 (hwpx=false) | 순수 |
| `ev_thumb_path` | 캐시 PNG 경로 산출 | file, dir | 경로 문자열(stdout) | 순수 |
| `ev_render_image_cmd` | chafa 명령 조립 | png, cols, lines | 명령 문자열(stdout) | 순수 |
| `ev_make_thumb` | 썸네일 생성(부수효과) | file, out_png | exit 0/1, PNG 파일 | 통합(수동/조건부) |

설계 원칙:
- `ev_render_image_cmd`는 `lib/preview.sh`의 `ev_preview_cmd`와 동일하게 **명령 문자열을 stdout으로**
  출력하고 호출부에서 `eval` (순수·단위테스트 가능).
- `ev_graphics_supported` 판정: `KITTY_WINDOW_ID` 존재 OR `TERM_PROGRAM` ∈ {ghostty, WezTerm}
  OR `TERM` ∈ {xterm-ghostty, xterm-kitty} OR `GHOSTTY_RESOURCES_DIR` 존재. (iTerm2는 kitty
  protocol 미지원이므로 제외 — 추후 확장.)
- `ev_visual_previewable` 허용 확장자: pdf, docx, pptx, xlsx, png, jpg, jpeg, gif, bmp, webp, tiff, heic.
  명시적으로 hwpx 제외.

## `ev` 본체 변경

- 상태 파일 `visual`(`0|1`) 추가 — `scope`/`hidden`과 동일 패턴, `_ev_init`에서 `0`으로 초기화.
- `lib/visual.sh` source 추가.
- 헬퍼 `_ev_visual()` (상태 읽기), 바인딩, 서브커맨드 추가:
  - 바인딩: `ctrl-v:execute-silent(<self> __toggle-visual)+refresh-preview`
    (`execute-silent`는 상태 파일을 뒤집고, `refresh-preview`가 `<self> __preview {1} {2}`를 재실행)
  - hidden 서브커맨드 `__toggle-visual` → `visual` 상태 토글.
- `_ev_preview` 분기:
  - 비주얼 모드 && 조건 충족 → `ev_make_thumb`(캐시) 후 `ev_render_image_cmd | eval`.
  - 아니면 기존 텍스트 경로 + 필요 시 힌트.

## 의존성

- `chafa` 신규 추가. `bat`/`poppler`와 동일하게 **선택적**(없으면 텍스트 폴백 + brew 힌트).
- 필수 의존성(rg/fzf/fd) 자동설치 목록에는 넣지 않음.
- README / `lib/deps.sh` 안내에 chafa 한 줄 추가.

## 에러 처리

- `ev_make_thumb` 실패(QL 제너레이터 없음, qlmanage 비정상 종료) → 텍스트 폴백.
- chafa 실패/미설치 → 텍스트 폴백.
- 비-그래픽 터미널에서 비주얼 토글 → 텍스트 + "이 터미널은 인라인 이미지를 지원하지 않습니다" 힌트.
- 모든 폴백은 조용히 실패하지 말고 preview 창에 한 줄 힌트를 남긴다.

## 테스트

- 신규 bats 파일(예: `test/visual.bats`): `ev_graphics_supported`(env 분기),
  `ev_visual_renderer`(PATH 분기), `ev_visual_previewable`(확장자 표/hwpx 제외),
  `ev_thumb_path`(결정성·mtime 반영), `ev_render_image_cmd`(명령 문자열 포맷).
  - `@test` 제목은 ASCII만.
- `ev_make_thumb`는 `qlmanage` 존재 시에만 도는 조건부 통합 테스트(skip 가드).
- 인라인 이미지 실제 렌더는 TTY 필요 → `docs/MANUAL-CHECKLIST.md`에 Ghostty 수동 확인 항목 추가
  (토글 동작, pdf/docx 렌더, hwpx 폴백, chafa 미설치 힌트).

## 범위 밖 (YAGNI)

- 다중 페이지 스크롤/페이지 넘기기 (첫 페이지만).
- iTerm2/sixel 등 비-kitty 프로토콜 (추후 `ev_graphics_supported` 확장).
- hwpx 비주얼 렌더 (한컴 QL 플러그인 의존, 불가).
- 썸네일 영구 캐시 (per-run mktemp만).
