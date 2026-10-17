import 'models.dart';

enum PlaybackRecoveryAction { alternative, refresh, stop }

class PlaybackRecovery {
  static const maxAttempts = 3;
  int _attempts = 0;
  bool _refreshed = false;
  Duration? _resumedPosition;
  DateTime? _resumedAt;

  void reset() {
    _attempts = 0;
    _refreshed = false;
    _resumedPosition = null;
    _resumedAt = null;
  }

  void resumed(Duration position, DateTime now) {
    if (_attempts == 0) return;
    _resumedPosition = position;
    _resumedAt = now;
  }

  void progressed(Duration position, DateTime now) {
    final resumedPosition = _resumedPosition;
    final resumedAt = _resumedAt;
    if (resumedPosition != null &&
        resumedAt != null &&
        position >= resumedPosition + const Duration(seconds: 15) &&
        now.difference(resumedAt) >= const Duration(seconds: 15)) {
      reset();
    }
  }

  PlaybackRecoveryAction next(PlaybackPlan plan) {
    if (_attempts >= maxAttempts) {
      return PlaybackRecoveryAction.stop;
    }
    if (plan.hasAlternative) {
      _attempts++;
      return PlaybackRecoveryAction.alternative;
    }
    if (!_refreshed) {
      _attempts++;
      _refreshed = true;
      return PlaybackRecoveryAction.refresh;
    }
    return PlaybackRecoveryAction.stop;
  }
}

class PlaybackHealth {
  static const stallTimeout = Duration(seconds: 20);
  Duration? _position;
  DateTime? _lastProgress;

  void reset() {
    _position = null;
    _lastProgress = null;
  }

  bool stalled({
    required Duration position,
    required bool playing,
    required bool foreground,
    required DateTime now,
  }) {
    if (!playing || !foreground || position != _position) {
      _position = position;
      _lastProgress = now;
      return false;
    }
    _lastProgress ??= now;
    return now.difference(_lastProgress!) >= stallTimeout;
  }
}
