import 'package:flutter/material.dart';

import 'package:teqani_youtube_player/src/models/watermark_config.dart';

/// A widget that displays text and/or image watermarks over the video content.
class WatermarkOverlay extends StatelessWidget {

  /// Creates a WatermarkOverlay widget
  const WatermarkOverlay({
    super.key,
    this.textWatermark,
    this.imageWatermark,
  });

  /// The text watermark configuration
  final TextWatermarkConfig? textWatermark;
  
  /// The image watermark configuration
  final ImageWatermarkConfig? imageWatermark;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Text watermark
        if (textWatermark != null) _buildTextWatermark(),
        
        // Image watermark
        if (imageWatermark != null) _buildImageWatermark(),
      ],
    );
  }

  /// Build the text watermark positioned according to its configuration
  Widget _buildTextWatermark() {
    return Positioned(
      left: _getLeftPosition(textWatermark!.position, textWatermark!.padding.left),
      right: _getRightPosition(textWatermark!.position, textWatermark!.padding.right),
      top: _getTopPosition(textWatermark!.position, textWatermark!.padding.top),
      bottom: _getBottomPosition(textWatermark!.position, textWatermark!.padding.bottom),
      child: Text(
        textWatermark!.text,
        style: textWatermark!.style,
      ),
    );
  }

  /// Build the image watermark positioned according to its configuration
  Widget _buildImageWatermark() {
    return Positioned(
      left: _getLeftPosition(imageWatermark!.position, imageWatermark!.padding.left),
      right: _getRightPosition(imageWatermark!.position, imageWatermark!.padding.right),
      top: _getTopPosition(imageWatermark!.position, imageWatermark!.padding.top),
      bottom: _getBottomPosition(imageWatermark!.position, imageWatermark!.padding.bottom),
      child: SizedBox(
        width: imageWatermark!.size.width,
        height: imageWatermark!.size.height,
        child: Opacity(
          opacity: imageWatermark!.opacity,
          child: imageWatermark!.image,
        ),
      ),
    );
  }

  /// Get the left position based on watermark position
  double? _getLeftPosition(WatermarkPosition position, double paddingValue) {
    switch (position) {
      case WatermarkPosition.topLeft:
      case WatermarkPosition.bottomLeft:
        return paddingValue;
      case WatermarkPosition.center:
        return null; // Will be handled by alignment
      case WatermarkPosition.topRight:
      case WatermarkPosition.bottomRight:
        return null;
    }
  }

  /// Get the right position based on watermark position
  double? _getRightPosition(WatermarkPosition position, double paddingValue) {
    switch (position) {
      case WatermarkPosition.topRight:
      case WatermarkPosition.bottomRight:
        return paddingValue;
      case WatermarkPosition.center:
        return null; // Will be handled by alignment
      case WatermarkPosition.topLeft:
      case WatermarkPosition.bottomLeft:
        return null;
    }
  }

  /// Get the top position based on watermark position
  double? _getTopPosition(WatermarkPosition position, double paddingValue) {
    switch (position) {
      case WatermarkPosition.topLeft:
      case WatermarkPosition.topRight:
        return paddingValue;
      case WatermarkPosition.center:
        return null; // Will be handled by alignment
      case WatermarkPosition.bottomLeft:
      case WatermarkPosition.bottomRight:
        return null;
    }
  }

  /// Get the bottom position based on watermark position
  double? _getBottomPosition(WatermarkPosition position, double paddingValue) {
    switch (position) {
      case WatermarkPosition.bottomLeft:
      case WatermarkPosition.bottomRight:
        return paddingValue;
      case WatermarkPosition.center:
        return null; // Will be handled by alignment
      case WatermarkPosition.topLeft:
      case WatermarkPosition.topRight:
        return null;
    }
  }
}
