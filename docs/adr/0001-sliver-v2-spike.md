# ADR-0001: Spike `sliverV2` para `LazyWrap.dynamic`

- Fecha: 2026-02-12
- Estado: Propuesto (resultado de spike)
- Dueño: equipo `lazy_wrap`

## Contexto

`LazyWrap.dynamic` hoy usa engine `offstageV1` basado en medición previa de items para evitar layout jumps. En el roadmap del techo técnico (Sprint 4) se definió validar una arquitectura deep alternativa (`sliverV2`) y comparar A/B contra V1 antes de exponer API pública.

## Decisión evaluada

Se implementó un prototipo interno `sliverV2`:

- Archivo: `lib/src/dynamic_lazy_wrap_sliver_v2.dart`
- Alcance: solo scroll vertical
- Layout: filas wrap precalculadas por ancho disponible
- Virtualización: `SliverList` por filas
- Supuesto del prototipo: tamaños de item provistos por `itemWidthBuilder` e `itemHeightBuilder`

## Evidencia

A/B ejecutado con script:

- `dart run benchmarks/run_sliver_v2_ab.dart --device linux --repeats 2`

Resultados usados (última corrida A/B):

- Card V1: `benchmarks/results/20260212_044123Z/summary.json`, `benchmarks/results/20260212_044157Z/summary.json`
- Card V2: `benchmarks/results/20260212_044210Z/summary.json`, `benchmarks/results/20260212_044244Z/summary.json`
- Chip V1: `benchmarks/results/20260212_044259Z/summary.json`, `benchmarks/results/20260212_044332Z/summary.json`
- Chip V2: `benchmarks/results/20260212_044347Z/summary.json`, `benchmarks/results/20260212_044405Z/summary.json`
- Reporte: `benchmarks/sliver_v2_ab_report.md`

Comparación (`dynamic_card_50k`, mediana):

- `p95_build_ms`: 3.587 (V1) vs 3.750 (V2) -> regresión leve
- `p95_raster_ms`: 7.867 (V1) vs 7.719 (V2) -> mejora leve
- `% jank`: 1.167 (V1) vs 2.012 (V2) -> regresión
- `peak_memory_mb`: 159.488 (V1) vs 162.143 (V2) -> regresión
- `time_to_first_interaction_ms`: 231.404 (V1) vs 251.869 (V2) -> regresión

Comparación (`dynamic_chip_10k`, mediana):

- `p95_build_ms`: 0.252 (V1) vs 36.778 (V2) -> regresión severa
- `p95_raster_ms`: 5.194 (V1) vs 10.976 (V2) -> regresión severa
- `% jank`: 1.833 (V1) vs 31.145 (V2) -> regresión severa
- `peak_memory_mb`: 164.590 (V1) vs 218.814 (V2) -> regresión severa
- `time_to_first_interaction_ms`: 253.546 (V1) vs 330.317 (V2) -> regresión severa

## Tradeoffs

Beneficios del spike:

- Demostró viabilidad funcional del enfoque sliver para wrap dinámico vertical.
- Permitió establecer infraestructura A/B repetible para próximos prototipos.

Costos y riesgos observados:

- El prototipo actual no supera V1 en métricas globales de los escenarios evaluados.
- La dependencia de tamaños externos (`itemWidthBuilder`/`itemHeightBuilder`) limita adopción directa en API pública.
- Riesgo de mantener dos arquitecturas con distinta semántica sin suficiente mejora medible.
- En `dynamic_chip_10k` se observan regresiones severas de build, jank, memoria y TTI.

## Recomendación

No avanzar este prototipo a API pública en su forma actual.

Acción recomendada para siguiente iteración deep:

1. Mantener `offstageV1` como baseline de producción.
2. Iterar un `sliverV2` de segunda generación con foco en reducir build/jank en escenarios tipo chip.
3. Re-ejecutar A/B con criterio de salida: mejoras netas en jank/build y sin regresiones de memoria/TTI.

## Impacto en roadmap

- Sprint 4 US1: cumplido (existe prototipo interno + A/B ejecutado).
- Sprint 4 US2: cumplido (ADR con tradeoffs, riesgos y recomendación).
- Sprint 4 US3: cumplido con pruebas de paridad mínima (`test/dynamic_lazy_wrap_sliver_v2_test.dart`).
