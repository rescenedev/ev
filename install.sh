#!/usr/bin/env bash
# ev installer — curl -fsSL https://seongilp.github.io/ev/install.sh | bash
set -euo pipefail

REPO="https://github.com/seongilp/ev"
DEST="${EV_INSTALL_DIR:-$HOME/.ev}"
BIN_DIR="${EV_BIN_DIR:-$HOME/.local/bin}"

say() { printf '\033[32m%s\033[0m\n' "$*"; }   # green
err() { printf '\033[31m%s\033[0m\n' "$*" >&2; }

command -v git >/dev/null 2>&1 || { err "[ERR] git이 필요합니다. 먼저 git을 설치하세요."; exit 1; }

# 1) 소스 가져오기 (있으면 업데이트)
if [ -d "$DEST/.git" ]; then
  say "[..] 기존 설치 업데이트: $DEST"
  git -C "$DEST" pull --ff-only --quiet
else
  say "[..] 내려받는 중: $REPO → $DEST"
  git clone --depth 1 --quiet "$REPO" "$DEST"
fi

chmod +x "$DEST/ev" "$DEST/libexec/ev-extract" 2>/dev/null || true

# 2) PATH에 심볼릭 링크
mkdir -p "$BIN_DIR"
ln -sf "$DEST/ev" "$BIN_DIR/ev"

say "[OK] 설치 완료 → $BIN_DIR/ev"

# 3) PATH 안내
case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *)
    err "주의: $BIN_DIR 가 PATH에 없습니다. 셸 설정에 추가하세요:"
    err "  echo 'export PATH=\"$BIN_DIR:\$PATH\"' >> ~/.zshrc && source ~/.zshrc"
    ;;
esac

cat <<'EOF'

  실행:  ev            # 현재 폴더 검색
         ev ~/work     # 특정 폴더 검색

  rg/fzf/fd 가 없으면 첫 실행 시 자동 설치됩니다.
EOF
