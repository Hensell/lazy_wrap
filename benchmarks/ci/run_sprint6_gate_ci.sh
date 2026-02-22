#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

RUN_ID="$(date -u +%Y%m%d_%H%M%SZ)"
OUT_DIR="${CI_OUT_DIR:-benchmarks/results/ci/$RUN_ID}"
BASELINE_SUMMARY="${BASELINE_SUMMARY:-benchmarks/results/20260211_232622Z/summary.json}"
BENCH_DEVICE="${BENCH_DEVICE:-linux}"
BENCH_REPEATS="${BENCH_REPEATS:-3}"
BENCH_WARMUP_RUNS="${BENCH_WARMUP_RUNS:-1}"
BENCH_MIN_REPEATS="${BENCH_MIN_REPEATS:-$BENCH_REPEATS}"
ENFORCE_GO="${ENFORCE_GO:-false}"
CI_SKIP_BENCH="${CI_SKIP_BENCH:-false}"
CI_SKIP_TESTS="${CI_SKIP_TESTS:-false}"
CI_SKIP_P0_P1_CHECK="${CI_SKIP_P0_P1_CHECK:-false}"
BENCH_CANDIDATE_JSON="${BENCH_CANDIDATE_JSON:-}"

mkdir -p "$OUT_DIR"

echo "Sprint 6 CI gate run"
echo "OUT_DIR=$OUT_DIR"
echo "BASELINE_SUMMARY=$BASELINE_SUMMARY"
echo "BENCH_DEVICE=$BENCH_DEVICE"
echo "BENCH_REPEATS=$BENCH_REPEATS"
echo "BENCH_WARMUP_RUNS=$BENCH_WARMUP_RUNS"
echo "BENCH_MIN_REPEATS=$BENCH_MIN_REPEATS"
echo "ENFORCE_GO=$ENFORCE_GO"
echo "CI_SKIP_BENCH=$CI_SKIP_BENCH"
echo "CI_SKIP_TESTS=$CI_SKIP_TESTS"
echo "CI_SKIP_P0_P1_CHECK=$CI_SKIP_P0_P1_CHECK"

CANDIDATE_JSON="$OUT_DIR/sliver_v2_ab.json"
CANDIDATE_MD="$OUT_DIR/sliver_v2_ab.md"
GATE_JSON="$OUT_DIR/sprint6_gate.json"
GATE_MD="$OUT_DIR/sprint6_gate.md"

if [[ "$CI_SKIP_BENCH" == "true" ]]; then
  if [[ -z "$BENCH_CANDIDATE_JSON" ]]; then
    echo "CI_SKIP_BENCH=true requires BENCH_CANDIDATE_JSON path." >&2
    exit 2
  fi
  if [[ ! -f "$BENCH_CANDIDATE_JSON" ]]; then
    echo "BENCH_CANDIDATE_JSON not found: $BENCH_CANDIDATE_JSON" >&2
    exit 2
  fi
  cp "$BENCH_CANDIDATE_JSON" "$CANDIDATE_JSON"
  cat >"$CANDIDATE_MD" <<EOF
# sliverV2 A/B (Skipped in CI)

This run used an existing JSON candidate instead of executing benchmarks.

- source_json: \`$BENCH_CANDIDATE_JSON\`
EOF
  echo "Using existing candidate A/B JSON: $BENCH_CANDIDATE_JSON"
else
  echo "Running sliverV2 A/B benchmark..."
  dart run benchmarks/run_sliver_v2_ab.dart \
    --device "$BENCH_DEVICE" \
    --repeats "$BENCH_REPEATS" \
    --warmup-runs "$BENCH_WARMUP_RUNS" \
    --report-path "$CANDIDATE_MD" \
    --json-report-path "$CANDIDATE_JSON"
fi

if [[ "$CI_SKIP_TESTS" != "true" ]]; then
  echo "Running flutter test..."
  flutter test
fi

GATE_ARGS=(
  --baseline-summary "$BASELINE_SUMMARY"
  --candidate-ab-json "$CANDIDATE_JSON"
  --functional-tests-pass
  --min-repeats "$BENCH_MIN_REPEATS"
  --report-path "$GATE_MD"
  --json-report-path "$GATE_JSON"
)

if [[ "$CI_SKIP_P0_P1_CHECK" != "true" ]]; then
  GATE_ARGS+=(--no-p0-p1-open)
fi

echo "Running Sprint 6 gate..."
dart run benchmarks/run_sprint6_gate.dart "${GATE_ARGS[@]}"

DECISION_LABEL="$(jq -r '.decision.label' "$GATE_JSON")"
echo "Sprint 6 gate decision: $DECISION_LABEL"

if [[ "$ENFORCE_GO" == "true" && "$DECISION_LABEL" != "GO" ]]; then
  echo "ENFORCE_GO=true and decision is $DECISION_LABEL. Failing pipeline." >&2
  exit 1
fi

echo "Artifacts:"
echo "- $CANDIDATE_MD"
echo "- $CANDIDATE_JSON"
echo "- $GATE_MD"
echo "- $GATE_JSON"
