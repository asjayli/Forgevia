#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMMON="$ROOT_DIR/scripts/firefly-common.sh"

# firefly must support both `sha256sum` (Linux) and `shasum -a 256` (macOS)
# without silently downgrading to a weaker hash. This test exercises the
# provider-selection helper under controlled PATH sandboxes so it does not
# depend on which tool the host happens to have installed.
#
# Fake providers use an absolute `#!/bin/sh` shebang and the helper is launched
# via "$BASH", so a sandbox can hide /usr/bin and /bin from PATH without losing
# the ability to execute anything.

assert_eq() {
  local expected="$1"
  local actual="$2"
  local label="$3"
  if [[ "$expected" != "$actual" ]]; then
    echo "FAIL $label: expected [$expected] got [$actual]" >&2
    exit 1
  fi
}

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

fixture="$tmp_dir/fixture.txt"
printf 'firefly portability fixture\n' > "$fixture"

only_sha256sum_bin="$tmp_dir/only-sha256sum"
only_shasum_bin="$tmp_dir/only-shasum"
empty_bin="$tmp_dir/empty"
mkdir -p "$only_sha256sum_bin" "$only_shasum_bin" "$empty_bin"

# Fake sha256sum: emits a fixed digest in the standard "<digest>  <path>" layout.
cat > "$only_sha256sum_bin/sha256sum" <<'EOF'
#!/bin/sh
printf 'LINUX_FIXTURE_HASH  %s\n' "$1"
EOF
chmod +x "$only_sha256sum_bin/sha256sum"

# Fake shasum: accepts `-a 256 <path>` and emits the same layout.
cat > "$only_shasum_bin/shasum" <<'EOF'
#!/bin/sh
last=""
for arg in "$@"; do last="$arg"; done
printf 'MACOS_FIXTURE_HASH  %s\n' "$last"
EOF
chmod +x "$only_shasum_bin/shasum"

hash_under_path() {
  local bin="$1"
  PATH="$bin" "$BASH" -c '. "$1"; firefly_sha256_file "$2"' _ "$COMMON" "$fixture"
}

# Scenario 1: only sha256sum available (Linux-like).
out="$(hash_under_path "$only_sha256sum_bin")"
assert_eq "LINUX_FIXTURE_HASH" "$out" "only sha256sum selects sha256sum"

# Scenario 2: only shasum available (macOS-like).
out="$(hash_under_path "$only_shasum_bin")"
assert_eq "MACOS_FIXTURE_HASH" "$out" "only shasum selects shasum -a 256"

# Scenario 3: neither provider -> non-zero exit with a clear dependency message.
set +e
err_output="$(PATH="$empty_bin" "$BASH" -c '. "$1"; firefly_sha256_file "$2"' _ "$COMMON" "$fixture" 2>&1 >/dev/null)"
neither_status=$?
set -e
if [[ "$neither_status" -eq 0 ]]; then
  echo "FAIL neither-provider: expected non-zero exit but got 0" >&2
  exit 1
fi
if [[ "$err_output" != *"sha256sum or shasum"* ]]; then
  echo "FAIL neither-provider: expected clear dependency error, got [$err_output]" >&2
  exit 1
fi

# firefly_require_sha256 must refuse to run when no provider is available.
set +e
req_err="$(PATH="$empty_bin" "$BASH" -c '. "$1"; firefly_require_sha256' _ "$COMMON" 2>&1 >/dev/null)"
req_status=$?
set -e
if [[ "$req_status" -eq 0 ]]; then
  echo "FAIL require-neither: expected non-zero exit" >&2
  exit 1
fi
if [[ "$req_err" != *"sha256sum or shasum"* ]]; then
  echo "FAIL require-neither: expected clear dependency error, got [$req_err]" >&2
  exit 1
fi

# Scenario 4: real-provider consistency. Skip if the host has neither tool.
# shellcheck source=/dev/null
. "$COMMON"
if command -v sha256sum >/dev/null 2>&1; then
  direct="$(sha256sum "$fixture")"
  direct="${direct%% *}"
elif command -v shasum >/dev/null 2>&1; then
  direct="$(shasum -a 256 "$fixture")"
  direct="${direct%% *}"
else
  direct=""
fi
if [[ -n "$direct" ]]; then
  forged="$(firefly_sha256_file "$fixture")"
  assert_eq "$direct" "$forged" "real provider digest matches direct call"
fi

echo "hash portability test passed"
