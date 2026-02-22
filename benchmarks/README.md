# Benchmarks de `lazy_wrap`

Este directorio contiene el harness de benchmarks para Sprint 1.

## Comando unico

```bash
dart run benchmarks/run_benchmarks.dart --device linux
```

Si omites `--device`, Flutter usa el default.

## Escenarios soportados (estables)

1. `dynamic_chip_10k`
2. `dynamic_card_50k`
3. `fixed_grid_10k`

## Escenario experimental (Sprint 4)

- `dynamic_card_50k_sliver_v2`
- `dynamic_card_50k_sliver_v3` (spike interno)
- `dynamic_chip_10k_sliver_v2`
- `dynamic_chip_10k_sliver_v3` (spike interno)

Se ejecuta en modo single-scenario (no forma parte de la corrida baseline por
defecto).

```bash
dart run benchmarks/run_benchmarks.dart --device linux --scenario dynamic_card_50k_sliver_v2
```

## A/B offstageV1 vs sliverV2

```bash
dart run benchmarks/run_sliver_v2_ab.dart --device linux
```

El script ejecuta ambos pares de comparación:

1. `dynamic_card_50k` vs `dynamic_card_50k_sliver_v2`
2. `dynamic_chip_10k` vs `dynamic_chip_10k_sliver_v2`

Para reducir ruido entre corridas:

```bash
dart run benchmarks/run_sliver_v2_ab.dart --device linux --repeats 5 --warmup-runs 1
```

Salida:

- `benchmarks/sliver_v2_ab_report.md`
- `benchmarks/sliver_v2_ab_report.json`

## Triplet offstageV1 vs sliverV2 vs sliverV3 (chip)

```bash
dart run benchmarks/run_sliver_v3_triplet.dart --device linux --repeats 5 --warmup-runs 1
```

Salida:

- `benchmarks/sliver_v3_triplet_report.md`
- `benchmarks/sliver_v3_triplet_report.json`
- `benchmarks/sliver_v3_spike_report.md` (checkpoint de lectura)

Opcional en ambos scripts (`run_sliver_v2_ab` y `run_sliver_v3_triplet`):

- `--report-path <path>` (markdown)
- `--json-report-path <path>` (JSON)

Reportes de sprint relacionados:

- `benchmarks/sprint4_report.md`
- `benchmarks/sprint5_report.md`
- `benchmarks/sprint6_go_no_go_report.md`

## Gate Sprint 6 (automatizado)

El gate transforma evidencia A/B en una decision GO/NO-GO contra criterios del
roadmap.

```bash
dart run benchmarks/run_sprint6_gate.dart \
  --baseline-summary benchmarks/results/20260211_232622Z/summary.json \
  --candidate-ab-json benchmarks/sliver_v2_ab_report.json \
  --functional-tests-pass \
  --no-p0-p1-open
```

Salida:

- `benchmarks/sprint6_gate_report.md`
- `benchmarks/sprint6_gate_report.json`

Opcional:

- `--min-repeats <n>` (default `3`)
- `--report-path <path>`
- `--json-report-path <path>`

Script orquestador CI/local:

- `benchmarks/ci/run_sprint6_gate_ci.sh`
- Variables utiles:
  - `ENFORCE_GO=true|false`
  - `BENCH_REPEATS=<n>`
  - `BENCH_WARMUP_RUNS=<n>`
  - `BENCH_MIN_REPEATS=<n>`
  - `CI_OUT_DIR=<path>`

Workflow GitHub Actions (manual):

- `.github/workflows/sprint6-gate.yml`
- Ejecuta benchmark A/B + `flutter test` + gate y sube artefactos.

## Pair offstageV1 (chip + card) con repeticiones

```bash
dart run benchmarks/run_offstage_v1_pair.dart --device linux --repeats 5 --warmup-runs 1
```

Opcional:

```bash
dart run benchmarks/run_offstage_v1_pair.dart --device linux --repeats 5 --warmup-runs 1 \
  --baseline-summary benchmarks/results/20260211_232622Z/summary.json
```

`--baseline-summary` acepta dos formatos:

1. `summary.json` de `run_benchmarks` (campo `results`).
2. `pair.json` de `run_offstage_v1_pair` (campo `scenarios[].medians`), util
   para comparar tuning contra un control `pair` de la misma tanda.

Opcional (si quieres ver todos los valores sin filtrar outliers):

```bash
dart run benchmarks/run_offstage_v1_pair.dart --device linux --repeats 5 \
  --warmup-runs 1 --no-outlier-filter
```

