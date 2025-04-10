/// Configuration class for YouTube player UI styling options
class YouTubeStyleOptions {
  
  /// Hide all UI elements
  factory YouTubeStyleOptions.minimal() {
    return const YouTubeStyleOptions(
      showPlayButton: false,
      showPauseButton: false,
      showVolumeControls: false,
      showProgressBar: false,
      showFullscreenButton: false,
      showYouTubeLogo: false,
      showSettingsButton: false,
      showCaptionsButton: false,
      showTitle: false,
      showTopControls: false,
      showBottomControls: false,
    );
  }
  
  /// Constructor for YouTube Style Options
  // ignore: sort_unnamed_constructors_first
  const YouTubeStyleOptions({
    this.showPlayButton = true,
    this.showPauseButton = true,
    this.showVolumeControls = true,
    this.showProgressBar = true,
    this.showFullscreenButton = false,
    this.showYouTubeLogo = false,
    this.showSettingsButton = false,
    this.showCaptionsButton = false,
    this.showTitle = false,
    this.showTopControls = false,
    this.showBottomControls = true,
    this.customCSS,
  });
  
  /// Show all UI elements
  factory YouTubeStyleOptions.complete() {
    return const YouTubeStyleOptions(
      showPlayButton: true,
      showPauseButton: true,
      showVolumeControls: true,
      showProgressBar: true,
      showFullscreenButton: false,
      showYouTubeLogo: true,
      showSettingsButton: true,
      showCaptionsButton: true,
      showTitle: true,
      showTopControls: true,
      showBottomControls: true,
    );
  }
  
  /// Default YouTube style
  factory YouTubeStyleOptions.youtubeDefault() {
    return const YouTubeStyleOptions(
      showPlayButton: true,
      showPauseButton: true,
      showVolumeControls: true,
      showProgressBar: true,
      showFullscreenButton: false,
      showYouTubeLogo: true,
      showSettingsButton: true,
      showCaptionsButton: true,
      showTitle: true,
      showTopControls: true,
      showBottomControls: true,
    );
  }
  /// Show/hide the play button
  final bool showPlayButton;
  
  /// Show/hide the pause button
  final bool showPauseButton;
  
  /// Show/hide volume controls
  final bool showVolumeControls;
  
  /// Show/hide the progress bar
  final bool showProgressBar;
  
  /// Show/hide the full screen button
  final bool showFullscreenButton;
  
  /// Show/hide the YouTube logo
  final bool showYouTubeLogo;
  
  /// Show/hide the settings button
  final bool showSettingsButton;
  
  /// Show/hide the captions button
  final bool showCaptionsButton;
  
  /// Show/hide the title
  final bool showTitle;
  
  /// Show/hide top controls bar
  final bool showTopControls;
  
  /// Show/hide bottom controls bar
  final bool showBottomControls;
  
  /// Custom CSS to apply to the video player
  final String? customCSS;
  
  /// Create a copy of this configuration with modifications
  YouTubeStyleOptions copyWith({
    bool? showPlayButton,
    bool? showPauseButton,
    bool? showVolumeControls,
    bool? showProgressBar,
    bool? showFullscreenButton,
    bool? showYouTubeLogo,
    bool? showSettingsButton,
    bool? showCaptionsButton,
    bool? showTitle,
    bool? showTopControls,
    bool? showBottomControls,
    String? customCSS,
  }) {
    return YouTubeStyleOptions(
      showPlayButton: showPlayButton ?? this.showPlayButton,
      showPauseButton: showPauseButton ?? this.showPauseButton,
      showVolumeControls: showVolumeControls ?? this.showVolumeControls,
      showProgressBar: showProgressBar ?? this.showProgressBar,
      showFullscreenButton: showFullscreenButton ?? this.showFullscreenButton,
      showYouTubeLogo: showYouTubeLogo ?? this.showYouTubeLogo,
      showSettingsButton: showSettingsButton ?? this.showSettingsButton,
      showCaptionsButton: showCaptionsButton ?? this.showCaptionsButton,
      showTitle: showTitle ?? this.showTitle,
      showTopControls: showTopControls ?? this.showTopControls,
      showBottomControls: showBottomControls ?? this.showBottomControls,
      customCSS: customCSS ?? this.customCSS,
    );
  }
} 