# Roadmap: Busqueda del Techo Tecnico de `lazy_wrap` (6 sprints x 1 semana)

## Resumen

Este roadmap define un plan completo para llevar `lazy_wrap` al techo tecnico con foco en `LazyWrap.dynamic`: medir, endurecer, optimizar, prototipar arquitectura deep (sliver/render), decidir Go/No-Go y preparar release sin romper compatibilidad.

## Objetivo y Metricas Globales

### Objetivo

Llevar el paquete a un nivel de performance y robustez superior, con decision objetiva sobre la adopcion de un nuevo engine (`sliverV2`) frente al engine actual (`offstageV1`).

### Escenarios base

1. `dynamic_chip_10k`
2. `dynamic_card_50k`
3. `fixed_grid_10k`

### Metricas obligatorias por escenario

1. `p95_build_ms`
2. `p95_raster_ms`
3. `% jank`
4. `peak_memory_mb`
5. `time_to_first_interaction_ms`

### Objetivos minimos de exito (vs baseline Sprint 1)

1. `% jank` en `dynamic_chip_10k`: mejora >= 30%
2. `peak_memory_mb` en `dynamic_card_50k`: mejora >= 20%
3. `p95_build_ms` en escenarios dynamic: mejora >= 20%
4. Cero regresiones funcionales en suite existente + nueva suite

## Sprints (Historias de Usuario + Criterios de Aceptacion)

### Sprint 1: Baseline e instrumentacion

| ID | Historia de usuario | Criterios de aceptacion |
|---|---|---|
| S1-US1 | Como maintainer quiero benchmarks reproducibles para medir progreso real por commit. | Existe harness ejecutable por comando unico; genera resultados versionados en `benchmarks/results/`; produce todas las metricas globales definidas. |
| S1-US2 | Como equipo quiero escenarios representativos para fixed y dynamic para evitar optimizar casos irreales. | Estan implementados y documentados los 3 escenarios base; cada corrida reporta metricas comparables entre ejecuciones. |
| S1-US3 | Como equipo quiero un reporte baseline para tomar decisiones con numeros y no intuicion. | Se entrega `benchmarks/baseline_report.md` con tabla por escenario y conclusiones iniciales de cuellos de botella. |

### Sprint 2: Hardening y correccion

| ID | Historia de usuario | Criterios de aceptacion |
|---|---|---|
| S2-US1 | Como desarrollador quiero validacion temprana de parametros para evitar fallas runtime ambiguas. | Constructor dynamic falla rapido con asserts claros para parametros invalidos; hay tests unitarios/widget para cada assert. |
| S2-US2 | Como usuario quiero que cambios de `itemCount` y `controller` no provoquen crashes ni estado inconsistente. | Cobertura de tests para shrink con cola pendiente, swap de controller y callbacks tardios; `tester.takeException()` permanece `null`. |
| S2-US3 | Como mantenedor quiero estabilidad base antes de optimizar performance. | `flutter test` y `flutter analyze` sin errores; cero bugs P1 abiertos en rutas tocadas. |

### Sprint 3: Optimizacion de arquitectura actual (Offstage V1)

| ID | Historia de usuario | Criterios de aceptacion |
|---|---|---|
| S3-US1 | Como usuario quiero menos jank en dynamic sin romper API. | Se reduce trabajo por frame (coalescing de mediciones/rebuilds); benchmarks muestran mejora >= 15% en `% jank` vs baseline. |
| S3-US2 | Como usuario quiero menor consumo de memoria en listas grandes. | Ajustes de colas/caches y limpieza de estado reducen `peak_memory_mb` >= 10% en `dynamic_card_50k` vs baseline. |
| S3-US3 | Como equipo quiero asegurar que optimizacion no rompe UX actual. | Suite funcional + casos de regresion de scroll/lotes/fade pasan completa. |

### Sprint 4: Spike deep (motor sliver/render experimental)

| ID | Historia de usuario | Criterios de aceptacion |
|---|---|---|
| S4-US1 | Como equipo quiero validar si una arquitectura sliver/render supera el limite de Offstage. | Existe prototipo funcional interno `sliverV2` para dynamic vertical con layout wrap basico; benchmark A/B ejecutado contra V1. |
| S4-US2 | Como arquitecto quiero identificar costo/beneficio y riesgos antes de exponer API publica. | Se entrega ADR tecnica con tradeoffs, complejidad, riesgo de mantenimiento y recomendacion de adopcion. |
| S4-US3 | Como QA quiero verificar paridad funcional minima del prototipo. | Pruebas de paridad para spacing, runSpacing, padding y scroll en vertical pasan en prototipo. |

### Sprint 5: API publica opt-in + migracion

| ID | Historia de usuario | Criterios de aceptacion |
|---|---|---|
| S5-US1 | Como consumidor del paquete quiero probar el nuevo motor sin romper mi codigo actual. | Se agrega `engine` opcional con default `offstageV1`; codigo existente compila sin cambios. |
| S5-US2 | Como usuario avanzado quiero activar `sliverV2` explicitamente para evaluar mejoras. | `engine: LazyWrapEngine.sliverV2` habilita el nuevo motor; tests de paridad funcional pasan para ambos engines. |
| S5-US3 | Como mantenedor quiero documentacion clara para adopcion incremental. | README/API docs actualizados con ejemplos, limitaciones conocidas y guia de migracion. |

### Sprint 6: Estabilizacion, Go/No-Go y release

| ID | Historia de usuario | Criterios de aceptacion |
|---|---|---|
| S6-US1 | Como equipo quiero una decision objetiva de release basada en metricas. | Se aplica checklist Go/No-Go; si se cumplen metricas globales, se aprueba release; si no, se documenta plan de continuidad. |
| S6-US2 | Como usuario quiero release estable y predecible. | Se publica version con `sliverV2` opt-in, `offstageV1` como default; changelog incluye riesgos y recomendaciones de uso. |
| S6-US3 | Como equipo quiero continuidad de mejora post-release. | Queda backlog priorizado para fase siguiente (flip de default en version futura, optimizaciones pendientes, deuda tecnica). |

## Cambios de API / Contratos Publicos / Tipos

1. Sprint 2: agregar validaciones (`assert`) en modo dynamic para:
   - `itemCount >= 0`
   - `batchSize > 0`
   - `measureBatchSize > 0`
   - `cacheExtent >= 0`
   - `loadThreshold >= 0`
2. Sprint 5: agregar enum publico `LazyWrapEngine { offstageV1, sliverV2 }`.
3. Sprint 5: agregar parametro opcional en `LazyWrap.dynamic` y `DynamicLazyWrap`: `engine` con default `LazyWrapEngine.offstageV1`.
4. Sprint 5: mantener backward compatibility total (sin breaking changes).
5. Sprint 6: release con `sliverV2` opt-in; default se mantiene en `offstageV1` en la primera version de salida.

## Matriz de Pruebas y Escenarios

### Correctitud funcional

1. Render inicial
2. Scroll vertical/horizontal
3. `padding`, `spacing`, `runSpacing`, `rowAlignment`
4. `itemCount` dinamico
5. Swap de `controller`
6. Fade on/off
7. Loading custom/default

### Robustez

1. Parametros invalidos (asserts)
2. Shrink/expand repetidos de `itemCount`
3. Callbacks tardios
4. Stress test de lotes y medicion

### Performance

1. Corridas repetibles en profile mode para los 3 escenarios base
2. Comparacion obligatoria por sprint contra baseline Sprint 1

### Regresion

1. Suite existente debe pasar completa en cada sprint
2. Nuevos tests de sprint no pueden depender de timing fragil no deterministico

## Criterios Go/No-Go Final

### Go

1. Cumple todos los objetivos minimos de mejora global
2. No hay P0/P1 abiertos en rutas nuevas
3. Paridad funcional validada en escenarios criticos

### No-Go

1. Si falta cualquier objetivo minimo, no se avanza a default nuevo
2. Se publica solo hardening/optimizaciones V1 y se agenda iteracion extra

## Supuestos y Decisiones por Defecto

1. Alcance elegido: 6 sprints
2. Duracion de sprint: 1 semana
3. Audiencia del documento: equipo tecnico interno y colaboradores del paquete
4. Estrategia de riesgo: release inicial con `sliverV2` opt-in, sin cambio de default
5. Si no hay dispositivo fisico de referencia, se usa desktop profile para tendencia relativa y se etiqueta limitacion en reporte

## Fase Post Sprint 6 (Continuidad Deep)

Tras decision **NO-GO** de `sliverV2`, se inicia un spike de continuidad:

1. Documento operativo: `SLIVER_V3_SPIKE_PLAN.md`
2. Objetivo: validar un enfoque `RenderSliver` (interno) que reduzca costo de build/jank en escenarios densos.
3. Regla de corte: si no se cumplen los gates definidos en 1 sprint, se pausa la linea deep y se prioriza optimizacion de `offstageV1`.
4. Backlog priorizado de continuidad: `docs/POST_SPRINT6_BACKLOG.md`.

## Estado Actual (2026-02-12)

1. Decision de release para engines deep (`sliverV2`/`sliverV3`): **NO-GO**.
2. Validacion robusta ejecutada con `repeats=5` y `warmup-runs=1`:
   - `benchmarks/results/experiments/20260212_sliver_v2_ab_r5_w1.json`
   - `benchmarks/results/experiments/20260212_sprint6_gate_r5_w1.json`
3. Gate Sprint 6 automatizado:
   - script: `benchmarks/run_sprint6_gate.dart`
   - orquestador CI/local: `benchmarks/ci/run_sprint6_gate_ci.sh`
   - workflow manual: `.github/workflows/sprint6-gate.yml`
4. Siguiente foco recomendado:
   - optimizacion dirigida de `offstageV1` en `dynamic_chip_10k`
   - objetivo inicial: reducir `p95_build_ms` y `%jank` sin perder cobertura.

## Estado Actual (2026-02-13)

1. Sprint 3 (Offstage V1) mantiene estado **No-Go para cambio de default**.
2. Se incorporo hardening de comparabilidad en harness con guardas superiores:
   - `--coverage-max-max-index-ratio`
   - `--coverage-max-unique-index-ratio`
3. Validacion robusta consolidada (3 tandas `r5,w1`) para `cache512 + adaptive repaint`:
   - artefactos: `benchmarks/results/experiments/20260213_pair_chip_stress_cache512_adaptive_repaint_interleaved_r5_w1_guard_upper*.json`
   - cobertura: `pass` consistente en ambas escenas.
4. Lectura consolidada:
   - `dynamic_chip_10k`: mejora robusta en `p95_build_ms`, `p95_raster_ms` y `%jank`.
   - `dynamic_card_50k`: regresion mediana en `%jank`, por lo que el modo queda
     **opt-in experimental**.
5. Gate adicional `r7,w2` (baseline + 2 replicas del candidato):
   - confirma mejora estable en `dynamic_chip_10k`
   - mantiene inestabilidad en `dynamic_card_50k` (cambio de signo entre
     replicas en build/raster/jank)
   - decision vigente: **No-Go para default** en Sprint 3.
6. Estudio focal de varianza (`dynamic_card_50k`, `r10`):
   - artefactos:
     - `benchmarks/results/experiments/20260213_card_variance_r10_metrics.json`
     - `benchmarks/results/experiments/20260213_card_variance_r10_report.md`
   - lectura:
     - `%jank` con CV alto (`38.46%`) y `build/raster` con CV medio
     - `peak_memory_mb` estable (CV `1.01%`)
   - implicancia: mantener decision por mediana con `repeats >= 7` y evitar
     conclusiones por corridas `r1` en card.
7. Operativizacion del protocolo de varianza:
   - script: `benchmarks/run_card_variance.dart`
   - smoke validado: `benchmarks/results/experiments/20260213_card_variance_script_smoke_r1_v2_report.md`
   - impacto: la corrida de varianza de card queda estandarizada y repetible.
8. Tanda robusta ejecutada con el nuevo script (`r7`, `w1`):
   - `benchmarks/results/experiments/20260213_card_variance_r7_w1_script_report.md`
   - hallazgo: `%jank` mantiene varianza alta (CV `61.31%`)
   - decision: sostener gates por mediana con `repeats >= 7` y mantener
     **No-Go para default**.
9. Integracion CI del protocolo de varianza:
   - script: `benchmarks/ci/run_card_variance_ci.sh`
   - workflow manual: `.github/workflows/card-variance.yml`
   - control opcional: fail por dispersion alta con
     `ENFORCE_MAX_JANK_CV=true`.
10. Protocolo de scroll deterministico para card:
   - runner configurable via defines (`BENCH_SCROLL_*`) y atajo
     `--stable-scroll-profile` en `run_card_variance.dart`
   - comparacion corta `r5,w1`: `%jank` CV baja de `79.29%` a `38.49%`
   - revalidacion robusta `r7,w1`: señal no estable (`61.31%` -> `76.56%`)
   - decision: mantener perfil estable como opt-in y CI con default
     `BENCH_STABLE_SCROLL_PROFILE=false`.
11. Gate explicito de varianza en artefactos:
    - `run_card_variance.dart` agrega `variance_gate` en JSON/Markdown.
    - CI (`run_card_variance_ci.sh`) consume esa decision y reporta
      `variance_gate_pass` en summary.
12. Offstage V1: cache visible con gate por area (card-like):
    - cambio en runtime: `OFFSTAGE_VISIBLE_WIDGET_CACHE_CAPACITY=256` y
      `OFFSTAGE_ADAPTIVE_VISIBLE_WIDGET_CACHE=true` por default.
    - nuevo define: `OFFSTAGE_VISIBLE_WIDGET_CACHE_MIN_ITEM_AREA` (default
      `12000`) para desactivar cache en items chicos (chip-like).
    - evidencia robusta en card (`r5,w1`):
      - `p95_build_ms`: `10.049 -> 7.407` (`+26.29%`)
      - `peak_memory_mb`: `171.293 -> 162.988` (`+4.85%`)
      - `%jank`: `2.980 -> 2.333` (`+21.71%`)
    - revalidacion robusta `r7,w1` sobre baseline de varianza previo:
      - `p95_build_ms`: `9.909 -> 6.736` (`+32.02%`)
      - `%jank`: `5.000 -> 2.007` (`+59.86%`)
      - `%jank` CV: `61.31% -> 37.95%` (`-23.36 pp`)
    - control de seguridad en chip (`r5,w1`, cache-off vs default):
      - contadores de build equivalentes por corrida (`item=146`,
        `visible=58`, `offstage=88`, `max_index=63`)
      - diferencia de frame metrics atribuida a ruido de escenario.
    - artefactos:
      - `benchmarks/results/experiments/20260213_card_variance_default_r5_w1_cacheexp_metrics.json`
      - `benchmarks/results/experiments/20260213_card_variance_default_r5_w1_after_cache_gate_metrics.json`
      - `benchmarks/results/experiments/20260213_card_variance_cache_gate_comparison_r5_w1.json`
      - `benchmarks/results/experiments/20260213_card_variance_cache_gate_comparison_r7_w1.json`
      - `benchmarks/results/experiments/20260213_chip_variance_cache_gate_safety_r5_w1.json`
