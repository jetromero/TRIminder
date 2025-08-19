import 'dart:async';
import 'package:flutter/foundation.dart';

/// Centralized timer management to optimize battery usage and reduce conflicts
/// Consolidates multiple small timers into efficient larger intervals
class TimerManager {
  static final TimerManager _instance = TimerManager._internal();
  factory TimerManager() => _instance;
  TimerManager._internal();

  // Master timer configuration
  static const Duration _masterInterval = Duration(seconds: 30); // Master tick every 30s

  // Timer state
  Timer? _masterTimer;
  int _tickCount = 0;
  
  // Registered callbacks
  final Map<String, VoidCallback> _every30SecondCallbacks = {};
  final Map<String, VoidCallback> _every5MinuteCallbacks = {};
  final Map<String, VoidCallback> _everyHourCallbacks = {};
  
  // State tracking
  bool _isRunning = false;

  /// Start the master timer system
  void start() {
    if (_isRunning) return;
    
    print('⏰ Starting consolidated timer manager');
    _isRunning = true;
    _tickCount = 0;
    
    _masterTimer = Timer.periodic(_masterInterval, _onMasterTick);
  }

  /// Stop all timers
  void stop() {
    if (!_isRunning) return;
    
    print('⏰ Stopping consolidated timer manager');
    _masterTimer?.cancel();
    _masterTimer = null;
    _isRunning = false;
    _tickCount = 0;
  }



  /// Register callback for every 30 seconds
  void registerEvery30Seconds(String id, VoidCallback callback) {
    _every30SecondCallbacks[id] = callback;
    print('⏰ Registered 30s callback: $id');
  }

  /// Register callback for every 5 minutes
  void registerEvery5Minutes(String id, VoidCallback callback) {
    _every5MinuteCallbacks[id] = callback;
    print('⏰ Registered 5m callback: $id');
  }

  /// Register callback for every hour
  void registerEveryHour(String id, VoidCallback callback) {
    _everyHourCallbacks[id] = callback;
    print('⏰ Registered 1h callback: $id');
  }

  /// Unregister callback
  void unregister(String id) {
    _every30SecondCallbacks.remove(id);
    _every5MinuteCallbacks.remove(id);
    _everyHourCallbacks.remove(id);
    print('⏰ Unregistered callback: $id');
  }

  /// Master tick handler - coordinates all timer events
  void _onMasterTick(Timer timer) {
    _tickCount++;
    
    try {
      // Every 30 seconds (every tick)
      for (final callback in _every30SecondCallbacks.values) {
        callback();
      }

      // Every 5 minutes (every 10 ticks: 10 * 30s = 5min)
      if (_tickCount % 10 == 0) {
        for (final callback in _every5MinuteCallbacks.values) {
          callback();
        }
      }

      // Every hour (every 120 ticks: 120 * 30s = 1hour)
      if (_tickCount % 120 == 0) {
        for (final callback in _everyHourCallbacks.values) {
          callback();
        }
      }

      // Reset tick count to prevent overflow (every 24 hours)
      if (_tickCount >= 2880) { // 2880 * 30s = 24 hours
        _tickCount = 0;
      }

    } catch (e) {
      print('❌ Error in timer manager tick: $e');
    }
  }

  /// Get timer statistics
  Map<String, dynamic> getStats() {
    return {
      'isRunning': _isRunning,
      'tickCount': _tickCount,
      'uptimeMinutes': (_tickCount * _masterInterval.inSeconds) / 60,
      'registered30s': _every30SecondCallbacks.length,
      'registered5m': _every5MinuteCallbacks.length,
      'registered1h': _everyHourCallbacks.length,
      'totalCallbacks': _every30SecondCallbacks.length + 
                        _every5MinuteCallbacks.length + 
                        _everyHourCallbacks.length,
    };
  }

  /// Force immediate execution of specific interval callbacks
  void triggerImmediate(String interval) {
    switch (interval) {
      case '30s':
        for (final callback in _every30SecondCallbacks.values) {
          callback();
        }
        break;
      case '5m':
        for (final callback in _every5MinuteCallbacks.values) {
          callback();
        }
        break;
      case '1h':
        for (final callback in _everyHourCallbacks.values) {
          callback();
        }
        break;
    }
  }

  /// Cleanup when app is terminated
  void dispose() {
    stop();
    _every30SecondCallbacks.clear();
    _every5MinuteCallbacks.clear();
    _everyHourCallbacks.clear();
  }
}
