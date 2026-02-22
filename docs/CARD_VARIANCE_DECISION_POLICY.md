# Politica de Decision de Varianza (Card)

Fecha de adopcion: 2026-02-13

## Objetivo

Definir un criterio operativo unico para decidir PASS/FAIL de varianza en
`dynamic_card_50k` sin perder trazabilidad de CV y MAD por separado.

## Politica operativa vigente

1. Modo de decision: `cv_and_mad`.
2. Threshold CV: `30`.
3. Threshold MAD/mediana: `30`.
4. Enforcement de decision: `true`.
5. `scroll_input_mode`: `jump`.
6. `scroll_jump_profile`: `edge_bounce`.
7. `scroll_step_px`: `-280`.
8. Warmup recomendado: `2`.
9. Workflow de referencia: `.github/workflows/card-variance.yml`.

## Razon tecnica

1. Se validaron 2 tandas robustas consecutivas (`r7,w2`) con
   `BENCH_SCROLL_INPUT_MODE=jump`, `BENCH_SCROLL_JUMP_PROFILE=edge_bounce` y
   `BENCH_SCROLL_STEP_PX=-280`.
2. En ambas tandas se cumplio `jank_cv_percent <= 30` y
   `jank_mad_percent_of_median <= 30`.
3. Con esa evidencia, el criterio puede endurecerse sin depender de
   `cv_or_mad` para decisiones operativas.

## Implementacion

Variables relevantes en CI:

- `VARIANCE_DECISION_MODE=cv_and_mad`
- `ENFORCE_VARIANCE_DECISION=true`
- `MAX_JANK_CV=30`
- `MAX_JANK_MAD=30`
- `BENCH_SCROLL_INPUT_MODE=jump`
- `BENCH_SCROLL_JUMP_PROFILE=edge_bounce`
- `BENCH_SCROLL_STEP_PX=-280`
- `BENCH_WARMUP_RUNS=2`

Resumen en artefacto CI (`card_variance_ci_summary.md`):

- `variance_decision_mode`
- `variance_decision_json_pass`
- `variance_decision_evaluated_pass`
- `enforce_variance_decision`