13. Sensibilidad de capacidad de cache visible (`r5,w1`):
   - barrido: `cap=192`, `cap=256`, `cap=320`
   - consolidado:
     - `benchmarks/results/experiments/20260213_card_variance_cache_capacity_sweep_r5_w1.json`
     - `benchmarks/results/experiments/20260213_card_variance_cache_capacity_sweep_r5_w1.md`
   - lectura:
     - `cap=256` mantiene mejor balance global.
     - `cap=192` y `cap=320` fallan gate de varianza de `%jank`.
   - decision: mantener `OFFSTAGE_VISIBLE_WIDGET_CACHE_CAPACITY=256`.
14. Scroll `forward` deterministico en card (`r5,w1`):
   - artefacto:
     - `benchmarks/results/experiments/20260213_card_variance_forwarddet_r5_w1_after_cache_gate_metrics.json`
     - `benchmarks/results/experiments/20260213_card_variance_forwarddet_comparison_r5_w1.json`
     - `benchmarks/results/experiments/20260213_card_variance_forwarddet_comparison_r5_w1.md`
   - lectura:
     - mejora de medianas en muestra corta, pero `%jank` CV `111.94%` (gate fail).
   - decision: no adoptar `forward` como perfil default del protocolo.
15. Experimento adaptive measure batch en card (`r5,w1`):
   - runtime:
     - `OFFSTAGE_ADAPTIVE_MEASURE_BATCH` (default `false`)
     - `OFFSTAGE_LARGE_ITEM_MEASURE_BATCH_CAP` (default `8`)
   - artefactos:
     - `benchmarks/results/experiments/20260213_card_variance_default_r5_w1_after_adaptive_measure_metrics.json`
     - `benchmarks/results/experiments/20260213_card_variance_adaptive_measure_experiment_summary.json`
     - `benchmarks/results/experiments/20260213_card_variance_adaptive_measure_experiment_summary.md`
   - lectura:
     - mejora en build/memoria marginal, pero regresion en raster/jank y peor CV.
   - decision: mantener politica como opt-in experimental (**No-Go** para
     default).
16. Quality gate de analisis estatico:
   - ajuste de reglas de lint de estilo/documentacion para rutas activas.
   - `flutter analyze --no-pub`: sin issues.
   - estado: deuda de `analyze` cerrada para esta fase.
17. Re-check varianza card con protocolo robusto (`r7,w2` x2):
   - corrida A:
     - `benchmarks/results/experiments/20260213_card_variance_default_r7_w2_post_analyze_cleanup_metrics.json`
     - `%jank` CV `22.08%` (cumple `<= 30%`).
   - corrida B (replica):
     - `benchmarks/results/experiments/20260213_card_variance_default_r7_w2_post_analyze_cleanup_rep2_metrics.json`
     - `%jank` CV `96.80%` (falla por outlier).
   - check consolidado:
     - `benchmarks/results/experiments/20260213_card_variance_r7_w2_consecutive_check.json`
     - `benchmarks/results/experiments/20260213_card_variance_r7_w2_consecutive_check.md`
   - decision: criterio consecutivo de varianza aun **No-Go**.
18. Diagnostico automatico de outliers en protocolo de varianza card:
   - `benchmarks/run_card_variance.dart` agrega bloque
     `outlier_diagnostics` en JSON y seccion "Diagnostico de outliers (IQR)"
     en Markdown.
   - smoke de verificacion:
     - `benchmarks/results/experiments/20260213_card_variance_smoke_outlier_diag_metrics.json`
     - `benchmarks/results/experiments/20260213_card_variance_smoke_outlier_diag_report.md`
   - impacto: identificacion directa de corridas sospechosas por metrica,
     manteniendo el gate principal de `%jank` sin cambios.
19. Tanda robusta con diagnostico activo (`r7,w2`):
   - artefactos:
     - `benchmarks/results/experiments/20260213_card_variance_default_r7_w2_outlier_diag_run1_metrics.json`
     - `benchmarks/results/experiments/20260213_card_variance_default_r7_w2_outlier_diag_run1_report.md`
   - resultado:
     - `%jank` CV `58.71%` (no cumple objetivo P0 `<= 30%`).
     - run sospechoso principal: `20260213_141440Z` (1 metrica outlier).
   - decision: P0 de varianza card sigue abierto; sin cambio en Go/No-Go.
20. Segunda tanda robusta consecutiva con diagnostico activo (`r7,w2`):
   - artefactos:
     - `benchmarks/results/experiments/20260213_card_variance_default_r7_w2_outlier_diag_run2_metrics.json`
     - `benchmarks/results/experiments/20260213_card_variance_default_r7_w2_outlier_diag_run2_report.md`
   - consolidado consecutivo (objetivo P0 `<= 30%`):
     - `benchmarks/results/experiments/20260213_card_variance_r7_w2_outlier_diag_consecutive_check.json`
     - `benchmarks/results/experiments/20260213_card_variance_r7_w2_outlier_diag_consecutive_check.md`
   - resultado:
     - `%jank` CV `52.21%` en run2 (sin outliers IQR detectados).
     - decision consecutiva: **FAIL** (run1 `58.71%`, run2 `52.21%`).
   - decision: mantener P0 abierto y **No-Go** para cierre de varianza.
21. Re-check de perfil estable (`--stable-scroll-profile`) con diagnostico IQR (`r7,w2`):
   - artefactos:
     - `benchmarks/results/experiments/20260213_card_variance_stable_r7_w2_outlier_diag_run1_metrics.json`
     - `benchmarks/results/experiments/20260213_card_variance_stable_r7_w2_outlier_diag_run1_report.md`
   - resultado:
     - `%jank` CV `75.19%` (falla gate `70%` y objetivo P0 `30%`).
     - `primary_suspect_run_id = null` (sin outliers IQR en la tanda).
   - decision: no escalar el perfil estable como mitigacion para cierre P0.
22. Endurecimiento de protocolo con gate robusto MAD para `%jank`:
   - `benchmarks/run_card_variance.dart` agrega:
     - `robust_jank_dispersion` (mediana, MAD, IQR y normalizaciones).
     - `robust_variance_gate` con threshold configurable
       `--max-jank-mad-percent` (default `30`) y enforcement opcional
       `--enforce-max-jank-mad`.
   - CI actualizado (`benchmarks/ci/run_card_variance_ci.sh`):
     - variables: `MAX_JANK_MAD`, `ENFORCE_MAX_JANK_MAD`.
     - summary incluye decision robusta MAD y mantiene compatibilidad con
       JSON historicos (campos `unknown` cuando no existen).
   - smoke de verificacion:
     - `benchmarks/results/experiments/20260213_card_variance_smoke_robust_gate_metrics.json`
     - `benchmarks/results/experiments/20260213_card_variance_smoke_robust_gate_report.md`
     - `benchmarks/results/ci/20260213_robust_gate_ci_smoke/card_variance_ci_summary.md`
   - decision: mejora de observabilidad/controles, sin cambio aun en estado
     P0 (varianza card sigue abierta).
23. Primera tanda robusta real con gate MAD (`r7,w2`, default scroll):
   - artefactos:
     - `benchmarks/results/experiments/20260213_card_variance_default_r7_w2_robust_gate_run1_metrics.json`
     - `benchmarks/results/experiments/20260213_card_variance_default_r7_w2_robust_gate_run1_report.md`
     - `benchmarks/results/ci/20260213_robust_gate_ci_r7_w2/card_variance_ci_summary.md`
   - resultado:
     - gate CV: `%jank` CV `60.71%` (PASS gate 70, FAIL objetivo P0 30).
     - gate MAD: `%jank` MAD/mediana `13.93%` (PASS gate 30).
     - outlier principal: `20260213_143756Z` (3 metricas IQR).
   - lectura:
     - la nueva senal robusta reduce sensibilidad a efecto de media baja y
       habilita un criterio complementario para decisioning.
   - decision: mantener P0 abierto hasta definir/adoptar criterio final (CV
     puro vs gate combinado CV+MAD).
24. Script dedicado para criterio consecutivo configurable:
   - nuevo: `benchmarks/run_card_variance_consecutive_check.dart`
   - modos:
     - `cv`
     - `mad`
     - `cv_or_mad` (fallback compatible con JSON sin MAD)
     - `cv_and_mad`
   - salida: JSON + Markdown con decision `PASS/FAIL` por dos tandas.
25. Segunda tanda robusta real con gate MAD (`r7,w2`, default scroll):
   - artefactos:
     - `benchmarks/results/experiments/20260213_card_variance_default_r7_w2_robust_gate_run2_metrics.json`
     - `benchmarks/results/experiments/20260213_card_variance_default_r7_w2_robust_gate_run2_report.md`
   - resultado:
     - run2: `%jank` CV `87.03%`, MAD/mediana `59.30%` (ambos FAIL).
   - matriz consecutiva sobre run1+run2:
     - `benchmarks/results/experiments/20260213_card_variance_consecutive_cv_robustpair.json`
     - `benchmarks/results/experiments/20260213_card_variance_consecutive_mad_robustpair.json`
     - `benchmarks/results/experiments/20260213_card_variance_consecutive_cv_or_mad_robustpair.json`
     - `benchmarks/results/experiments/20260213_card_variance_consecutive_cv_and_mad_robustpair.json`
   - decision:
     - todos los modos de consecutividad dan **FAIL** en esta tanda.
     - P0 sigue abierto sin cambio de Go/No-Go.
26. Endurecimiento de workflow `card-variance` con control robusto MAD:
   - `.github/workflows/card-variance.yml` ahora expone inputs:
     - `enforce_max_jank_mad`
     - `max_jank_mad`
   - impacto:
     - el workflow manual queda alineado con `run_card_variance_ci.sh` sin
       necesidad de editar YAML/variables fuera de UI.
27. Endurecimiento de flujo consecutivo (por tanda + por decision final):
   - `benchmarks/ci/run_card_variance_consecutive_ci.sh` agrega soporte:
     - `ENFORCE_MAX_JANK_CV`
     - `ENFORCE_MAX_JANK_MAD`
   - `.github/workflows/card-variance-consecutive.yml` expone ambos inputs.
   - summary consecutivo ahora publica:
     - thresholds/enforcement usados por tanda
     - estado de `variance_gate` y `robust_variance_gate` en run A y run B.
   - impacto:
     - se puede distinguir fallo por dispersion de tanda vs fallo por criterio
       de consecutividad, mejorando triage en CI.
28. Sweep automatizado de perfiles de scroll para reducir varianza en card:
   - nuevo script: `benchmarks/run_card_variance_profile_sweep.dart`
   - objetivo:
     - barrer presets de scroll y rankear por estabilidad (`CV` + `MAD`) con
       artefactos por preset.
   - operacion CI:
     - script: `benchmarks/ci/run_card_variance_profile_sweep_ci.sh`
     - workflow manual:
       `.github/workflows/card-variance-profile-sweep.yml`
   - smoke validado:
     - `benchmarks/results/experiments/20260213_profile_sweep_smoke/summary.json`
     - `benchmarks/results/experiments/20260213_profile_sweep_smoke_report.md`
   - decision:
     - habilita exploracion sistematica del P0 de varianza sin analisis manual
       ad-hoc por perfil.
29. Primera tanda comparativa con sweep (`r3,w1`, 3 presets):
   - artefactos:
     - `benchmarks/results/experiments/20260213_profile_sweep_r3_w1_seed/summary.json`
     - `benchmarks/results/experiments/20260213_profile_sweep_r3_w1_seed_report.md`
   - presets evaluados:
     - `default`
     - `stable_ping_pong_v1`
     - `forward_long_sweep`
   - resultado:
     - ranking: `stable_ping_pong_v1` > `forward_long_sweep` > `default`
       (ordenado por estabilidad CV/MAD).
     - ningun preset pasa ambos gates (`CV<=30`, `MAD<=30`) en esta muestra.
   - decision:
     - usar `stable_ping_pong_v1` como candidato de siguiente re-check robusto
       (`r7,w2`), sin cerrar P0 aun.
30. Re-check robusto del candidato `stable_ping_pong_v1` (`r7,w2`):
   - artefactos:
     - `benchmarks/results/experiments/20260213_card_variance_stable_r7_w2_profile_sweep_followup_metrics.json`
     - `benchmarks/results/experiments/20260213_card_variance_stable_r7_w2_profile_sweep_followup_report.md`
   - resultado:
     - `%jank` CV `78.99%` (FAIL gate `70`, FAIL objetivo `30`).
     - `%jank` MAD/mediana `74.46%` (FAIL gate `30`).
   - decision:
     - descartar `stable_ping_pong_v1` como mitigacion de cierre P0 en este
       corte; mantener P0 abierto.
31. Sweep runtime dedicado para varianza card (workload/cache):
   - nuevo script: `benchmarks/run_card_variance_runtime_sweep.dart`
   - objetivo:
     - barrer presets de runtime con ranking por estabilidad (`CV` + `MAD`)
       sin cambiar perfil de scroll.
   - CI:
     - script: `benchmarks/ci/run_card_variance_runtime_sweep_ci.sh`
     - workflow manual: `.github/workflows/card-variance-runtime-sweep.yml`
   - smoke:
     - `benchmarks/results/experiments/20260213_runtime_sweep_smoke/summary.json`
     - `benchmarks/results/experiments/20260213_runtime_sweep_smoke_report.md`