Opcional (recomendado para bajar drift entre escenarios en tandas largas):

```bash
dart run benchmarks/run_offstage_v1_pair.dart --device linux --repeats 5 \
  --warmup-runs 1 --interleaved-runs
```

Salida:

- `benchmarks/offstage_v1_pair_report.md`
- `benchmarks/offstage_v1_pair_report.json`

Comparacion con coverage guard (candidato vs control):

1. Genera primero un control (`default`) con salida JSON versionada.
2. Corre candidato apuntando al control para invalidar comparaciones cuando
   caiga cobertura relativa.

```bash
dart run benchmarks/run_offstage_v1_pair.dart --device linux --repeats 3 --warmup-runs 1 \
  --interleaved-runs \
  --report-path benchmarks/results/experiments/control.md \
  --json-report-path benchmarks/results/experiments/control.json

dart run benchmarks/run_offstage_v1_pair.dart --device linux --repeats 3 --warmup-runs 1 \
  --interleaved-runs \
  --card-single-measure-batch --chip-single-measure-batch \
  --coverage-reference-pair-json benchmarks/results/experiments/control.json \
  --coverage-min-max-index-ratio 0.80 \
  --coverage-min-unique-index-ratio 0.80 \
  --coverage-max-max-index-ratio 1.20 \
  --coverage-max-unique-index-ratio 1.20 \
  --report-path benchmarks/results/experiments/candidate.md \
  --json-report-path benchmarks/results/experiments/candidate.json
```

Nota: el reporte pair incluye columnas de instrumentacion cuando estan
disponibles (`build_calls`, `visible_calls`, `offstage_calls`, `uniq_idx`,
`uniq_visible`, `uniq_offstage`, `builds_per_idx`, `visible_per_idx`,
`offstage_per_idx`, `max_index`, `max_visible`, `max_offstage`).

Overrides de tuning disponibles en el par:

- `--chip-batch-size <n>`
- `--chip-measure-batch-size <n>`
- `--chip-load-threshold <px>`
- `--chip-cache-extent <px>`
- `--chip-visible-cache-cap <n>`
- `--chip-single-measure-batch`
- `--chip-keep-alives`
- `--chip-repaint-boundaries`
- `--chip-adaptive-repaint-boundaries`
- `--chip-incremental-load`
- `--chip-adaptive-visible-cache`
- `--card-batch-size <n>`
- `--card-measure-batch-size <n>`
- `--card-load-threshold <px>`
- `--card-cache-extent <px>`
- `--card-visible-cache-cap <n>`
- `--card-single-measure-batch`
- `--card-keep-alives`
- `--card-repaint-boundaries`
- `--card-adaptive-repaint-boundaries`
- `--card-incremental-load`
- `--card-adaptive-visible-cache`
- `--report-path <path>` (markdown)
- `--json-report-path <path>`
- `--coverage-reference-pair-json <path>`
- `--coverage-min-max-index-ratio <0-1>` (default `0.8`)
- `--coverage-min-unique-index-ratio <0-1>` (default `0.8`)
- `--coverage-max-max-index-ratio <n>` (`n >= 1`, default: disabled)
- `--coverage-max-unique-index-ratio <n>` (`n >= 1`, default: disabled)
- `--interleaved-runs` (alterna chip/card por ciclo)

Stress chip (churn alto) para diagnostico de Offstage V1:

```bash
dart run benchmarks/run_benchmarks.dart \
  --device linux \
  --scenario dynamic_chip_10k \
  --define OFFSTAGE_CHIP_BATCH_SIZE=16

dart run benchmarks/run_benchmarks.dart \
  --device linux \
  --scenario dynamic_chip_10k \
  --define OFFSTAGE_CHIP_BATCH_SIZE=16 \
  --define OFFSTAGE_VISIBLE_WIDGET_CACHE_CAPACITY=512
```

Objetivo: medir sensibilidad de churn/build/jank en chip cuando la cobertura de
indices sube (no usar como baseline oficial sin recalibracion previa).

Nota (estado actual Offstage V1):

1. `OFFSTAGE_VISIBLE_WIDGET_CACHE_CAPACITY` default: `256`.
2. `OFFSTAGE_ADAPTIVE_VISIBLE_WIDGET_CACHE` default: `true`.
3. `OFFSTAGE_VISIBLE_WIDGET_CACHE_MIN_ITEM_AREA` default: `12000`.
4. El runtime activa cache visible solo para items grandes (card-like) y la
   desactiva para items pequenos (chip-like).
