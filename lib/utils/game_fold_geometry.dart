import 'dart:ui' show DisplayFeatureState, DisplayFeatureType, Rect;

import 'package:foldable/foldable.dart';
import 'package:material_ui/material_ui.dart';

/// Fold / crease geometry for crease-safe layouts (iPhone Duo, Android foldables).
///
/// Prefer [MediaQuery.displayFeatures] so widget tests (and Android) can inject
/// folds without a native hinge plugin. On iPhone Duo, also reads active
/// division regions from the `foldable` package when posture is partially open.
class GameFoldGeometry {
  GameFoldGeometry._();

  /// Active fold/hinge bounds while the device is partially open.
  ///
  /// Returns null when flat, closed, or when no division is reported.
  static Rect? activeDivisionBounds(BuildContext context) {
    final fromMediaQuery = _fromDisplayFeatures(context);
    if (fromMediaQuery != null) {
      return fromMediaQuery;
    }
    return _fromFoldablePackage(context);
  }

  static Rect? _fromDisplayFeatures(BuildContext context) {
    final features = MediaQuery.displayFeaturesOf(context);
    for (final feature in features) {
      final isDivision =
          feature.type == DisplayFeatureType.fold ||
          feature.type == DisplayFeatureType.hinge;
      if (!isDivision) {
        continue;
      }
      if (feature.state != DisplayFeatureState.postureHalfOpened) {
        continue;
      }
      final bounds = feature.bounds;
      if (!_isUsableBounds(bounds)) {
        continue;
      }
      return bounds;
    }
    return null;
  }

  static Rect? _fromFoldablePackage(BuildContext context) {
    final data = DuoMediaQuery.maybeOf(context);
    if (data == null || !data.isPartiallyOpen) {
      return null;
    }
    for (final region in data.activeDivisions) {
      final bounds = region.bounds;
      if (!_isUsableBounds(bounds)) {
        continue;
      }
      return bounds;
    }
    return null;
  }

  static bool _isUsableBounds(Rect bounds) {
    if (bounds.width <= 0 && bounds.height <= 0) {
      return false;
    }
    // Ignore degenerate zero-area bands that would still split layout.
    if (bounds.width < 1 && bounds.height < 1) {
      return false;
    }
    return true;
  }

  /// Vertical crease (book pose) vs horizontal crease (laptop pose).
  static bool isVerticalDivision(Rect bounds) {
    return bounds.height >= bounds.width;
  }

  /// Maps window-space [foldBounds] into the SafeArea child's local coordinates.
  static Rect toSafeAreaLocal(
    Rect foldBounds,
    EdgeInsets padding,
    Size safeSize,
  ) {
    final local = foldBounds.translate(-padding.left, -padding.top);
    final safeRect = Offset.zero & safeSize;
    final intersection = local.intersect(safeRect);
    if (intersection.isEmpty) {
      return local;
    }
    return intersection;
  }

  /// Padding that keeps children clear of [bounds] inside [viewport].
  static EdgeInsets avoidInsets(Size viewport, Rect bounds) {
    if (isVerticalDivision(bounds)) {
      final leftClear = bounds.left;
      final rightClear = viewport.width - bounds.right;
      return EdgeInsets.only(
        left: leftClear < rightClear ? 0 : bounds.width,
        right: rightClear <= leftClear ? 0 : bounds.width,
      );
    }
    final topClear = bounds.top;
    final bottomClear = viewport.height - bounds.bottom;
    return EdgeInsets.only(
      top: topClear < bottomClear ? 0 : bounds.height,
      bottom: bottomClear <= topClear ? 0 : bounds.height,
    );
  }
}
