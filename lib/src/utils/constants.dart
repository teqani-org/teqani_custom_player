library;

/// Default YouTube player parameters
class YouTubePlayerDefaults {
  /// Private constructor to prevent instantiation
  const YouTubePlayerDefaults._();
  
  /// Default player height
  static const double playerHeight = 200.0;
  
  /// Default player width
  static const double playerWidth = 300.0;
  
  /// Default player aspect ratio
  static const double aspectRatio = 16 / 9;
  
  /// Default autoplay setting
  static const bool autoPlay = true;
  
  /// Default controls visibility setting
  static const bool showControls = true;
  
  /// Default caption support
  static const bool enableCaption = true;
  
  /// Default controls time out in milliseconds
  static const int controlsTimeOut = 3000;
  
  /// Default player animation duration
  static const Duration animationDuration = Duration(milliseconds: 300);
}

/// YouTube player error codes
class YouTubeErrorCodes {
  /// Private constructor to prevent instantiation
  const YouTubeErrorCodes._();
  
  /// Invalid parameter value (2)
  static const int invalidParam = 2;
  
  /// HTML5 player error (5)
  static const int html5Error = 5;
  
  /// Video not found or removed (100)
  static const int videoNotFound = 100;
  
  /// Video cannot be embedded (101)
  static const int notEmbeddable = 101;
  
  /// Same as 101, for another reason (150)
  static const int notEmbeddable2 = 150;
} 