5. `OFFSTAGE_ADAPTIVE_MEASURE_BATCH` default: `false` (opt-in experimental).
6. `OFFSTAGE_LARGE_ITEM_MEASURE_BATCH_CAP` default: `8` (aplica cuando
   `OFFSTAGE_ADAPTIVE_MEASURE_BATCH=true`).
7. `OFFSTAGE_MEASUREMENT_FLUSH_CHUNK_SIZE` default: `0` (si es `<=0`, flush
   completo por frame; si es `>0`, limita el maximo de tamanos aplicados por
   frame).
8. `OFFSTAGE_INCREMENTAL_MEASURE_SCAN_CURSOR` default: `false` (si es `true`,
   habilita cursor incremental para reconstruir la cola de medicion; util para
   A/B de costo O(n) vs cursor incremental).
9. `BENCH_AUTO_PRE_MEASURE_EDGE_BOUNCE` default: `true` (si es `true`, activa
   una fase de pre-measure automatica para perfil `jump + edge_bounce`).
10. `BENCH_EDGE_BOUNCE_AUTO_PRE_MEASURE_STEPS` default: `24` (pasos de
   pre-measure automatico para el caso anterior; override explicito posible
   via `BENCH_PRE_MEASURE_SCROLL_STEPS`).

Smoke rapido de cache adaptativo (opt-in) sobre chip stress:

```bash
dart run benchmarks/run_offstage_v1_pair.dart \
  --device linux \
  --repeats 1 \
  --warmup-runs 0 \
  --interleaved-runs \
  --chip-batch-size 16 \
  --chip-visible-cache-cap 512 \
  --chip-adaptive-visible-cache
```

Revalidacion robusta adaptive vs fijo (intercalado, `r5/w1`):

```bash
dart run benchmarks/run_offstage_v1_pair.dart \
  --device linux \
  --repeats 5 \
  --warmup-runs 1 \
  --interleaved-runs \
  --chip-batch-size 16 \
  --chip-visible-cache-cap 512 \
  --chip-adaptive-visible-cache \
  --baseline-summary benchmarks/results/experiments/20260213_pair_chip_stress_cache512_interleaved_r5_w1.json \
  --coverage-reference-pair-json benchmarks/results/experiments/20260213_pair_chip_stress_cache512_interleaved_r5_w1.json \
  --coverage-min-max-index-ratio 0.95 \
  --coverage-min-unique-index-ratio 0.95 \
  --coverage-max-max-index-ratio 1.20 \
  --coverage-max-unique-index-ratio 1.20
```

Smoke rapido de repaint boundaries adaptativo (opt-in) sobre chip stress:

```bash
dart run benchmarks/run_offstage_v1_pair.dart \
  --device linux \
  --repeats 1 \
  --warmup-runs 0 \
  --interleaved-runs \
  --chip-batch-size 16 \
  --chip-visible-cache-cap 512 \
  --chip-adaptive-repaint-boundaries
```

Revalidacion robusta adaptive repaint vs fijo (intercalado, `r5/w1`):

```bash
dart run benchmarks/run_offstage_v1_pair.dart \
  --device linux \
  --repeats 5 \
  --warmup-runs 1 \
  --interleaved-runs \
  --chip-batch-size 16 \
  --chip-visible-cache-cap 512 \
  --chip-adaptive-repaint-boundaries \
  --baseline-summary benchmarks/results/experiments/20260213_pair_chip_stress_cache512_interleaved_r5_w1.json \
  --coverage-reference-pair-json benchmarks/results/experiments/20260213_pair_chip_stress_cache512_interleaved_r5_w1.json \
  --coverage-min-max-index-ratio 0.95 \
  --coverage-min-unique-index-ratio 0.95 \
  --coverage-max-max-index-ratio 1.20 \
  --coverage-max-unique-index-ratio 1.20
```

## Estudio de varianza focal (`dynamic_card_50k`)

Script dedicado para medir dispersion de metricas en un solo escenario y
generar artefactos reproducibles (`run_ids`, `metrics.json`, `report.md`).

Smoke rapido (`r1/w0`):

```bash
dart run benchmarks/run_card_variance.dart \
  --device linux \
  --repeats 1 \
  --warmup-runs 0
```

Corrida recomendada para decision de gate (`r10/w0`):