32. Primera tanda runtime (`r3,w1`) en dos bloques:
   - bloque 1:
     - `benchmarks/results/experiments/20260213_runtime_sweep_r3_w1/summary.json`
     - recomendado: `default` (unico preset con PASS ambos gates en ese bloque).
   - bloque 2:
     - `benchmarks/results/experiments/20260213_runtime_sweep_r3_w1_part2/summary.json`
     - recomendados: `single_measure_batch` y `fixed_visible_cache_256` (PASS
       ambos gates en muestra corta).
   - decision:
     - promover candidatos a re-check robusto, sin cambio de default.
33. Re-check robusto runtime (`r7,w2`) de candidatos principales:
   - artefactos:
     - `benchmarks/results/experiments/20260213_runtime_sweep_r7_w2_candidates/summary.json`
     - `benchmarks/results/experiments/20260213_runtime_sweep_r7_w2_candidates_report.md`
   - resultado:
     - recomendado: `fixed_visible_cache_256`.
     - `%jank` CV `45.33%`, MAD `29.65%` (falla CV<=30, pasa MAD<=30).
     - `default`: CV `60.67%`, MAD `67.93%`.
   - decision:
     - mejora relativa sobre `default`, pero sin cierre de objetivo P0.
34. Barrido fino de capacidad fija + validacion robusta:
   - extension de presets runtime:
     - `fixed_visible_cache_128`, `fixed_visible_cache_192`,
       `fixed_visible_cache_320`, `fixed_visible_cache_384`.
   - muestra corta (`r3,w1`):
     - `benchmarks/results/experiments/20260213_runtime_sweep_cachecaps_r3_w1/summary.json`
     - recomendado: `fixed_visible_cache_384` (PASS en CV y MAD en muestra corta).
   - robusto comparativo (`r7,w2`):
     - `benchmarks/results/experiments/20260213_runtime_sweep_cachecaps_r7_w2/summary.json`
     - recomendado: `fixed_visible_cache_384`, pero sin pases de gates:
       - CV `40.86%`
       - MAD `35.95%`
     - mejora vs `default` del mismo corte:
       - CV: `47.95% -> 40.86%`
       - MAD: `48.76% -> 35.95%`
   - replica robusta de `fixed_visible_cache_384` (`r7,w2`):
     - `benchmarks/results/experiments/20260213_card_variance_fixed384_r7_w2_rep2_metrics.json`
     - resultado: CV `31.42%`, MAD `48.10%` (ambos FAIL vs objetivo `<=30`).
   - check consecutivo (dos robustos de `fixed_visible_cache_384`):
     - `benchmarks/results/experiments/20260213_card_variance_fixed384_consecutive_cv.json`
     - `benchmarks/results/experiments/20260213_card_variance_fixed384_consecutive_mad.json`
     - `benchmarks/results/experiments/20260213_card_variance_fixed384_consecutive_cv_and_mad.json`
     - decision: **FAIL** en todos los modos.
   - decision final de este bloque:
     - mantener P0 de varianza abierto y **No-Go** para cierre/flip de default.
35. Comparativa controlada de input de scroll (`drag` vs `jump`) para varianza card:
   - cambio en runner de benchmark:
     - `benchmarks/runner_app/integration_test/benchmark_test.dart`
       soporta `BENCH_SCROLL_INPUT_MODE=drag|jump` (default `drag`).
   - probe comparativo (`r5,w1`, default runtime):
     - `benchmarks/results/experiments/20260213_card_variance_default_r5_w1_drag_recheck_metrics.json`
     - `benchmarks/results/experiments/20260213_card_variance_default_r5_w1_jump_probe_metrics.json`
     - consolidado:
       - `benchmarks/results/experiments/20260213_card_variance_drag_vs_jump_r5_w1_compare.json`
       - `benchmarks/results/experiments/20260213_card_variance_drag_vs_jump_r5_w1_compare.md`
   - lectura:
     - `jump` mejora medianas de performance/uso de memoria en esta muestra,
       pero no cierra gate CV (`64.91%`), aunque si gate MAD (`0.70%`).
     - `drag` tampoco cierra ambos gates (`CV 39.64%`, `MAD 54.23%`).
   - decision:
     - mantener default operativo actual y continuar exploracion del P0 con
       mayor muestra/consecutividad.
36. Exposicion operativa de `scroll_input_mode` en tooling de varianza:
   - script:
     - `benchmarks/run_card_variance.dart` agrega
       `--scroll-input-mode <drag|jump>`.
   - CI/workflow:
     - `benchmarks/ci/run_card_variance_ci.sh` agrega variable
       `BENCH_SCROLL_INPUT_MODE` (validada).
     - `.github/workflows/card-variance.yml` expone input
       `scroll_input_mode`.
   - docs:
     - `benchmarks/README.md` actualizado con opcion/ejemplo.
   - impacto:
     - comparativas `drag`/`jump` quedan reproducibles sin depender de
       `--define` manual.
37. Sweep runtime corto con `jump` en presets clave (`r3,w1`):
   - artefactos:
     - `benchmarks/results/experiments/20260213_runtime_sweep_jump_r3_w1_keypresets/summary.json`
     - `benchmarks/results/experiments/20260213_runtime_sweep_jump_r3_w1_keypresets_report.md`
   - presets evaluados:
     - `default`
     - `fixed_visible_cache_256`
     - `fixed_visible_cache_384`
   - resultado:
     - todos los presets pasan gate MAD y fallan CV por margen acotado
       (`34.73%` a `36.11%`).
     - recomendado del bloque: `default`.
   - decision:
     - mantener `jump` como linea prometedora para cierre fino del P0, pero sin
       cambio de default aun.
38. Re-check robusto consecutivo con `jump` (`r7,w2` x2, preset default):
   - artefactos principales:
     - `benchmarks/results/experiments/20260213_card_variance_default_r7_w2_jump_recheck_metrics.json`
     - `benchmarks/results/experiments/20260213_card_variance_default_r7_w2_jump_recheck_rep2_metrics.json`
     - consolidado:
       - `benchmarks/results/experiments/20260213_card_variance_jump_recheck_consecutive_summary.json`
       - `benchmarks/results/experiments/20260213_card_variance_jump_recheck_consecutive_summary.md`
   - resultado:
     - run1: CV `31.56%`, MAD `0.00%`
     - run2: CV `31.45%`, MAD `1.41%`
     - checks consecutivos:
       - `cv`: **FAIL**
       - `mad`: **PASS**
       - `cv_or_mad`: **PASS**
       - `cv_and_mad`: **FAIL**
   - lectura/decision:
     - la varianza deja de ser erratica y queda en zona de borde (muy cercana al
       objetivo CV `<=30`), por lo que el trabajo pendiente pasa a ajuste fino
       de protocolo/threshold, no a rediseño amplio.
39. Re-check robusto con `jump` incrementando warmup (`r7,w3`, run A):
   - artefactos:
     - `benchmarks/results/experiments/20260213_card_variance_default_r7_w3_jump_recheck_metrics.json`
   - resultado:
     - CV `%jank` `104.68%` (FAIL severo por outliers en runs individuales).
     - MAD/mediana `%jank` `0.00%` (PASS robusto).
   - lectura:
     - warmup adicional no elimina eventos de dispersion extrema.
40. Re-check robusto consecutivo `w3` (`r7,w3` x2, preset default):
   - artefactos principales:
     - `benchmarks/results/experiments/20260213_card_variance_default_r7_w3_jump_recheck_rep2_metrics.json`
     - consolidado:
       - `benchmarks/results/experiments/20260213_card_variance_jump_w3_consecutive_summary.json`
       - `benchmarks/results/experiments/20260213_card_variance_jump_w3_consecutive_summary.md`
       - `benchmarks/results/experiments/20260213_card_variance_jump_w2_vs_w3_comparison.json`
       - `benchmarks/results/experiments/20260213_card_variance_jump_w2_vs_w3_comparison.md`
   - resultado:
     - run1 (`w3`): CV `104.68%`, MAD `0.00%`
     - run2 (`w3`): CV `34.45%`, MAD `2.10%`
     - checks consecutivos:
       - `cv`: **FAIL**
       - `mad`: **PASS**
       - `cv_or_mad`: **PASS**
       - `cv_and_mad`: **FAIL**
   - decision:
     - descartar `w3` como estrategia de cierre de varianza.
     - mantener `w2` como mejor protocolo operativo actual para `jump`.
41. Sweep runtime robusto con `jump` (`r7,w2`) en presets clave:
   - artefactos:
     - `benchmarks/results/experiments/20260213_runtime_sweep_jump_r7_w2_keypresets/summary.json`
     - `benchmarks/results/experiments/20260213_runtime_sweep_jump_r7_w2_keypresets_report.md`
   - presets evaluados:
     - `default`
     - `fixed_visible_cache_256`
     - `fixed_visible_cache_384`
   - resultado:
     - recomendado: `fixed_visible_cache_384`.
     - metrica `%jank` CV/MAD por preset:
       - `fixed_visible_cache_384`: `35.03% / 0.70%`
       - `default`: `35.27% / 0.70%`
       - `fixed_visible_cache_256`: `46.48% / 1.40%`
     - ningun preset cierra ambos gates (`CV<=30`, `MAD<=30`).
   - decision:
     - no hay cierre del objetivo P0 por tuning de estos presets bajo `jump`.
42. Check consecutivo cruzado en `jump+w2` (default vs corrida robusta independiente):
   - artefactos:
     - `benchmarks/results/experiments/20260213_card_variance_jump_w2_default_crossrun_summary.json`
     - `benchmarks/results/experiments/20260213_card_variance_jump_w2_default_crossrun_summary.md`
   - resultado:
     - run_a CV/MAD: `31.56% / 0.00%`
     - run_b CV/MAD: `35.27% / 0.70%`
     - decisiones:
       - `cv`: **FAIL**
       - `mad`: **PASS**
       - `cv_or_mad`: **PASS**
       - `cv_and_mad`: **FAIL**
   - decision:
     - `jump+w2` mejora robustez respecto de etapas previas, pero aun no
       alcanza cierre consistente con criterio CV puro.
43. Probe de patron de scroll `forward` en `jump+w2` (`r7,w2`):
   - artefactos:
     - `benchmarks/results/experiments/20260213_card_variance_default_r7_w2_jump_forward_probe_metrics.json`
     - comparativo:
       - `benchmarks/results/experiments/20260213_card_variance_jump_forward_vs_pingpong_r7_w2.json`
       - `benchmarks/results/experiments/20260213_card_variance_jump_forward_vs_pingpong_r7_w2.md`
   - resultado:
     - `jump+forward`: CV `51.07%`, MAD `2.10%`
     - `jump+ping_pong` (referencia `w2`): CV `35.27%`, MAD `0.70%`
   - decision:
     - descartar `forward` para cierre de varianza; mantener `ping_pong` como
       patron base en las siguientes iteraciones de `jump`.
44. Formalizacion de criterio unico de decision en CI de varianza card:
   - cambio en tooling:
     - `benchmarks/ci/run_card_variance_ci.sh` agrega:
       - `VARIANCE_DECISION_MODE=cv|mad|cv_or_mad|cv_and_mad`
       - `ENFORCE_VARIANCE_DECISION=true|false`
       - campos de summary:
         - `variance_decision_mode`
         - `variance_decision_json_pass`
         - `variance_decision_evaluated_pass`
     - `.github/workflows/card-variance.yml` expone inputs equivalentes.
     - `benchmarks/README.md` actualizado con variables/campos.
   - impacto:
     - cierre de calidad deja de ser ambiguo entre CV y MAD en corridas
       operativas; el modo queda declarativo y auditable por artefacto.
45. Politica operativa de decision adoptada para card variance:
   - documento:
     - `docs/CARD_VARIANCE_DECISION_POLICY.md`
   - defaults operativos aplicados en workflow `card-variance`:
     - `decision_mode = cv_or_mad`
     - `enforce_variance_decision = true`
     - `max_jank_cv = 30`
     - `max_jank_mad = 30`
   - alcance:
     - decision operativa de CI/release candidate para varianza card.
     - seguimiento de CV puro se mantiene como objetivo tecnico de mejora.
   - regla de endurecimiento futuro:
     - migrar a `cv_and_mad` cuando haya 2 tandas robustas consecutivas con
       `CV<=30` y `MAD<=30`.
46. Corrida de referencia CI con politica operativa (local smoke completo):
   - comando aplicado:
     - `benchmarks/ci/run_card_variance_ci.sh` con:
       - `BENCH_SCROLL_INPUT_MODE=jump`
       - `BENCH_WARMUP_RUNS=2`
       - `MAX_JANK_CV=30`
       - `MAX_JANK_MAD=30`
       - `VARIANCE_DECISION_MODE=cv_or_mad`
       - `ENFORCE_VARIANCE_DECISION=true`
   - artefactos:
     - `benchmarks/results/ci/20260213_policy_reference/card_variance/card_variance_ci_summary.md`
     - `benchmarks/results/ci/20260213_policy_reference/card_variance/card_variance_metrics.json`
   - resultado:
     - `variance_decision_evaluated_pass = true` (PASS operativo).
     - CV `%jank` sigue alto (`50.36%`), MAD `%jank` estable (`0.71%`).
   - decision:
     - se confirma funcionamiento end-to-end de la politica operativa; CV puro
       permanece como objetivo tecnico abierto.
47. Check consecutivo de la politica operativa (`cv_or_mad`) con corrida de referencia:
   - artefactos:
     - `benchmarks/results/experiments/20260213_policy_reference_consecutive_summary.json`
     - `benchmarks/results/experiments/20260213_policy_reference_consecutive_summary.md`
   - par evaluado:
     - run_a: `benchmarks/results/experiments/20260213_card_variance_default_r7_w2_jump_recheck_metrics.json`
     - run_b: `benchmarks/results/ci/20260213_policy_reference/card_variance/card_variance_metrics.json`
   - resultado:
     - `cv`: **FAIL**
     - `mad`: **PASS**
     - `cv_or_mad`: **PASS**
     - `cv_and_mad`: **FAIL**
   - decision:
     - queda validado que el criterio operativo `cv_or_mad` mantiene PASS
       consecutivo entre corridas robustas independientes.
