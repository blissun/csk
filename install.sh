#!/usr/bin/env bash
# csk installer — Claude Skills Kit
# curl -fsSL https://raw.githubusercontent.com/blissun/csk/main/install.sh | bash
set -e

R="\033[0m" B="\033[1m" G="\033[32m" D="\033[90m" Y="\033[33m"

echo -e "\n  ${B}csk${R} — Claude Skills Kit 설치\n"

# 1. Determine install dir
BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"

# 2. Download csk
CSK_URL="https://raw.githubusercontent.com/blissun/csk/main/csk"
TMP="$(mktemp)"
echo -e "  다운로드 중..."
curl -fsSL "$CSK_URL" -o "$TMP"
mv "$TMP" "$BIN_DIR/csk"
chmod +x "$BIN_DIR/csk"
echo -e "  ${G}✓${R} $BIN_DIR/csk 설치 완료"

# 3. Ensure PATH
case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *)
    echo -e "\n  ${Y}!${R} PATH에 $BIN_DIR 추가 필요:"
    SHELL_NAME="$(basename "$SHELL")"
    case "$SHELL_NAME" in
      zsh)  RC="$HOME/.zshrc" ;;
      bash) RC="$HOME/.bashrc" ;;
      *)    RC="$HOME/.profile" ;;
    esac
    if ! grep -q "$BIN_DIR" "$RC" 2>/dev/null; then
      echo "export PATH=\"$BIN_DIR:\$PATH\"" >> "$RC"
      echo -e "  ${G}✓${R} $RC 에 PATH 추가됨"
      echo -e "  ${D}적용: source $RC${R}"
    fi
    ;;
esac

# 4. Setup dirs
mkdir -p "$HOME/.csk/registry" "$HOME/.claude/skills"

echo -e "
  ${G}설치 완료!${R}

  ${B}시작하기:${R}
    csk install gstack     gstack 스킬팩 설치
    csk ls                 스킬 목록
    csk help               전체 도움말

"
