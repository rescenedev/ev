# 비주얼 미리보기 (인라인 이미지) 설계

## 배경 / 목적

`ev`는 office 문서(hwpx/docx/pptx/xlsx)와 pdf를 **텍스트로 추출해** 미리보기 창에 보여준다.
사용자는 Finder의 Quick Look처럼 **문서를 시각적으로** 보고 싶어한다.

Ghostty가 kitty graphics protocol을 지원하므로, fzf preview 창 안에 문서 첫 페이지를
이미지로 렌더링할 수 있다. 단 기존 "텍스트 검색 → 원본 라인 표시" 철학은 유지하고,
비주얼은 **키 토글로 켜는 부가 모드**로 둔다.

## 사전 조사 결과 (검증됨)

- Ghostty (`TERM=xterm-ghostty`, `TERM_PROGRAM=ghostty`) → kitty graphics protocol 지원.
- `qlmanage -t`는 pdf 등 레거시 제너레이터는 처리하지만, **hwpx 같은 모던 QuickLook App
  Extension(`Alhangeul.app`)은 제대로 몰지 못해 멈춘다(타임아웃)**. → `qlmanage` CLI는 부적합.
- **`QLThumbnailGenerator` API(Swift)는 hwpx를 포함한 모든 포맷을 Finder 품질로 렌더**한다
  (hwpx 849×1201 PNG 생성·확인 완료). 모던 익스텐션을 정상적으로 사용한다.
- `swiftc -O` 컴파일 ~3.8s(1회성), 컴파일된 바이너리 실행 첫 회 ~0.4s / 이후 ~0.02s.
- `chafa` 1.18.2 설치 완료, `-f kitty` 출력 = kitty graphics protocol APC(`ESC _ G`) 확인.
- hwpx QuickLook은 `Alhangeul.app`(cask `postmelee/tap/alhangeul`) 익스텐션에 의존.
  앱을 한 번 실행하면 `com.postmelee.alhangeul.{QLExtension,ThumbnailExtension}` 등록됨.

## 동작

1. 기본 미리보기는 현재처럼 **텍스트 추출**(`_ev_preview_extracted` / `bat`).
2. fzf에서 **`Ctrl-V`** 로 비주얼 ↔ 텍스트 토글.
3. 비주얼 모드일 때, 아래 조건을 모두 만족하면 이미지로 렌더:
   - 그래픽 지원 터미널(`ev_graphics_supported`)
   - 렌더러 존재(`ev_visual_renderer` = `chafa`)
   - 썸네일 생성 가능(`ev_make_thumb` 성공)
4. 하나라도 불만족이면 **텍스트로 폴백 + 짧은 힌트** (사유별로 다른 한 줄, "에러 처리" 참조).

## 파이프라인

```
모든 지원 포맷(hwpx/docx/pptx/xlsx/pdf/이미지)
   → ev-qlthumb (QLThumbnailGenerator) → PNG(캐시) → chafa -f kitty → fzf preview 창
```

- 단일 통일 경로. 포맷별 분기 없음 — QuickLook이 포맷을 판단한다.
- 이미지 파일(png/jpg/...)도 동일하게 `ev-qlthumb`로 통과시킨다(QuickLook이 이미지 썸네일 반환).
  포맷별 특수 처리(예: 이미지 직접 렌더)는 두지 않아 코드 경로를 하나로 유지한다.
- 썸네일 캐시: `$EV_STATE/thumbs/` (per-run mktemp 디렉터리, 종료 시 자동 삭제).
  키 = 파일 절대경로 + mtime 해시. 두 번째 preview부터 즉시 표시.
- 이미지 크기: fzf가 preview 프로세스에 export 하는 `FZF_PREVIEW_COLUMNS`/`FZF_PREVIEW_LINES` 사용.

## 신규 파일 1: `libexec/ev-qlthumb.swift` + 컴파일된 `libexec/ev-qlthumb`

- `QLThumbnailGenerator.shared.generateBestRepresentation`로 `<file>`의 썸네일을
  `<out.png>`로 저장하는 작은 CLI. 인자: `ev-qlthumb <file> <out.png> [size]`.
- 내부 타임아웃 가드(예: 30s)로 QL 데몬 hang 시 비정상 종료(exit≠0).
- 종료코드: 성공 0 / 생성 실패 1 / 인자 오류 2 / 타임아웃 3.
- **컴파일 전략**: 소스는 repo에 커밋. 컴파일된 바이너리는 **첫 사용 시 자동 생성**하고
  캐시. 바이너리가 없거나 소스보다 오래됐을 때만 `swiftc -O ev-qlthumb.swift -o <bin>` 실행.
  - 바이너리 캐시 위치: `${XDG_CACHE_HOME:-$HOME/.cache}/ev/ev-qlthumb`
    (repo 내부에 빌드 산출물을 두지 않아 git 청결 유지; `.gitignore`에 추가 불필요).
  - `swiftc` 부재 시 컴파일 생략 → 비주얼 불가, 텍스트 폴백 + 힌트.

## 신규 파일 2: `lib/visual.sh`

source 전용. zsh(런타임)·bash(bats) 양쪽에서 동작해야 함(zsh-only 문법 금지).

