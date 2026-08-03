import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class VoiceNotePlayer extends StatefulWidget {
  final String url;
  final bool isLocal;
  final Color? activeColor;
  final Color? iconColor;
  final Color? textColor;

  const VoiceNotePlayer({
    super.key,
    required this.url,
    this.isLocal = false,
    this.activeColor,
    this.iconColor,
    this.textColor,
  });

  @override
  State<VoiceNotePlayer> createState() => _VoiceNotePlayerState();
}

class _VoiceNotePlayerState extends State<VoiceNotePlayer> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  StreamSubscription? _playerStateSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _positionSub;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();

    _playerStateSub = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
          if (state == PlayerState.completed) {
            _position = Duration.zero;
          }
        });
      }
    });

    _durationSub = _audioPlayer.onDurationChanged.listen((dur) {
      if (mounted) {
        setState(() {
          _duration = dur;
        });
      }
    });

    _positionSub = _audioPlayer.onPositionChanged.listen((pos) {
      if (mounted) {
        setState(() {
          _position = pos;
        });
      }
    });
  }

  @override
  void dispose() {
    _playerStateSub?.cancel();
    _durationSub?.cancel();
    _positionSub?.cancel();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (widget.url.isEmpty) return;

    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        setState(() => _isLoading = true);
        if (widget.isLocal) {
          await _audioPlayer.play(DeviceFileSource(widget.url));
        } else {
          await _audioPlayer.play(UrlSource(widget.url));
        }
      }
    } catch (e) {
      debugPrint('VoiceNotePlayer error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = widget.activeColor ?? Colors.blue[700]!;
    final iconCol = widget.iconColor ?? Colors.white;
    final textCol = widget.textColor ?? Colors.grey[800]!;

    final double maxVal = _duration.inMilliseconds.toDouble();
    final double curVal = _position.inMilliseconds.toDouble().clamp(0.0, maxVal > 0 ? maxVal : 0.0);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _togglePlay,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryColor,
              shape: BoxShape.circle,
            ),
            child: _isLoading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(iconCol),
                    ),
                  )
                : Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: iconCol,
                    size: 20,
                  ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                  activeTrackColor: primaryColor,
                  inactiveTrackColor: primaryColor.withValues(alpha: 0.3),
                  thumbColor: primaryColor,
                ),
                child: Slider(
                  value: curVal,
                  max: maxVal > 0 ? maxVal : 1.0,
                  onChanged: (val) {
                    _audioPlayer.seek(Duration(milliseconds: val.toInt()));
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(_position),
                    style: TextStyle(fontSize: 10, color: textCol),
                  ),
                  Text(
                    _formatDuration(_duration),
                    style: TextStyle(fontSize: 10, color: textCol),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
