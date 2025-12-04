## [1.0.0]

### 🚀 Major Release - Zero Layout Jumps

- **Offstage measurement**: Items are now measured invisibly before display
- **Zero layout jumps**: No more "5 items → 10 items" sudden changes
- **Fade-in animation**: Optional smooth appearance (`fadeInItems: true`)
- **Simplified API**: Removed `estimatedItemMainSize` (no longer needed)
- **Updated SDK**: Requires Flutter 3.38+ and Dart 3.10+

### Breaking Changes
- Removed `estimatedItemMainSize` and `estimatedItemCrossSize` params
- Removed `animateRows`, `cleanupOffscreenSizes`, `memoryBufferMultiplier` params

---

## [0.1.1] 
- Bug fixed.

## [0.1.0] 
- Update documentation.

## [0.0.9+3] 
- Update screenshot.

## [0.0.9+2] 
- Update screenshot.

## [0.0.9+1] 
- Update screenshot.

## [0.0.9] 
- Added horizontal scroll.

## [0.0.8+6] 
- Added constructors.

## [0.0.8+5] 
- Update dynamic lazy wrap.

## [0.0.8+4] 
- Update default values.

## [0.0.8+3] 
- Added live demo.

## [0.0.8+2] 
- Bug fixed.

## [0.0.8+1] 
### Fixed
- Fixed row alignment issue that caused overflow when using `MainAxisAlignment.center`.
- Wrapped `Row` in `SizedBox` with calculated width to prevent layout overflow.

## 0.0.8
- Added `rowAlignment` to allow horizontal alignment of children inside each row (e.g. center).

## 0.0.7
- Added fixed mode

## 0.0.6
- Performance improve

## 0.0.5
- Bug fixed.

## 0.0.4
- Bug fixed.

## 0.0.3
- Bug fixed.

## 0.0.2
- Added `rowAlignment` to allow horizontal alignment of children inside each row (e.g. center).

## 0.0.1
- Initial release.