```bash
dart run benchmarks/run_card_variance.dart \
  --device linux \
  --repeats 10 \
  --warmup-runs 0 \
  --output-prefix benchmarks/results/experiments/$(date -u +%Y%m%d)_card_variance_r10
```

Corrida recomendada low-noise (perfil de scroll estable):

```bash
dart run benchmarks/run_card_variance.dart \
  --device linux \
  --repeats 7 \
  --warmup-runs 1 \
  --stable-scroll-profile \
  --output-prefix benchmarks/results/experiments/$(date -u +%Y%m%d)_card_variance_r7_w1_stable
```

Nota: con evidencia actual, este perfil se mantiene **opt-in** para
experimentacion (no es el default del CI).

Probe alternativo para aislar ruido de gestos (scroll por `jumpTo`):

```bash
dart run benchmarks/run_card_variance.dart \
  --device linux \
  --repeats 5 \
  --warmup-runs 1 \
  --scroll-input-mode jump \
  --output-prefix benchmarks/results/experiments/$(date -u +%Y%m%d)_card_variance_r5_w1_jump
```

Probe de `jump` con rebote en bordes para evitar no-op al saturar extremos:

```bash
dart run benchmarks/run_card_variance.dart \
  --device linux \
  --repeats 7 \
  --warmup-runs 2 \
  --scroll-input-mode jump \
  --scroll-jump-profile edge_bounce \
  --output-prefix benchmarks/results/experiments/$(date -u +%Y%m%d)_card_variance_r7_w2_jump_edge_bounce
```

Salida por defecto:

1. `<prefix>_run_ids.txt`
2. `<prefix>_metrics.json`
3. `<prefix>_report.md`

Opcional:

- `--scenario <name>` (default `dynamic_card_50k`)
- `--stable-scroll-profile` (preset deterministico: `ping_pong` + pre-scroll)
- `--scroll-steps <n>`
- `--scroll-step-px <num>`
- `--scroll-settle-frames <n>`
- `--scroll-pump-frame-ms <n>`
- `--pre-measure-scroll-steps <n>`
- `--scroll-input-mode <drag|jump>` (default `drag`)
- `--scroll-jump-profile <relative|edge_bounce>` (default `relative`)
- `--scroll-pattern <forward|ping_pong>`
- `--scroll-pattern-segment-steps <n>`
- `--max-jank-cv <num>` (threshold para gate de varianza en `%jank`, default `70`)
- `--enforce-max-jank-cv` (sale con code `1` si falla el gate)
- `--max-jank-mad-percent <num>` (threshold para gate robusto MAD/mediana en `%jank`, default `30`)
- `--enforce-max-jank-mad` (sale con code `1` si falla el gate robusto)
- `--cooldown-ms <n>` (espera entre corridas para aislar ruido de scheduling/termal)
- `--define KEY=VALUE` (repetible)
- `--frame-budget-ms <num>`
- `--run-ids-path <path>`
- `--json-report-path <path>`
- `--report-path <path>`

Nota: en `run_card_variance.dart`, si se usa `--scroll-input-mode jump` +
`--scroll-jump-profile edge_bounce` y no se pasa `--scroll-step-px`, se aplica
`-280` como default tuned.

Salida JSON adicional:

