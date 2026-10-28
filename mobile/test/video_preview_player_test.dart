import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:zuno/shared/widgets/video_preview_player.dart';

/// The saved-video preview shared by the service and service-item forms.
///
/// It takes the video's address and starts loading it at once. Until the player says it is
/// ready, it must hold its square with a spinner rather than drawing nothing or failing to build
/// — the moment checked here, with a stand-in player that never finishes loading.
void main() {
  late VideoPlayerPlatform realPlatform;
  late _StillLoadingPlatform fake;

  setUp(() {
    realPlatform = VideoPlayerPlatform.instance;
    fake = _StillLoadingPlatform();
    VideoPlayerPlatform.instance = fake;
  });
  tearDown(() => VideoPlayerPlatform.instance = realPlatform);

  testWidgets('loads the given address, with a spinner until it is ready', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: VideoPreviewPlayer(url: 'https://example.test/clip.mp4'),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(fake.requested, ['https://example.test/clip.mp4']);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.getSize(find.byType(VideoPreviewPlayer)),
      const Size(200, 200),
    );
  });
}

/// A player that accepts the video and then never reports it ready.
class _StillLoadingPlatform extends VideoPlayerPlatform {
  final requested = <String?>[];
  final _events = StreamController<VideoEvent>.broadcast();

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    requested.add(options.dataSource.uri);
    return 1;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => _events.stream;

  @override
  Future<void> dispose(int playerId) async {}
}
