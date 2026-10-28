import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:zuno/core/theme/app_colors.dart';

/// Plays an already-uploaded video from [url], for a quick look before replacing or removing it.
///
/// Starts playing as soon as it is ready, and a tap pauses or resumes. Until then it holds a
/// fixed square with a spinner, so the dialog it sits in does not jump from nothing to full size.
///
/// One widget for the service and the service-item forms, which had grown identical private
/// copies of it.
class VideoPreviewPlayer extends StatefulWidget {
  const VideoPreviewPlayer({required this.url, super.key});

  /// The full address of the video, server base included.
  final String url;

  @override
  State<VideoPreviewPlayer> createState() => _VideoPreviewPlayerState();
}

class _VideoPreviewPlayerState extends State<VideoPreviewPlayer> {
  late final VideoPlayerController _controller =
      VideoPlayerController.networkUrl(Uri.parse(widget.url))
        ..initialize().then((_) {
          if (mounted) setState(() {});
          _controller.play();
        });

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return const SizedBox(
        width: 200,
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: Stack(
        alignment: Alignment.center,
        children: [
          VideoPlayer(_controller),
          GestureDetector(
            onTap: () => setState(
              () => _controller.value.isPlaying
                  ? _controller.pause()
                  : _controller.play(),
            ),
            child: AnimatedOpacity(
              opacity: _controller.value.isPlaying ? 0 : 1,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.play_circle_fill,
                size: 56,
                color: AppColors.onMediaMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