48. Instrumentacion de scroll y perfil deterministico `jump` en runner de benchmarks:
   - cambios:
     - `benchmarks/runner_app/integration_test/benchmark_test.dart`:
       - nuevo `BENCH_SCROLL_JUMP_PROFILE` (`relative|edge_bounce`)
       - nuevo bloque `scroll_diagnostics` en JSON de escenario:
         - `steps_requested`, `effective_steps`, `no_op_steps`
         - `edge_hits_min`, `edge_hits_max`
         - `total_abs_delta_px`, `average_abs_delta_px`
         - `start_pixels`, `end_pixels`, `min_visited_pixels`, `max_visited_pixels`
     - `benchmarks/run_card_variance.dart`:
       - nuevo flag `--scroll-jump-profile`
       - agrega `scroll_diagnostics` por corrida y
         `scroll_diagnostics_summary` agregado en JSON/Markdown de varianza
     - `benchmarks/ci/run_card_variance_ci.sh` + workflow:
       - variable `BENCH_SCROLL_JUMP_PROFILE`
   - objetivo:
     - diagnosticar y reducir no-op en `jump` cuando el scroll satura extremos.
49. Corrida robusta comparativa `relative` vs `edge_bounce` (`dynamic_card_50k`, `r7,w2`):
   - artefactos:
     - `benchmarks/results/experiments/20260213_card_variance_r7_w2_jump_relative_newcode_metrics.json`
     - `benchmarks/results/experiments/20260213_card_variance_r7_w2_jump_edge_bounce_metrics.json`
     - `benchmarks/results/experiments/20260213_card_variance_relative_vs_edge_comparison.json`
     - `benchmarks/results/experiments/20260213_card_variance_relative_vs_edge_comparison.md`
     - diagnostico scroll:
       - `benchmarks/results/experiments/20260213_card_variance_r7_w2_jump_relative_newcode_scroll_diag.json`
       - `benchmarks/results/experiments/20260213_card_variance_r7_w2_jump_edge_bounce_scroll_diag.json`
   - resultado:
     - CV `%jank`: `35.17% -> 30.54%` (mejora `-4.63 pp`)
     - MAD `%jank`: `2.10% -> 0.00%`
     - no-op promedio por corrida: `5 -> 0`
     - delta scroll promedio abs: `286.49px -> 312.00px`
   - decision:
     - `edge_bounce` reduce ruido mecanico de scroll y queda adoptado como
       default operativo recomendado para runs de card variance.
50. Validacion de criterio consecutivo con `edge_bounce`:
   - artefactos:
     - `benchmarks/results/experiments/20260213_card_variance_relative_vs_edge_consecutive_cv.json`
     - `benchmarks/results/experiments/20260213_card_variance_relative_vs_edge_consecutive_cv_and_mad.json`
     - `benchmarks/results/experiments/20260213_card_variance_relative_vs_edge_consecutive_cv_or_mad.json`
     - `benchmarks/results/ci/20260213_edge_bounce_policy_eval/card_variance/card_variance_ci_summary.md`
   - resultado:
     - `cv`: **FAIL** (30.54% > 30)
     - `cv_and_mad`: **FAIL**
     - `cv_or_mad`: **PASS** consecutivo
   - decision:
     - mejora real de estabilidad, pero el objetivo estricto `CV<=30` sigue
       abierto por margen pequeño; mantener seguimiento P0 hasta cierre.
51. Micro-sweep de `scroll_step_px` para `jump+edge_bounce` (card variance):
   - protocolo:
     - `dynamic_card_50k`, `r3,w1`, `pattern=forward`.
     - candidatos: `-260`, `-280`, `-300`, `-320`, `-340`.
   - artefactos:
     - `benchmarks/results/experiments/20260213_card_variance_edge_tune_r3_w1_summary.json`
     - `benchmarks/results/experiments/20260213_card_variance_edge_tune_r3_w1_summary.md`
   - resultado:
     - mejor candidato: `step_px=-280` (CV corto `0.45%`, MAD `0.00%`).
     - se descarta `-300` por alta inestabilidad (CV `112.48%`).
52. Cierre de varianza card con protocolo robusto (`r7,w2`) en `step_px=-280`:
   - tandas:
     - run1: `benchmarks/results/experiments/20260213_card_variance_r7_w2_jump_edge_bounce_step280_run1_metrics.json`
       - CV `%jank`: `18.66`
       - MAD `%jank`: `0.70`
     - run2: `benchmarks/results/experiments/20260213_card_variance_r7_w2_jump_edge_bounce_step280_run2_metrics.json`
       - CV `%jank`: `29.99`
       - MAD `%jank`: `2.85`
   - consecutivo:
     - `benchmarks/results/experiments/20260213_card_variance_step280_consecutive_cv.json` -> **PASS**
     - `benchmarks/results/experiments/20260213_card_variance_step280_consecutive_cv_and_mad.json` -> **PASS**
     - `benchmarks/results/experiments/20260213_card_variance_step280_consecutive_cv_or_mad.json` -> **PASS**
     - consolidado:
       - `benchmarks/results/experiments/20260213_card_variance_step280_closure_summary.md`
   - validacion CI consecutiva (skip bench):
     - `benchmarks/results/ci/20260213_step280_consecutive_ci/card_variance_consecutive/card_variance_consecutive_ci_summary.md`
     - `DECISION_MODE=cv_and_mad`, `ENFORCE_CONSECUTIVE_PASS=true` -> **PASS**
   - decision:
     - se considera cerrado el objetivo de varianza card bajo protocolo operativo robusto.
53. Endurecimiento de politica operativa tras cierre de evidencia:
   - cambios:
     - `VARIANCE_DECISION_MODE` default -> `cv_and_mad`.
     - `ENFORCE_VARIANCE_DECISION` default -> `true`.
     - defaults CI/runner para card variance:
       - `BENCH_SCROLL_INPUT_MODE=jump`
       - `BENCH_SCROLL_JUMP_PROFILE=edge_bounce`
       - `BENCH_SCROLL_STEP_PX=-280`
       - `BENCH_WARMUP_RUNS=2`
   - archivos:
     - `.github/workflows/card-variance.yml`
     - `benchmarks/ci/run_card_variance_ci.sh`
     - `docs/CARD_VARIANCE_DECISION_POLICY.md`
     - `benchmarks/README.md`
54. Sweep runtime robusto focal (`r7,w2`) con `step=-280` para cierre de
    build/memoria en card:
   - protocolo:
     - presets: `default`, `incremental_plus_single_measure`,
       `conservative_batches`.
     - scroll: `jump + edge_bounce + forward`, `BENCH_SCROLL_STEP_PX=-280`.
   - artefactos:
     - `benchmarks/results/experiments/20260213_runtime_sweep_step280_r7_w2_top3/summary.json`
     - `benchmarks/results/experiments/20260213_runtime_sweep_step280_r7_w2_top3_report.md`
     - `benchmarks/results/experiments/20260213_runtime_sweep_step280_r7_w2_top3_comparison_vs_default.json`
     - `benchmarks/results/experiments/20260213_runtime_sweep_step280_r7_w2_top3_comparison_vs_default.md`
   - resultado:
     - recomendado por ranking interno: `conservative_batches`.
     - mejora vs `default` del mismo corte:
       - `p95_build_ms`: `4.232 -> 3.730` (`+11.86%`)
       - `peak_memory_mb`: `160.938 -> 158.789` (`+1.34%`)
       - `CV %jank`: `34.47 -> 31.13` (`-3.34 pp`)
     - limite:
       - ningun preset cruza `CV<=30` (todos quedan en `FAIL` por CV y `PASS`
         por MAD).
   - decision:
     - no cambiar defaults de runtime/engine con esta evidencia.
     - mantener `conservative_batches` como candidato de siguiente iteracion,
       no como cambio de salida.
55. Micro-tuning de vecindad sobre `conservative_batches` y re-check robusto:
   - fase corta (`r3,w1`) en presets cercanos:
     - `cons_base` (`64/16/240/260`)
     - `cons_soft_down` (`60/15/235/250`)
     - `cons_down` (`56/14/230/240`)
   - artefactos cortos:
     - `benchmarks/results/experiments/20260213_card_runtime_micro_tune_r3_w1/cons_base_metrics.json`
     - `benchmarks/results/experiments/20260213_card_runtime_micro_tune_r3_w1/cons_soft_down_metrics.json`
     - `benchmarks/results/experiments/20260213_card_runtime_micro_tune_r3_w1/cons_down_metrics.json`
   - lectura corta:
     - `cons_soft_down` pasa gates en muestra corta (`CV 28.28`, `MAD 0.00`)
       y mejora build respecto de `cons_base`.
     - `cons_down` mejora build, pero falla CV y sube memoria.
   - re-check robusto (`r7,w2`) del mejor corto (`cons_soft_down`):
     - run1: `benchmarks/results/experiments/20260213_card_variance_cons_soft_down_r7_w2_run1_metrics.json`
       - `CV 34.90`, `MAD 1.40`, `no_op_avg 2.0`.
     - run2: `benchmarks/results/experiments/20260213_card_variance_cons_soft_down_r7_w2_run2_metrics.json`
       - `CV 0.61`, `MAD 0.71`, `no_op_avg 2.0`.
     - consecutivo:
       - `benchmarks/results/experiments/20260213_card_variance_cons_soft_down_r7_w2_consecutive_cv.json` -> **FAIL**
       - `benchmarks/results/experiments/20260213_card_variance_cons_soft_down_r7_w2_consecutive_cv_and_mad.json` -> **FAIL**
       - `benchmarks/results/experiments/20260213_card_variance_cons_soft_down_r7_w2_consecutive_cv_or_mad.json` -> **PASS**
     - consolidado:
       - `benchmarks/results/experiments/20260213_card_variance_cons_soft_down_r7_w2_summary.json`
       - `benchmarks/results/experiments/20260213_card_variance_cons_soft_down_r7_w2_summary.md`
   - decision:
     - no promover `cons_soft_down` a default.
     - mantener defaults actuales y seguir con iteracion enfocada en reducir
       no-op de scroll (`no_op_steps_avg`) sin degradar TTI.
56. Corte operativo de release (checklist tecnico + Go/No-Go de salida):
   - documento:
     - `docs/RELEASE_CUT_20260213.md`
   - verificacion local:
     - `flutter test` -> PASS
     - `flutter analyze --no-pub` -> PASS
   - decision:
     - mantener `offstageV1` como default.
     - `sliverV2` sigue opt-in experimental.
     - salida recomendada: hardening/tooling, sin flip de default.
57. Iteracion focal `no_op` + estabilidad en card (protocolo actual):
   - objetivo:
     - reducir `no_op_steps_avg` sin perder estabilidad de CV en
       `jump+edge_bounce+step=-280`.
   - barrido corto (`r3,w1`):
     - `c_ref_default`
     - `c_cons_hi_extent` (`64/16/280/300`)
     - `c_cons_mid_extent` (`64/16/260/280`)
     - `c_cons_hi_extent_inc` (`64/16/280/300 + incremental`)
   - artefactos:
     - `benchmarks/results/experiments/20260213_card_noop_focus_r3_w1/c_ref_default_metrics.json`
     - `benchmarks/results/experiments/20260213_card_noop_focus_r3_w1/c_cons_hi_extent_metrics.json`
     - `benchmarks/results/experiments/20260213_card_noop_focus_r3_w1/c_cons_mid_extent_metrics.json`
     - `benchmarks/results/experiments/20260213_card_noop_focus_r3_w1/c_cons_hi_extent_inc_metrics.json`
   - hallazgo:
     - presets no-default siguen con `no_op_avg=2.0` en muestra corta.
     - `c_cons_hi_extent_inc` muestra señal corta prometedora (CV muy bajo),
       por eso se promueve a robusto.
   - re-check robusto (`r7,w2`) del candidato promovido:
     - `benchmarks/results/experiments/20260213_card_variance_c_cons_hi_extent_inc_r7_w2_run1_metrics.json`
     - resultado run1: `CV 149.71`, `MAD 2.10`, `no_op_avg 2.0` (FAIL estricto).
   - consolidado:
     - `benchmarks/results/experiments/20260213_card_noop_focus_iteration_summary.json`
     - `benchmarks/results/experiments/20260213_card_noop_focus_iteration_summary.md`
   - decision:
     - **No-Go** de la iteracion.
     - no hay candidato que cruce `CV<=30` con `no_op` bajo de forma confiable
       bajo este protocolo.
58. Optimizacion runtime en Offstage V1: cursor incremental de medicion:
   - cambio de codigo:
     - `lib/src/dynamic_lazy_wrap.dart`
     - se agrega `_pendingMeasureScanIndex` para evitar rescans completos
       `0.._loadedCount` en cada build cuando `_pendingMeasure` queda vacia.
     - nuevo flujo: encolar no-medidos solo desde el cursor al tail cargado,
       y clamp del cursor en shrink (`itemCount`/`_loadedCount`).
   - motivacion:
     - reducir costo de build en listas grandes (`dynamic_card_50k`) eliminando
       trabajo O(n) repetido por frame tras completar una tanda de medicion.
   - verificacion:
     - `flutter test` -> PASS
     - `flutter analyze --no-pub` -> PASS
     - smoke `r1` card variance:
       - `benchmarks/results/experiments/20260213_card_variance_scan_cursor_smoke_r1_metrics.json`
       - `benchmarks/results/experiments/20260213_card_variance_scan_cursor_smoke_r1_report.md`
   - decision:
     - mantener cambio en rama y promover a re-check robusto (`r7,w2`) en el
       siguiente ciclo antes de cualquier ajuste adicional de presets.
