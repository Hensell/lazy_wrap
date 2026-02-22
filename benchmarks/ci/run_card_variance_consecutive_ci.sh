#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

RUN_ID="$(date -u +%Y%m%d_%H%M%SZ)"
OUT_DIR="${CI_OUT_DIR:-benchmarks/results/ci/$RUN_ID/card_variance_consecutive}"

BENCH_SCENARIO="${BENCH_SCENARIO:-dynamic_card_50k}"
BENCH_DEVICE="${BENCH_DEVICE:-linux}"
BENCH_REPEATS="${BENCH_REPEATS:-7}"
BENCH_WARMUP_RUNS="${BENCH_WARMUP_RUNS:-2}"
BENCH_MIN_REPEATS="${BENCH_MIN_REPEATS:-7}"
BENCH_STABLE_SCROLL_PROFILE="${BENCH_STABLE_SCROLL_PROFILE:-false}"
BENCH_SCROLL_INPUT_MODE="${BENCH_SCROLL_INPUT_MODE:-jump}"
BENCH_SCROLL_JUMP_PROFILE="${BENCH_SCROLL_JUMP_PROFILE:-edge_bounce}"
BENCH_SCROLL_STEP_PX="${BENCH_SCROLL_STEP_PX:--280}"

MAX_JANK_CV="${MAX_JANK_CV:-70}"
MAX_JANK_MAD="${MAX_JANK_MAD:-30}"
ENFORCE_MAX_JANK_CV="${ENFORCE_MAX_JANK_CV:-false}"
ENFORCE_MAX_JANK_MAD="${ENFORCE_MAX_JANK_MAD:-false}"

DECISION_MODE="${DECISION_MODE:-cv_and_mad}"
CV_THRESHOLD="${CV_THRESHOLD:-30}"
MAD_THRESHOLD="${MAD_THRESHOLD:-30}"
ENFORCE_CONSECUTIVE_PASS="${ENFORCE_CONSECUTIVE_PASS:-true}"

CI_SKIP_BENCH="${CI_SKIP_BENCH:-false}"
RUN_A_JSON="${RUN_A_JSON:-}"
RUN_A_MD="${RUN_A_MD:-}"
RUN_A_RUN_IDS="${RUN_A_RUN_IDS:-}"
RUN_B_JSON="${RUN_B_JSON:-}"
RUN_B_MD="${RUN_B_MD:-}"
RUN_B_RUN_IDS="${RUN_B_RUN_IDS:-}"

mkdir -p "$OUT_DIR"

echo "Card variance consecutive CI run"
echo "OUT_DIR=$OUT_DIR"
echo "BENCH_SCENARIO=$BENCH_SCENARIO"
echo "BENCH_DEVICE=$BENCH_DEVICE"
echo "BENCH_REPEATS=$BENCH_REPEATS"
echo "BENCH_WARMUP_RUNS=$BENCH_WARMUP_RUNS"
echo "BENCH_MIN_REPEATS=$BENCH_MIN_REPEATS"
echo "BENCH_STABLE_SCROLL_PROFILE=$BENCH_STABLE_SCROLL_PROFILE"
echo "BENCH_SCROLL_INPUT_MODE=$BENCH_SCROLL_INPUT_MODE"
echo "BENCH_SCROLL_JUMP_PROFILE=$BENCH_SCROLL_JUMP_PROFILE"
echo "BENCH_SCROLL_STEP_PX=$BENCH_SCROLL_STEP_PX"
echo "MAX_JANK_CV=$MAX_JANK_CV"
echo "MAX_JANK_MAD=$MAX_JANK_MAD"
echo "ENFORCE_MAX_JANK_CV=$ENFORCE_MAX_JANK_CV"
echo "ENFORCE_MAX_JANK_MAD=$ENFORCE_MAX_JANK_MAD"
echo "DECISION_MODE=$DECISION_MODE"
echo "CV_THRESHOLD=$CV_THRESHOLD"
echo "MAD_THRESHOLD=$MAD_THRESHOLD"
echo "ENFORCE_CONSECUTIVE_PASS=$ENFORCE_CONSECUTIVE_PASS"
echo "CI_SKIP_BENCH=$CI_SKIP_BENCH"

