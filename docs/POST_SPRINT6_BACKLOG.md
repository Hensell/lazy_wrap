# Backlog Post Sprint 6 (Priorizado)

Fecha de corte: 2026-02-13

## Objetivo

Cerrar la brecha para alcanzar el techo tecnico en `LazyWrap.dynamic` despues del
NO-GO de `sliverV2`, manteniendo `offstageV1` como default estable.

## Prioridad P0 (actual)

1. Reducir varianza de `%jank` en `dynamic_card_50k`.
   - Historia: como equipo, queremos decision robusta por tendencia real y no por
     ruido entre corridas.
   - Criterios de aceptacion:
     - CV de `%jank` <= 30% con protocolo `repeats >= 7`, `warmup >= 1`.
     - al menos 2 tandas consecutivas con misma conclusion (signo de mejora o
       regresion).
     - reporte versionado en `benchmarks/results/experiments/`.
   - Estado 2026-02-13: cumplido (gate estandarizado, CV `%jank` baja de
     `61.31%` a `37.95%`, aun por encima del objetivo <= `30%`; sweep de
     capacidad (`192/256/320`) y perfil `forward` no mejoran estabilidad para
     cerrar el objetivo; experimento `adaptive measure batch` tambien queda
     No-Go para default por regresion de jank/raster; re-check `r7,w2` logra
     una corrida con CV `22.08%` pero no sostiene en replica (CV `96.80%`);
     se agrego diagnostico automatico de outliers (IQR) por metrica/corrida en
     `run_card_variance.dart`; nueva tanda robusta con ese diagnostico
     (`r7,w2`) reporta `%jank` CV `58.71%`; segunda tanda consecutiva del mismo
     protocolo reporta `%jank` CV `52.21%` (sin outliers IQR), pero ambas
     siguen por encima de `30%`, por lo que el criterio consecutivo permanece
     abierto; prueba adicional con `--stable-scroll-profile` (`r7,w2`) marca
     `%jank` CV `75.19%` y sin outliers IQR, por lo que no se adopta como
     mitigacion de cierre; se agrega gate robusto MAD para `%jank` en script +
     CI (enforcement opt-in); primera tanda `r7,w2` con ese gate muestra
     `%jank` CV `60.71%` y MAD/mediana `13.93%` (PASS robusto), dejando abierto
     definir criterio final de decision (CV puro vs combinado); se automatiza el
     check consecutivo con `run_card_variance_consecutive_check.dart`, pero una
     segunda tanda robusta (`r7,w2`) da `%jank` CV `87.03%` y MAD `59.30%`,
     provocando FAIL consecutivo en todos los modos (`cv`, `mad`, `cv_or_mad`,
     `cv_and_mad`) y manteniendo el objetivo P0 abierto; se incorpora ademas un
     sweep automatizado de perfiles de scroll
     (`run_card_variance_profile_sweep.dart` + CI dedicado) para iterar
     estabilidad con ranking reproducible por preset; primera tanda corta del
     sweep (`r3,w1`) recomienda `stable_ping_pong_v1`, aunque aun sin pases
     simultaneos de gates CV+MAD; re-check robusto posterior (`r7,w2`) del
     candidato arroja CV `%jank` `78.99%` y MAD `74.46%`, por lo que se
     descarta como mitigacion de cierre en este corte; se incorpora luego un
     sweep runtime dedicado (`run_card_variance_runtime_sweep.dart`) con foco
     en workload/cache: tanda robusta de candidatos (`r7,w2`) mejora en
     `fixed_visible_cache_256` (CV `45.33%`, MAD `29.65%`) respecto de
     `default` (CV `60.67%`, MAD `67.93%`), pero sin cerrar objetivo; barrido
     fino de capacidad fija (`128/192/256/320/384`) en muestra corta sugiere
     `384`, y robusto posterior (`r7,w2`) tambien rankea `384` como mejor
     candidato, aunque falla gates (CV `40.86%`, MAD `35.95%`); replica robusta
     de `384` (`r7,w2`) mantiene conclusion de no-cierre (CV `31.42%`, MAD
     `48.10%`) y el check consecutivo (`cv`, `mad`, `cv_and_mad`) da FAIL; se
     agrega comparativa controlada de input de scroll (`drag` vs `jump`) en
     `r5,w1`: `jump` mejora medianas de performance, pero mantiene FAIL por CV
     (`64.91%`) y no habilita cierre del P0; en una fase posterior se ejecuta
     sweep corto con `jump` (`r3,w1`) y re-check robusto consecutivo
     (`r7,w2` x2) con preset `default`, quedando ambos CV casi en el objetivo
     (`31.56%` y `31.45%`) con PASS robusto MAD en ambas tandas; se prueba
     luego incrementar warmup a `w3` (mismo `r7`), pero la replica consecutiva
     no mejora cierre CV (run1 `104.68%`, run2 `34.45%`), por lo que `w3` queda
     descartado y `w2` se mantiene como mejor protocolo operativo actual; se
     ejecuta ademas un sweep robusto de presets con `jump+w2`
     (`default/256/384`) y ningun preset cruza `CV<=30` (mejor: `384` con
     `35.03%`), y un check cruzado de dos corridas robustas `default+w2`
     (`31.56%` vs `35.27%`) confirma que CV puro sigue sin cierre consecutivo;
     se prueba tambien `jump+forward` (`r7,w2`) y empeora dispersion
     (`CV 51.07%`), por lo que se mantiene `jump+ping_pong` como base de
     experimentacion; adicionalmente, el CI de card variance incorpora
     `VARIANCE_DECISION_MODE` + `ENFORCE_VARIANCE_DECISION` para explicitar y
     auditar el criterio final de cierre (cv, mad, cv_or_mad o cv_and_mad); se
     adopta politica operativa `cv_or_mad` con enforcement `true` y thresholds
     `30/30` en el workflow `card-variance` (ver
     `docs/CARD_VARIANCE_DECISION_POLICY.md`), manteniendo CV puro como objetivo
     tecnico pendiente para endurecer a `cv_and_mad`; corrida de referencia CI
     local con esta politica (`jump`, `w2`) confirma PASS operativo por decision
     mode (`variance_decision_evaluated_pass=true`) aun con CV `%jank` alto
     (`50.36%`); check consecutivo con corrida robusta independiente mantiene
     PASS en `cv_or_mad` (y FAIL en `cv`), consolidando el criterio operativo
     mientras CV puro sigue abierto como objetivo tecnico; en el spike mas
     reciente se agrega `BENCH_SCROLL_JUMP_PROFILE=edge_bounce` +
     `scroll_diagnostics` en runner, y la comparativa robusta `r7,w2` contra
     `relative` mejora CV `%jank` (`35.17% -> 30.54%`) y elimina no-op de
     scroll (`5 -> 0` promedio); micro-sweep de `scroll_step_px` identifica
     `-280` como candidato y se valida cierre robusto en dos tandas `r7,w2`
     consecutivas (run1 CV/MAD `18.66/0.70`, run2 `29.99/2.85`), con PASS en
     `cv`, `cv_and_mad` y `cv_or_mad`).