- `variance_gate.metric`
- `variance_gate.max_allowed_percent`
- `variance_gate.observed_percent`
- `variance_gate.pass`
- `variance_gate.enforced`
- `robust_jank_dispersion.method`
- `robust_jank_dispersion.median`
- `robust_jank_dispersion.mad`
- `robust_jank_dispersion.scaled_mad`
- `robust_jank_dispersion.iqr`
- `robust_jank_dispersion.iqr_percent_of_median`
- `robust_jank_dispersion.mad_percent_of_median`
- `robust_variance_gate.metric`
- `robust_variance_gate.max_allowed_percent`
- `robust_variance_gate.observed_percent`
- `robust_variance_gate.pass`
- `robust_variance_gate.enforced`
- `outlier_diagnostics.method`
- `outlier_diagnostics.metrics.<metrica>.q1`
- `outlier_diagnostics.metrics.<metrica>.q3`
- `outlier_diagnostics.metrics.<metrica>.iqr`
- `outlier_diagnostics.metrics.<metrica>.lower_fence`
- `outlier_diagnostics.metrics.<metrica>.upper_fence`
- `outlier_diagnostics.metrics.<metrica>.outlier_runs[]`
- `outlier_diagnostics.run_outlier_counts`
- `outlier_diagnostics.primary_suspect_run_id`
- `outlier_diagnostics.primary_suspect_metric_count`
- `single_run_anomaly.suspect_run_id`
- `single_run_anomaly.suspect_outlier_metric_count`
- `single_run_anomaly.jank_cv_percent_original`
- `single_run_anomaly.jank_cv_percent_without_suspect`
- `single_run_anomaly.jank_cv_reduction_percent_points`
- `single_run_anomaly.max_jank_cv_percent`
- `single_run_anomaly.target_jank_cv_percent`
- `single_run_anomaly.pass_without_suspect`
- `single_run_anomaly.pass_without_suspect_for_target`
- `single_run_anomaly.single_run_dominated`
- `single_run_anomaly.single_run_dominated_for_target`
- `scroll_diagnostics_summary.no_op_steps_avg`
- `scroll_diagnostics_summary.no_op_steps_max`
- `scroll_diagnostics_summary.effective_steps_avg`
- `scroll_diagnostics_summary.edge_hits_min_avg`
- `scroll_diagnostics_summary.edge_hits_max_avg`
- `scroll_diagnostics_summary.average_abs_delta_px_avg`
- `runs[].scroll_diagnostics.pattern`
- `runs[].scroll_diagnostics.input_mode`
- `runs[].scroll_diagnostics.jump_profile`
- `runs[].scroll_diagnostics.no_op_steps`
- `frame_diagnostics_summary.jank_frames_over_budget_avg`
- `frame_diagnostics_summary.jank_frames_over_2x_budget_avg`
- `frame_diagnostics_summary.max_total_ms_median`
- `frame_diagnostics_summary.primary_suspect_run_id`
- `runs[].frame_diagnostics.max_total_ms`
- `runs[].frame_diagnostics.p99_total_ms`
- `runs[].frame_diagnostics.primary_spike_phase`

Nota: el detalle completo `pre_measure/measured` queda en cada artefacto de
escenario (`benchmarks/results/<run_id>/<scenario>.json`).

Salida Markdown adicional:

- tabla "Diagnostico de outliers (IQR)" por metrica
- resumen de corridas con outliers y run sospechoso principal
- bloque "Diagnostico de corrida anomala (single-run)" con CV original vs CV sin run sospechoso
- tabla "Diagnostico de frames (spikes)" por corrida
- resumen de frames con run sospechoso por spikes `>2x`

Orquestacion CI/local:

- script: `benchmarks/ci/run_card_variance_ci.sh`
- workflow manual: `.github/workflows/card-variance.yml`

Variables utiles del script CI:

- `BENCH_SCENARIO=dynamic_card_50k`
- `BENCH_DEVICE=linux`
- `BENCH_REPEATS=<n>`
- `BENCH_WARMUP_RUNS=<n>` (default `2`)
- `BENCH_MIN_REPEATS=<n>`
- `BENCH_STABLE_SCROLL_PROFILE=true|false` (default `false`)
- `BENCH_SCROLL_INPUT_MODE=drag|jump` (default `jump`)
- `BENCH_SCROLL_JUMP_PROFILE=relative|edge_bounce` (default `edge_bounce`)
- `BENCH_SCROLL_STEP_PX=<num>` (default `-280`)
- `ENFORCE_MAX_JANK_CV=true|false`
- `MAX_JANK_CV=<num>`
- `ENFORCE_MAX_JANK_MAD=true|false`
- `MAX_JANK_MAD=<num>`
- `VARIANCE_DECISION_MODE=cv|mad|cv_or_mad|cv_and_mad` (default `cv_and_mad`)
- `ENFORCE_VARIANCE_DECISION=true|false` (default `true`)
- `CI_OUT_DIR=<path>`

Politica operativa recomendada (Sprint 3/Sprint 6):

- `VARIANCE_DECISION_MODE=cv_and_mad`
- `ENFORCE_VARIANCE_DECISION=true`
- `MAX_JANK_CV=30`
- `MAX_JANK_MAD=30`
- `BENCH_SCROLL_INPUT_MODE=jump`
- `BENCH_SCROLL_JUMP_PROFILE=edge_bounce`
- `BENCH_SCROLL_STEP_PX=-280`
- `BENCH_WARMUP_RUNS=2`

Con esta politica, el gate sigue reportando CV y MAD por separado y exige
PASS simultaneo (`cv_and_mad`) para la decision operativa.

El summary de CI (`card_variance_ci_summary.md`) expone decision explicita:

