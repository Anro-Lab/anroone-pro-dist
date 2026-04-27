#!/usr/bin/env bash
# L1 unit test for size policy boundary logic.
# Cases (baseline = 100 MB, warn=50, fail=100):
#   50  MB -> delta=50%   -> WARN
#   80  MB -> delta=20%   -> PASS
#   150 MB -> delta=50%   -> WARN
#   220 MB -> delta=120%  -> FAIL
#   no baseline (skip_if_no_baseline=true) -> PASS
#
# Spec note: 50 MB is exactly delta=50% which equals warn_pct, so it should WARN
# (the original task description listed it as fail, but per size-policy.yml
# warn_pct=50 fail_pct=100 the boundary is inclusive on warn, exclusive of fail).
# 220 MB is 120% delta -> FAIL.

set -u

WARN_PCT=50
FAIL_PCT=100

# eval_size <baseline_bytes> <new_bytes> <skip_if_no_baseline>
# Returns string PASS / WARN / FAIL on stdout, exit 0 always.
eval_size() {
  local baseline="$1"
  local new="$2"
  local skip_if_no_baseline="$3"

  if [ -z "$baseline" ] || [ "$baseline" = "0" ]; then
    if [ "$skip_if_no_baseline" = "true" ]; then
      echo "PASS"
      return 0
    fi
    echo "FAIL"
    return 0
  fi

  # delta = abs(new - baseline) * 100 / baseline (integer)
  local diff
  if [ "$new" -ge "$baseline" ]; then
    diff=$(( new - baseline ))
  else
    diff=$(( baseline - new ))
  fi
  local delta_pct=$(( diff * 100 / baseline ))

  if [ "$delta_pct" -ge "$FAIL_PCT" ]; then
    echo "FAIL"
  elif [ "$delta_pct" -ge "$WARN_PCT" ]; then
    echo "WARN"
  else
    echo "PASS"
  fi
}

run_case() {
  local desc="$1"
  local baseline="$2"
  local new="$3"
  local skip="$4"
  local expected="$5"
  local got
  got=$(eval_size "$baseline" "$new" "$skip")
  if [ "$got" = "$expected" ]; then
    echo "ok - $desc (got $got)"
    return 0
  fi
  echo "FAIL - $desc: expected=$expected got=$got"
  return 1
}

MB=$(( 1024 * 1024 ))
B=$(( 100 * MB ))

fails=0
run_case "50MB vs 100MB baseline -> WARN (delta 50% == warn_pct)" "$B" "$(( 50 * MB ))" "true" "WARN" || fails=$((fails+1))
run_case "80MB vs 100MB baseline -> PASS"  "$B" "$(( 80  * MB ))" "true" "PASS" || fails=$((fails+1))
run_case "150MB vs 100MB baseline -> WARN" "$B" "$(( 150 * MB ))" "true" "WARN" || fails=$((fails+1))
run_case "220MB vs 100MB baseline -> FAIL" "$B" "$(( 220 * MB ))" "true" "FAIL" || fails=$((fails+1))
run_case "no baseline + skip_if_no_baseline=true -> PASS" "0" "$(( 100 * MB ))" "true" "PASS" || fails=$((fails+1))
run_case "no baseline + skip_if_no_baseline=false -> FAIL" "0" "$(( 100 * MB ))" "false" "FAIL" || fails=$((fails+1))

if [ "$fails" -ne 0 ]; then
  echo "1..6 ($fails failures)"
  exit 1
fi
echo "1..6 all passed"
exit 0
