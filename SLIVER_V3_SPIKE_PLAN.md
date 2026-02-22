# Spike Plan: `sliverV3` (RenderSliver Deep)

## Objetivo

Construir un prototipo `sliverV3` que supere los limites observados en `sliverV2` para cargas densas tipo `dynamic_chip_10k`, manteniendo compatibilidad total de API publica (sin cambios para consumidores en esta etapa).

## Estado actual (punto de partida)

1. `offstageV1` sigue siendo baseline de produccion.
2. `sliverV2` se mantiene experimental (opt-in) con decision Sprint 6: **NO-GO** para release por regresiones de `%jank`, `p95_build_ms`, memoria y `TTI`.
3. Cuello principal: composicion por fila con alto costo de build en escenarios de chips.

## Hipotesis tecnica de `sliverV3`

1. El limite de `sliverV2` viene de la estrategia de composicion/widget tree por fila, no solo del algoritmo de packing.
2. Un engine basado en `RenderSliver` + virtualizacion por ventana visible (con cache) puede reducir trabajo por frame.
3. Separar:
   - calculo de geometria (deterministico, puro, testeable),
   - layout/pintado (render layer),
   reduce costos y facilita optimizaciones incrementales.

## Alcance (1 sprint, 1 semana)

1. Implementar nucleo de geometria reutilizable:
   - packing de filas,
   - offsets acumulados,
   - consulta de ventana visible por busqueda binaria.
2. Implementar prototipo interno `sliverV3` (no publico):
   - solo scroll vertical,
   - paridad minima de `spacing`, `runSpacing`, `padding`.
3. Ejecutar A/B:
   - `offstageV1` vs `sliverV2` vs `sliverV3` (interno),
   - foco en `dynamic_chip_10k` y `dynamic_card_50k`.

## No alcance

1. No cambiar defaults de API.
2. No exponer `LazyWrapEngine.sliverV3` en esta semana.
3. No cubrir horizontal hasta validar ventaja clara en vertical.

## Historias de usuario y criterios de aceptacion

| ID | Historia de usuario | Criterios de aceptacion |
|---|---|---|
| V3-US1 | Como equipo quiero una capa de geometria pura para desacoplar performance de layout/render. | Existe modulo interno con tests unitarios para packing y ventana visible (casos normales + edge cases). |
| V3-US2 | Como maintainer quiero un prototipo render-level para validar si el enfoque deep mejora chips. | Existe `sliverV3` interno funcional en vertical, sin crashes en smoke tests. |
| V3-US3 | Como equipo quiero decidir continuidad con numeros objetivos. | Se genera reporte A/B con mediana (>= 3 repeticiones) y recomendacion Go/No-Go del spike. |

## Plan de trabajo por dia

1. Dia 1:
   - cerrar modulo de geometria + tests,
   - integrar en el prototipo interno base.
2. Dia 2:
   - montar esqueleto `RenderSliver` minimo viable,
   - validar layout/pintado con dataset chico.
3. Dia 3:
   - optimizar invalidacion/relayout parcial,
   - agregar pruebas de paridad visual minima.
4. Dia 4:
   - conectar harness benchmark para escenario V3 interno,
   - correr A/B inicial y ajustar cuellos obvios.
5. Dia 5:
   - repetir benchmarks (>= 3 corridas),
   - redactar reporte y decision de continuidad.

## Metricas de salida del spike (gate)

1. `dynamic_chip_10k`:
   - `p95_build_ms` mejora >= 20% vs `sliverV2`,
   - `% jank` mejora >= 30% vs `sliverV2`.
2. `dynamic_card_50k`:
   - sin regresion mayor al 10% en `p95_raster_ms` y `TTI` vs `offstageV1`.
3. Correctitud:
   - `flutter test` completo en verde,
   - sin crashes en escenarios benchmark.

## Riesgos y mitigaciones

1. Riesgo: complejidad alta de `RenderSliver`.
   - Mitigacion: mantener scope minimo y feature flag interno.
2. Riesgo: resultados inestables por entorno desktop.
   - Mitigacion: usar mediana de multiples corridas y documentar varianza.
