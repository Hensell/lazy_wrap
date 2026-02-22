# Corte Operativo de Release (2026-02-22)

## Decision

- Engine default: `offstageV1` (se mantiene).
- Engine publico opt-in: `sliverV2` permanece **experimental**.
- Linea deep `sliverV3`: **NO-GO** para default y se mantiene fuera del path
  publico por ahora.
- Decision de flip de default: **NO-GO** en este corte.
- Alcance de salida recomendado: release estable con hardening + mejoras V1 +
  engine opt-in existente (`sliverV2`), sin cambio de default.

## Checklist de Corte

1. Suite funcional (`flutter test`): **PASS** (validada en la iteracion final).
2. Analisis estatico (`flutter analyze --no-pub`): **PASS** (validado en la
   iteracion final).
3. Gate Sprint 6 automatizado (baseline Sprint 1 vs candidato `sliverV3`):
   **NO-GO**.
4. Decision de alcance de release (default/opt-in): **PASS** (default se mantiene,
   `sliverV2` opt-in, `sliverV3` no se promueve).

## Resultado del Gate Sprint 6 (2026-02-22)

### Resumen

- Baseline: `benchmarks/results/20260211_232622Z/summary.json`
- Candidate A/B: `benchmarks/results/experiments/20260221_sliverv3_ab_r5_w1.json`
- Device: `linux`
- Repeats: `5`
- Warmup: `1`
- Veredicto: **NO-GO** (`decision.go=false`)

### Checks obligatorios

1. `% jank` en `dynamic_chip_10k` mejora >= 30%: **FAIL** (`-1437.16%`)
2. `peak_memory_mb` en `dynamic_card_50k` mejora >= 20%: **FAIL** (`-4.40%`)
3. `p95_build_ms` en `dynamic_chip_10k` mejora >= 20%: **FAIL** (`-7616.34%`)
4. `p95_build_ms` en `dynamic_card_50k` mejora >= 20%: **FAIL** (`-48.72%`)
5. Suite funcional sin regresiones: **PASS**
6. Sin P0/P1 abiertos en rutas nuevas: **PASS**
7. Calidad de evidencia (`repeats >= 3`): **PASS** (`5`)

### Lectura tecnica de metricas

1. `dynamic_card_50k` muestra mejora parcial en `%jank` (`+25.25%`), pero no
   alcanza los objetivos globales de memoria ni `p95_build_ms` vs baseline de
   Sprint 1.
2. `dynamic_chip_10k` queda claramente por debajo del baseline de Sprint 1 en
   `p95_build_ms`, `p95_raster_ms`, `%jank`, memoria y `TTI`, por lo que bloquea
   cualquier cambio de default del engine.
3. El mejor tuning de `sliverV3` (`default300_guard`) es util como aprendizaje
   y mejora local en el frente card, pero no cumple los criterios globales del
   roadmap para promotion de default.

## Evidencia Principal

- A/B `sliverV3` (`r5,w1`):
  - `benchmarks/results/experiments/20260221_sliverv3_ab_r5_w1_report.md`
  - `benchmarks/results/experiments/20260221_sliverv3_ab_r5_w1.json`
- Gate Sprint 6:
  - `benchmarks/results/experiments/20260222_sprint6_gate_sliverv3_r5_w1_report.md`
  - `benchmarks/results/experiments/20260222_sprint6_gate_sliverv3_r5_w1_report.json`
- Evidencia de tuning final `sliverV3` (`default300_guard`):
  - `benchmarks/results/experiments/20260221_card_sliverv3_startupcache_tuning_summary.md`
  - `benchmarks/results/experiments/20260221_card_sliverv3_startupcache_tuning_summary.json`

## Riesgos y Estado Abierto

1. La brecha principal para una linea deep sigue en `dynamic_chip_10k`.
2. `dynamic_card_50k` mejora en estabilidad/jank, pero no cruza umbrales globales
   de `p95_build_ms` y memoria vs baseline Sprint 1.
3. Cambiar el default ahora aumentaria riesgo de regresion en escenarios
   frecuentes y romperia el criterio objetivo definido por el roadmap.

## Plan Inmediato Post-Corte

1. Publicar/cerrar release sin flip de default (`offstageV1` se mantiene).
2. Mantener `sliverV2` como opt-in experimental documentado.
3. Dejar `sliverV3` en backlog/linea deep para una iteracion futura separada,
   enfocada primero en `dynamic_chip_10k`.