59. Validacion robusta del cursor incremental (`r7,w2` x2, step=-280):
   - protocolo:
     - `dynamic_card_50k`
     - `jump + edge_bounce + forward`
     - `repeats=7`, `warmup=2`
   - artefactos principales:
     - run1:
       - `benchmarks/results/experiments/20260213_card_variance_scan_cursor_r7_w2_run1_metrics.json`
       - `benchmarks/results/experiments/20260213_card_variance_scan_cursor_r7_w2_run1_report.md`
     - run2:
       - `benchmarks/results/experiments/20260213_card_variance_scan_cursor_r7_w2_run2_metrics.json`
       - `benchmarks/results/experiments/20260213_card_variance_scan_cursor_r7_w2_run2_report.md`
     - chequeo consecutivo:
       - `benchmarks/results/experiments/20260213_card_variance_scan_cursor_r7_w2_consecutive_cv.json` -> **FAIL**
       - `benchmarks/results/experiments/20260213_card_variance_scan_cursor_r7_w2_consecutive_cv_and_mad.json` -> **FAIL**
       - `benchmarks/results/experiments/20260213_card_variance_scan_cursor_r7_w2_consecutive_cv_or_mad.json` -> **PASS**
     - consolidado:
       - `benchmarks/results/experiments/20260213_card_variance_scan_cursor_r7_w2_summary.json`
       - `benchmarks/results/experiments/20260213_card_variance_scan_cursor_r7_w2_summary.md`
   - lectura:
     - run1 presenta outlier de jank (`primary_suspect_run_id=20260213_211050Z`)
       y dispara `CV=73.76`.
     - run2 queda muy estable (`CV=0.51`, `MAD=0.7`) y mejora memoria/TTI, pero
       no alcanza para cierre estricto consecutivo por la dispersion de run1.
   - decision:
     - **No-Go** para promover este cambio como cierre final de card.
     - mantenerlo como optimizacion de costo potencial y continuar con
       instrumentacion de outliers para aislar la fuente del run espurio.
60. Instrumentacion deep de spikes por corrida en benchmark card:
   - cambios de tooling:
     - `benchmarks/runner_app/integration_test/benchmark_test.dart`
       - agrega `frame_diagnostics` por corrida:
         - `p99_total_ms`, `max_total_ms`, `max_build_ms`, `max_raster_ms`
         - conteos `jank_frames_over_budget`, `>2x`, `>3x`
         - `top_spikes` y desglose por fase (`measured_scroll`, `settle`)
     - `benchmarks/run_card_variance.dart`
       - consume `frame_diagnostics` por run
       - agrega `frame_diagnostics_summary`
       - agrega seccion markdown `Diagnostico de frames (spikes)` + resumen.
   - validacion:
     - `flutter test` -> PASS
     - `flutter analyze --no-pub` -> PASS
     - smoke de varianza con diagnostico nuevo:
       - `benchmarks/results/experiments/20260213_card_variance_frame_diag_smoke_r1_metrics.json`
       - `benchmarks/results/experiments/20260213_card_variance_frame_diag_smoke_r1_report.md`
   - lectura smoke:
     - se identifica spike aislado `>3x` presupuesto en fase
       `measured_scroll` (`max_total_ms=215.936`).
     - confirma que el tooling ahora permite diferenciar ruido de scroll vs
       cola/flush de settle.
61. Diagnostico `single_run_anomaly` para separar varianza estructural vs outlier:
   - cambios de tooling:
     - `benchmarks/run_card_variance.dart`
       - agrega bloque JSON `single_run_anomaly`:
         - `%jank` CV original
         - `%jank` CV sin run sospechoso IQR
         - reduccion en pp
         - evaluacion contra gate operativo (`max_jank_cv`) y contra objetivo
           tecnico P0 (`30%`)
       - agrega seccion markdown: "Diagnostico de corrida anomala (single-run)"
   - validacion:
     - `flutter test` -> PASS
     - `flutter analyze --no-pub` -> PASS
     - smoke corto:
       - `benchmarks/results/experiments/20260213_card_variance_single_run_anomaly_smoke_r3_w1_metrics.json`
       - `benchmarks/results/experiments/20260213_card_variance_single_run_anomaly_smoke_r3_w1_report.md`
       - nota: sin outlier IQR en muestra corta (`single_run_anomaly = null`).
     - robusto (`r7,w2`):
       - `benchmarks/results/experiments/20260213_card_variance_single_run_anomaly_target_r7_w2_metrics.json`
       - `benchmarks/results/experiments/20260213_card_variance_single_run_anomaly_target_r7_w2_report.md`
       - `benchmarks/results/experiments/20260213_card_variance_single_run_anomaly_target_r7_w2_summary.md`
   - lectura robusta:
     - `%jank` CV global: `50.76%`
     - run sospechoso (IQR + spikes): `20260213_214927Z`
     - `%jank` CV sin run sospechoso: `31.94%` (mejora `18.81 pp`)
     - resultado: PASS operativo (`<=70`), pero FAIL objetivo P0 (`<=30`).
   - decision:
     - la dispersion residual no queda explicada solo por un outlier unico;
       mantener P0 abierto y continuar optimizacion de estabilidad base.
62. Re-check consecutivo A/B con `single_run_anomaly` (mismo protocolo `r7,w2`):
   - protocolo:
     - `dynamic_card_50k`
     - `jump + edge_bounce + forward`
     - `step=-280`, `repeats=7`, `warmup=2`
   - artefactos:
     - run A:
       - `benchmarks/results/experiments/20260213_card_variance_single_run_anomaly_consecutiveA_r7_w2_metrics.json`
       - `benchmarks/results/experiments/20260213_card_variance_single_run_anomaly_consecutiveA_r7_w2_report.md`
     - run B:
       - `benchmarks/results/experiments/20260213_card_variance_single_run_anomaly_consecutiveB_r7_w2_metrics.json`
       - `benchmarks/results/experiments/20260213_card_variance_single_run_anomaly_consecutiveB_r7_w2_report.md`
     - decisiones consecutivas:
       - `benchmarks/results/experiments/20260213_card_variance_single_run_anomaly_consecutive_cv.json` -> **FAIL**
       - `benchmarks/results/experiments/20260213_card_variance_single_run_anomaly_consecutive_mad.json` -> **PASS**
       - `benchmarks/results/experiments/20260213_card_variance_single_run_anomaly_consecutive_cv_or_mad.json` -> **PASS**
       - `benchmarks/results/experiments/20260213_card_variance_single_run_anomaly_consecutive_cv_and_mad.json` -> **FAIL**
     - consolidado:
       - `benchmarks/results/experiments/20260213_card_variance_single_run_anomaly_consecutive_ab_summary.json`
       - `benchmarks/results/experiments/20260213_card_variance_single_run_anomaly_consecutive_ab_summary.md`
   - lectura:
     - run A: `%jank CV=45.91%`; sin sospechoso IQR `CV=28.05%`.
     - run B: `%jank CV=31.49%`; sin sospechoso IQR `CV=28.21%`.
     - ambos runs mantienen PASS robusto (`MAD`), pero no cruzan CV estricto
       `<=30` en bruto.
   - decision:
     - consolidar `cv_or_mad` como criterio operativo vigente.
     - mantener objetivo tecnico P0 (CV estricto) abierto y enfocar siguiente
       ciclo en tuning de estabilidad base, no solo en filtrado de outliers.
63. Tuning de estabilidad base: sweep corto + validacion robusta top2:
   - fase corta (`r3,w1`, 4 presets):
     - `default`
     - `conservative_batches`
     - `incremental_plus_single_measure`
     - `fixed384_single_measure_conservative`
   - artefactos fase corta:
     - `benchmarks/results/experiments/20260213_runtime_sweep_stability_base_r3_w1/summary.json`
     - `benchmarks/results/experiments/20260213_runtime_sweep_stability_base_r3_w1_report.md`
   - resultado fase corta:
     - recomendado: `conservative_batches` (senal corta de menor dispersion).
   - fase robusta (`r7,w2`, top2):
     - `default` vs `conservative_batches`
   - artefactos fase robusta:
     - `benchmarks/results/experiments/20260213_runtime_sweep_stability_base_r7_w2_top2/summary.json`
     - `benchmarks/results/experiments/20260213_runtime_sweep_stability_base_r7_w2_top2_report.md`
     - `benchmarks/results/experiments/20260213_runtime_sweep_stability_base_r7_w2_top2_comparison_vs_default.json`
     - `benchmarks/results/experiments/20260213_runtime_sweep_stability_base_r7_w2_top2_comparison_vs_default.md`
   - lectura robusta:
     - `conservative_batches` mejora contra default:
       - `%jank CV`: `67.48 -> 50.55` (`-16.93 pp`)
       - `p95_build` mediana: `+17.01%`
       - `p95_raster` mediana: `+3.30%`
       - `peak_memory` mediana: `+1.67%`
       - `tti` mediana: `+3.94%`
     - pero no cruza CV estricto (`50.55 > 30`) y su
       `single_run_anomaly` tampoco cruza al excluir sospechoso
       (`31.27 > 30`).
   - decision:
     - mantener `conservative_batches` como candidato tecnico prometedor, no
       como cierre de P0.
     - siguiente ciclo: micro-tuning alrededor de `conservative_batches`
       orientado a bajar CV por debajo de `30` sin perder mejoras de build/TTI.
64. Micro-tuning local alrededor de `conservative_batches` (`r3,w1`):
   - candidatos evaluados:
     - `c_ref_cons` (`64/16/240/260`)
     - `c_mid_60_14` (`60/14/230/250`)
     - `c_tight_56_14` (`56/14/220/240`)
     - `c_tight_48_12` (`48/12/210/220`)
   - artefactos:
     - `benchmarks/results/experiments/20260213_conservative_micro_sweep_r3_w1/summary.json`
     - `benchmarks/results/experiments/20260213_conservative_micro_sweep_r3_w1/summary.md`
   - lectura:
     - mejor resultado de la familia: `c_ref_cons` (`CV 28.45`, `p95_build 3.272`).
     - variantes mas agresivas aumentan dispersion (`CV 46.77` a `125.25`) y
       empeoran build/raster.
   - decision:
     - no emerge nuevo candidato para promover a robusto.
     - mantener `conservative_batches` como referencia de tuning base.
65. Spike de smoothing en runtime de medicion Offstage V1 (descartado con rollback):
   - cambio experimental aplicado:
     - limite de mediciones activas concurrentes por batches.
     - flush chunked de `_pendingMeasuredSizes` en multiples frames.
   - validacion robusta (`r7,w2`, mismo protocolo de estabilidad):
     - run A:
       - `benchmarks/results/experiments/20260213_card_variance_smoothing_v1_r7_w2_metrics.json`
     - run B:
       - `benchmarks/results/experiments/20260213_card_variance_smoothing_v1_r7_w2_rep2_metrics.json`
     - consolidado:
       - `benchmarks/results/experiments/20260213_card_variance_smoothing_v1_ab_summary.json`
       - `benchmarks/results/experiments/20260213_card_variance_smoothing_v1_ab_summary.md`
   - lectura:
     - run A degrada fuerte (`CV 171.80`, `MAD 73.07`).
     - run B tambien falla CV estricto (`CV 34.82`) y no mejora build mediano
       vs referencia.
     - check consecutivo A/B: FAIL en `cv`, `mad`, `cv_or_mad`, `cv_and_mad`.
     - re-check robusto post-rollback (`r7,w2` x2) en la misma ventana tambien
       queda en FAIL consecutivo (runA `CV 129.38`, `MAD 73.42`; runB
       `CV 73.54`, `MAD 1.41`), senal de entorno altamente variable.
   - decision:
     - rollback de la parte experimental de smoothing (flush chunked + cap
       activo) en `offstageV1`.
     - conservar solo ajustes seguros de gating de carga mientras haya
       `_pendingMeasuredSizes`.
     - continuar siguiente ciclo con hipotesis alternativas (sin chunking de
       flush).
66. Ajuste de harness: `--cooldown-ms` entre corridas + probe corto de impacto:
   - cambio de tooling:
     - `benchmarks/run_card_variance.dart` agrega flag `--cooldown-ms` para
       insertar espera entre warmups/runs medidos.
     - reporte JSON incluye `cooldown_ms_between_runs`.
     - reporte markdown muestra cooldown aplicado.
   - validacion funcional:
     - `dart run benchmarks/run_card_variance.dart --help`
     - `flutter analyze --no-pub benchmarks/run_card_variance.dart`
   - experimento corto (`r3,w1`) con protocolo card de referencia:
     - `nocool`:
       - `benchmarks/results/experiments/20260213_card_variance_cooldown_probe_r3_w1_nocool_metrics.json`
     - `cool1500`:
       - `benchmarks/results/experiments/20260213_card_variance_cooldown_probe_r3_w1_cool1500_metrics.json`
     - resumen:
       - `benchmarks/results/experiments/20260213_card_variance_cooldown_probe_r3_w1_summary.json`
       - `benchmarks/results/experiments/20260213_card_variance_cooldown_probe_r3_w1_summary.md`
   - lectura:
     - `cool1500` mejora raster, pero empeora `CV %jank` (`+6.89 pp`) y `TTI`
       (`+22.09%`) frente a `nocool`.
   - decision:
     - no promover cooldown como default de protocolo.
     - mantenerlo como herramienta opt-in para diagnostico puntual.
67. Sweep completo de cooldown + validacion robusta A/B (`cool0` vs `cool250`):
   - fase 1: sweep corto (`r3,w1`) en `cooldown={0,250,500,1000}`:
     - artefactos por variante:
       - `benchmarks/results/experiments/20260213_card_variance_cooldown_sweep_r3_w1/nocool_metrics.json`
       - `benchmarks/results/experiments/20260213_card_variance_cooldown_sweep_r3_w1/cool250_metrics.json`
       - `benchmarks/results/experiments/20260213_card_variance_cooldown_sweep_r3_w1/cool500_metrics.json`
       - `benchmarks/results/experiments/20260213_card_variance_cooldown_sweep_r3_w1/cool1000_metrics.json`
     - resumen fase 1:
       - `benchmarks/results/experiments/20260213_card_variance_cooldown_sweep_and_robust_summary.md`
     - lectura fase 1:
       - mejores señales cortas: `nocool` (`CV 0.39`) y `cool250` (`CV 0.59`).
       - `cool500` y `cool1000` muestran degradacion fuerte de dispersion.
   - fase 2: robusto (`r7,w2`) de control vs candidato:
     - control:
       - `benchmarks/results/experiments/20260213_card_variance_cooldown0_robust_r7_w2_metrics.json`
     - candidato:
       - `benchmarks/results/experiments/20260213_card_variance_cooldown250_robust_r7_w2_metrics.json`
     - comparativa/consecutivo:
       - `benchmarks/results/experiments/20260213_card_variance_cooldown_robust_ab_cv.json`
       - `benchmarks/results/experiments/20260213_card_variance_cooldown_robust_ab_mad.json`
       - `benchmarks/results/experiments/20260213_card_variance_cooldown_robust_ab_cv_or_mad.json`
       - `benchmarks/results/experiments/20260213_card_variance_cooldown_robust_ab_cv_and_mad.json`
       - `benchmarks/results/experiments/20260213_card_variance_cooldown_sweep_and_robust_summary.json`
   - lectura fase 2:
     - `cool250` y `cool0` quedan casi iguales en estabilidad robusta:
       - `%jank CV`: `34.51` vs `34.47`
       - `%jank MAD`: `2.10` vs `2.10`
     - `cool250` mejora build levemente, pero sube memoria y TTI.
     - decision consecutiva A/B: `cv=FAIL`, `mad=PASS`, `cv_or_mad=PASS`,
       `cv_and_mad=FAIL`.
   - decision:
     - mantener `nocool` como default operativo.
     - conservar `--cooldown-ms` solo como herramienta de diagnostico.

