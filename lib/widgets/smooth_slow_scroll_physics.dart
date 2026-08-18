import 'package:flutter/material.dart';

/// A custom [ScrollPhysics] that provides controlled, slower, and weighted scrolling.
///
/// Dampens direct drag speed and fling velocity to eliminate hyper-fast scrolling
/// and maintain steady 60/120 FPS frame pacing.
class SmoothSlowScrollPhysics extends ScrollPhysics {
  final double dragFactor;
  final double flingFactor;

  const SmoothSlowScrollPhysics({
    super.parent = const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
    this.dragFactor = 0.85,
    this.flingFactor = 0.50,
  });

  @override
  SmoothSlowScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return SmoothSlowScrollPhysics(
      parent: buildParent(ancestor),
      dragFactor: dragFactor,
      flingFactor: flingFactor,
    );
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    if (parent != null) {
      return parent!.applyPhysicsToUserOffset(position, offset) * dragFactor;
    }
    return offset * dragFactor;
  }

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    final double dampenedVelocity = velocity * flingFactor;
    if (parent != null) {
      return parent!.createBallisticSimulation(position, dampenedVelocity);
    }
    return super.createBallisticSimulation(position, dampenedVelocity);
  }
}
