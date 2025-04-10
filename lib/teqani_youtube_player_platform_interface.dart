import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'teqani_youtube_player_method_channel.dart';

abstract class TeqaniYoutubePlayerPlatform extends PlatformInterface {
  /// Constructs a TeqaniYoutubePlayerPlatform.
  TeqaniYoutubePlayerPlatform() : super(token: _token);

  static final Object _token = Object();

  static TeqaniYoutubePlayerPlatform _instance = MethodChannelTeqaniYoutubePlayer();

  /// The default instance of [TeqaniYoutubePlayerPlatform] to use.
  ///
  /// Defaults to [MethodChannelTeqaniYoutubePlayer].
  static TeqaniYoutubePlayerPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [TeqaniYoutubePlayerPlatform] when
  /// they register themselves.
  static set instance(TeqaniYoutubePlayerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Get the platform version for debugging purposes
  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
  
  /// Initialize the YouTube player with a video ID and configuration
  Future<void> initialize({
    required String videoId,
    required bool autoPlay,
    required bool showControls,
    required bool fullscreenByDefault,
    required bool allowFullscreen,
    required bool muted,
    required bool loop,
    required double playbackRate,
    required bool enableCaption,
    required bool showRelatedVideos,
    int? startAt,
    int? endAt,
  }) {
    throw UnimplementedError('initialize() has not been implemented.');
  }
  
  /// Play the video
  Future<void> play() {
    throw UnimplementedError('play() has not been implemented.');
  }
  
  /// Pause the video
  Future<void> pause() {
    throw UnimplementedError('pause() has not been implemented.');
  }
  
  /// Seek to a specific position in the video
  Future<void> seekTo(double seconds) {
    throw UnimplementedError('seekTo() has not been implemented.');
  }
  
  /// Set the playback rate
  Future<void> setPlaybackRate(double rate) {
    throw UnimplementedError('setPlaybackRate() has not been implemented.');
  }
  
  /// Enter fullscreen mode
  Future<void> enterFullscreen() {
    throw UnimplementedError('enterFullscreen() has not been implemented.');
  }
  
  /// Exit fullscreen mode
  Future<void> exitFullscreen() {
    throw UnimplementedError('exitFullscreen() has not been implemented.');
  }
  
  /// Load a new video
  Future<void> loadVideo({
    required String videoId,
    int? startAt,
    required bool autoPlay,
  }) {
    throw UnimplementedError('loadVideo() has not been implemented.');
  }
  
  /// Mute the video
  Future<void> mute() {
    throw UnimplementedError('mute() has not been implemented.');
  }
  
  /// Unmute the video
  Future<void> unmute() {
    throw UnimplementedError('unmute() has not been implemented.');
  }
  
  /// Clean up resources
  Future<void> dispose() {
    throw UnimplementedError('dispose() has not been implemented.');
  }
}