- `variance_gate_json_pass`
- `variance_gate_observed_cv_percent`
- `variance_gate_json_threshold_cv_percent`
- `variance_gate_evaluated_threshold_cv_percent`
- `variance_gate_evaluated_pass`
- `robust_jank_median_percent`
- `robust_jank_mad_percent_point`
- `robust_jank_mad_percent_of_median`
- `robust_jank_iqr_percent_of_median`
- `robust_variance_gate_json_pass`
- `robust_variance_gate_observed_mad_percent`
- `robust_variance_gate_json_threshold_percent`
- `robust_variance_gate_evaluated_threshold_percent`
- `robust_variance_gate_evaluated_pass`
- `variance_decision_mode`
- `variance_decision_json_pass`
- `variance_decision_evaluated_pass`
- `enforce_variance_decision`

Modo reutilizando artefacto existente (sin correr benchmark):

- `CI_SKIP_BENCH=true`
- `BENCH_VARIANCE_JSON=<path>`
- `BENCH_VARIANCE_MD=<path>` (opcional)
- `BENCH_VARIANCE_RUN_IDS=<path>` (opcional)

## Check consecutivo (2 tandas) para card variance

Script dedicado para formalizar decision de consecutividad entre dos JSON de
`run_card_variance.dart`.

```bash
dart run benchmarks/run_card_variance_consecutive_check.dart \
  --run-a-json benchmarks/results/experiments/<run_a>_metrics.json \
  --run-b-json benchmarks/results/experiments/<run_b>_metrics.json \
  --mode cv \
  --cv-threshold 30 \
  --mad-threshold 30
```

Salida por defecto:

1. `benchmarks/results/experiments/<date>_card_variance_consecutive_<mode>.json`
2. `benchmarks/results/experiments/<date>_card_variance_consecutive_<mode>.md`

Modos soportados:

- `cv`: decide solo por `metrics.jank_percent.cv_percent <= cv_threshold`.
- `mad`: decide solo por `robust_jank_dispersion.mad_percent_of_median <= mad_threshold`.
- `cv_or_mad`: pasa si CV o MAD pasan (si falta MAD/CV, hace fallback al disponible).
- `cv_and_mad`: requiere que CV y MAD pasen en ambas tandas.

Campos JSON clave:

- `mode`
- `thresholds.cv_percent`
- `thresholds.mad_percent_of_median`
- `run_a.mode_pass`
- `run_b.mode_pass`
- `consecutive_pass`
- `decision`

Orquestacion CI/local de consecutividad:

- script: `benchmarks/ci/run_card_variance_consecutive_ci.sh`
- workflow manual: `.github/workflows/card-variance-consecutive.yml`

Variables utiles del script consecutivo:

- `BENCH_SCENARIO=dynamic_card_50k`
- `BENCH_DEVICE=linux`
- `BENCH_REPEATS=<n>`
- `BENCH_WARMUP_RUNS=<n>` (default `2`)
- `BENCH_MIN_REPEATS=<n>`
- `BENCH_STABLE_SCROLL_PROFILE=true|false` (default `false`)
- `BENCH_SCROLL_INPUT_MODE=drag|jump` (default `jump`)
- `BENCH_SCROLL_JUMP_PROFILE=relative|edge_bounce` (default `edge_bounce`)
- `BENCH_SCROLL_STEP_PX=<num>` (default `-280`)
- `MAX_JANK_CV=<num>` (threshold CV para cada tanda)
- `MAX_JANK_MAD=<num>` (threshold MAD para cada tanda)
- `ENFORCE_MAX_JANK_CV=true|false` (si `true`, cada tanda falla si CV supera threshold)
- `ENFORCE_MAX_JANK_MAD=true|false` (si `true`, cada tanda falla si MAD supera threshold)
- `DECISION_MODE=cv|mad|cv_or_mad|cv_and_mad` (default `cv_and_mad`)
- `CV_THRESHOLD=<num>`
- `MAD_THRESHOLD=<num>`
- `ENFORCE_CONSECUTIVE_PASS=true|false` (default `true`)
- `CI_OUT_DIR=<path>`

Politica consecutiva recomendada:

- `DECISION_MODE=cv_and_mad`
- `ENFORCE_CONSECUTIVE_PASS=true`
- `CV_THRESHOLD=30`
- `MAD_THRESHOLD=30`

Modo reutilizando artefactos existentes (sin correr benchmarks):

