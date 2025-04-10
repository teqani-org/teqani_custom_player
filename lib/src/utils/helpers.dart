library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Formats duration in seconds to a readable string in mm:ss format
String formatDuration(double seconds) {
  if (seconds.isNaN || seconds < 0) return '00:00';
  
  final duration = Duration(seconds: seconds.floor());
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final secs = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  
  return '$minutes:$secs';
}

/// Formats duration including hours (if applicable) in hh:mm:ss format
String formatDurationWithHours(double seconds) {
  if (seconds.isNaN || seconds < 0) return '00:00:00';
  
  final duration = Duration(seconds: seconds.floor());
  final hours = duration.inHours.toString().padLeft(2, '0');
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final secs = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  
  return duration.inHours > 0 ? '$hours:$minutes:$secs' : '$minutes:$secs';
}

/// Constrains a value between a minimum and maximum
double clamp(double value, double min, double max) {
  return math.min(math.max(value, min), max);
}

/// Gets a human-readable name for YouTube quality
String getQualityDisplayName(String quality) {
  switch (quality) {
    case 'tiny': return '144p';
    case 'small': return '240p';
    case 'medium': return '360p';
    case 'large': return '480p';
    case 'hd720': return '720p';
    case 'hd1080': return '1080p';
    case 'highres': return 'High Res';
    case 'default': return 'Auto';
    default: return quality;
  }
}

/// Safely prints debug information in debug mode only
void debugLog(String message, {bool enabled = true}) {
  if (enabled) {
    debugPrint('TeqaniYoutubePlayer: $message');
  }
} 