# ADR-0002: Spike `sliverV3` (RenderSliver interno)

- Fecha: 2026-02-12
- Estado: Propuesto (resultado de spike)
- Dueño: equipo `lazy_wrap`

## Contexto

Luego del ADR-0001 (`sliverV2` no supera a `offstageV1`), se ejecuto un spike deep para validar una segunda arquitectura interna (`sliverV3`) apoyada en `RenderSliver` y geometria precalculada por filas.

Objetivo del spike: reducir costo de build/jank en `dynamic_chip_10k` sin exponer cambios de API publica.

## Decision evaluada

Se implemento un prototipo interno:

- `lib/src/dynamic_lazy_wrap_sliver_v3.dart`
- `lib/src/sliver_v3_layout_core.dart`
- `lib/src/sliver_v3_render_list.dart`

Alcance del prototipo:

1. Solo vertical
2. Geometria por filas precomputada
3. Virtualizacion por ventana visible en render layer
4. Sin exposicion publica (`LazyWrapEngine` no incluye `sliverV3`)

## Evidencia

Comando ejecutado:

- `dart run benchmarks/run_sliver_v3_triplet.dart --device linux --repeats 3`

Reporte fuente:

- `benchmarks/sliver_v3_triplet_report.md` (timestamp UTC `2026-02-12T14:00:48.502601Z`)

Medianas (`dynamic_chip_10k`):

- `offstageV1`: build `0.279`, raster `5.065`, jank `2.013`, memoria `163.973`, tti `213.477`
- `sliverV2`: build `38.100`, raster `9.705`, jank `31.081`, memoria `217.863`, tti `329.792`
- `sliverV3`: build `38.568`, raster `11.317`, jank `31.757`, memoria `219.984`, tti `333.857`

## Tradeoffs observados

Beneficios del spike:

1. Se valido la viabilidad tecnica de un path `RenderSliver` dedicado.
2. Se modularizo geometria y ventana visible con tests especificos.

Costos/riesgos:

1. `sliverV3` no logra mejora medible frente a `sliverV2` en la metrica critica (`p95_build_ms`/`% jank`) para chip denso.
2. Se mantiene una brecha muy alta frente a `offstageV1` en build/jank/memoria/tti.
3. Complejidad de mantenimiento sube sin retorno tecnico suficiente para release.

## Recomendacion

Decision: **NO-GO** para adopcion publica de `sliverV3` en este ciclo.

Acciones:

1. Mantener `offstageV1` como default y baseline de produccion.
2. Mantener `sliverV2`/`sliverV3` como lineas experimentales internas.
3. Si se retoma la via deep, iniciar una iteracion nueva con hipotesis mas fuerte de reduccion de build por item (no solo por fila) y gates de salida estrictos.

## Impacto en roadmap

1. Spike `sliverV3` completado con evidencia de benchmark repetible.
2. Se confirma que el techo tecnico actual, para escenario chip denso, sigue del lado `offstageV1`.
3. No se habilitan cambios de API ni flip de default por este spike.
