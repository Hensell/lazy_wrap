/// Rendering engine selection for `LazyWrap.dynamic`.
///
/// `offstageV1` is the production default.
/// `sliverV2` is experimental and currently optimized for vertical scrolling.
enum LazyWrapEngine {
  /// Existing production engine based on offstage measurement.
  offstageV1,

  /// Experimental sliver-based engine (opt-in).
  sliverV2,
}
