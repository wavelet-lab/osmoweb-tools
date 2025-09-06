#!/usr/bin/env bash
# Simple smoke tests for scripts/lib/libosmolog.sh
# Use manual assertions instead of `set -e` to avoid premature exits.
set -uo pipefail

# Resolve repo root from this test's location
TEST_SRC="${BASH_SOURCE[0]:-$0}"
TEST_DIR="$(cd -- "$(dirname -- "$TEST_SRC")" >/dev/null 2>&1 && pwd)"
REPO_ROOT="$(cd -- "$TEST_DIR/.." >/dev/null 2>&1 && pwd)"

# shellcheck source=../scripts/lib/libosmolog.sh
. "$REPO_ROOT/scripts/lib/libosmolog.sh"

reload_libosmolog() {
	# Allow re-sourcing with new env like NO_COLOR
	unset LIBOSMOLOG_LOADED
	# shellcheck source=../scripts/lib/libosmolog.sh
	. "$REPO_ROOT/scripts/lib/libosmolog.sh"
}

pass_count=0
fail_count=0

assert_contains() {
	local haystack="$1" needle="$2" msg="${3:-}"
	if grep -Fq -- "$needle" <<<"$haystack"; then
		((pass_count++))
	else
		((fail_count++))
		printf 'ASSERT FAIL: %s\nExpected to find: %s\nIn: %s\n' "${msg:-contains}" "$needle" "$haystack" >&2
	fi
}

section() { printf '\n==== %s ====\n' "$1"; }

section "Colors off with NO_COLOR=1"
NO_COLOR=1
export NO_COLOR
reload_libosmolog
LOG_LEVEL=info QUIET=false \
	output=$({ log_info "hello"; } 2>&1)
assert_contains "$output" "hello" "info no color"
# ensure no escape sequences
if grep -q $'\e' <<<"$output"; then
	((fail_count++))
	echo 'ASSERT FAIL: unexpected ANSI escape sequences when NO_COLOR=1' >&2
else
	((pass_count++))
fi

section "Error goes to stderr"
NO_COLOR=1 LOG_LEVEL=info QUIET=false \
	err_output=$({ log_error "boom"; } 2>&1 1>/dev/null)
assert_contains "$err_output" "boom" "error to stderr"

section "Quiet mode hides log_output"
NO_COLOR=1 LOG_LEVEL=info QUIET=true \
	q_out=$({ log_output "visible?"; } 2>&1)
if [[ -z "$q_out" ]]; then ((pass_count++)); else
	((fail_count++))
	echo 'ASSERT FAIL: log_output not quiet' >&2
fi

section "Log level filters"
NO_COLOR=1 LOG_LEVEL=warn QUIET=false \
	filtered=$({
		log_info "skip"
		log_warning "warn"
	} 2>&1)
if grep -Fq "skip" <<<"$filtered"; then
	((fail_count++))
	echo 'ASSERT FAIL: info should be filtered at warn level' >&2
else ((pass_count++)); fi
assert_contains "$filtered" "warn" "warn visible"

section "Die exits non-zero"
NO_COLOR=1 LOG_LEVEL=info QUIET=false die_output=$({
	die "fatal"
	echo "after"
} 2>&1)
rc=$?
if [[ $rc -ne 0 ]]; then ((pass_count++)); else
	((fail_count++))
	echo 'ASSERT FAIL: die returned 0' >&2
fi
assert_contains "$die_output" "fatal" "die logs"

printf '\nPASSED: %d\nFAILED: %d\n' "$pass_count" "$fail_count"
[[ $fail_count -eq 0 ]]