if [[ "$BENCH_SCROLL_INPUT_MODE" != "drag" && "$BENCH_SCROLL_INPUT_MODE" != "jump" ]]; then
  echo "BENCH_SCROLL_INPUT_MODE must be drag or jump." >&2
  exit 2
fi

case "$BENCH_SCROLL_JUMP_PROFILE" in
  relative|edge_bounce|edge-bounce|edgebounce|bounce) ;;
  *)
    echo "BENCH_SCROLL_JUMP_PROFILE must be relative or edge_bounce." >&2
    exit 2
    ;;
esac

RUN_A_PREFIX="$OUT_DIR/run_a"
RUN_B_PREFIX="$OUT_DIR/run_b"
RUN_A_JSON_OUT="$OUT_DIR/run_a_metrics.json"
RUN_A_MD_OUT="$OUT_DIR/run_a_report.md"
RUN_A_RUN_IDS_OUT="$OUT_DIR/run_a_run_ids.txt"
RUN_B_JSON_OUT="$OUT_DIR/run_b_metrics.json"
RUN_B_MD_OUT="$OUT_DIR/run_b_report.md"
RUN_B_RUN_IDS_OUT="$OUT_DIR/run_b_run_ids.txt"

CHECK_JSON="$OUT_DIR/consecutive_check.json"
CHECK_MD="$OUT_DIR/consecutive_check.md"
SUMMARY_MD="$OUT_DIR/card_variance_consecutive_ci_summary.md"

if [[ "$CI_SKIP_BENCH" == "true" ]]; then
  if [[ -z "$RUN_A_JSON" || -z "$RUN_B_JSON" ]]; then
    echo "CI_SKIP_BENCH=true requires RUN_A_JSON and RUN_B_JSON." >&2
    exit 2
  fi
  if [[ ! -f "$RUN_A_JSON" ]]; then
    echo "RUN_A_JSON not found: $RUN_A_JSON" >&2
    exit 2
  fi
  if [[ ! -f "$RUN_B_JSON" ]]; then
    echo "RUN_B_JSON not found: $RUN_B_JSON" >&2
    exit 2
  fi

  cp "$RUN_A_JSON" "$RUN_A_JSON_OUT"
  cp "$RUN_B_JSON" "$RUN_B_JSON_OUT"

  if [[ -n "$RUN_A_MD" && -f "$RUN_A_MD" ]]; then
    cp "$RUN_A_MD" "$RUN_A_MD_OUT"
  else
    cat >"$RUN_A_MD_OUT" <<EOF
# Card Variance Run A (Skipped in CI)

