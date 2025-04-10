import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:teqani_youtube_player/teqani_youtube_player_method_channel.dart';
import 'package:teqani_youtube_player/teqani_youtube_player_platform_interface.dart';

class MockTeqaniYoutubePlayerPlatform 
    with MockPlatformInterfaceMixin
    implements TeqaniYoutubePlayerPlatform {

  bool initializeCalled = false;
  bool playCalled = false;
  bool pauseCalled = false;
  
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
  }) async {
    initializeCalled = true;
  }
  
  @override
  Future<void> play() async {
    playCalled = true;
  }
  
  @override
  Future<void> pause() async {
    pauseCalled = true;
  }
  
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

  test('Player methods call through to platform implementation', () async {
    final MockTeqaniYoutubePlayerPlatform fakePlatform = MockTeqaniYoutubePlayerPlatform();
    TeqaniYoutubePlayerPlatform.instance = fakePlatform;

    // Test initialize method
    await TeqaniYoutubePlayerPlatform.instance.initialize(
      videoId: 'testVideo',
      autoPlay: true,
      showControls: true,
      fullscreenByDefault: false,
      allowFullscreen: true,
      muted: false,
      loop: false,
      playbackRate: 1.0,
      enableCaption: true,
      showRelatedVideos: false,
    );
    expect(fakePlatform.initializeCalled, true);
    
    // Test play method
    await TeqaniYoutubePlayerPlatform.instance.play();
    expect(fakePlatform.playCalled, true);
    
    // Test pause method
    await TeqaniYoutubePlayerPlatform.instance.pause();
    expect(fakePlatform.pauseCalled, true);
  });
}