| 함수 | 역할 | 입력 | 출력/반환 | 테스트 |
|---|---|---|---|---|
| `ev_graphics_supported` | 그래픽 지원 터미널 감지 | env | exit 0/1 | env 스텁 |
| `ev_visual_renderer` | 렌더러 경로 | PATH | `chafa` 또는 빈 문자열 | PATH 스텁 |
| `ev_thumb_path` | 캐시 PNG 경로 산출 | file, dir | 경로 문자열(stdout) | 순수 |
| `ev_render_image_cmd` | chafa 명령 조립 | png, cols, lines | 명령 문자열(stdout) | 순수 |
| `ev_qlthumb_bin` | 헬퍼 바이너리 경로 산출(빌드 안 함) | env | 경로 문자열(stdout) | 순수(env 스텁) |
| `ev_ensure_qlthumb` | 필요 시 컴파일하고 바이너리 경로 반환 | env, swiftc | exit 0/1 + 경로 | 통합(조건부) |
| `ev_make_thumb` | 썸네일 생성(부수효과) | file, out_png | exit 0/1, PNG 파일 | 통합(조건부) |

설계 원칙:
- `ev_render_image_cmd`는 `lib/preview.sh`의 `ev_preview_cmd`와 동일하게 **명령 문자열을 stdout으로**
  출력하고 호출부에서 `eval` (순수·단위테스트 가능).
- `ev_graphics_supported` 판정: `KITTY_WINDOW_ID` 존재 OR `TERM_PROGRAM` ∈ {ghostty, WezTerm}
  OR `TERM` ∈ {xterm-ghostty, xterm-kitty} OR `GHOSTTY_RESOURCES_DIR` 존재. (iTerm2는 kitty
  protocol 미지원이므로 제외 — 추후 확장.)
- 포맷 화이트리스트(`ev_visual_previewable`)는 **두지 않는다**. QuickLook이 처리 가능 여부를
  판단하고, 실패하면 `ev_make_thumb`가 비0 종료 → 텍스트 폴백. (hwpx 포함 모든 포맷 시도)

## `ev` 본체 변경

- 상태 파일 `visual`(`0|1`) 추가 — `scope`/`hidden`과 동일 패턴, `_ev_init`에서 `0`으로 초기화.
- `lib/visual.sh` source 추가.
- 헬퍼 `_ev_visual()` (상태 읽기), 바인딩, 서브커맨드 추가:
  - 바인딩: `ctrl-v:execute-silent(<self> __toggle-visual)+refresh-preview`
    (`execute-silent`는 상태 파일을 뒤집고, `refresh-preview`가 `<self> __preview {1} {2}`를 재실행)
  - hidden 서브커맨드 `__toggle-visual` → `visual` 상태 토글.
- `_ev_preview` 분기:
  - 비주얼 모드 && `ev_graphics_supported` && `ev_visual_renderer` 존재 →
    `ev_make_thumb`(캐시) 후 성공 시 `ev_render_image_cmd | eval`, 실패 시 텍스트+힌트.
  - 아니면 기존 텍스트 경로.

## 의존성

- `chafa`(렌더러), `swiftc`(헬퍼 컴파일; Xcode CLT 포함), `Alhangeul.app`(hwpx QL) —
  **모두 선택적**. 없으면 해당 단계에서 텍스트 폴백.
- 필수 의존성(rg/fzf/fd) 자동설치 목록은 그대로. 비주얼용은 자동설치하지 않는다.
- README / 의존성 안내에 `chafa`, hwpx용 `alhangeul` cask 안내 추가.
- "빌드 스텝 없음" 원칙 영향: 헬퍼 1개를 **첫 실행 시 1회 자동 컴파일·캐시**(사용자 투명, ~4s).
  rg/fzf 자동설치와 같은 "필요 시 준비" 결.

## 에러 처리

- `swiftc` 부재 → 컴파일 불가 → 텍스트 폴백 + `[hint] 비주얼 미리보기: Xcode CLT 필요(xcode-select --install)`.
- `chafa` 부재 → 텍스트 폴백 + `[hint] 비주얼 미리보기: brew install chafa`.
- 비-그래픽 터미널 → 텍스트 폴백 + `[hint] 이 터미널은 인라인 이미지를 지원하지 않습니다`.
- `ev_make_thumb` 실패(QL 미지원 포맷, hwpx인데 Alhangeul 미설치, 타임아웃) → 텍스트 폴백 +
  `[hint] 이 파일은 비주얼 미리보기를 생성할 수 없습니다`.
- 모든 폴백은 조용히 실패하지 말고 preview 창에 한 줄 힌트를 남긴다.

## 테스트

- 신규 bats 파일(`test/visual.bats`):
  - `ev_graphics_supported`(env 분기: ghostty/kitty/wezterm/미지원)
  - `ev_visual_renderer`(PATH 스텁: chafa 있음/없음)
  - `ev_thumb_path`(결정성, mtime 변경 시 경로 변화)
  - `ev_render_image_cmd`(명령 문자열 포맷: png/cols/lines 반영)
  - `ev_qlthumb_bin`(`XDG_CACHE_HOME`/`HOME` 반영한 경로 산출)
  - `@test` 제목은 ASCII만.
- `ev_ensure_qlthumb`/`ev_make_thumb`는 `swiftc`·QL 의존 → 조건부 통합 테스트(skip 가드).
- 인라인 이미지 실제 렌더는 TTY 필요 → `docs/MANUAL-CHECKLIST.md`에 Ghostty 수동 확인 항목 추가
  (토글 동작, hwpx/pdf/docx 렌더, chafa·swiftc 미설치 힌트, 비-그래픽 터미널 폴백).

## 범위 밖 (YAGNI)

- 다중 페이지 스크롤/페이지 넘기기 (첫 페이지만).
- iTerm2/sixel 등 비-kitty 프로토콜 (추후 `ev_graphics_supported` 확장).
- 썸네일 영구 캐시 (per-run mktemp만).
- 헬퍼 바이너리 사전 배포(precompiled) — 아키텍처 의존이라 첫 실행 컴파일로 갈음.
