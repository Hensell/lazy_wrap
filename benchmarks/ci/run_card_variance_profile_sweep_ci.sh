#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

RUN_ID="$(date -u +%Y%m%d_%H%M%SZ)"
OUT_DIR="${CI_OUT_DIR:-benchmarks/results/ci/$RUN_ID/card_variance_profile_sweep}"

BENCH_SCENARIO="${BENCH_SCENARIO:-dynamic_card_50k}"
BENCH_DEVICE="${BENCH_DEVICE:-linux}"
BENCH_REPEATS="${BENCH_REPEATS:-7}"
BENCH_WARMUP_RUNS="${BENCH_WARMUP_RUNS:-2}"
MAX_JANK_CV="${MAX_JANK_CV:-30}"
MAX_JANK_MAD="${MAX_JANK_MAD:-30}"
PROFILE_PRESETS="${PROFILE_PRESETS:-}"
ENFORCE_AT_LEAST_ONE_PASS="${ENFORCE_AT_LEAST_ONE_PASS:-false}"

CI_SKIP_BENCH="${CI_SKIP_BENCH:-false}"
SWEEP_SUMMARY_JSON="${SWEEP_SUMMARY_JSON:-}"
SWEEP_REPORT_MD="${SWEEP_REPORT_MD:-}"

mkdir -p "$OUT_DIR"

SWEEP_OUTPUT_DIR="$OUT_DIR/sweep"
SWEEP_SUMMARY_OUT="$SWEEP_OUTPUT_DIR/summary.json"
REPORT_MD="$OUT_DIR/card_variance_profile_sweep_report.md"
CI_SUMMARY_MD="$OUT_DIR/card_variance_profile_sweep_ci_summary.md"

mkdir -p "$SWEEP_OUTPUT_DIR"

echo "Card variance profile sweep CI run"
echo "OUT_DIR=$OUT_DIR"
echo "BENCH_SCENARIO=$BENCH_SCENARIO"
echo "BENCH_DEVICE=$BENCH_DEVICE"
echo "BENCH_REPEATS=$BENCH_REPEATS"
echo "BENCH_WARMUP_RUNS=$BENCH_WARMUP_RUNS"
echo "MAX_JANK_CV=$MAX_JANK_CV"
echo "MAX_JANK_MAD=$MAX_JANK_MAD"
echo "PROFILE_PRESETS=$PROFILE_PRESETS"
echo "ENFORCE_AT_LEAST_ONE_PASS=$ENFORCE_AT_LEAST_ONE_PASS"
echo "CI_SKIP_BENCH=$CI_SKIP_BENCH"

if [[ "$CI_SKIP_BENCH" == "true" ]]; then
  if [[ -z "$SWEEP_SUMMARY_JSON" ]]; then
    echo "CI_SKIP_BENCH=true requires SWEEP_SUMMARY_JSON." >&2
    exit 2
  fi
  if [[ ! -f "$SWEEP_SUMMARY_JSON" ]]; then
    echo "SWEEP_SUMMARY_JSON not found: $SWEEP_SUMMARY_JSON" >&2
    exit 2
  fi

  cp "$SWEEP_SUMMARY_JSON" "$SWEEP_SUMMARY_OUT"

  if [[ -n "$SWEEP_REPORT_MD" && -f "$SWEEP_REPORT_MD" ]]; then
    cp "$SWEEP_REPORT_MD" "$REPORT_MD"
  else
    cat >"$REPORT_MD" <<'__REPORT__'
# Card Variance Profile Sweep (Skipped in CI)

- source_summary_json: provided via SWEEP_SUMMARY_JSON
__REPORT__
  fi

  echo "Using existing sweep artifacts:"
  echo "- summary_json: $SWEEP_SUMMARY_JSON"
  if [[ -n "$SWEEP_REPORT_MD" ]]; then
    echo "- report_md: $SWEEP_REPORT_MD"
  fi
else
  SWEEP_ARGS=(
    --scenario "$BENCH_SCENARIO"
    --device "$BENCH_DEVICE"
    --repeats "$BENCH_REPEATS"
    --warmup-runs "$BENCH_WARMUP_RUNS"
    --max-jank-cv "$MAX_JANK_CV"
    --max-jank-mad-percent "$MAX_JANK_MAD"
    --output-dir "$SWEEP_OUTPUT_DIR"
    --report-path "$REPORT_MD"
  )

  if [[ -n "$PROFILE_PRESETS" ]]; then
    IFS=',' read -r -a PRESET_LIST <<< "$PROFILE_PRESETS"
    for raw_preset in "${PRESET_LIST[@]}"; do
      preset="${raw_preset// /}"
      if [[ -n "$preset" ]]; then
        SWEEP_ARGS+=(--preset "$preset")
      fi
    done
  fi

  dart run benchmarks/run_card_variance_profile_sweep.dart "${SWEEP_ARGS[@]}"
fi

if [[ ! -f "$SWEEP_SUMMARY_OUT" ]]; then
  echo "Sweep summary not found: $SWEEP_SUMMARY_OUT" >&2
  exit 1
fi

RECOMMENDED_PRESET="$(jq -r '.recommended_preset // "unknown"' "$SWEEP_SUMMARY_OUT")"
RESULT_COUNT="$(jq -r '.results | length' "$SWEEP_SUMMARY_OUT")"
PASS_BOTH_COUNT="$(jq -r '[.results[] | select(.both_gates_pass == true)] | length' "$SWEEP_SUMMARY_OUT")"
PASS_BOTH_PRESETS="$(jq -r '[.results[] | select(.both_gates_pass == true) | .preset] | join(",")' "$SWEEP_SUMMARY_OUT")"
if [[ -z "$PASS_BOTH_PRESETS" ]]; then
  PASS_BOTH_PRESETS="none"
fi

cat >"$CI_SUMMARY_MD" <<EOF
# Card Variance Profile Sweep CI Summary

- benchmark_scenario: $BENCH_SCENARIO
- benchmark_device: $BENCH_DEVICE
- repeats: $BENCH_REPEATS
- warmup_runs: $BENCH_WARMUP_RUNS
- cv_threshold: $MAX_JANK_CV
- mad_threshold: $MAX_JANK_MAD
- profile_presets: $PROFILE_PRESETS
- enforce_at_least_one_pass: $ENFORCE_AT_LEAST_ONE_PASS
- result_count: $RESULT_COUNT
- pass_both_count: $PASS_BOTH_COUNT
- pass_both_presets: $PASS_BOTH_PRESETS
- recommended_preset: $RECOMMENDED_PRESET
- source_summary_json: $SWEEP_SUMMARY_OUT
- source_report_md: $REPORT_MD
EOF

if [[ "$ENFORCE_AT_LEAST_ONE_PASS" == "true" && "$PASS_BOTH_COUNT" -eq 0 ]]; then
  echo "No preset passed both CV and MAD gates." >&2
  exit 1
fi

echo "Card variance profile sweep CI checks completed."
echo "Artifacts:"
echo "- $SWEEP_SUMMARY_OUT"
echo "- $REPORT_MD"
echo "- $CI_SUMMARY_MD"