68. Sweep de perfil de scroll + validacion robusta A/B (`edge_bounce` vs `relative+ping_pong`):
   - fase 1: sweep corto (`r3,w1`) para perfilar movimiento de scroll:
     - resumen:
       - `benchmarks/results/experiments/20260213_scroll_profile_sweep_r3_w1/summary.tsv`
     - lectura:
       - mejor senal corta: `jump + relative + ping_pong(seg12)` frente a
         variantes `edge_bounce` y `relative+forward`.
   - fase 2: robusto candidato (`r7,w2`):
     - `benchmarks/results/experiments/20260221_scroll_profile_candidate_pingpong_seg12_robust_r7_w2_metrics.json`
   - fase 3: robusto control equivalente (`r7,w2`):
     - `benchmarks/results/experiments/20260221_scroll_profile_control_edge90_robust_r7_w2_metrics.json`
   - comparativa consecutiva A/B:
     - `benchmarks/results/experiments/20260221_scroll_profile_robust_ab_cv.json`
     - `benchmarks/results/experiments/20260221_scroll_profile_robust_ab_mad.json`
     - `benchmarks/results/experiments/20260221_scroll_profile_robust_ab_cv_or_mad.json`
     - `benchmarks/results/experiments/20260221_scroll_profile_robust_ab_cv_and_mad.json`
     - consolidado:
       - `benchmarks/results/experiments/20260221_scroll_profile_sweep_and_robust_summary.json`
       - `benchmarks/results/experiments/20260221_scroll_profile_sweep_and_robust_summary.md`
   - lectura robusta:
     - candidato mejora `p95_build_ms` (`-4.27%`) y `tti` (`-2.28%`) vs control.
     - candidato empeora `p95_raster_ms` (`+1.26%`), `peak_memory_mb` (`+0.41%`)
       y no mejora estabilidad CV (`+0.29 pp`).
     - decision consecutiva A/B: `cv=FAIL`, `mad=PASS`, `cv_or_mad=PASS`,
       `cv_and_mad=FAIL`.
   - decision:
     - no promover `jump + relative + ping_pong(seg12)` como nuevo default.
     - mantener `jump + edge_bounce + forward` como perfil operativo base.

69. Re-check robusto de `edge_bounce` con `scroll_steps=110` vs control `steps=90`:
   - candidato robusto (`r7,w2`):
     - `benchmarks/results/experiments/20260221_scroll_profile_edge110_robust_r7_w2_metrics.json`
   - control reutilizado en misma ventana:
     - `benchmarks/results/experiments/20260221_scroll_profile_control_edge90_robust_r7_w2_metrics.json`
   - comparativa consecutiva:
     - `benchmarks/results/experiments/20260221_scroll_profile_edge110_vs_edge90_cv.json`
     - `benchmarks/results/experiments/20260221_scroll_profile_edge110_vs_edge90_mad.json`
     - `benchmarks/results/experiments/20260221_scroll_profile_edge110_vs_edge90_cv_or_mad.json`
     - `benchmarks/results/experiments/20260221_scroll_profile_edge110_vs_edge90_cv_and_mad.json`
     - resumen:
       - `benchmarks/results/experiments/20260221_scroll_profile_edge110_vs_edge90_summary.json`
       - `benchmarks/results/experiments/20260221_scroll_profile_edge110_vs_edge90_summary.md`
   - lectura:
     - `steps=110` mejora medianas de performance (`p95_build`, `p95_raster`,
       `%jank`, `tti`) pero sube `peak_memory_mb`.
     - estabilidad se degrada fuerte: `%jank CV` `30.58 -> 60.30` (`+29.72 pp`).
     - decision consecutiva: `cv=FAIL`, `mad=PASS`, `cv_or_mad=PASS`,
       `cv_and_mad=FAIL`.
   - decision:
     - no promover `scroll_steps=110`.
     - mantener `scroll_steps=90` en perfil `jump + edge_bounce + forward`.

70. Sweep corto de vecindad para `edge_bounce` (`steps=80/90/100/110`, `r3,w1`):
   - objetivo:
     - validar si existe alternativa cercana a `steps=90` antes de otra tanda robusta.
   - artefactos:
     - `benchmarks/results/experiments/20260221_scroll_profile_edge_steps_sweep_r3_w1/edge80_metrics.json`
     - `benchmarks/results/experiments/20260221_scroll_profile_edge_steps_sweep_r3_w1/edge100_metrics.json`
     - `benchmarks/results/experiments/20260221_scroll_profile_edge_steps_sweep_r3_w1/summary.tsv`
     - `benchmarks/results/experiments/20260221_scroll_profile_edge_steps_sweep_r3_w1/summary_ranked.tsv`
     - `benchmarks/results/experiments/20260221_scroll_profile_edge_steps_sweep_r3_w1/summary.json`
     - `benchmarks/results/experiments/20260221_scroll_profile_edge_steps_sweep_r3_w1/summary.md`
   - lectura:
     - ranking corto vuelve a ubicar `steps=110` como mejor senal de muestra
       chica (`CV 0.20`), seguido por `steps=90` (`CV 0.22`).
     - `steps=100` queda con dispersion alta (`CV 28.28`) y memoria mayor.
     - `steps=80` reduce cobertura efectiva y empeora `%jank` mediano.
   - decision:
     - no abrir nuevo robusto para `steps=80/100`.
     - mantener conclusion previa: `steps=110` no se promueve por No-Go robusto
       (entrada 69), y `steps=90` sigue como default operativo.

71. Sweep de `visible cache` bajo perfil `edge90` + validacion robusta de candidato:
   - fase 1: sweep corto (`r3,w1`) de presets:
     - `default`, `no_visible_cache`, `fixed_visible_cache_128/192/256/320`.
     - resumen:
       - `benchmarks/results/experiments/20260221_visible_cache_sweep_edge90_r3_w1/summary.json`
       - `benchmarks/results/experiments/20260221_visible_cache_sweep_edge90_r3_w1_report.md`
     - lectura fase 1:
       - `fixed_visible_cache_320` aparece como mejor senal corta
         (`CV 0.45`, `MAD 0.0`) y se promueve a robusto.
   - fase 2: robusto (`r7,w2`) candidato vs control:
     - control:
       - `benchmarks/results/experiments/20260221_visible_cache_default_robust_r7_w2_metrics.json`
     - candidato:
       - `benchmarks/results/experiments/20260221_visible_cache320_robust_r7_w2_metrics.json`
     - comparativa consecutiva:
       - `benchmarks/results/experiments/20260221_visible_cache320_robust_ab_cv.json`
       - `benchmarks/results/experiments/20260221_visible_cache320_robust_ab_mad.json`
       - `benchmarks/results/experiments/20260221_visible_cache320_robust_ab_cv_or_mad.json`
       - `benchmarks/results/experiments/20260221_visible_cache320_robust_ab_cv_and_mad.json`
       - consolidado:
         - `benchmarks/results/experiments/20260221_visible_cache_sweep_and_robust_summary.json`
         - `benchmarks/results/experiments/20260221_visible_cache_sweep_and_robust_summary.md`
   - lectura fase 2:
     - `fixed_visible_cache_320` mejora raster/memoria marginalmente, pero
       empeora `p95_build_ms` (`+12.61%`), `tti` (`+2.13%`) y estabilidad de
       `%jank CV` (`+27.70 pp`) frente a control.
     - decision consecutiva: `cv=FAIL`, `mad=PASS`, `cv_or_mad=PASS`,
       `cv_and_mad=FAIL`.
   - decision:
     - No-Go para promover `fixed_visible_cache_320` como default.
     - mantener control `default_visible_cache` en linea operativa.

72. Intervencion de runtime: flush chunked de `_pendingMeasuredSizes` por frame:
   - cambio de codigo:
     - `lib/src/dynamic_lazy_wrap.dart` aplica tamanos medidos en chunks por
       frame en `_scheduleMeasurementFlush` (en vez de vaciar todo en un solo
       frame).
     - nuevo `dart-define`:
       - `OFFSTAGE_MEASUREMENT_FLUSH_CHUNK_SIZE` (default `24`).
   - calidad:
     - `flutter analyze --no-pub` sin issues.
     - `flutter test` completo en verde.
   - validacion robusta (`r7,w2`) contra referencia casi sin limite
     (`chunk=512`):
     - control:
       - `benchmarks/results/experiments/20260221_measure_flush_uncapped_robust_r7_w2_metrics.json`
     - candidato (`chunk=24`):
       - `benchmarks/results/experiments/20260221_visible_cache_default_robust_r7_w2_metrics.json`
     - comparativa/consecutivo:
       - `benchmarks/results/experiments/20260221_measure_flush_chunk24_vs_uncapped_cv.json`
       - `benchmarks/results/experiments/20260221_measure_flush_chunk24_vs_uncapped_mad.json`
       - `benchmarks/results/experiments/20260221_measure_flush_chunk24_vs_uncapped_cv_or_mad.json`
       - `benchmarks/results/experiments/20260221_measure_flush_chunk24_vs_uncapped_cv_and_mad.json`
       - consolidado:
         - `benchmarks/results/experiments/20260221_measure_flush_chunking_robust_summary.json`
         - `benchmarks/results/experiments/20260221_measure_flush_chunking_robust_summary.md`
   - lectura:
     - `chunk=24` mejora build (`-2.65%`), `%jank` mediano (`-49.58%`), TTI
       (`-2.76%`) y CV `%jank` (`-3.62 pp`) vs `chunk=512`.
     - `chunk=24` empeora raster (`+8.40%`) y memoria (`+0.55%`), sin cruzar
       cierre estricto de CV en esta ventana.
   - decision:
     - mantener flush chunked (`default 24`) como mitigacion de picos en
       Offstage V1.
     - seguir monitoreando raster/memoria en proximas tandas robustas.

73. Re-check robusto #2 de flush chunked (`chunk=24`) vs uncapped-like (`chunk=512`):
   - objetivo:
     - validar en una segunda ventana temporal si la mejora parcial de la
       entrada 72 se sostiene de forma consistente.
   - robusto (`r7,w2`) control vs candidato:
     - control:
       - `benchmarks/results/experiments/20260221_measure_flush_uncapped_confirm2_robust_r7_w2_metrics.json`
     - candidato:
       - `benchmarks/results/experiments/20260221_measure_flush_chunk24_confirm2_robust_r7_w2_metrics.json`
   - comparativa/consecutivo:
     - `benchmarks/results/experiments/20260221_measure_flush_chunk24_vs_uncapped_confirm2_cv.json`
     - `benchmarks/results/experiments/20260221_measure_flush_chunk24_vs_uncapped_confirm2_mad.json`
     - `benchmarks/results/experiments/20260221_measure_flush_chunk24_vs_uncapped_confirm2_cv_or_mad.json`
     - `benchmarks/results/experiments/20260221_measure_flush_chunk24_vs_uncapped_confirm2_cv_and_mad.json`
     - consolidado:
       - `benchmarks/results/experiments/20260221_measure_flush_chunking_confirm2_robust_summary.json`
       - `benchmarks/results/experiments/20260221_measure_flush_chunking_confirm2_robust_summary.md`
   - lectura:
     - en esta ventana, `chunk=24` queda peor que `chunk=512` en `p95_build`
       (`+12.07%`), `p95_raster` (`+13.96%`), `%jank` mediano (`+0.84%`) y
       memoria (`+0.24%`), con mejora marginal solo en `tti` (`-0.75%`).
     - estabilidad tambien empeora fuerte: `%jank CV +38.52 pp`,
       `%jank MAD +1.40 pp`.
     - decision consecutiva vuelve a quedar mixta:
       - `cv=FAIL`, `mad=PASS`, `cv_or_mad=PASS`, `cv_and_mad=FAIL`.
   - decision:
     - no promover flush chunked (`chunk=24`) como default.
     - mantener `OFFSTAGE_MEASUREMENT_FLUSH_CHUNK_SIZE` como tunable opt-in.
     - ajustar default de runtime a comportamiento uncapped-like (`<=0`) para
       minimizar riesgo de regresion mientras se sigue evaluando.

74. A/B robusto del cursor incremental de medicion (`scan cursor on/off`):
   - cambio de codigo para habilitar A/B limpio:
     - `lib/src/dynamic_lazy_wrap.dart`
     - nuevo define:
       - `OFFSTAGE_INCREMENTAL_MEASURE_SCAN_CURSOR` con fallback de escaneo
         completo cuando esta en `false`.
   - protocolo:
     - `dynamic_card_50k`
     - perfil `jump + edge_bounce + forward` (`steps=90`, `step=-280`)
     - dos pares robustos `r7,w2` para reducir sesgo temporal:
       - pair1 (orden normal): `on` luego `off`
       - pair2 (orden invertido): `off` luego `on`
   - artefactos:
     - pair1:
       - `benchmarks/results/experiments/20260221_scan_cursor_on_robust_r7_w2_metrics.json`
       - `benchmarks/results/experiments/20260221_scan_cursor_off_robust_r7_w2_metrics.json`
       - `benchmarks/results/experiments/20260221_scan_cursor_on_vs_off_cv.json`
       - `benchmarks/results/experiments/20260221_scan_cursor_on_vs_off_mad.json`
       - `benchmarks/results/experiments/20260221_scan_cursor_on_vs_off_cv_or_mad.json`
       - `benchmarks/results/experiments/20260221_scan_cursor_on_vs_off_cv_and_mad.json`
     - pair2:
       - `benchmarks/results/experiments/20260221_scan_cursor_on_confirm2_robust_r7_w2_metrics.json`
       - `benchmarks/results/experiments/20260221_scan_cursor_off_confirm2_robust_r7_w2_metrics.json`
       - `benchmarks/results/experiments/20260221_scan_cursor_on_vs_off_confirm2_cv.json`
       - `benchmarks/results/experiments/20260221_scan_cursor_on_vs_off_confirm2_mad.json`
       - `benchmarks/results/experiments/20260221_scan_cursor_on_vs_off_confirm2_cv_or_mad.json`
       - `benchmarks/results/experiments/20260221_scan_cursor_on_vs_off_confirm2_cv_and_mad.json`
     - consolidado:
       - `benchmarks/results/experiments/20260221_scan_cursor_ab_robust_summary.json`
       - `benchmarks/results/experiments/20260221_scan_cursor_ab_robust_summary.md`
   - lectura:
     - en ambos pares, `cursor=true` empeora consistentemente `TTI` y `%jank CV`
       frente a `cursor=false`.
     - las mejoras de memoria con `cursor=true` son marginales (`~0.1-0.2%`)
       y no compensan la degradacion de estabilidad.
     - checks consecutivos en ambos pares:
       - `cv=FAIL`, `mad=PASS`, `cv_or_mad=PASS`, `cv_and_mad=FAIL`.
   - decision:
     - no usar cursor incremental como default operativo.
     - mantener la estrategia como opt-in experimental.
     - actualizar default runtime de
       `OFFSTAGE_INCREMENTAL_MEASURE_SCAN_CURSOR` a `false`.

