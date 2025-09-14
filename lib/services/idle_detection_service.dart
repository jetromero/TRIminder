import 'package:flutter/services.dart';

class IdleDetectionService {
  static const MethodChannel _channel = MethodChannel('idle_detection');
  
  static Future<bool> isDeviceMoving() async {
    try {
      final bool isMoving = await _channel.invokeMethod('isDeviceMoving');
      return isMoving;
    } catch (e) {
      print('Error checking device motion: $e');
      return false;
    }
  }
}