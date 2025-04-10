import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teqani_youtube_player/teqani_youtube_player_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final MethodChannelTeqaniYoutubePlayer platform = MethodChannelTeqaniYoutubePlayer();
  const MethodChannel channel = MethodChannel('teqani_youtube_player');

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

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
