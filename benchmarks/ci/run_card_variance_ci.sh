#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

RUN_ID="$(date -u +%Y%m%d_%H%M%SZ)"
OUT_DIR="${CI_OUT_DIR:-benchmarks/results/ci/$RUN_ID/card_variance}"
BENCH_SCENARIO="${BENCH_SCENARIO:-dynamic_card_50k}"
BENCH_DEVICE="${BENCH_DEVICE:-linux}"
BENCH_REPEATS="${BENCH_REPEATS:-7}"
BENCH_WARMUP_RUNS="${BENCH_WARMUP_RUNS:-2}"
BENCH_MIN_REPEATS="${BENCH_MIN_REPEATS:-7}"
BENCH_STABLE_SCROLL_PROFILE="${BENCH_STABLE_SCROLL_PROFILE:-false}"
BENCH_SCROLL_INPUT_MODE="${BENCH_SCROLL_INPUT_MODE:-jump}"
BENCH_SCROLL_JUMP_PROFILE="${BENCH_SCROLL_JUMP_PROFILE:-edge_bounce}"
BENCH_SCROLL_STEP_PX="${BENCH_SCROLL_STEP_PX:--280}"
ENFORCE_MAX_JANK_CV="${ENFORCE_MAX_JANK_CV:-false}"
MAX_JANK_CV="${MAX_JANK_CV:-70}"
ENFORCE_MAX_JANK_MAD="${ENFORCE_MAX_JANK_MAD:-false}"
MAX_JANK_MAD="${MAX_JANK_MAD:-30}"
VARIANCE_DECISION_MODE="${VARIANCE_DECISION_MODE:-cv_and_mad}"
ENFORCE_VARIANCE_DECISION="${ENFORCE_VARIANCE_DECISION:-true}"
CI_SKIP_BENCH="${CI_SKIP_BENCH:-false}"
BENCH_VARIANCE_JSON="${BENCH_VARIANCE_JSON:-}"
BENCH_VARIANCE_MD="${BENCH_VARIANCE_MD:-}"
BENCH_VARIANCE_RUN_IDS="${BENCH_VARIANCE_RUN_IDS:-}"

mkdir -p "$OUT_DIR"

echo "Card variance CI run"
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
echo "ENFORCE_MAX_JANK_CV=$ENFORCE_MAX_JANK_CV"
echo "MAX_JANK_CV=$MAX_JANK_CV"
echo "ENFORCE_MAX_JANK_MAD=$ENFORCE_MAX_JANK_MAD"
echo "MAX_JANK_MAD=$MAX_JANK_MAD"
echo "VARIANCE_DECISION_MODE=$VARIANCE_DECISION_MODE"
echo "ENFORCE_VARIANCE_DECISION=$ENFORCE_VARIANCE_DECISION"
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

case "$VARIANCE_DECISION_MODE" in
  cv|mad|cv_or_mad|cv_and_mad) ;;
  *)
    echo "VARIANCE_DECISION_MODE must be cv, mad, cv_or_mad, or cv_and_mad." >&2
    exit 2
    ;;
esac

if [[ "$ENFORCE_VARIANCE_DECISION" != "true" && "$ENFORCE_VARIANCE_DECISION" != "false" ]]; then
  echo "ENFORCE_VARIANCE_DECISION must be true or false." >&2
  exit 2
fi

evaluate_mode_pass() {
  local mode="$1"
  local cv_pass="$2"
  local mad_pass="$3"
  case "$mode" in
    cv)
      echo "$cv_pass"
      return
      ;;
    mad)
      echo "$mad_pass"
      return
      ;;
    cv_or_mad)
      if [[ "$cv_pass" == "unknown" && "$mad_pass" == "unknown" ]]; then
        echo "unknown"
      elif [[ "$cv_pass" == "unknown" ]]; then
        echo "$mad_pass"
      elif [[ "$mad_pass" == "unknown" ]]; then
        echo "$cv_pass"
      elif [[ "$cv_pass" == "true" || "$mad_pass" == "true" ]]; then
        echo "true"
      else
        echo "false"
      fi
      return
      ;;
    cv_and_mad)
      if [[ "$cv_pass" == "unknown" || "$mad_pass" == "unknown" ]]; then
        echo "unknown"
      elif [[ "$cv_pass" == "true" && "$mad_pass" == "true" ]]; then
        echo "true"
      else
        echo "false"
      fi
      return
      ;;
  esac
}

