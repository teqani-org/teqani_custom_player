import 'package:flutter/material.dart';

/// Position options for watermark placement on the video.
enum WatermarkPosition {
  /// Top left corner of the video
  topLeft,
  
  /// Top right corner of the video
  topRight,
  
  /// Bottom left corner of the video
  bottomLeft,
  
  /// Bottom right corner of the video
  bottomRight,
  
  /// Center of the video
  center
}

/// Duration mode for how long the watermark should be displayed.
enum WatermarkDuration {
  /// Watermark is always visible throughout video playback
  always,
  
  /// Watermark is visible for a specified period of time
  timed,
  
  /// Watermark appears and disappears based on custom logic
  custom
}

/// Configuration for a text watermark displayed over the video.
class TextWatermarkConfig {
  
  /// Constructor for text watermark configuration
  const TextWatermarkConfig({
    required this.text,
    required this.position,
    this.style = const TextStyle(
      color: Colors.white,
      fontSize: 16.0,
      fontWeight: FontWeight.bold,
    ),
    this.durationType = WatermarkDuration.always,
    this.durationSeconds,
    this.padding = const EdgeInsets.all(16.0),
  });
  /// The text to display as watermark
  final String text;
  
  /// Style to apply to the text watermark
  final TextStyle style;
  
  /// Position of the text watermark
  final WatermarkPosition position;
  
  /// Duration mode for the text watermark
  final WatermarkDuration durationType;
  
  /// Duration in seconds if [durationType] is [WatermarkDuration.timed]
  final int? durationSeconds;
  
  /// Padding around the watermark
  final EdgeInsets padding;
}

/// Configuration for an image watermark displayed over the video.
class ImageWatermarkConfig {
  
  /// Constructor for image watermark configuration
  const ImageWatermarkConfig({
    required this.image,
    required this.position,
    this.size = const Size(80, 40),
    this.durationType = WatermarkDuration.always,
    this.durationSeconds,
    this.opacity = 0.8,
    this.padding = const EdgeInsets.all(16.0),
  });
  /// The image widget to display as watermark
  final Widget image;
  
  /// Size of the image watermark
  final Size size;
  
  /// Position of the image watermark
  final WatermarkPosition position;
  
  /// Duration mode for the image watermark
  final WatermarkDuration durationType;
  
  /// Duration in seconds if [durationType] is [WatermarkDuration.timed]
  final int? durationSeconds;
  
  /// Opacity of the image (0.0 to 1.0)
  final double opacity;
  
  /// Padding around the watermark
  final EdgeInsets padding;
}