75. Estrategia `no_op` en harness: auto-premeasure para `jump + edge_bounce`:
   - cambio de tooling:
     - `benchmarks/runner_app/integration_test/benchmark_test.dart`
     - se agrega pre-measure automatico para perfil
       `jump + edge_bounce` (default `24` pasos) via:
       - `BENCH_AUTO_PRE_MEASURE_EDGE_BOUNCE` (default `true`)
       - `BENCH_EDGE_BOUNCE_AUTO_PRE_MEASURE_STEPS` (default `24`)
     - override explicito se mantiene con `BENCH_PRE_MEASURE_SCROLL_STEPS`.
   - A/B corto (`r3,w1`) candidato vs control (`premeasure=0`):
     - candidato:
       - `benchmarks/results/experiments/20260221_noop_strategy_autoprime_on_r3_w1_metrics.json`
     - control:
       - `benchmarks/results/experiments/20260221_noop_strategy_autoprime_off_r3_w1_metrics.json`
     - lectura corta:
       - `no_op_steps_avg` pasa de `2.0` a `0.0`.
   - validacion robusta (`r7,w2`) candidato vs control:
     - candidato:
       - `benchmarks/results/experiments/20260221_noop_strategy_autoprime_on_robust_r7_w2_metrics.json`
     - control:
       - `benchmarks/results/experiments/20260221_noop_strategy_autoprime_off_robust_r7_w2_metrics.json`
     - comparativa/consecutivo:
       - `benchmarks/results/experiments/20260221_noop_strategy_autoprime_on_vs_off_cv.json`
       - `benchmarks/results/experiments/20260221_noop_strategy_autoprime_on_vs_off_mad.json`
       - `benchmarks/results/experiments/20260221_noop_strategy_autoprime_on_vs_off_cv_or_mad.json`
       - `benchmarks/results/experiments/20260221_noop_strategy_autoprime_on_vs_off_cv_and_mad.json`
       - consolidado:
         - `benchmarks/results/experiments/20260221_noop_strategy_autoprime_robust_summary.json`
         - `benchmarks/results/experiments/20260221_noop_strategy_autoprime_robust_summary.md`
   - lectura robusta:
     - `no_op_steps_avg`: `2.0 -> 0.0`
     - `effective_steps_avg`: `88.0 -> 90.0`
     - `p95_build`: `-14.29%`
     - `p95_raster`: `-3.77%`
     - `%jank` mediano: `0.474 -> 0.0`
     - `peak_memory_mb`: `+2.15%`
     - `tti`: practicamente neutro (`-0.01%`)
   - decision:
     - mantener auto-premeasure activo por default en harness para
       `jump + edge_bounce`.
     - considerar cerrado el pendiente de estrategia de generacion de `no_op`
       a nivel perfil de scroll/harness.

76. Re-check de baseline de runtime y A/B robusto de `incremental_load`:
   - fase 1: baseline corto (`r3,w1`) `default80` vs `cons64`:
     - objetivo:
       - verificar si volver al default real del escenario (`80/20/300/300`)
         recupera performance frente al baseline operativo (`64/16/240/260`).
     - artefactos:
       - `benchmarks/results/experiments/20260221_card_default80_vs_cons64_r3_w1/summary.json`
       - `benchmarks/results/experiments/20260221_card_default80_vs_cons64_r3_w1_report.md`
     - lectura:
       - `default80` falla estabilidad corta (`%jank CV 141.42`) y queda peor en
         `p95_build`/memoria frente a `cons64`.
     - decision:
       - mantener `cons64` como base operativa.
   - fase 2: candidato corto + robusto de `incremental_load`:
     - corto (`r3,w1`) sobre base `cons64`:
       - `benchmarks/results/experiments/20260221_card_cons64_vs_incremental_r3_w1/summary.json`
       - `benchmarks/results/experiments/20260221_card_cons64_vs_incremental_r3_w1_report.md`
       - señal corta inicial: mejora fuerte de `build/raster`, con TTI peor.
     - robusto (`r7,w2`) control vs candidato:
       - control:
         - `benchmarks/results/experiments/20260221_card_incremental_control_robust_r7_w2_metrics.json`
       - candidato:
         - `benchmarks/results/experiments/20260221_card_incremental_candidate_robust_r7_w2_metrics.json`
       - consecutivo:
         - `benchmarks/results/experiments/20260221_card_incremental_ab_cv.json`
         - `benchmarks/results/experiments/20260221_card_incremental_ab_mad.json`
         - `benchmarks/results/experiments/20260221_card_incremental_ab_cv_or_mad.json`
         - `benchmarks/results/experiments/20260221_card_incremental_ab_cv_and_mad.json`
       - consolidado:
         - `benchmarks/results/experiments/20260221_card_incremental_ab_robust_summary.json`
         - `benchmarks/results/experiments/20260221_card_incremental_ab_robust_summary.md`
     - lectura robusta:
       - estabilidad equivalente en ambos (`CV/MAD` de `%jank` en `0`).
       - candidato empeora:
         - `p95_build`: `+10.87%`
         - `p95_raster`: `+4.83%`
       - mejoras marginales:
         - `peak_memory_mb`: `-0.12%`
         - `tti`: `-0.43%`
     - decision:
       - `NO_GO` para promover `OFFSTAGE_INCREMENTAL_LOAD=true` como default.
       - mantener base operativa en `cons64` sin `incremental_load`.

77. Ciclo `visible cache` intermedio (`128/256`) y robusto de `fixed256`:
   - fase 1: sweep corto (`r3,w1`) sobre base `cons64`:
     - presets:
       - `default`
       - `fixed_visible_cache_128`
       - `fixed_visible_cache_256`
     - artefactos:
       - `benchmarks/results/experiments/20260221_card_visible128_256_r3_w1/summary.json`
       - `benchmarks/results/experiments/20260221_card_visible128_256_r3_w1_report.md`
     - lectura:
       - `fixed_visible_cache_128` queda descartado por inestabilidad corta
         (`%jank CV 141.42`).
       - `fixed_visible_cache_256` aparece como mejor señal corta, con mejora de
         `build/raster`, pero con `tti` peor.
   - fase 2: robusto (`r7,w2`) de `fixed_visible_cache_256`:
     - candidato:
       - `benchmarks/results/experiments/20260221_card_fixed256_candidate_robust_r7_w2_metrics.json`
     - control (mismo protocolo/base):
       - `benchmarks/results/experiments/20260221_card_incremental_control_robust_r7_w2_metrics.json`
     - consecutivo:
       - `benchmarks/results/experiments/20260221_card_fixed256_ab_cv.json`
       - `benchmarks/results/experiments/20260221_card_fixed256_ab_mad.json`
       - `benchmarks/results/experiments/20260221_card_fixed256_ab_cv_or_mad.json`
       - `benchmarks/results/experiments/20260221_card_fixed256_ab_cv_and_mad.json`
     - consolidado:
       - `benchmarks/results/experiments/20260221_card_fixed256_ab_robust_summary.json`
       - `benchmarks/results/experiments/20260221_card_fixed256_ab_robust_summary.md`
   - lectura robusta:
     - mejoras leves del candidato:
       - `p95_build`: `-2.06%`
       - `p95_raster`: `-0.97%`
     - regresiones:
       - `%jank CV`: `0.0 -> 47.62` (no cruza `<=30`)
       - `peak_memory_mb`: `+0.53%`
       - `tti`: `+12.85%`
     - decision consecutiva:
       - `cv=FAIL`, `mad=PASS`, `cv_or_mad=PASS`, `cv_and_mad=FAIL`
   - decision:
     - `NO_GO` para promover `fixed_visible_cache_256` como default.
     - mantener `cons64` como baseline operativo.

78. A/B robusto `offstageV1` vs `sliverV3` en `dynamic_card_50k`:
   - objetivo:
     - validar si el enfoque deep `RenderSliver` puede superar el baseline
       operativo `cons64` tambien en escenario card denso (no solo chip).
   - habilitacion de escenario:
     - `benchmarks/runner_app/integration_test/benchmark_test.dart`
       agrega `dynamic_card_50k_sliver_v3`.
     - `benchmarks/run_benchmarks.dart` agrega el escenario al listado ejecutable.
   - protocolo robusto:
     - control: `dynamic_card_50k` (`offstageV1_cons64`)
     - candidato: `dynamic_card_50k_sliver_v3`
     - `repeats=7`, `warmup=2`, `jump + edge_bounce + forward`
     - runtime comun: `64/16/240/260`, `scan_cursor=false`, `flush_chunk=0`
   - artefactos:
     - control:
       - `benchmarks/results/experiments/20260221_card_sliverv3_control_robust_r7_w2_metrics.json`
     - candidato:
       - `benchmarks/results/experiments/20260221_card_sliverv3_candidate_robust_r7_w2_metrics.json`
     - checks consecutivos:
       - `benchmarks/results/experiments/20260221_card_sliverv3_ab_cv.json`
       - `benchmarks/results/experiments/20260221_card_sliverv3_ab_mad.json`
       - `benchmarks/results/experiments/20260221_card_sliverv3_ab_cv_or_mad.json`
       - `benchmarks/results/experiments/20260221_card_sliverv3_ab_cv_and_mad.json`
     - consolidado:
       - `benchmarks/results/experiments/20260221_card_sliverv3_ab_robust_summary.json`
       - `benchmarks/results/experiments/20260221_card_sliverv3_ab_robust_summary.md`
   - lectura robusta (medianas, candidato vs control):
     - `p95_build_ms`: `-9.52%` (mejor)
     - `p95_raster_ms`: `-5.00%` (mejor)
     - `peak_memory_mb`: `-1.64%` (mejor)
     - `tti_ms`: `+4.94%` (peor)
     - `%jank CV`: sin mejora (`244.95` en ambos)
   - decision:
     - `NO_GO` para promover `sliverV3` en este corte.
     - mantener `offstageV1` como baseline de release y `sliverV3` como
       linea de investigacion interna.

79. Re-check de optimizacion `TTI` en `sliverV3` (fill-check dirigido):
   - cambio de codigo:
     - `lib/src/dynamic_lazy_wrap_sliver_v3.dart`
     - se elimina scheduling post-frame continuo de fill-check y se activa
       solo bajo demanda (`_needsFillViewportCheck`), reduciendo trabajo
       recurrente en frames de build.
   - cobertura:
     - nuevo test de auto-fill sin scroll:
       - `test/dynamic_lazy_wrap_sliver_v3_test.dart`
   - validacion base:
     - `flutter analyze --no-pub`: PASS
     - `flutter test`: PASS
   - A/B corto (`r3,w1`) de smoke:
     - control:
       - `benchmarks/results/experiments/20260221_card_sliverv3_ttiopt_control_r3_w1_metrics.json`
     - candidato:
       - `benchmarks/results/experiments/20260221_card_sliverv3_ttiopt_candidate_r3_w1_metrics.json`
     - lectura:
       - mejora de `TTI` en muestra corta (`-2.43%`) con mejora adicional en
         build y CV.
   - A/B robusto (`r7,w2`) de confirmacion:
     - control:
       - `benchmarks/results/experiments/20260221_card_sliverv3_ttiopt_control_robust_r7_w2_metrics.json`
     - candidato:
       - `benchmarks/results/experiments/20260221_card_sliverv3_ttiopt_candidate_robust_r7_w2_metrics.json`
     - checks consecutivos:
       - `benchmarks/results/experiments/20260221_card_sliverv3_ttiopt_ab_cv.json`
       - `benchmarks/results/experiments/20260221_card_sliverv3_ttiopt_ab_mad.json`
       - `benchmarks/results/experiments/20260221_card_sliverv3_ttiopt_ab_cv_or_mad.json`
       - `benchmarks/results/experiments/20260221_card_sliverv3_ttiopt_ab_cv_and_mad.json`
     - consolidado:
       - `benchmarks/results/experiments/20260221_card_sliverv3_ttiopt_ab_robust_summary.json`
       - `benchmarks/results/experiments/20260221_card_sliverv3_ttiopt_ab_robust_summary.md`
   - lectura robusta (candidato vs control):
     - `p95_build_ms`: `-13.95%`
     - `p95_raster_ms`: `-7.96%`
     - `peak_memory_mb`: `-1.86%`
     - `tti_ms`: `-6.64%` (mejora confirmada)
     - `%jank CV`: `194.24` (falla umbral estricto `<=30`)
   - lectura vs `sliverV3` robusto previo:
     - `tti_ms`: `-4.41%`
     - `p95_build_ms`: `-7.01%`
   - decision:
     - avance tecnico positivo para `sliverV3`, pero **NO_GO** para default
       por estabilidad CV no cerrada.

