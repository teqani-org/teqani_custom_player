import 'package:flutter/foundation.dart';

/// Type of ad content.
enum AdType {
  image,
  video, // Video ads require further implementation (e.g., video_player package)
}

/// Specifies when an ad should be displayed.
enum AdDisplayTime {
  start,      // At the beginning of the video
  end,        // At the end of the video
  custom,     // At a specific time
  quarter,    // At 25% of video duration
  half,       // At 50% of video duration
  threeQuarter, // At 75% of video duration
  everyMinute,  // Every minute of video playback
  everyTwoMinutes, // Every two minutes of video playback
  everyFiveMinutes, // Every five minutes of video playback
}

/// Configuration for a single ad.
@immutable
class AdConfig {

  /// Creates a configuration for an advertisement.
  const AdConfig({
    required this.id,
    required this.adType,
    required this.adSource,
    required this.displayTime,
    this.customStartTime,
    required this.duration,
    this.isSkippable = false, // Default to not skippable for now
    this.skipOffset,
  }) : assert(
            displayTime != AdDisplayTime.custom || customStartTime != null,
            'customStartTime must be provided if displayTime is custom.');
  /// Unique identifier for the ad.
  final String id;

  /// The type of the ad content.
  final AdType adType;

  /// The source of the ad content (local path or URL).
  final String adSource;

  /// Specifies when the ad should be displayed.
  final AdDisplayTime displayTime;

  /// The specific time the ad should start if [displayTime] is [AdDisplayTime.custom].
  final Duration? customStartTime;

  /// How long the ad should be displayed.
  final Duration duration;

  /// Whether the ad can be skipped (feature for future enhancement).
  final bool isSkippable;

  /// Time after which the skip button appears (feature for future enhancement).
  final Duration? skipOffset;
            
  // Basic equality override
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdConfig &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
} 