2. Cerrar gap de `p95_build_ms` en card para candidato `offstageV1`.
   - Historia: como usuario, quiero menor costo de build en listas densas sin
     degradar interaccion.
   - Criterios de aceptacion:
     - mejora >= 20% vs baseline Sprint 1 en `dynamic_card_50k`.
     - sin regresion > 5% en `time_to_first_interaction_ms`.
     - `flutter test` completo en verde.
   - Estado 2026-02-13: en progreso con mejora robusta (`p95_build_ms` +26.29%
     vs protocolo anterior equivalente), falta cierre contra objetivo global;
     en re-check focal `r7,w2` con `step=-280` y presets top3
     (`default`, `incremental_plus_single_measure`,
     `conservative_batches`), el mejor candidato (`conservative_batches`)
     mejora frente a default del mismo corte (`p95_build_ms +11.86%`,
     `peak_memory_mb +1.34%`, `CV %jank -3.34 pp`) pero queda en
     `CV=31.13` (umbral `<=30`) y aun sin cierre para cambio de default;
     micro-tuning adicional de vecindad (`r3,w1`) detecta señal corta en
     `cons_soft_down` (`60/15/235/250`), pero re-check robusto consecutivo
     (`r7,w2`) no sostiene criterio estricto (`cv`: FAIL, `cv_and_mad`: FAIL)
     y muestra `no_op_steps_avg=2.0` en ambas tandas, por lo que se mantiene
     No-Go para flip de defaults; una iteracion posterior enfocada en `no_op`
     (`c_ref_default`, `c_cons_hi_extent`, `c_cons_mid_extent`,
     `c_cons_hi_extent_inc`) tampoco cierra criterio estricto: el candidato
     promovido a robusto (`c_cons_hi_extent_inc`) falla en run1 (`CV=149.71`)
     con `no_op_steps_avg=2.0` (ver
     `benchmarks/results/experiments/20260213_card_noop_focus_iteration_summary.md`);
     adicionalmente se integra una optimizacion de runtime en Offstage V1
     (cursor incremental de escaneo de medicion en
     `lib/src/dynamic_lazy_wrap.dart`) para eliminar rescans O(n) por frame con
     cola vacia; calidad base valida (`flutter test`/`flutter analyze`) y smoke
     inicial reportado en
     `benchmarks/results/experiments/20260213_card_variance_scan_cursor_smoke_r1_metrics.json`;
     el re-check robusto consecutivo (`r7,w2` x2) queda mixto: run1 con
     outlier de jank (`CV=73.76`) y run2 estable (`CV=0.51`, `MAD=0.7`);
     decision consecutiva estricta: `cv=FAIL`, `cv_and_mad=FAIL`,
     `cv_or_mad=PASS` (ver
     `benchmarks/results/experiments/20260213_card_variance_scan_cursor_r7_w2_summary.md`),
     por lo que no se promueve como cierre final del P0; como siguiente paso
     se instrumenta diagnostico deep de spikes por corrida/fase en runner +
     script de varianza (`frame_diagnostics` y `frame_diagnostics_summary`),
     validado en smoke
     (`benchmarks/results/experiments/20260213_card_variance_frame_diag_smoke_r1_metrics.json`)
     donde aparece un spike aislado `>3x` en `measured_scroll`, habilitando
     el proximo ciclo de aislamiento con evidencia mas precisa; en la iteracion
     siguiente se agrega diagnostico `single_run_anomaly` (CV original vs CV
     excluyendo el run sospechoso IQR) en `run_card_variance.dart` + reporte
     markdown, validado en robusto
     (`benchmarks/results/experiments/20260213_card_variance_single_run_anomaly_target_r7_w2_metrics.json`):
     `%jank` CV `50.76% -> 31.94%` al excluir el sospechoso, pero aun FAIL en
     objetivo P0 (`<=30`), por lo que la varianza residual no queda explicada
     solo por una corrida extrema; re-check consecutivo inmediato con el mismo
     protocolo (`r7,w2` x2) confirma escenario mixto:
     - run A: CV `%jank` `45.91` (sin sospechoso `28.05`)
     - run B: CV `%jank` `31.49` (sin sospechoso `28.21`)
     - decision consecutiva: `cv=FAIL`, `mad=PASS`, `cv_or_mad=PASS`,
       `cv_and_mad=FAIL`
     (ver
     `benchmarks/results/experiments/20260213_card_variance_single_run_anomaly_consecutive_ab_summary.md`);
     conclusion operativa: estabilidad robusta sostenida, pero CV estricto
     sigue abierto y requiere tuning de base para cierre P0; en el siguiente
     ciclo se ejecuta sweep de estabilidad base con presets runtime
     (`default`, `conservative_batches`, `incremental_plus_single_measure`,
     `fixed384_single_measure_conservative`) y validacion robusta top2
     (`default` vs `conservative_batches`):
     - corto `r3,w1`: recomienda `conservative_batches` (CV `0.00` en muestra corta)
     - robusto `r7,w2`: `conservative_batches` mejora vs `default`
       (`CV -16.93 pp`, `p95_build +17.01%`, `raster +3.30%`, `mem +1.67%`,
       `tti +3.94%`) pero mantiene `CV=50.55` (FAIL `<=30`)
     (ver
       `benchmarks/results/experiments/20260213_runtime_sweep_stability_base_r7_w2_top2_comparison_vs_default.md`);
     - `single_run_anomaly` del candidato confirma que ni excluyendo run
       sospechoso (`CV 31.27`) se cruza `<=30`, por lo que persiste varianza
       residual estructural; micro-sweep adicional alrededor de
       `conservative_batches` (`r3,w1`, variantes `60/14`, `56/14`, `48/12`)
       no encuentra mejor reemplazo: `c_ref_cons` sigue liderando
       (`CV 28.45`, mejor build), mientras las variantes tight empeoran
       dispersion y raster (ver
       `benchmarks/results/experiments/20260213_conservative_micro_sweep_r3_w1/summary.md`);
     en un spike posterior se prototipa smoothing de runtime de medicion
     (cap de mediciones activas + flush chunked de `_pendingMeasuredSizes`) y
     se valida en robusto `r7,w2` con A/B consecutivo:
     - run A: `CV 171.80`, `MAD 73.07`
     - run B: `CV 34.82`, `MAD 0.70`
     - decision consecutiva: FAIL en `cv`, `mad`, `cv_or_mad`, `cv_and_mad`
     (ver
     `benchmarks/results/experiments/20260213_card_variance_smoothing_v1_ab_summary.md`);
     conclusion: No-Go para este enfoque; se aplica rollback del tramo
     experimental y se mantiene la linea de tuning sin flush chunking; el
     re-check robusto post-rollback (`r7,w2` x2) tambien falla en todos los
     modos consecutivos (`cv`, `mad`, `cv_or_mad`, `cv_and_mad`), por lo que
     se marca esta ventana como ambiente ruidoso no concluyente para promover
     cambios de runtime; en paralelo se extiende el harness con
     `--cooldown-ms` entre corridas para evaluar aislamiento de ruido:
     probe corto `r3,w1` (`nocool` vs `cool1500`) muestra mejora de raster
     pero degradacion en `CV %jank` (`+6.89 pp`) y `TTI` (`+22.09%`), por lo
     que cooldown queda como flag opt-in de diagnostico y no se adopta por
     default (ver
     `benchmarks/results/experiments/20260213_card_variance_cooldown_probe_r3_w1_summary.md`);
     iteracion siguiente con sweep completo `r3,w1` (`cooldown=0/250/500/1000`)
     y robusto A/B `r7,w2` (`cool0` vs `cool250`) confirma que cooldown no
     mejora estabilidad robusta (CV `34.47` vs `34.51`, MAD `2.1` en ambos) y
     no se promueve como default (ver
     `benchmarks/results/experiments/20260213_card_variance_cooldown_sweep_and_robust_summary.md`);
     en una iteracion posterior de perfil de scroll (2026-02-21), el candidato
     `jump+relative+ping_pong(seg12)` se valida en robusto `r7,w2` contra el
     control `jump+edge_bounce+forward` y muestra mejora parcial (`p95_build`
     y `tti`), pero regresion en raster/memoria y sin mejora de estabilidad CV
     (`30.87` vs `30.58`), por lo que tampoco se promueve como nuevo default
     (ver
     `benchmarks/results/experiments/20260221_scroll_profile_sweep_and_robust_summary.md`);
     re-check robusto posterior de `edge_bounce` con `scroll_steps=110` vs
     control `steps=90` confirma No-Go para `110`: aunque mejora medianas de
     performance, empeora fuerte la estabilidad (`%jank CV 30.58 -> 60.30`), y
     queda descartado para default (ver
     `benchmarks/results/experiments/20260221_scroll_profile_edge110_vs_edge90_summary.md`);
     sweep corto adicional de vecindad (`steps=80/90/100/110`, `r3,w1`) no
     muestra alternativa nueva para robusto (lidera `110` en corto, pero ya
     descartado por robusto; `100` empeora dispersion), por lo que se mantiene
     `steps=90` como base operativa (ver
     `benchmarks/results/experiments/20260221_scroll_profile_edge_steps_sweep_r3_w1/summary.md`);
     en paralelo, un sweep corto de `visible cache` bajo `edge90` (`r3,w1`)
     promueve `fixed_visible_cache_320` por señal inicial, pero el robusto
     `r7,w2` contra control revela falso positivo: sube `p95_build` y `tti`, y
     degrada fuerte estabilidad (`%jank CV +27.70 pp`), por lo que también
     queda No-Go para default (ver
     `benchmarks/results/experiments/20260221_visible_cache_sweep_and_robust_summary.md`);
     adicionalmente, el re-check robusto #2 de flush chunked (`chunk=24` vs
     `chunk=512`) revierte la señal favorable inicial y muestra degradacion en
     build/raster/estabilidad CV (`+38.52 pp`), por lo que se decide no
     promoverlo como default y dejarlo solo como tunable opt-in (ver
     `benchmarks/results/experiments/20260221_measure_flush_chunking_confirm2_robust_summary.md`);
     luego se ejecuta A/B robusto del cursor incremental de medicion
     (`OFFSTAGE_INCREMENTAL_MEASURE_SCAN_CURSOR`) en dos pares `r7,w2` con
     orden normal e invertido: en ambos pares, `cursor=true` empeora `TTI` y
     `%jank CV` frente a `cursor=false`, con mejora de memoria marginal, por lo
     que tambien queda No-Go como default y pasa a opt-in experimental (ver
     `benchmarks/results/experiments/20260221_scan_cursor_ab_robust_summary.md`);
     finalmente, se cierra el frente de `no_op` a nivel harness con
     auto-premeasure para `jump + edge_bounce`: robusto `r7,w2` vs
     `BENCH_PRE_MEASURE_SCROLL_STEPS=0` elimina `no_op_steps_avg` (`2.0 -> 0.0`)
     y mejora build/raster/jank con TTI neutro y costo moderado de memoria
     (`+2.15%`), por lo que se mantiene activo por default en el runner (ver
     `benchmarks/results/experiments/20260221_noop_strategy_autoprime_robust_summary.md`);
     en el ciclo siguiente, re-check corto `default80` vs `cons64` confirma que
     volver a `80/20/300/300` no conviene (falla estabilidad y empeora build),
     y el A/B robusto `r7,w2` de `incremental_load` sobre `cons64` muestra
     estabilidad equivalente pero degradacion de `p95_build` y `p95_raster`, por
     lo que tambien queda `NO_GO` para default (ver
     `benchmarks/results/experiments/20260221_card_incremental_ab_robust_summary.md`);
     en una iteracion adicional, `fixed_visible_cache_256` se promueve desde
     señal corta a robusto `r7,w2` y confirma falso positivo parcial: mejora
     levemente build/raster, pero cae en estabilidad CV (`FAIL`) y degrada `TTI`
     de forma relevante (`+12.85%`), por lo que tambien queda `NO_GO` (ver
     `benchmarks/results/experiments/20260221_card_fixed256_ab_robust_summary.md`).

