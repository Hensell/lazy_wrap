# Corte Operativo de Release (2026-02-13)

## Decision

- Engine default: `offstageV1` (se mantiene).
- Engine deep: `sliverV2` permanece **opt-in experimental**.
- Decision de flip de default: **NO-GO** en este corte.
- Alcance de salida recomendado: hardening + tooling + observabilidad, sin cambio de default.

## Checklist de Corte

1. Suite funcional completa (`flutter test`): **PASS**.
2. Analisis estatico (`flutter analyze --no-pub`): **PASS**.
3. Politica operativa de varianza card en CI (`cv_and_mad`, enforcement): **PASS**.
4. Cierre robusto de varianza card (criterio estricto consecutivo): **PASS** para protocolo `step=-280` base.
5. Objetivo global de performance en `dynamic_card_50k`:
   - `p95_build_ms` mejora >= 20% vs baseline Sprint 1: **FAIL**.
   - `peak_memory_mb` mejora >= 20% vs baseline Sprint 1: **FAIL**.

## Evidencia Principal

- Baseline Sprint 1:
  - `benchmarks/baseline_report.md`
- Cierre de varianza card (protocolo operativo):
  - `benchmarks/results/experiments/20260213_card_variance_step280_closure_summary.md`
- Sweep robusto top3 (`r7,w2`) para runtime card:
  - `benchmarks/results/experiments/20260213_runtime_sweep_step280_r7_w2_top3/summary.json`
  - `benchmarks/results/experiments/20260213_runtime_sweep_step280_r7_w2_top3_report.md`
  - `benchmarks/results/experiments/20260213_runtime_sweep_step280_r7_w2_top3_comparison_vs_default.md`
- Re-check robusto de candidato de vecindad (`cons_soft_down`):
  - `benchmarks/results/experiments/20260213_card_variance_cons_soft_down_r7_w2_summary.md`

## Lectura Ejecutiva

1. Se estabilizo el protocolo de varianza para card (operativamente usable en CI).
2. El tuning de runtime mejora parcialmente build/memoria contra default en cortes robustos,
   pero no alcanza el umbral global de Sprint 1 para `dynamic_card_50k`.
3. El riesgo de flip de default sigue alto por dispersion CV en escenarios limite.

## Riesgos Abiertos

1. `dynamic_card_50k` no cumple objetivo global de build/memoria (>= 20%).
2. Algunos candidatos de tuning introducen `no_op_steps_avg > 0`, afectando estabilidad
   de decision por CV entre tandas.

## Plan Inmediato Post-Corte

1. Mantener default actual y continuar tuning focal de carga/medicion en card.
2. Priorizar reduccion de `no_op_steps_avg` sin degradar `time_to_first_interaction_ms`.
3. Repetir gate robusto (`r7,w2`) solo con 1-2 candidatos de mayor potencial antes de
   reconsiderar cambio de default.