3. Riesgo: sobre-ingenieria sin mejora real.
   - Mitigacion: gate estricto de 1 sprint; si no cumple, detener e iterar sobre `offstageV1`.

## Entregables esperados

1. Codigo:
   - modulo geometria `sliverV3` con tests,
   - prototipo interno `sliverV3`.
2. Benchmark:
   - resultados versionados en `benchmarks/results/`,
   - reporte A/B comparativo.
3. Documentacion:
   - decision tecnica (ADR/update),
   - plan de continuacion o cierre del spike.

## Resultado de cierre (2026-02-12)

1. Corrida de decision completada con `--repeats 3`:
   - `benchmarks/sliver_v3_triplet_report.md`
2. Decision: **NO-GO** para adopcion publica de `sliverV3` en este ciclo.
3. Documento de decision:
   - `docs/adr/0002-sliver-v3-render-spike.md`
4. Revalidacion robusta posterior (`--repeats 5 --warmup-runs 1`) confirma NO-GO:
   - `benchmarks/sliver_v3_triplet_report.md`
   - `benchmarks/sliver_v3_spike_report.md`

## Re-check posterior (2026-02-21)

1. Se habilito benchmark dedicado `dynamic_card_50k_sliver_v3` para medir el
   frente card con protocolo robusto `r7,w2`.
2. Resultado mediano vs `offstageV1_cons64`:
   - mejora en `p95_build_ms`, `p95_raster_ms` y `peak_memory_mb`.
   - regresion en `time_to_first_interaction_ms`.
   - estabilidad estricta no cerrada en check consecutivo (`cv`, `cv_and_mad`).
3. Decision: se mantiene **NO-GO** para adopcion publica/default de `sliverV3`
   en este corte.
4. Evidencia:
   - `benchmarks/results/experiments/20260221_card_sliverv3_ab_robust_summary.md`
   - `benchmarks/results/experiments/20260221_card_sliverv3_ab_robust_summary.json`
5. Iteracion adicional `TTI` (mismo dia):
   - se optimiza scheduling de fill-check en `DynamicLazyWrapSliverV3` para
     evitar callbacks post-frame continuos.
   - robusto `r7,w2` confirma mejora de `TTI` vs control y mejora adicional
     frente a `sliverV3` previo.
   - se mantiene **NO-GO** para default por dispersion CV de `%jank` aun fuera
     de umbral estricto.
   - evidencia:
     - `benchmarks/results/experiments/20260221_card_sliverv3_ttiopt_ab_robust_summary.md`
     - `benchmarks/results/experiments/20260221_card_sliverv3_ttiopt_ab_robust_summary.json`
6. Spike corto descartado (mismo dia):
   - hipotesis: throttling de cache en saltos grandes de scroll.
   - resultado corto `r3,w1`: mejora build/raster, pero empeora `TTI` y no
     mejora estabilidad.
   - decision: **NO-GO** y rollback del cambio en render.
   - evidencia:
     - `benchmarks/results/experiments/20260221_card_sliverv3_jumpcache_ab_short_summary.md`
     - `benchmarks/results/experiments/20260221_card_sliverv3_jumpcache_ab_short_summary.json`
7. Diagnostico por segmentos (mismo dia):
   - se extiende harness/report para partir `measured_scroll` en segmentos y
     localizar hotspots por tramo.
   - robusto `r7,w2` (`segments=6`) identifica hotspot primario en `s0`:
     - `jank>2x_avg=0.143`
     - `max_total_ms_max=46.741`
   - decision:
     - mantiene **NO-GO** para default de `sliverV3`.
     - proxima iteracion debe atacar especificamente el costo del primer tramo.
   - evidencia:
     - `benchmarks/results/experiments/20260221_card_sliverv3_segmentdiag_ab_robust_summary.md`
     - `benchmarks/results/experiments/20260221_card_sliverv3_segmentdiag_ab_robust_summary.json`
