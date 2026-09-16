#!/usr/bin/env bash
set -eu
exec python3 "$(dirname "${BASH_SOURCE[0]}")/run_tests.py" --roundtrip-only
