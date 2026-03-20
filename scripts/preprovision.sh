#!/usr/bin/env sh
set -eu

if command -v pwsh >/dev/null 2>&1; then
  exec pwsh -NoLogo -NoProfile -File "$(dirname "$0")/preprovision.ps1"
fi

echo "The POSIX preprovision hook currently requires PowerShell (pwsh) to run the Microsoft Graph automation." >&2
exit 1