8. Control cruzado por segmentos (`offstageV1` vs `sliverV3`):
   - se corre `dynamic_card_50k` con el mismo protocolo (`r7,w2`, `segments=6`)
     para validar si el hotspot era exclusivo del candidato.
   - hallazgo:
     - ambos engines concentran picos en `s0`.
     - `sliverV3` es mas severo en `s0`
       (`max_total_ms_max=46.741` vs `32.984` control).
     - `sliverV3` mantiene mejor throughput (build/raster) y memoria, con peor
       `tti`.
   - decision:
     - se mantiene **NO-GO** para default.
     - siguiente experimento: mitigacion del tramo inicial (`s0`) en `sliverV3`.
   - evidencia:
     - `benchmarks/results/experiments/20260221_card_segmentdiag_sliverv3_vs_offstage_summary.md`
     - `benchmarks/results/experiments/20260221_card_segmentdiag_sliverv3_vs_offstage_summary.json`
9. Mitigacion `s0` por diferido de load-step en scroll:
   - cambio:
     - `lib/src/dynamic_lazy_wrap_sliver_v3.dart`
     - `loadMore` pasa a diferido por frame solo para eventos de scroll.
     - `fill viewport` conserva `loadMore` inmediato.
   - resultado robusto `r7,w2`:
     - caida marcada de severidad en segmento inicial:
       - `s0 jank>2x_avg: 0.143 -> 0.000`
       - `s0 max_total_ms_max: 46.741 -> 8.225`
     - mejora de throughput (`p95_build`, `p95_raster`) y de picos globales.
     - tradeoff: `TTI` mediana empeora (`+4.29%` vs sliverV3 previo).
   - decision:
     - **avance parcial** (mitigacion de `s0` valida).
     - **NO-GO** para default hasta recuperar `TTI`.
   - evidencia:
     - `benchmarks/results/experiments/20260221_card_sliverv3_loadstepdefer_segmentdiag_summary.md`
     - `benchmarks/results/experiments/20260221_card_sliverv3_loadstepdefer_segmentdiag_summary.json`
10. Test de `startup batch cap` para `TTI`:
   - hipotesis:
     - bajar costo del primer frame limitando batch inicial.
   - validacion:
     - smoke `r3,w1` con buena señal inicial de `TTI`.
     - robusto `r7,w2` confirma tradeoff no aceptable:
       - `TTI` mejora, pero empeoran throughput y severidad de picos (`s0`).
   - decision:
     - **NO-GO**.
     - rollback aplicado en codigo para preservar baseline de `load-step defer`.
   - evidencia:
     - `benchmarks/results/experiments/20260221_card_sliverv3_startupcap_robust_report.md`
     - `benchmarks/results/experiments/20260221_card_sliverv3_startupcap_robust_summary.md`
     - `benchmarks/results/experiments/20260221_card_sliverv3_startupcap_robust_summary.json`
11. Test de `startup cacheExtent cap` con promocion post-scroll:
   - hipotesis:
     - reducir trabajo inicial de cache sin tocar batch inicial; recuperar
       picos globales sin perder estabilidad de scroll.
   - cambio:
     - `lib/src/dynamic_lazy_wrap_sliver_v3.dart`
       - `cacheExtent` efectivo cappeado en arranque.
       - promocion al valor configurado tras primer scroll real.
   - robusto `r7,w2` (vs baseline `loadstepdefer`):
     - mejora `p95_build` (`-3.17%`) y `p95_raster` (`-9.07%`).
     - `%jank` medio cae a `0.0` (`-100%`).
     - hotspot `s5` reduce severidad (`max_total_ms_max -57.15%`).
     - tradeoff: `TTI` mediana sube levemente (`+1.71%`) y memoria mediana
       sube marginalmente (`+0.35%`).
   - hardening:
     - se detecta y corrige regresion no-batch: la promocion de cache no debe
       depender de `_hasMoreItems`.
     - se agrega test de regresion:
       - `promotes startup cache extent after first user scroll`.
   - decision:
     - mantener ajuste en codigo (**GO condicional** del experimento).
     - se mantiene **NO-GO** para default de `sliverV3` hasta cerrar brecha de
       `TTI` frente a `offstageV1`.
   - evidencia:
     - `benchmarks/results/experiments/20260221_card_sliverv3_startupcachecap_robust_report.md`
     - `benchmarks/results/experiments/20260221_card_sliverv3_startupcachecap_robust_summary.md`
     - `benchmarks/results/experiments/20260221_card_sliverv3_startupcachecap_robust_summary.json`