## Prioridad P1 (siguiente)

1. Limpiar quality gate estatico del paquete.
   - Historia: como mantenedor, quiero `flutter analyze` limpio para evitar deuda
     de lints acumulada.
   - Criterios de aceptacion:
     - `flutter analyze` sin issues de severidad error/warning/info en rutas del
       paquete y herramientas de benchmark.
   - Estado 2026-02-13: cumplido (`flutter analyze --no-pub` sin issues).
2. Endurecer CI de varianza en card.
   - Historia: como equipo, quiero que la dispersion alta no pase inadvertida en
     corridas manuales de workflow.
   - Criterios de aceptacion:
     - workflow `card-variance` con opcion de enforcement activable por input.
     - artefacto CI incluye decision explicita PASS/FAIL por umbral de CV y MAD.
     - flujo consecutivo (`card-variance-consecutive`) expone enforcement por tanda
       y por decision final.
   - Estado 2026-02-13: cumplido (inputs CV+MAD en ambos workflows, summary
     consecutivo con gates por tanda y decision final).
3. Formalizar corte operativo de release (Go/No-Go).
   - Historia: como equipo, queremos un checkpoint auditable de salida para
     evitar cambios de criterio ad-hoc.
   - Criterios de aceptacion:
     - checklist tecnico con evidencia (`test`, `analyze`, performance).
     - decision explicita de alcance de release (default/opt-in).
   - Estado 2026-02-13: cumplido (`docs/RELEASE_CUT_20260213.md`).
   - Re-validado 2026-02-22 con gate Sprint 6 y cierre actualizado:
     `docs/RELEASE_CUT_20260222.md` (**NO-GO** para flip de default).
   - Preparacion de paquete de release 2026-02-22:
     - `pubspec.yaml` actualizado a `1.1.0`.
     - `CHANGELOG.md` cerrado para `1.1.0`.
     - `docs/RELEASE_NOTES_1_1_0.md` agregado.
     - `.pubignore` agregado para excluir artefactos internos/benchmarks/build.
     - `flutter pub publish --dry-run` validado con payload `28 KB`; queda solo
       warning por worktree con cambios sin commit.