- `CI_SKIP_BENCH=true`
- `RUN_A_JSON=<path>`
- `RUN_B_JSON=<path>`
- `RUN_A_MD=<path>` (opcional)
- `RUN_B_MD=<path>` (opcional)
- `RUN_A_RUN_IDS=<path>` (opcional)
- `RUN_B_RUN_IDS=<path>` (opcional)

## Sweep de perfiles de scroll para card variance

Script dedicado para buscar un perfil de scroll mas estable en
`dynamic_card_50k` usando los mismos gates de varianza (`CV` + `MAD`).

Listado de presets:

```bash
dart run benchmarks/run_card_variance_profile_sweep.dart --list-presets
```

Corrida completa (todos los presets):

```bash
dart run benchmarks/run_card_variance_profile_sweep.dart \
  --device linux \
  --repeats 7 \
  --warmup-runs 2 \
  --max-jank-cv 30 \
  --max-jank-mad-percent 30
```

Filtrar presets concretos:

```bash
dart run benchmarks/run_card_variance_profile_sweep.dart \
  --device linux \
  --preset default \
  --preset stable_ping_pong_v1 \
  --preset forward_long_sweep
```

Salida:

- `benchmarks/card_variance_profile_sweep_report.md`
- `benchmarks/results/experiments/<date>_card_variance_profile_sweep/summary.json`
- artefactos por preset (`*_run_ids.txt`, `*_metrics.json`, `*_report.md`) en
  `benchmarks/results/experiments/<date>_card_variance_profile_sweep/`

Orquestacion CI/local del sweep:

- script: `benchmarks/ci/run_card_variance_profile_sweep_ci.sh`
- workflow manual: `.github/workflows/card-variance-profile-sweep.yml`

Variables utiles del script CI:

- `BENCH_SCENARIO=dynamic_card_50k`
- `BENCH_DEVICE=linux`
- `BENCH_REPEATS=<n>`
- `BENCH_WARMUP_RUNS=<n>`
- `MAX_JANK_CV=<num>`
- `MAX_JANK_MAD=<num>`
- `PROFILE_PRESETS=<id1,id2,...>` (opcional; vacio = todos)
- `ENFORCE_AT_LEAST_ONE_PASS=true|false`
- `CI_OUT_DIR=<path>`

Modo reutilizando artefacto existente (sin correr benchmark):

- `CI_SKIP_BENCH=true`
- `SWEEP_SUMMARY_JSON=<path>`
- `SWEEP_REPORT_MD=<path>` (opcional)

## Sweep runtime de carga/cache para card variance

Script dedicado para barrer presets de runtime (lotes, cache visible, carga
incremental, etc.) manteniendo el mismo perfil de scroll.

Listado de presets:

```bash
dart run benchmarks/run_card_variance_runtime_sweep.dart --list-presets
```

Corrida completa (todos los presets):

```bash
dart run benchmarks/run_card_variance_runtime_sweep.dart \
  --device linux \
  --repeats 7 \
  --warmup-runs 2 \
  --max-jank-cv 30 \
  --max-jank-mad-percent 30
```

Filtrar presets concretos (ejemplo capacidad fija):

```bash
dart run benchmarks/run_card_variance_runtime_sweep.dart \
  --device linux \
  --preset default \
  --preset fixed_visible_cache_192 \
  --preset fixed_visible_cache_256 \
  --preset fixed_visible_cache_384
```

Salida:

- `benchmarks/card_variance_runtime_sweep_report.md`
- `benchmarks/results/experiments/<date>_card_variance_runtime_sweep/summary.json`
- artefactos por preset (`*_run_ids.txt`, `*_metrics.json`, `*_report.md`) en
  `benchmarks/results/experiments/<date>_card_variance_runtime_sweep/`

Orquestacion CI/local del sweep:

- script: `benchmarks/ci/run_card_variance_runtime_sweep_ci.sh`
- workflow manual: `.github/workflows/card-variance-runtime-sweep.yml`

Variables utiles del script CI:

- `BENCH_SCENARIO=dynamic_card_50k`
- `BENCH_DEVICE=linux`
- `BENCH_REPEATS=<n>`
- `BENCH_WARMUP_RUNS=<n>`
- `MAX_JANK_CV=<num>`
- `MAX_JANK_MAD=<num>`
- `RUNTIME_PRESETS=<id1,id2,...>` (opcional; vacio = todos)
- `BENCH_STABLE_SCROLL_PROFILE=true|false`
- `ENFORCE_AT_LEAST_ONE_PASS=true|false`
- `CI_OUT_DIR=<path>`

Modo reutilizando artefacto existente (sin correr benchmark):