12. Retuning de startup cache cap + cierre de default tecnico:
   - barrido:
     - sweep corto (`r3,w1`) para caps `80`, `120`, `180`, `240`, `300`.
     - robustos (`r7,w2`) para `cap180`, `cap240`, `cap300`.
   - resultados:
     - `cap180`: **NO-GO** por severidad en tramo inicial y outliers.
     - `cap240`: mejora parcial, pero sin dominar estabilidad global.
     - `cap300`: mejor señal robusta combinada (`build`, `TTI`, `%jank`).
   - hardening de implementacion:
     - `lib/src/dynamic_lazy_wrap_sliver_v3.dart`
       - default `_startupCacheExtentCapDefault = 300`.
       - guard `_hasStartupCacheCap` para evitar promocion/setState cuando el
         cap no aplica.
   - validacion:
     - `flutter analyze --no-pub`: PASS
     - `flutter test`: PASS
   - robust final de default (`default300_guard`, sin define):
     - `p95_build_ms` mediana `2.077`
     - `p95_raster_ms` mediana `4.679`
     - `%jank` medio `0.0`
     - `TTI` mediana `244.711`
     - `hot_max_total` `7.924`
   - decision:
     - **GO** para tuning de startup cache en este ciclo.
     - se mantiene **NO-GO** para default de engine `sliverV3` hasta cerrar
       brecha de `TTI` vs `offstageV1`.
   - evidencia:
     - `benchmarks/results/experiments/20260221_card_sliverv3_startupcache_tuning_summary.md`
     - `benchmarks/results/experiments/20260221_card_sliverv3_startupcache_tuning_summary.json`
13. Gate Sprint 6 (re-check global contra baseline Sprint 1):
   - objetivo:
     - validar si `sliverV3` ya cruza criterios globales del roadmap con el
       mejor candidato actual (`default300_guard`).
   - ejecucion:
     - se agrega `benchmarks/run_sliver_v3_ab.dart` (formato compatible con
       `run_sprint6_gate.dart`, schema `pairs[].v2`).
     - A/B `r5,w1` en `linux`:
       - `dynamic_card_50k` vs `dynamic_card_50k_sliver_v3`
       - `dynamic_chip_10k` vs `dynamic_chip_10k_sliver_v3`
     - gate:
       - `dart run benchmarks/run_sprint6_gate.dart ... --functional-tests-pass --no-p0-p1-open`
   - resultado:
     - **NO-GO** (gate automatizado).
     - fallas de checks:
       - `chip_jank_30`
       - `card_memory_20`
       - `chip_build_20`
       - `card_build_20`
   - lectura:
     - `dynamic_card_50k`: mejora `%jank` (`+25.25%`) pero no alcanza umbral de
       memoria ni build vs baseline Sprint 1.
     - `dynamic_chip_10k`: regresion fuerte vs baseline Sprint 1 en build,
       raster, `%jank`, memoria y `TTI`.
   - decision:
     - cerrar esta iteracion deep con `sliverV3` en modo **opt-in**.
     - no avanzar cambio de default; mantener foco en backlog/hipotesis futuras
       si se reabre una iteracion deep.
   - evidencia:
     - `benchmarks/results/experiments/20260221_sliverv3_ab_r5_w1_report.md`
     - `benchmarks/results/experiments/20260221_sliverv3_ab_r5_w1.json`
     - `benchmarks/results/experiments/20260222_sprint6_gate_sliverv3_r5_w1_report.md`
     - `benchmarks/results/experiments/20260222_sprint6_gate_sliverv3_r5_w1_report.json`
     - `docs/RELEASE_CUT_20260222.md`
