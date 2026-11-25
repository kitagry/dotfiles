#!/usr/bin/env bash
# Tests for .local/bin/aws-sso. `aws` is replaced by a stub, so nothing touches real AWS.
# usage: tests/aws-sso_test.sh
set -uo pipefail

SCRIPT="$(cd "$(dirname "$0")/../.local/bin" && pwd)/aws-sso"
T=$(mktemp -d "${TMPDIR:-/tmp}/aws-sso-test.XXXXXX") || exit 1
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin"
pass=0 fail=0

# stub_aws <expiration or empty>: `export-credentials` returns it; every call is logged.
stub_aws() {
  cat >"$T/bin/aws" <<STUB
#!/bin/bash
echo "\$*" >>"$T/calls.log"
if [ "\$1 \$2" = "configure export-credentials" ]; then
  [ -n "$1" ] && echo '{"Expiration":"$1"}'
  [ -n "$1" ]
elif [ "\$1 \$2" = "sso login" ]; then
  echo "login output"
fi
STUB
  chmod +x "$T/bin/aws"
  : >"$T/calls.log"
}
run() { PATH="$T/bin:$PATH" bash "$SCRIPT" "$@" 2>"$T/stderr"; }
check() { # check <name> <condition exit status>
  if [ "$2" -eq 0 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $1"; fi
}

future=$(date -u -v+1H +%Y-%m-%dT%H:%M:%S+00:00 2>/dev/null || date -u -d '+1 hour' +%Y-%m-%dT%H:%M:%S+00:00)

stub_aws "$future"
out=$(run -e pay-dev)
[ "$out" = "export AWS_PROFILE=pay-dev" ]; check "valid session: export line on stdout" $?
! grep -q "sso login" "$T/calls.log"; check "valid session: no login" $?

stub_aws "2020-01-01T00:00:00+00:00"
out=$(run -e pay-dev)
grep -q "sso login --profile pay-dev" "$T/calls.log"; check "expired session: logs in" $?
[ "$out" = "export AWS_PROFILE=pay-dev" ]; check "expired session: login output stays off stdout" $?

stub_aws ""
run -e pay-dev >/dev/null
grep -q "sso login" "$T/calls.log"; check "no credentials: logs in" $?

stub_aws ""
out=$(run --export=fish pay-qa)
[ "$out" = "set -gx AWS_PROFILE pay-qa" ]; check "fish export" $?

stub_aws ""
out=$(run default -e)
! grep -q "sso login" "$T/calls.log" && [ "$out" = "export AWS_PROFILE=default" ]; check "default profile skips login" $?

stub_aws "$future"
out=$(run pay-dev)
[ -z "$out" ] && grep -q "eval" "$T/stderr"; check "without -e: nothing on stdout, hint on stderr" $?

run >/dev/null; [ $? -eq 1 ]; check "no profile: exit 1" $?
run -x p >/dev/null; [ $? -eq 2 ]; check "unknown option: exit 2" $?
run -h | grep -q usage; check "help" $?

echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