VAR_PREFIX="$OUT_DIR/card_variance"
VAR_RUN_IDS="$OUT_DIR/card_variance_run_ids.txt"
VAR_JSON="$OUT_DIR/card_variance_metrics.json"
VAR_MD="$OUT_DIR/card_variance_report.md"
SUMMARY_MD="$OUT_DIR/card_variance_ci_summary.md"

if [[ "$CI_SKIP_BENCH" == "true" ]]; then
  if [[ -z "$BENCH_VARIANCE_JSON" ]]; then
    echo "CI_SKIP_BENCH=true requires BENCH_VARIANCE_JSON path." >&2
    exit 2
  fi
  if [[ ! -f "$BENCH_VARIANCE_JSON" ]]; then
    echo "BENCH_VARIANCE_JSON not found: $BENCH_VARIANCE_JSON" >&2
    exit 2
  fi

  cp "$BENCH_VARIANCE_JSON" "$VAR_JSON"

  if [[ -n "$BENCH_VARIANCE_MD" && -f "$BENCH_VARIANCE_MD" ]]; then
    cp "$BENCH_VARIANCE_MD" "$VAR_MD"
  else
    cat >"$VAR_MD" <<EOF
# Card Variance Report (Skipped in CI)

This run used an existing variance JSON instead of executing benchmarks.

