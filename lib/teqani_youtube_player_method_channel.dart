import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:teqani_youtube_player/teqani_youtube_player_platform_interface.dart';

/// An implementation of [TeqaniYoutubePlayerPlatform] that uses method channels.
class MethodChannelTeqaniYoutubePlayer extends TeqaniYoutubePlayerPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('com.teqani.youtube_player/player');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
  
  @override
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
  }) async {
    await methodChannel.invokeMethod<void>('initialize', {
      'videoId': videoId,
      'autoPlay': autoPlay,
      'showControls': showControls,
      'fullscreenByDefault': fullscreenByDefault,
      'allowFullscreen': allowFullscreen,
      'muted': muted,
      'loop': loop,
      'playbackRate': playbackRate,
      'enableCaption': enableCaption,
      'showRelatedVideos': showRelatedVideos,
      'startAt': startAt,
      'endAt': endAt,
    });
  }
  
  @override
  Future<void> play() async {
    await methodChannel.invokeMethod<void>('play');
  }
  
  @override
  Future<void> pause() async {
    await methodChannel.invokeMethod<void>('pause');
  }
  
  @override
  Future<void> seekTo(double seconds) async {
    await methodChannel.invokeMethod<void>('seekTo', {'seconds': seconds});
  }
  
  @override
  Future<void> setPlaybackRate(double rate) async {
    await methodChannel.invokeMethod<void>('setPlaybackRate', {'rate': rate});
  }
  
  @override
  Future<void> enterFullscreen() async {
    await methodChannel.invokeMethod<void>('enterFullscreen');
  }
  
  @override
  Future<void> exitFullscreen() async {
    await methodChannel.invokeMethod<void>('exitFullscreen');
  }
  
  @override
  Future<void> loadVideo({
    required String videoId,
    int? startAt,
    required bool autoPlay,
  }) async {
    await methodChannel.invokeMethod<void>('loadVideo', {
      'videoId': videoId,
      'startAt': startAt,
      'autoPlay': autoPlay,
    });
  }
  
  @override
  Future<void> mute() async {
    await methodChannel.invokeMethod<void>('mute');
  }
  
  @override
  Future<void> unmute() async {
    await methodChannel.invokeMethod<void>('unmute');
  }
  
  @override
  Future<void> dispose() async {
    await methodChannel.invokeMethod<void>('dispose');
  }
}
