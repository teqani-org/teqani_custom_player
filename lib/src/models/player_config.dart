import 'package:teqani_youtube_player/src/models/ad_config.dart';
import 'package:teqani_youtube_player/src/models/watermark_config.dart';
import 'package:teqani_youtube_player/src/models/youtube_style_options.dart';

/// Configuration for the TeqaniYoutubePlayer.
class PlayerConfig {
  
  /// Constructor for PlayerConfig
  const PlayerConfig({
    required this.videoId,
    this.autoPlay = true,
    this.showControls = true,
    this.fullscreenByDefault = false,
    this.allowFullscreen = true,
    this.muted = false,
    this.loop = false,
    this.textWatermark,
    this.imageWatermark,
    this.playbackRate = 1.0,
    this.enableCaption = true,
    this.enableJsApi = true,
    this.showRelatedVideos = false,
    this.startAt,
    this.endAt,
    this.enableHardwareAcceleration = true,
    this.volume = 1.0,
    this.styleOptions,
    this.ads,
  });
  /// The YouTube video ID to play
  final String videoId;
  
  /// Whether to automatically start playback when the player is ready
  final bool autoPlay;
  
  /// Whether to show the default player controls
  final bool showControls;
  
  /// Whether the player should start in fullscreen mode
  final bool fullscreenByDefault;
  
  /// Whether to allow fullscreen mode
  final bool allowFullscreen;
  
  /// Whether to mute the video by default
  final bool muted;
  
  /// Whether to loop the video when it ends
  final bool loop;
  
  /// Text watermark configuration (optional)
  final TextWatermarkConfig? textWatermark;
  
  /// Image watermark configuration (optional)
  final ImageWatermarkConfig? imageWatermark;
  
  /// Initial playback rate (1.0 = normal speed)
  final double playbackRate;
  
  /// Whether to use closed captions if available
  final bool enableCaption;
  
  /// Whether to enable the YouTube player API
  final bool enableJsApi;
  
  /// Whether to show the suggested videos when the video finishes
  final bool showRelatedVideos;
  
  /// Starting point in the video in seconds
  final int? startAt;
  
  /// Ending point in the video in seconds
  final int? endAt;
  
  /// Whether to enable hardware acceleration
  final bool? enableHardwareAcceleration;
  
  /// Initial volume (0.0 to 1.0)
  final double? volume;
  
  /// YouTube UI styling options
  final YouTubeStyleOptions? styleOptions;
  
  /// List of ads to display during playback
  final List<AdConfig>? ads;
  
  /// Create a copy of this configuration with modifications
  PlayerConfig copyWith({
    String? videoId,
    bool? autoPlay,
    bool? showControls,
    bool? fullscreenByDefault,
    bool? allowFullscreen,
    bool? muted,
    bool? loop,
    TextWatermarkConfig? textWatermark,
    ImageWatermarkConfig? imageWatermark,
    double? playbackRate,
    bool? enableCaption,
    bool? enableJsApi,
    bool? showRelatedVideos,
    int? startAt,
    int? endAt,
    bool? enableHardwareAcceleration,
    double? volume,
    YouTubeStyleOptions? styleOptions,
    List<AdConfig>? ads,
  }) {
    return PlayerConfig(
      videoId: videoId ?? this.videoId,
      autoPlay: autoPlay ?? this.autoPlay,
      showControls: showControls ?? this.showControls,
      fullscreenByDefault: fullscreenByDefault ?? this.fullscreenByDefault,
      allowFullscreen: allowFullscreen ?? this.allowFullscreen,
      muted: muted ?? this.muted,
      loop: loop ?? this.loop,
      textWatermark: textWatermark ?? this.textWatermark,
      imageWatermark: imageWatermark ?? this.imageWatermark,
      playbackRate: playbackRate ?? this.playbackRate,
      enableCaption: enableCaption ?? this.enableCaption,
      enableJsApi: enableJsApi ?? this.enableJsApi,
      showRelatedVideos: showRelatedVideos ?? this.showRelatedVideos,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      enableHardwareAcceleration: enableHardwareAcceleration ?? this.enableHardwareAcceleration,
      volume: volume ?? this.volume,
      styleOptions: styleOptions ?? this.styleOptions,
      ads: ads ?? this.ads,
    );
  }
}
