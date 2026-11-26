#!/bin/bash
set -euo pipefail
ROOT="$(dirname "$0")/.."
bash "$ROOT/Scripts/build-app.sh" "$@"
open "$ROOT/dist/charl.app"
