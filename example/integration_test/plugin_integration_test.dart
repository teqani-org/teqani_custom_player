// This is a basic Flutter integration test.
//
// Since integration tests run in a full Flutter application, they can interact
// with the host side of a plugin implementation, unlike Dart unit tests.
//
// For more information about Flutter integration tests, please see
// https://flutter.dev/to/integration-testing


import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';

import 'package:teqani_youtube_player/teqani_youtube_player.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TeqaniYoutubePlayer basic test', (WidgetTester tester) async {
    // Create a controller first
    final controller = TeqaniYoutubePlayerController(
      initialConfig: PlayerConfig(
        videoId: 'dQw4w9WgXcQ', // Example video ID
        autoPlay: false,
      ),
    );
    
    // Build the player widget with the controller
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeqaniYoutubePlayer(
            controller: controller,
          ),
        ),
      ),
    );
    
    // Verify the controller is properly initialized
    expect(controller.initialConfig.videoId, 'dQw4w9WgXcQ');
    expect(controller.initialConfig.autoPlay, false);
    
    // Allow the widget to build
    await tester.pumpAndSettle();
  });
}
