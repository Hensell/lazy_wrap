# Release Notes `1.1.0`

## Resumen

`lazy_wrap` `1.1.0` consolida hardening del motor actual (`offstageV1`) y suma
una via publica **opt-in** para experimentar con motor alternativo (`sliverV2`)
sin romper compatibilidad.

## Highlights

1. Nuevo enum publico `LazyWrapEngine { offstageV1, sliverV2 }`.
2. Nuevo parametro `engine` en `LazyWrap.dynamic` y `DynamicLazyWrap`.
3. `sliverV2` disponible como motor experimental **opt-in**.
4. Fix de robustez en dynamic mode:
   - limpieza de colas/estado de medicion al achicar `itemCount`
   - evita builds fuera de rango cuando quedan mediciones pendientes
5. Mejoras internas de tuning/hardening para `offstageV1` (sin cambio de API).

## Compatibilidad

1. **Sin breaking changes**.
2. El engine default sigue siendo `offstageV1`.
3. El codigo existente compila sin cambios.

## Como probar `sliverV2` (opt-in)

```dart
LazyWrap.dynamic(
  itemCount: items.length,
  itemBuilder: (context, index) => buildItem(items[index]),
  engine: LazyWrapEngine.sliverV2,
  itemWidthBuilder: (index) => 120,
  itemHeightBuilder: (index) => 48,
)
```

## Limitaciones conocidas (`1.1.0`)

1. `sliverV2` es experimental y su alcance es mas acotado que `offstageV1`.
2. La linea `sliverV3` queda como exploracion deep interna y no se expone como
   API publica en esta version.
3. El default no cambia porque el gate de Sprint 6 confirmo `NO-GO` para flip
   de engine con la evidencia de benchmarks definida por el roadmap.

## Validacion de salida

1. Corte operativo final: `docs/RELEASE_CUT_20260222.md`
2. Gate Sprint 6 (A/B + decision): `benchmarks/results/experiments/20260222_sprint6_gate_sliverv3_r5_w1_report.md`
3. Changelog de cambios: `CHANGELOG.md`

## Recomendacion de adopcion

1. Mantener `offstageV1` en produccion por defecto.
2. Evaluar `sliverV2` de forma controlada en pantallas concretas.
3. Comparar métricas de scroll/memoria en escenarios reales antes de promover
   `sliverV2` en apps productivas.
