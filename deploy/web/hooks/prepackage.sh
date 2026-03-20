#!/usr/bin/env sh
set -eu

load_env() {
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    key=${line%%=*}
    value=${line#*=}
    value=$(printf '%s' "$value" | sed 's/^"//; s/"$//')
    export "$key=$value"
  done <<EOF
$(azd env get-values)
EOF
}

load_env

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
DEPLOY_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
REPO_ROOT=$(CDPATH= cd -- "$DEPLOY_ROOT/../.." && pwd)
SERVER_ROOT="$REPO_ROOT/src/MyWorkID.Server"
CLIENT_ROOT="$REPO_ROOT/src/MyWorkID.Client"
DIST_ROOT="$DEPLOY_ROOT/.azd/dist"
TMP_ROOT="$DEPLOY_ROOT/.azd/tmp"
DEPLOY_MODE=${MYWORKID_DEPLOY_MODE:-releaseZip}

rm -rf "$DIST_ROOT"
mkdir -p "$DIST_ROOT" "$TMP_ROOT"

case "$DEPLOY_MODE" in
  releaseZip)
    RELEASE_VERSION=${MYWORKID_RELEASE_VERSION:-latest}
    if [ "$RELEASE_VERSION" = "latest" ]; then
      ZIP_URL="https://github.com/glueckkanja/MyWorkID/releases/latest/download/binaries.zip"
    else
      ZIP_URL="https://github.com/glueckkanja/MyWorkID/releases/download/$RELEASE_VERSION/binaries.zip"
    fi
    ZIP_PATH="$TMP_ROOT/binaries.zip"
    curl -fsSL "$ZIP_URL" -o "$ZIP_PATH"
    unzip -oq "$ZIP_PATH" -d "$DIST_ROOT"
    ;;
  sourceBuild)
    command -v npm >/dev/null 2>&1
    command -v dotnet >/dev/null 2>&1
    (
      cd "$CLIENT_ROOT"
      npm ci
      npm run build
    )
    (
      cd "$SERVER_ROOT"
      dotnet publish ./MyWorkID.Server.csproj -c Release -o "$DIST_ROOT"
    )
    mkdir -p "$DIST_ROOT/wwwroot"
    cp -R "$CLIENT_ROOT/dist/." "$DIST_ROOT/wwwroot/"
    ;;
  *)
    echo "Unsupported MYWORKID_DEPLOY_MODE '$DEPLOY_MODE'. Use 'releaseZip' or 'sourceBuild'." >&2
    exit 1
    ;;
esac