- `CI_SKIP_BENCH=true`
- `SWEEP_SUMMARY_JSON=<path>`
- `SWEEP_REPORT_MD=<path>` (opcional)

## Sweep de tuning offstageV1 (preset ranking)

Listado de presets:

```bash
dart run benchmarks/run_offstage_v1_tuning_sweep.dart --list-presets
```

Corrida completa:

```bash
dart run benchmarks/run_offstage_v1_tuning_sweep.dart \
  --device linux \
  --repeats 2 \
  --warmup-runs 1
```

Filtrar presets concretos:

```bash
dart run benchmarks/run_offstage_v1_tuning_sweep.dart \
  --device linux \
  --preset default \
  --preset balanced_v1 \
  --preset memory_guard
```

Sweep con coverage guard (para descartar presets no comparables por cobertura):

```bash
dart run benchmarks/run_offstage_v1_tuning_sweep.dart \
  --device linux \
  --repeats 2 \
  --warmup-runs 1 \
  --coverage-reference-pair-json benchmarks/results/experiments/control.json \
  --coverage-min-max-index-ratio 0.80 \
  --coverage-min-unique-index-ratio 0.80
```

Sweep usando baseline de control tipo `pair.json` (misma tanda, menos drift):

```bash
dart run benchmarks/run_offstage_v1_tuning_sweep.dart \
  --device linux \
  --repeats 2 \
  --warmup-runs 1 \
  --baseline-summary benchmarks/results/experiments/control.json \
  --coverage-reference-pair-json benchmarks/results/experiments/control.json \
  --coverage-min-max-index-ratio 0.80 \
  --coverage-min-unique-index-ratio 0.80
```

Salida:

- `benchmarks/offstage_v1_tuning_sweep_report.md`
- `benchmarks/results/tuning_sweep/<sweep_id>/summary.json`
- reportes por preset (`.md` + `.json`) en `benchmarks/results/tuning_sweep/<sweep_id>/`

## Opciones

```bash
dart run benchmarks/run_benchmarks.dart --help
```

- `--device <id>`: selecciona device Flutter (ej. `linux`, `chrome`)
- `--scenario <name>`: ejecuta un solo escenario
- `--frame-budget-ms <num>`: umbral para calcular `% jank` (default `16.67`)
- `--define KEY=VALUE`: inyecta `dart-define` extra al runner
- `--warmup-runs <n>`: corridas de calentamiento descartadas en scripts batch
- `--outlier-iqr-k <num>`: multiplicador IQR para filtrar outliers (default `1.5`)
- `--no-outlier-filter`: desactiva el filtrado de outliers en medianas

## Salida

Cada corrida crea una carpeta versionada:

`benchmarks/results/<run_id>/`

Contenido esperado:

1. `<scenario>.json` por escenario
2. `summary.json` con resumen de toda la corrida

Campos adicionales (instrumentacion de build):

1. `item_build_calls`: total de invocaciones a `itemBuilder` durante la corrida
2. `visible_item_build_calls`: builds de items en arbol visible
3. `offstage_item_build_calls`: builds de items en arbol Offstage (medicion)
4. `unique_built_indices`: cantidad de indices unicos construidos
5. `unique_visible_built_indices`: cantidad de indices unicos en arbol visible
6. `unique_offstage_built_indices`: cantidad de indices unicos en Offstage
7. `builds_per_unique_index`: `item_build_calls / unique_built_indices`
8. `visible_builds_per_unique_index`:
   `visible_item_build_calls / unique_visible_built_indices`
9. `offstage_builds_per_unique_index`:
   `offstage_item_build_calls / unique_offstage_built_indices`
10. `max_built_index`: mayor indice construido en la corrida
11. `max_visible_built_index`: mayor indice construido en arbol visible
12. `max_offstage_built_index`: mayor indice construido en arbol Offstage
13. `scroll_profile`: protocolo de scroll aplicado (`pattern`, `scroll_steps`,
    `scroll_step_px`, `pre_measure_scroll_steps`, `settle_frames`,
    `pump_frame_ms`)

La clasificacion visible/offstage se realiza en el `BuildContext` real del item
con un `Builder` wrapper, no en el callsite del `itemBuilder`.

Ademas, el script actualiza:

`benchmarks/baseline_report.md`

## Arquitectura del harness

El comando ejecuta `flutter drive` sobre `benchmarks/runner_app` (host app con
soporte Linux) para no depender de plataformas configuradas en la raiz del
package.