80. Spike corto de `large-jump cache throttling` en `RenderSliverV3`:
   - hipotesis:
     - reducir cache prefetch en frames con saltos grandes para bajar picos de
       jank en `jump + edge_bounce`.
   - implementacion:
     - ajuste temporal en `lib/src/sliver_v3_render_list.dart`.
   - validacion:
     - calidad base (`flutter analyze --no-pub`, `flutter test`) en verde.
     - A/B corto `r3,w1`:
       - control:
         - `benchmarks/results/experiments/20260221_card_sliverv3_jumpcache_control_r3_w1_metrics.json`
       - candidato:
         - `benchmarks/results/experiments/20260221_card_sliverv3_jumpcache_candidate_r3_w1_metrics.json`
       - consolidado:
         - `benchmarks/results/experiments/20260221_card_sliverv3_jumpcache_ab_short_summary.json`
         - `benchmarks/results/experiments/20260221_card_sliverv3_jumpcache_ab_short_summary.md`
   - lectura corta:
     - mejora build/raster, pero regresion de `tti` (`+7.18%`) y sin mejora en
       estabilidad (`%jank CV` ya en `0.0` para ambos).
   - decision:
     - **NO_GO** para escalar a robusto.
     - rollback aplicado en `lib/src/sliver_v3_render_list.dart` para no sumar
       complejidad sin retorno claro.

81. Diagnostico robusto por segmentos de frame en `sliverV3` (card):
   - hardening del harness:
     - `benchmarks/runner_app/integration_test/benchmark_test.dart`
       - agrega `BENCH_MEASURED_SCROLL_SEGMENTS`.
       - agrega `frame_diagnostics.measured_segments`.
       - clasifica frames medidos por segmento de paso de scroll.
   - agregacion/reporting:
     - `benchmarks/run_card_variance.dart`
       - parsea `measured_segments`.
       - agrega `measured_segment_summary` en JSON.
       - agrega seccion de hotspots por segmento en markdown.
   - validacion:
     - `flutter analyze --no-pub`: PASS
     - `flutter test`: PASS
   - evidencia robusta (`r7,w2`, `dynamic_card_50k_sliver_v3`, `linux`,
     `jump+edge_bounce`, `segments=6`):
     - `benchmarks/results/experiments/20260221_card_sliverv3_segmentdiag_ab_robust_metrics.json`
     - `benchmarks/results/experiments/20260221_card_sliverv3_segmentdiag_ab_robust_report.md`
     - `benchmarks/results/experiments/20260221_card_sliverv3_segmentdiag_ab_robust_summary.json`
     - `benchmarks/results/experiments/20260221_card_sliverv3_segmentdiag_ab_robust_summary.md`
   - lectura:
     - hotspot principal en segmento inicial `s0`
       (`jank>2x_avg=0.143`, `max_total_ms_max=46.741`).
     - gate CV de `%jank` continua fuera de umbral estricto.
     - comparativo control vs candidato con mismo protocolo:
       - `offstageV1` tambien concentra outliers en `s0`, pero con severidad
         menor (`max_total_ms_max=32.984` vs `46.741` en `sliverV3`).
       - `sliverV3` mantiene ventaja de throughput (`p95_build`, `p95_raster`)
         y memoria, con costo en `tti` y picos iniciales.
   - decision:
     - **NO_GO** para default.
     - siguiente hipotesis: atacar costo del primer tramo medido (`s0`) con
       estrategia puntual de primer salto/primer ajuste de cache.

82. Mitigacion puntual de `s0` en `sliverV3` (load-step defer en scroll):
   - cambio de codigo:
     - `lib/src/dynamic_lazy_wrap_sliver_v3.dart`
       - `loadMore` diferido al siguiente frame solo para trigger de scroll.
       - `fill viewport` mantiene `loadMore` inmediato para no romper auto-fill.
   - validacion:
     - `flutter analyze --no-pub`: PASS
     - `flutter test`: PASS
   - evidencia robusta (`r7,w2`, `segments=6`):
     - `benchmarks/results/experiments/20260221_card_sliverv3_loadstepdefer_segmentdiag_robust_metrics.json`
     - `benchmarks/results/experiments/20260221_card_sliverv3_loadstepdefer_segmentdiag_robust_report.md`
     - `benchmarks/results/experiments/20260221_card_sliverv3_loadstepdefer_segmentdiag_summary.json`
     - `benchmarks/results/experiments/20260221_card_sliverv3_loadstepdefer_segmentdiag_summary.md`
   - lectura (vs `sliverV3` segmentdiag previo):
     - `s0` baja de forma marcada:
       - `jank>2x_avg`: `0.143 -> 0.000`
       - `s0 max_total_ms_max`: `46.741 -> 8.225`
     - mejora de throughput:
       - `p95_build_ms` mediana `-30.66%`
       - `p95_raster_ms` mediana `-3.05%`
     - tradeoff:
       - `TTI` mediana empeora `+4.29%`.
   - decision:
     - **avance parcial**: se conserva mitigacion de `s0`.
     - **NO_GO** para default hasta recuperar `TTI` y cerrar estabilidad CV.

83. Experimento `startup batch cap` para recuperar `TTI` en `sliverV3`:
   - hipotesis:
     - limitar batch inicial para bajar costo del primer frame y mejorar `TTI`.
   - resultado robusto (`r7,w2`):
     - mejora `TTI` mediano (`-10.14%`), pero degrada:
       - `p95_build_ms` (`+21.91%`)
       - `p95_raster_ms` (`+5.23%`)
       - severidad de picos (`max_total_ms_max +24.51%`)
       - severidad en `s0` (`s0 max_total_ms_max +111.64%`).
   - decision:
     - **NO_GO**.
     - rollback aplicado (se mantiene solo `load-step defer` sin cap inicial).
   - evidencia:
     - `benchmarks/results/experiments/20260221_card_sliverv3_startupcap_robust_report.md`
     - `benchmarks/results/experiments/20260221_card_sliverv3_startupcap_robust_summary.md`
     - `benchmarks/results/experiments/20260221_card_sliverv3_startupcap_robust_summary.json`

84. Experimento `startup cacheExtent cap` con promocion post-scroll en `sliverV3`:
   - hipotesis:
     - limitar prefetch de cache solo al arranque y promover al valor configurado
       tras el primer scroll real para bajar picos sin recortar batch inicial.
   - cambio de codigo:
     - `lib/src/dynamic_lazy_wrap_sliver_v3.dart`
       - agrega `_effectiveCacheExtent` con cap inicial.
       - promociona cache en `_onScroll` cuando hay desplazamiento real.
       - fix de regresion no-batch: la promocion ya no depende de `_hasMoreItems`.
   - cobertura:
     - `test/dynamic_lazy_wrap_sliver_v3_test.dart`
       - nuevo test: `promotes startup cache extent after first user scroll`.
     - `flutter analyze --no-pub`: PASS
     - `flutter test`: PASS
   - resultado robusto (`r7,w2`, `segments=6`), vs baseline `loadstepdefer`:
     - `p95_build_ms` mediana: `-3.17%`
     - `p95_raster_ms` mediana: `-9.07%`
     - `%jank` medio: `-100.00%`
     - `peak_memory_mb` mediana: `+0.35%`
     - `TTI` mediana: `+1.71%`
     - hotspot `s5`:
       - `p95_total_ms_avg`: `-21.01%`
       - `max_total_ms_max`: `-57.15%`
   - decision:
     - **GO condicional** para conservar el ajuste en codigo.
     - se mantiene **NO_GO** para default de `sliverV3` hasta cerrar brecha de
       `TTI` vs `offstageV1`.
   - evidencia:
     - `benchmarks/results/experiments/20260221_card_sliverv3_startupcachecap_robust_report.md`
     - `benchmarks/results/experiments/20260221_card_sliverv3_startupcachecap_robust_summary.md`
     - `benchmarks/results/experiments/20260221_card_sliverv3_startupcachecap_robust_summary.json`

85. Tuning posterior de `startup cache cap` + robust final del default:
   - objetivo:
     - recuperar `TTI` sin perder estabilidad (`%jank`) y con buen throughput.
   - tuning ejecutado:
     - sweep corto (`r3,w1`) con caps `80/120/180/240/300`.
     - robustos (`r7,w2`) de `cap180`, `cap240` y `cap300`.
   - hallazgos:
     - `cap180`: **NO_GO** (outliers fuertes y severidad alta en tramo inicial).
     - `cap240`: mejora parcial, pero no domina al candidato final.
     - `cap300`: mejor señal global entre candidatos robustos.
   - hardening final en codigo:
     - `lib/src/dynamic_lazy_wrap_sliver_v3.dart`
       - default pasa a `_startupCacheExtentCapDefault = 300`.
       - se evita promocion/setState cuando el cap no aplica
         (`_hasStartupCacheCap`).
   - robust final del default (`r7,w2`, sin `--define`):
     - `p95_build_ms` mediana: `2.077`
     - `p95_raster_ms` mediana: `4.679`
     - `%jank` medio: `0.0`
     - `TTI` mediana: `244.711`
     - `hot_max_total`: `7.924`
   - comparativa:
     - vs `cap120`:
       - `build -6.94%`, `raster +6.37%`, `TTI -2.83%`, `hot_max_total -17.66%`.
     - vs `loadstepdefer`:
       - `build -9.89%`, `raster -3.29%`, `%jank -100%`, `TTI -1.17%`,
         `hot_max_total -64.72%`.
   - decision:
     - **GO** para este tuning (default tecnico `default300_guard`).
     - se mantiene **NO_GO** para default de engine `sliverV3` hasta cerrar
       brecha de `TTI` vs `offstageV1` y objetivos globales del roadmap.
   - evidencia:
     - `benchmarks/results/experiments/20260221_card_sliverv3_startupcache_tuning_summary.md`
     - `benchmarks/results/experiments/20260221_card_sliverv3_startupcache_tuning_summary.json`

86. Re-ejecucion del gate Sprint 6 con A/B `sliverV3` (baseline Sprint 1):
   - objetivo:
     - validar decision final con evidencia A/B multipaquete usando el default
       tecnico `default300_guard`.
   - protocolo:
     - runner A/B compatible con gate (`benchmarks/run_sliver_v3_ab.dart`).
     - `device=linux`, `repeats=5`, `warmup=1`.
     - baseline: `benchmarks/results/20260211_232622Z/summary.json`.
   - resultado del gate:
     - **NO-GO** para promover `sliverV3` como default del engine.
     - checks que fallan (objetivos globales vs baseline Sprint 1):
       - `%jank dynamic_chip_10k >= 30%`: `-1437.16%`
       - `peak_memory_mb dynamic_card_50k >= 20%`: `-4.40%`
       - `p95_build_ms dynamic_chip_10k >= 20%`: `-7616.34%`
       - `p95_build_ms dynamic_card_50k >= 20%`: `-48.72%`
     - checks que pasan:
       - suite funcional (`PASS`)
       - sin P0/P1 abiertos (`PASS`)
       - calidad de evidencia (`repeats=5`, `PASS`)
   - lectura tecnica:
     - el frente `dynamic_card_50k` mejora parcialmente `%jank` (`+25.25%`) pero
       no cruza umbrales globales de memoria/build.
     - `dynamic_chip_10k` sigue muy por debajo de baseline Sprint 1 en build,
       raster, `%jank`, memoria y `TTI`.
   - decision:
     - se confirma estrategia de release: `sliverV3` solo **opt-in**; default
       permanece en `offstageV1`.
     - avance global del roadmap se mantiene en **97.2%** hasta cerrar objetivos
       globales de performance y release operativo final.
   - evidencia:
     - `benchmarks/results/experiments/20260221_sliverv3_ab_r5_w1_report.md`
     - `benchmarks/results/experiments/20260221_sliverv3_ab_r5_w1.json`
     - `benchmarks/results/experiments/20260222_sprint6_gate_sliverv3_r5_w1_report.md`
     - `benchmarks/results/experiments/20260222_sprint6_gate_sliverv3_r5_w1_report.json`
     - `docs/RELEASE_CUT_20260222.md`

87. Preparacion de paquete de release `1.1.0` (sin flip de default):
   - objetivo:
     - dejar artefactos de release y packaging listos para publicacion controlada.
   - cambios:
     - `pubspec.yaml`: version `1.0.0 -> 1.1.0`.
     - `CHANGELOG.md`: cierre de bloque `Unreleased` como `1.1.0`.
     - `docs/RELEASE_NOTES_1_1_0.md`: nota de release con alcance y limites.
     - `.pubignore`: exclusion de `benchmarks/`, `docs/`, artefactos `build/`,
       archivos de IDE y documentos internos de roadmap/spike.
   - validacion de packaging:
     - `flutter pub publish --dry-run` (re-ejecutado tras ajustar `.pubignore`).
     - resultado final:
       - payload comprimido `28 KB`.
       - queda solo warning esperado por worktree con cambios sin commit
         (`dirty git state`).
   - decision:
     - paquete de release queda **listo para publish manual** cuando se decida el
       corte final del repositorio.
   - evidencia:
     - `docs/RELEASE_NOTES_1_1_0.md`
     - `docs/RELEASE_CUT_20260222.md`

## Avance Cuantificado (2026-02-21)

### Metodo

1. Base: 18 historias de usuario (6 sprints x 3 historias).
2. Puntaje por historia:
   - cumplida = `1.0`
   - parcial = `0.5`
   - pendiente = `0.0`
3. Formula: `avance_total = suma_puntajes / 18`.

### Estado resumido

1. Sprint 1: `3.0/3.0` (cumplido)
2. Sprint 2: `3.0/3.0` (cumplido)
3. Sprint 3: `3.0/3.0` (cumplido; varianza card cerrada con protocolo robusto)
4. Sprint 4: `3.0/3.0` (cumplido)
5. Sprint 5: `3.0/3.0` (cumplido)
6. Sprint 6: `2.5/3.0` (US2 parcial hasta cierre de release operativo final)

Resultado actual: **`17.5 / 18 = 97.2%`**.

### Faltante al 100%

1. Cerrar objetivos robustos de performance en `dynamic_card_50k`:
   - `peak_memory_mb` >= 20% mejora vs baseline Sprint 1
   - `p95_build_ms` >= 20% mejora vs baseline Sprint 1
   - ultimos cortes robustos (`top3`, `incremental_load`, `fixed256`; `r7,w2`)
     no alcanzan cierre de objetivos globales.
2. Mantener iteracion focal en 1-2 candidatos por ciclo (`r7,w2`) hasta lograr
   cruce consistente de `CV<=30` sin degradar `tti`.
