#!/bin/bash
set -euo pipefail

# Math Mage - Web Deploy Script
# builds/web/ の内容を mathmage-web リポジトリにデプロイ

PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
WEB_REPO="${WEB_REPO:-/Users/nakamuro/mathmage-web}"
BUILD_DIR="${PROJECT_DIR}/builds/web"
GODOT="${GODOT_BIN:-godot}"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

log()   { echo -e "${GREEN}[DEPLOY]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# 1. テスト
log "Running tests..."
cd "$PROJECT_DIR"
"$GODOT" --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd \
    --ignoreHeadlessMode -a tests/ 2>&1 | tail -3
log "Tests passed."

# 2. Webビルド
log "Building Web export..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
"$GODOT" --headless --export-release "Web" "$BUILD_DIR/index.html" 2>&1 | tail -3

if [ ! -f "$BUILD_DIR/index.html" ]; then
    error "Web build failed. index.html not found."
fi
log "Web build success."

# 3. デプロイ先にコピー
log "Deploying to $WEB_REPO ..."
if [ ! -d "$WEB_REPO/.git" ]; then
    error "Web repo not found: $WEB_REPO"
fi

# 古いファイルを削除（.gitは残す）
cd "$WEB_REPO"
find . -maxdepth 1 -not -name '.git' -not -name '.' -not -name '..' -exec rm -rf {} +

# ビルド成果物をコピー
cp -r "$BUILD_DIR"/* .

# 4. コミット+プッシュ
cd "$WEB_REPO"
git add -A
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
git commit -m "deploy: Math Mage Web build $TIMESTAMP" || log "No changes to deploy."
git push origin main 2>&1 || git push origin master 2>&1 || log "Push failed. Check remote."

log "Deploy complete!"
log "URL: https://nakamuro-unl.github.io/mathmage-web/"
