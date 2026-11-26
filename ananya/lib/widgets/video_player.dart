import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import 'package:ananya/l10n/app_localizations.dart';
import 'package:ananya/utils/constants.dart';

/// An embedded YouTube video inside a knowledge-hub article.
///
/// The embed is a WebView running YouTube's player, which is the fragile part:
/// it depends on the device's WebView build, on Play Services, and on YouTube
/// serving an embeddable page. When it fails it does so silently — a still
/// frame with a play triangle that does nothing when tapped. So the player is
/// no longer the only way through: every video also carries a link that opens
/// it in the YouTube app, which works when the embed does not.
class VideoPlayer extends StatefulWidget {
  final String? id;
  const VideoPlayer({required this.id, super.key});

  @override
  State<VideoPlayer> createState() => _VideoPlayerState();
}

class _VideoPlayerState extends State<VideoPlayer> {
  YoutubePlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    final id = widget.id;
    if (id == null || id.trim().isEmpty) return;

    _controller = YoutubePlayerController(
      initialVideoId: id.trim(),
      flags: const YoutubePlayerFlags(
        autoPlay: false,
        // Was muted. An explainer about menstrual health with no sound is not
        // a video that "plays" in any sense the viewer cares about — she taps
        // it, sees pictures move, hears nothing, and reasonably calls it
        // broken. She controls the volume with the handset.
        mute: false,
        isLive: false,
      ),
    )..addListener(_watchForError);
  }

  void _watchForError() {
    final c = _controller;
    if (c == null || !mounted) return;
    if (c.value.hasError && !_failed) {
      debugPrint('YouTube embed failed: error ${c.value.errorCode}');
      setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    // There was no dispose at all. The controller holds a live WebView, so
    // every article opened left one running: memory the phone never got back,
    // and on a low-end handset enough of them to stop later videos loading.
    _controller?.removeListener(_watchForError);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _openInYouTube() async {
    final id = widget.id?.trim();
    if (id == null || id.isEmpty) return;
    try {
      await launchUrl(
        Uri.parse('https://www.youtube.com/watch?v=$id'),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('Could not open YouTube: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    if (_controller == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_failed)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
            decoration: BoxDecoration(
              color: ACCENT.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(Icons.videocam_off_outlined,
                    size: 28, color: ACCENT.withValues(alpha: 0.4)),
                const SizedBox(height: 10),
                Text(
                  loc.video_could_not_load,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: ACCENT.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          )
        else
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: YoutubePlayer(
              controller: _controller!,
              showVideoProgressIndicator: true,
              progressIndicatorColor: PRIMARY_COLOR,
              progressColors: const ProgressBarColors(
                playedColor: PRIMARY_COLOR,
                handleColor: PRIMARY_COLOR,
              ),
            ),
          ),
        const SizedBox(height: 8),
        // Always present, not only after a failure: the embed can also just
        // sit there without reporting an error, and then this is the only way
        // she gets to watch anything.
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _openInYouTube,
            icon: const Icon(Icons.open_in_new_rounded, size: 15),
            label: Text(
              loc.watch_on_youtube,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
            style: TextButton.styleFrom(
              foregroundColor: PRIMARY_COLOR,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
      ],
    );
  }
}
