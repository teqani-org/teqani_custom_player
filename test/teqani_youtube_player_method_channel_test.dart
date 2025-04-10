import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teqani_youtube_player/teqani_youtube_player_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final MethodChannelTeqaniYoutubePlayer platform = MethodChannelTeqaniYoutubePlayer();
  const MethodChannel channel = MethodChannel('com.teqani.youtube_player/player');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        return '42';
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('initialize', () async {
    // Just verify it doesn't throw
    await platform.initialize(
      videoId: 'test123',
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
    // If it reaches here without exception, the test passes
    expect(true, isTrue);
  });
}
