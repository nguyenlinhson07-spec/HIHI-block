import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Strength of a haptic tap.
enum HapticStrength { selection, light, medium }

/// Fires the device's haptic feedback.
///
/// Kept behind an interface so widgets never call [HapticFeedback] directly
/// and tests can assert on what was requested.
abstract class GameHaptics {
  void impact(HapticStrength strength);
}

/// Real haptics.
class SystemGameHaptics implements GameHaptics {
  const SystemGameHaptics();

  @override
  void impact(HapticStrength strength) {
    // Fire and forget; a device without a vibrator just ignores it.
    switch (strength) {
      case HapticStrength.selection:
        HapticFeedback.selectionClick();
      case HapticStrength.light:
        HapticFeedback.lightImpact();
      case HapticStrength.medium:
        HapticFeedback.mediumImpact();
    }
  }
}

/// Does nothing. The default in tests.
class SilentGameHaptics implements GameHaptics {
  const SilentGameHaptics();

  @override
  void impact(HapticStrength strength) {}
}

/// Records requests instead of firing them. Test-only.
@visibleForTesting
class RecordingGameHaptics implements GameHaptics {
  final List<HapticStrength> impacts = <HapticStrength>[];

  @override
  void impact(HapticStrength strength) => impacts.add(strength);
}