- source_json: \`$RUN_A_JSON\`
EOF
  fi

  if [[ -n "$RUN_B_MD" && -f "$RUN_B_MD" ]]; then
    cp "$RUN_B_MD" "$RUN_B_MD_OUT"
  else
    cat >"$RUN_B_MD_OUT" <<EOF
# Card Variance Run B (Skipped in CI)

- source_json: \`$RUN_B_JSON\`
EOF
  fi

  if [[ -n "$RUN_A_RUN_IDS" && -f "$RUN_A_RUN_IDS" ]]; then
    cp "$RUN_A_RUN_IDS" "$RUN_A_RUN_IDS_OUT"
  else
    jq -r '.run_ids[]' "$RUN_A_JSON_OUT" >"$RUN_A_RUN_IDS_OUT"
  fi

  if [[ -n "$RUN_B_RUN_IDS" && -f "$RUN_B_RUN_IDS" ]]; then
    cp "$RUN_B_RUN_IDS" "$RUN_B_RUN_IDS_OUT"
  else
    jq -r '.run_ids[]' "$RUN_B_JSON_OUT" >"$RUN_B_RUN_IDS_OUT"
  fi

  echo "Using existing run JSONs:"
  echo "- run_a: $RUN_A_JSON"
  echo "- run_b: $RUN_B_JSON"
else
  echo "Running benchmark pair (run_a + run_b)..."
  COMMON_ARGS=(
    --scenario "$BENCH_SCENARIO"
    --device "$BENCH_DEVICE"
    --repeats "$BENCH_REPEATS"
    --warmup-runs "$BENCH_WARMUP_RUNS"
    --max-jank-cv "$MAX_JANK_CV"
    --max-jank-mad-percent "$MAX_JANK_MAD"
    --scroll-input-mode "$BENCH_SCROLL_INPUT_MODE"
    --scroll-jump-profile "$BENCH_SCROLL_JUMP_PROFILE"
    --scroll-step-px "$BENCH_SCROLL_STEP_PX"
  )
  if [[ "$ENFORCE_MAX_JANK_CV" == "true" ]]; then
    COMMON_ARGS+=(--enforce-max-jank-cv)
  fi
  if [[ "$ENFORCE_MAX_JANK_MAD" == "true" ]]; then
    COMMON_ARGS+=(--enforce-max-jank-mad)
  fi
  if [[ "$BENCH_STABLE_SCROLL_PROFILE" == "true" ]]; then
    COMMON_ARGS+=(--stable-scroll-profile)
  fi

  dart run benchmarks/run_card_variance.dart \
    "${COMMON_ARGS[@]}" \
    --output-prefix "$RUN_A_PREFIX"

  dart run benchmarks/run_card_variance.dart \
    "${COMMON_ARGS[@]}" \
    --output-prefix "$RUN_B_PREFIX"

  cp "${RUN_A_PREFIX}_metrics.json" "$RUN_A_JSON_OUT"
  cp "${RUN_A_PREFIX}_report.md" "$RUN_A_MD_OUT"
  cp "${RUN_A_PREFIX}_run_ids.txt" "$RUN_A_RUN_IDS_OUT"
  cp "${RUN_B_PREFIX}_metrics.json" "$RUN_B_JSON_OUT"
  cp "${RUN_B_PREFIX}_report.md" "$RUN_B_MD_OUT"
  cp "${RUN_B_PREFIX}_run_ids.txt" "$RUN_B_RUN_IDS_OUT"
fi

REPEATS_A="$(jq -r '.repeats // 0' "$RUN_A_JSON_OUT")"
REPEATS_B="$(jq -r '.repeats // 0' "$RUN_B_JSON_OUT")"
if (( REPEATS_A < BENCH_MIN_REPEATS )); then
  echo "run_a repeats ($REPEATS_A) below BENCH_MIN_REPEATS ($BENCH_MIN_REPEATS)." >&2
  exit 1
fi
if (( REPEATS_B < BENCH_MIN_REPEATS )); then
  echo "run_b repeats ($REPEATS_B) below BENCH_MIN_REPEATS ($BENCH_MIN_REPEATS)." >&2
  exit 1
fi

dart run benchmarks/run_card_variance_consecutive_check.dart \
  --run-a-json "$RUN_A_JSON_OUT" \
  --run-b-json "$RUN_B_JSON_OUT" \
  --mode "$DECISION_MODE" \
  --cv-threshold "$CV_THRESHOLD" \
  --mad-threshold "$MAD_THRESHOLD" \
  --json-report-path "$CHECK_JSON" \
  --report-path "$CHECK_MD"

DECISION="$(jq -r '.decision' "$CHECK_JSON")"
MODE_USED="$(jq -r '.mode' "$CHECK_JSON")"
CONSECUTIVE_PASS="$(jq -r '.consecutive_pass' "$CHECK_JSON")"
RUN_A_CV="$(jq -r '.run_a.jank_cv_percent // "unknown"' "$CHECK_JSON")"
RUN_A_MAD="$(jq -r '.run_a.jank_mad_percent_of_median // "unknown"' "$CHECK_JSON")"
RUN_A_MODE_PASS="$(jq -r '.run_a.mode_pass' "$CHECK_JSON")"
RUN_B_CV="$(jq -r '.run_b.jank_cv_percent // "unknown"' "$CHECK_JSON")"
RUN_B_MAD="$(jq -r '.run_b.jank_mad_percent_of_median // "unknown"' "$CHECK_JSON")"
RUN_B_MODE_PASS="$(jq -r '.run_b.mode_pass' "$CHECK_JSON")"
RUN_A_GATE_CV="$(jq -r 'if .variance_gate and (.variance_gate | has("pass")) then (.variance_gate.pass | tostring) else "unknown" end' "$RUN_A_JSON_OUT")"
RUN_A_GATE_MAD="$(jq -r 'if .robust_variance_gate and (.robust_variance_gate | has("pass")) then (.robust_variance_gate.pass | tostring) else "unknown" end' "$RUN_A_JSON_OUT")"
RUN_B_GATE_CV="$(jq -r 'if .variance_gate and (.variance_gate | has("pass")) then (.variance_gate.pass | tostring) else "unknown" end' "$RUN_B_JSON_OUT")"
RUN_B_GATE_MAD="$(jq -r 'if .robust_variance_gate and (.robust_variance_gate | has("pass")) then (.robust_variance_gate.pass | tostring) else "unknown" end' "$RUN_B_JSON_OUT")"

cat >"$SUMMARY_MD" <<EOF
# Card Variance Consecutive CI Summary

- decision_mode: \`$MODE_USED\`
- cv_threshold: \`$CV_THRESHOLD\`
- mad_threshold: \`$MAD_THRESHOLD\`
- max_jank_cv: \`$MAX_JANK_CV\`
- max_jank_mad: \`$MAX_JANK_MAD\`
- enforce_max_jank_cv: \`$ENFORCE_MAX_JANK_CV\`
- enforce_max_jank_mad: \`$ENFORCE_MAX_JANK_MAD\`
- scroll_input_mode: \`$BENCH_SCROLL_INPUT_MODE\`
- scroll_jump_profile: \`$BENCH_SCROLL_JUMP_PROFILE\`
- scroll_step_px: \`$BENCH_SCROLL_STEP_PX\`
- consecutive_pass: \`$CONSECUTIVE_PASS\`
- decision: \`$DECISION\`
- run_a_jank_cv_percent: \`$RUN_A_CV\`
- run_a_jank_mad_percent_of_median: \`$RUN_A_MAD\`
- run_a_mode_pass: \`$RUN_A_MODE_PASS\`
- run_a_variance_gate_pass: \`$RUN_A_GATE_CV\`
- run_a_robust_variance_gate_pass: \`$RUN_A_GATE_MAD\`
- run_b_jank_cv_percent: \`$RUN_B_CV\`
- run_b_jank_mad_percent_of_median: \`$RUN_B_MAD\`
- run_b_mode_pass: \`$RUN_B_MODE_PASS\`
- run_b_variance_gate_pass: \`$RUN_B_GATE_CV\`
- run_b_robust_variance_gate_pass: \`$RUN_B_GATE_MAD\`
- source_run_a_json: \`$RUN_A_JSON_OUT\`
- source_run_b_json: \`$RUN_B_JSON_OUT\`
- source_consecutive_json: \`$CHECK_JSON\`
- source_consecutive_md: \`$CHECK_MD\`
EOF

if [[ "$ENFORCE_CONSECUTIVE_PASS" == "true" && "$CONSECUTIVE_PASS" != "true" ]]; then
  echo "Consecutive decision failed in mode '$MODE_USED'." >&2
  exit 1
fi

echo "Card variance consecutive CI checks completed."
echo "Artifacts:"
echo "- $RUN_A_RUN_IDS_OUT"
echo "- $RUN_A_JSON_OUT"
echo "- $RUN_A_MD_OUT"
echo "- $RUN_B_RUN_IDS_OUT"
echo "- $RUN_B_JSON_OUT"
echo "- $RUN_B_MD_OUT"
echo "- $CHECK_JSON"
echo "- $CHECK_MD"
echo "- $SUMMARY_MD"
