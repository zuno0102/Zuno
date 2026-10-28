import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/features/business_owner/presentation/widgets/service_media_slots.dart';
import 'package:zuno/features/catalog/domain/entities/app_options.dart';
import 'package:zuno/features/catalog/presentation/providers/catalog_providers.dart';

/// The photo and video slots the service and service-item forms share.
///
/// How many photo slots there are, and what the line under them says, are the server's to
/// decide — so both are checked against options other than the defaults, which is the case a
/// hard-coded number would get wrong.
void main() {
  const options = AppOptions(
    serviceImageSlots: 5,
    serviceVideoMaxSeconds: 45,
    serviceVideoMaxBytes: 40 * 1024 * 1024,
  );

  Future<ServiceMediaSelection> pumpSlots(WidgetTester tester) async {
    ServiceMediaSelection? media;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [currentAppOptionsProvider.overrideWithValue(options)],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                // Sized from the options, the way both forms create it.
                media ??= ServiceMediaSelection(
                  slotCount: ref
                      .read(currentAppOptionsProvider)
                      .serviceImageSlots,
                );
                return ServiceMediaSlots(media: media!, onError: (_) {});
              },
            ),
          ),
        ),
      ),
    );
    return media!;
  }

  testWidgets('one photo slot per slot the options allow, then the video', (
    tester,
  ) async {
    await pumpSlots(tester);

    expect(find.text('Photos & video'), findsOneWidget);
    expect(find.byIcon(Icons.add_a_photo_outlined), findsNWidgets(5));
    expect(find.byIcon(Icons.videocam_outlined), findsOneWidget);
  });

  testWidgets('the hint under the slots comes from the options', (
    tester,
  ) async {
    await pumpSlots(tester);

    expect(find.text(options.serviceMediaHint), findsOneWidget);
    expect(options.serviceMediaHint, contains('Up to 5 photos'));
    expect(options.serviceMediaHint, contains('45 seconds, 40MB max'));
  });

  testWidgets('a picked video lights the video slot up', (tester) async {
    final media = await pumpSlots(tester);

    media.setVideo(Uint8List(4), 'mp4');
    await tester.pump();

    expect(find.byIcon(Icons.videocam), findsOneWidget);
    expect(find.byIcon(Icons.videocam_outlined), findsNothing);
  });

  group('ServiceMediaSelection', () {
    test('removing a saved picture is remembered, so saving takes it down', () {
      final media = ServiceMediaSelection(
        slotCount: 3,
        savedImageUrl: (slot) => slot == 1 ? '/img/1.jpg' : null,
      );
      expect(media.hasChanges, isFalse);
      expect(media.existingImageUrl(1), '/img/1.jpg');

      media.removeImage(1);
      expect(media.isImageRemoved(1), isTrue);
      expect(media.existingImageUrl(1), isNull);
      expect(media.hasChanges, isTrue);

      // Picking a new one there replaces it rather than removing it.
      media.setImage(1, Uint8List(2));
      expect(media.isImageRemoved(1), isFalse);
      expect(media.pickedImage(1), isNotNull);
    });

    test('emptying a slot that held nothing saved is no change at all', () {
      final media = ServiceMediaSelection(slotCount: 3);

      media.removeImage(0);
      expect(media.isImageRemoved(0), isFalse);
      expect(media.hasChanges, isFalse);
    });

    test('removing the saved video is remembered; a new pick clears it', () {
      final media = ServiceMediaSelection(
        slotCount: 3,
        savedVideoUrl: '/vid/1.mp4',
      );

      media.removeVideo();
      expect(media.isVideoRemoved, isTrue);
      expect(media.existingVideoUrl, isNull);

      media.setVideo(Uint8List(2), 'quicktime');
      expect(media.isVideoRemoved, isFalse);
      expect(media.pickedVideoMimeSubtype, 'quicktime');
    });
  });
}
