import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:teqani_youtube_player/teqani_youtube_player_method_channel.dart';
import 'package:teqani_youtube_player/teqani_youtube_player_platform_interface.dart';

class MockTeqaniYoutubePlayerPlatform 
    with MockPlatformInterfaceMixin
    implements TeqaniYoutubePlayerPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
  
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
  }) async {}
  
  @override
  Future<void> play() async {}
  
  @override
  Future<void> pause() async {}
  
  @override
  Future<void> seekTo(double seconds) async {}
  
  @override
  Future<void> setPlaybackRate(double rate) async {}
  
  @override
  Future<void> enterFullscreen() async {}
  
  @override
  Future<void> exitFullscreen() async {}
  
  @override
  Future<void> loadVideo({
    required String videoId,
    int? startAt,
    required bool autoPlay,
  }) async {}
  
  @override
  Future<void> mute() async {}
  
  @override
  Future<void> unmute() async {}
  
  @override
  Future<void> dispose() async {}
}

void main() {
  final TeqaniYoutubePlayerPlatform initialPlatform = TeqaniYoutubePlayerPlatform.instance;

  test('$MethodChannelTeqaniYoutubePlayer is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelTeqaniYoutubePlayer>());
  });

  test('getPlatformVersion', () async {
    // We only need to mock the platform for this test
    final MockTeqaniYoutubePlayerPlatform fakePlatform = MockTeqaniYoutubePlayerPlatform();
    TeqaniYoutubePlayerPlatform.instance = fakePlatform;

    // Call getPlatformVersion on the platform instance, not on the widget
    expect(await TeqaniYoutubePlayerPlatform.instance.getPlatformVersion(), '42');
  });
}