- source_json: \`$BENCH_VARIANCE_JSON\`
EOF
  fi

  if [[ -n "$BENCH_VARIANCE_RUN_IDS" && -f "$BENCH_VARIANCE_RUN_IDS" ]]; then
    cp "$BENCH_VARIANCE_RUN_IDS" "$VAR_RUN_IDS"
  else
    jq -r '.run_ids[]' "$VAR_JSON" >"$VAR_RUN_IDS"
  fi

  echo "Using existing variance JSON: $BENCH_VARIANCE_JSON"
else
  echo "Running variance benchmark script..."
  VAR_ARGS=(
    --scenario "$BENCH_SCENARIO"
    --device "$BENCH_DEVICE"
    --repeats "$BENCH_REPEATS"
    --warmup-runs "$BENCH_WARMUP_RUNS"
    --max-jank-cv "$MAX_JANK_CV"
    --max-jank-mad-percent "$MAX_JANK_MAD"
    --scroll-input-mode "$BENCH_SCROLL_INPUT_MODE"
    --scroll-jump-profile "$BENCH_SCROLL_JUMP_PROFILE"
    --scroll-step-px "$BENCH_SCROLL_STEP_PX"
    --output-prefix "$VAR_PREFIX"
  )
  if [[ "$ENFORCE_MAX_JANK_MAD" == "true" ]]; then
    VAR_ARGS+=(--enforce-max-jank-mad)
  fi
  if [[ "$BENCH_STABLE_SCROLL_PROFILE" == "true" ]]; then
    VAR_ARGS+=(--stable-scroll-profile)
  fi
  dart run benchmarks/run_card_variance.dart "${VAR_ARGS[@]}"
fi

REPEATS_USED="$(jq -r '.repeats' "$VAR_JSON")"
WARMUP_USED="$(jq -r '.warmup_runs' "$VAR_JSON")"
SCENARIO_USED="$(jq -r '.scenario' "$VAR_JSON")"
JANK_CV="$(jq -r '.metrics.jank_percent.cv_percent' "$VAR_JSON")"
BUILD_CV="$(jq -r '.metrics.p95_build_ms.cv_percent' "$VAR_JSON")"
RASTER_CV="$(jq -r '.metrics.p95_raster_ms.cv_percent' "$VAR_JSON")"
MEMORY_CV="$(jq -r '.metrics.peak_memory_mb.cv_percent' "$VAR_JSON")"
TTI_CV="$(jq -r '.metrics.time_to_first_interaction_ms.cv_percent' "$VAR_JSON")"
if jq -e '.variance_gate' "$VAR_JSON" >/dev/null 2>&1; then
  GATE_JSON_PASS="$(jq -r '.variance_gate.pass' "$VAR_JSON")"
  GATE_OBSERVED="$(jq -r '.variance_gate.observed_percent' "$VAR_JSON")"
  GATE_JSON_THRESHOLD="$(jq -r '.variance_gate.max_allowed_percent' "$VAR_JSON")"
  GATE_ENFORCED_FROM_JSON="$(jq -r '.variance_gate.enforced' "$VAR_JSON")"
else
  GATE_JSON_PASS="unknown"
  GATE_OBSERVED="$JANK_CV"
  GATE_JSON_THRESHOLD="unknown"
  GATE_ENFORCED_FROM_JSON="false"
fi
if awk -v jank="$GATE_OBSERVED" -v limit="$MAX_JANK_CV" 'BEGIN { exit !(jank <= limit) }'; then
  GATE_EVAL_PASS="true"
else
  GATE_EVAL_PASS="false"
fi

if jq -e '.robust_variance_gate' "$VAR_JSON" >/dev/null 2>&1; then
  ROBUST_GATE_JSON_PASS="$(jq -r '.robust_variance_gate.pass' "$VAR_JSON")"
  ROBUST_GATE_OBSERVED="$(jq -r '.robust_variance_gate.observed_percent' "$VAR_JSON")"
  ROBUST_GATE_JSON_THRESHOLD="$(jq -r '.robust_variance_gate.max_allowed_percent' "$VAR_JSON")"
  ROBUST_GATE_ENFORCED_FROM_JSON="$(jq -r '.robust_variance_gate.enforced' "$VAR_JSON")"
else
  ROBUST_GATE_JSON_PASS="unknown"
  ROBUST_GATE_OBSERVED="unknown"
  ROBUST_GATE_JSON_THRESHOLD="unknown"
  ROBUST_GATE_ENFORCED_FROM_JSON="false"
fi

if [[ "$ROBUST_GATE_OBSERVED" == "unknown" ]]; then
  ROBUST_GATE_EVAL_PASS="unknown"
elif awk -v mad="$ROBUST_GATE_OBSERVED" -v limit="$MAX_JANK_MAD" 'BEGIN { exit !(mad <= limit) }'; then
  ROBUST_GATE_EVAL_PASS="true"
else
  ROBUST_GATE_EVAL_PASS="false"
fi

DECISION_JSON_PASS="$(evaluate_mode_pass "$VARIANCE_DECISION_MODE" "$GATE_JSON_PASS" "$ROBUST_GATE_JSON_PASS")"
DECISION_EVAL_PASS="$(evaluate_mode_pass "$VARIANCE_DECISION_MODE" "$GATE_EVAL_PASS" "$ROBUST_GATE_EVAL_PASS")"

if jq -e '.robust_jank_dispersion' "$VAR_JSON" >/dev/null 2>&1; then
  ROBUST_JANK_MEDIAN="$(jq -r '.robust_jank_dispersion.median' "$VAR_JSON")"
  ROBUST_JANK_MAD="$(jq -r '.robust_jank_dispersion.mad' "$VAR_JSON")"
  ROBUST_JANK_MAD_PERCENT="$(jq -r '.robust_jank_dispersion.mad_percent_of_median' "$VAR_JSON")"
  ROBUST_JANK_IQR_PERCENT="$(jq -r '.robust_jank_dispersion.iqr_percent_of_median' "$VAR_JSON")"
else
  ROBUST_JANK_MEDIAN="unknown"
  ROBUST_JANK_MAD="unknown"
  ROBUST_JANK_MAD_PERCENT="unknown"
  ROBUST_JANK_IQR_PERCENT="unknown"
fi

cat >"$SUMMARY_MD" <<EOF
# Card Variance CI Summary

- scenario: \`$SCENARIO_USED\`
- repeats: \`$REPEATS_USED\`
- warmup_runs: \`$WARMUP_USED\`
- stable_scroll_profile: \`$BENCH_STABLE_SCROLL_PROFILE\`
- scroll_input_mode: \`$BENCH_SCROLL_INPUT_MODE\`
- scroll_jump_profile: \`$BENCH_SCROLL_JUMP_PROFILE\`
- scroll_step_px: \`$BENCH_SCROLL_STEP_PX\`
- jank_cv_percent: \`$JANK_CV\`
- build_cv_percent: \`$BUILD_CV\`
- raster_cv_percent: \`$RASTER_CV\`
- memory_cv_percent: \`$MEMORY_CV\`
- tti_cv_percent: \`$TTI_CV\`
- enforce_max_jank_cv: \`$ENFORCE_MAX_JANK_CV\`
- max_jank_cv_threshold: \`$MAX_JANK_CV\`
- enforce_max_jank_mad: \`$ENFORCE_MAX_JANK_MAD\`
- max_jank_mad_threshold: \`$MAX_JANK_MAD\`
- variance_gate_json_pass: \`$GATE_JSON_PASS\`
- variance_gate_observed_cv_percent: \`$GATE_OBSERVED\`
- variance_gate_json_threshold_cv_percent: \`$GATE_JSON_THRESHOLD\`
- variance_gate_evaluated_threshold_cv_percent: \`$MAX_JANK_CV\`
- variance_gate_evaluated_pass: \`$GATE_EVAL_PASS\`
- variance_gate_enforced_from_json: \`$GATE_ENFORCED_FROM_JSON\`
- robust_jank_median_percent: \`$ROBUST_JANK_MEDIAN\`
- robust_jank_mad_percent_point: \`$ROBUST_JANK_MAD\`
- robust_jank_mad_percent_of_median: \`$ROBUST_JANK_MAD_PERCENT\`
- robust_jank_iqr_percent_of_median: \`$ROBUST_JANK_IQR_PERCENT\`
- robust_variance_gate_json_pass: \`$ROBUST_GATE_JSON_PASS\`
- robust_variance_gate_observed_mad_percent: \`$ROBUST_GATE_OBSERVED\`
- robust_variance_gate_json_threshold_percent: \`$ROBUST_GATE_JSON_THRESHOLD\`
- robust_variance_gate_evaluated_threshold_percent: \`$MAX_JANK_MAD\`
- robust_variance_gate_evaluated_pass: \`$ROBUST_GATE_EVAL_PASS\`
- robust_variance_gate_enforced_from_json: \`$ROBUST_GATE_ENFORCED_FROM_JSON\`
- variance_decision_mode: \`$VARIANCE_DECISION_MODE\`
- variance_decision_json_pass: \`$DECISION_JSON_PASS\`
- variance_decision_evaluated_pass: \`$DECISION_EVAL_PASS\`
- enforce_variance_decision: \`$ENFORCE_VARIANCE_DECISION\`
- source_report: \`$VAR_MD\`
- source_json: \`$VAR_JSON\`
- source_run_ids: \`$VAR_RUN_IDS\`
EOF

if (( REPEATS_USED < BENCH_MIN_REPEATS )); then
  echo "Measured repeats ($REPEATS_USED) below BENCH_MIN_REPEATS ($BENCH_MIN_REPEATS)." >&2
  exit 1
fi

if [[ "$ENFORCE_MAX_JANK_CV" == "true" ]]; then
  if [[ "$GATE_EVAL_PASS" != "true" ]]; then
    echo "jank CV ${GATE_OBSERVED}% exceeds configured limit ${MAX_JANK_CV}%." >&2
    exit 1
  fi
fi

if [[ "$ENFORCE_MAX_JANK_MAD" == "true" ]]; then
  if [[ "$ROBUST_GATE_EVAL_PASS" != "true" ]]; then
    echo "jank MAD ${ROBUST_GATE_OBSERVED}% exceeds configured limit ${MAX_JANK_MAD}%." >&2
    exit 1
  fi
fi

if [[ "$ENFORCE_VARIANCE_DECISION" == "true" ]]; then
  if [[ "$DECISION_EVAL_PASS" != "true" ]]; then
    echo "variance decision mode ${VARIANCE_DECISION_MODE} failed (result: ${DECISION_EVAL_PASS})." >&2
    exit 1
  fi
fi

echo "Card variance CI checks passed."
echo "Artifacts:"
echo "- $VAR_RUN_IDS"
echo "- $VAR_JSON"
echo "- $VAR_MD"
echo "- $SUMMARY_MD"