## Prioridad P2 (exploracion deep)

1. Iteracion acotada de `sliverV3` con regla de corte estricta.
   - Historia: como equipo, queremos validar una ultima hipotesis deep sin
     expandir complejidad indefinidamente.
   - Criterios de aceptacion:
     - maximo 1 sprint de experimento.
     - si no supera a `offstageV1` en `dynamic_chip_10k` y `dynamic_card_50k`,
       se pausa linea deep y se documenta cierre.
   - Estado 2026-02-21: en progreso y con cierre parcial de frente card.
     - se habilito escenario dedicado `dynamic_card_50k_sliver_v3` en harness.
     - A/B robusto `r7,w2` (control `offstageV1_cons64` vs candidato `sliverV3`)
       muestra mejora de `p95_build`/`p95_raster`/memoria, pero regresion de
       `TTI` y fallo del criterio estricto consecutivo (`cv`, `cv_and_mad`).
     - decision del corte card: `NO_GO` para promover `sliverV3` como default.
     - evidencia:
       - `benchmarks/results/experiments/20260221_card_sliverv3_ab_robust_summary.md`
       - `benchmarks/results/experiments/20260221_card_sliverv3_ab_robust_summary.json`
     - re-check puntual de optimizacion `TTI` en `sliverV3` (fill-check dirigido):
       - cambio:
         - `lib/src/dynamic_lazy_wrap_sliver_v3.dart`
         - test: `test/dynamic_lazy_wrap_sliver_v3_test.dart`
       - robusto `r7,w2`:
         - mejora confirmada vs control en `p95_build`, `p95_raster`, memoria y
           `TTI` (`-6.64%`), pero con `%jank CV=194.24` (fuera de umbral).
       - decision:
         - mantiene `NO_GO` para default por criterio estricto de estabilidad CV.
       - evidencia:
         - `benchmarks/results/experiments/20260221_card_sliverv3_ttiopt_ab_robust_summary.md`
         - `benchmarks/results/experiments/20260221_card_sliverv3_ttiopt_ab_robust_summary.json`
     - spike corto adicional (`large-jump cache throttling` en render):
       - A/B corto `r3,w1` mejora build/raster pero empeora `TTI` y no aporta
         mejora de estabilidad (`CV` ya en `0` en ambos).
       - decision: `NO_GO` y rollback en codigo para no arrastrar complejidad.
     - evidencia:
       - `benchmarks/results/experiments/20260221_card_sliverv3_jumpcache_ab_short_summary.md`
       - `benchmarks/results/experiments/20260221_card_sliverv3_jumpcache_ab_short_summary.json`
     - diagnostico robusto por segmento (`r7,w2`, `segments=6`):
       - se agrega trazabilidad por tramo de scroll en harness/report.
       - hotspot primario detectado en `s0` con unico evento `>2x` del corte.
       - A/B de control confirma que `s0` no es exclusivo de `sliverV3`, pero
         en `sliverV3` aparece con mayor severidad de pico
         (`max_total_ms_max +41.71%` vs `offstageV1`).
       - decision: mantener `NO_GO` para default y enfocar siguiente hipotesis
         en costo del primer tramo medido.
       - evidencia:
         - `benchmarks/results/experiments/20260221_card_sliverv3_segmentdiag_ab_robust_summary.md`
         - `benchmarks/results/experiments/20260221_card_sliverv3_segmentdiag_ab_robust_summary.json`
         - `benchmarks/results/experiments/20260221_card_segmentdiag_sliverv3_vs_offstage_summary.md`
         - `benchmarks/results/experiments/20260221_card_segmentdiag_sliverv3_vs_offstage_summary.json`
     - mitigacion puntual de `s0` (load-step defer en scroll):
       - cambio en `lib/src/dynamic_lazy_wrap_sliver_v3.dart` para diferir
         `loadMore` al siguiente frame solo en trigger de scroll.
       - robusto `r7,w2` confirma reduccion fuerte de severidad en `s0`
         (`max_total_ms_max 46.741 -> 8.225`) y mejora de throughput.
       - tradeoff: `TTI` mediano empeora (`+4.29%` vs sliver previo), por lo
         que se mantiene `NO_GO` para default hasta resolver `TTI`.
       - evidencia:
         - `benchmarks/results/experiments/20260221_card_sliverv3_loadstepdefer_segmentdiag_summary.md`
         - `benchmarks/results/experiments/20260221_card_sliverv3_loadstepdefer_segmentdiag_summary.json`
     - experimento `startup batch cap` (revertido):
       - objetivo: recuperar `TTI` reduciendo costo del primer frame.
       - robusto `r7,w2`: mejora `TTI`, pero empeora build/raster y severidad
         de picos globales y en `s0`.
       - decision: `NO_GO` y rollback aplicado.
       - evidencia:
         - `benchmarks/results/experiments/20260221_card_sliverv3_startupcap_robust_report.md`
         - `benchmarks/results/experiments/20260221_card_sliverv3_startupcap_robust_summary.md`
         - `benchmarks/results/experiments/20260221_card_sliverv3_startupcap_robust_summary.json`
     - experimento `startup cacheExtent cap` (mantenido con guardas):
       - objetivo: limitar prefetch solo en arranque y promover cache tras el
         primer scroll real.
       - robusto `r7,w2`: mejora build/raster y cae `%jank` medio a `0.0`,
         con hotspot principal mas contenido.
       - tradeoff: `TTI` mediano sube levemente (`+1.71%` vs `loadstepdefer`).
       - hardening:
         - fix en `_onScroll` para promover cache tambien en modo sin batch.
         - test de regresion agregado para promotion post-scroll.
       - decision: mantener ajuste en codigo, pero continuar `NO_GO` para
         default de `sliverV3` hasta recuperar `TTI`.
       - evidencia:
         - `benchmarks/results/experiments/20260221_card_sliverv3_startupcachecap_robust_report.md`
         - `benchmarks/results/experiments/20260221_card_sliverv3_startupcachecap_robust_summary.md`
         - `benchmarks/results/experiments/20260221_card_sliverv3_startupcachecap_robust_summary.json`
     - retuning posterior de startup cache cap (caps `80/120/180/240/300`):
       - smoke `r3,w1` + robustos `r7,w2` de candidatos (`180/240/300`).
       - `cap180` y `cap240` quedan `NO_GO` por estabilidad/severidad relativa.
       - `cap300` se consolida como mejor compromiso.
       - se aplica hardening final:
         - default `_startupCacheExtentCapDefault=300`.
         - guard para no promover cache si el cap no aplica (evita setState
           no-op en flujo default).
       - robust final de default (`default300_guard`) vs `loadstepdefer`:
         - `build -9.89%`, `raster -3.29%`, `%jank -100%`, `TTI -1.17%`,
           `hot_max_total -64.72%`.
       - decision:
         - `GO` para tuning de startup cache en esta fase.
         - `NO_GO` aun para default del engine `sliverV3` (gap de `TTI` vs
           `offstageV1` pendiente).
     - evidencia:
       - `benchmarks/results/experiments/20260221_card_sliverv3_startupcache_tuning_summary.md`
       - `benchmarks/results/experiments/20260221_card_sliverv3_startupcache_tuning_summary.json`
     - gate Sprint 6 re-ejecutado con A/B `sliverV3` (`r5,w1`, linux):
       - runner compatible agregado: `benchmarks/run_sliver_v3_ab.dart`.
       - gate automatizado confirma **NO-GO** para default del engine.
       - fallan checks globales vs baseline Sprint 1 en:
         - `dynamic_chip_10k` (`%jank`, `p95_build_ms`)
         - `dynamic_card_50k` (`peak_memory_mb`, `p95_build_ms`)
       - pasan checks de higiene:
         - suite funcional, sin P0/P1, repeats minimos.
       - decision operativa:
         - mantener `sliverV3` como linea deep/opt-in y no promover default en
           esta fase.
       - evidencia:
         - `benchmarks/results/experiments/20260221_sliverv3_ab_r5_w1_report.md`
         - `benchmarks/results/experiments/20260221_sliverv3_ab_r5_w1.json`
       - `benchmarks/results/experiments/20260222_sprint6_gate_sliverv3_r5_w1_report.md`
       - `benchmarks/results/experiments/20260222_sprint6_gate_sliverv3_r5_w1_report.json`
       - `docs/RELEASE_CUT_20260222.md`

## Definicion de terminado (100%)

Se considera 100% de esta fase cuando:

1. Se cumplen los objetivos minimos globales del roadmap en evidencia robusta.
2. Existe decision final de engine para release (default y/o opt-in) con soporte
   en CI.
3. El paquete queda con tests y analisis estatico en verde.
