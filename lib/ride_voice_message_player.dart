import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class RideVoiceMessagePlayer extends StatefulWidget {
  const RideVoiceMessagePlayer({
    required this.rideRequestId,
    required this.messageId,
    required this.durationSeconds,
    this.compact = false,
    super.key,
  });

  final String rideRequestId;
  final String messageId;
  final int durationSeconds;
  final bool compact;

  @override
  State<RideVoiceMessagePlayer> createState() =>
      _RideVoiceMessagePlayerState();
}

class _RideVoiceMessagePlayerState
    extends State<RideVoiceMessagePlayer> {
  final AudioPlayer _player = AudioPlayer();

  StreamSubscription<void>? _completeSubscription;
  StreamSubscription<PlayerState>? _stateSubscription;

  bool _loading = false;
  bool _sourceLoaded = false;
  bool _playing = false;

  @override
  void initState() {
    super.initState();

    _completeSubscription = _player.onPlayerComplete.listen((_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _playing = false;
        _sourceLoaded = false;
      });
    });

    _stateSubscription = _player.onPlayerStateChanged.listen(
      (PlayerState state) {
        if (!mounted) {
          return;
        }

        final bool playing = state == PlayerState.playing;
        if (_playing != playing) {
          setState(() {
            _playing = playing;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _completeSubscription?.cancel();
    _stateSubscription?.cancel();
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    if (_loading) {
      return;
    }

    try {
      if (_playing) {
        await _player.pause();
        return;
      }

      if (_sourceLoaded) {
        await _player.resume();
        return;
      }

      setState(() {
        _loading = true;
      });

      final DocumentSnapshot<Map<String, dynamic>> snapshot =
          await FirebaseFirestore.instance
              .collection('ride_requests')
              .doc(widget.rideRequestId.trim())
              .collection('message_audio')
              .doc(widget.messageId.trim())
              .get();

      final Map<String, dynamic>? data = snapshot.data();
      final dynamic rawAudio = data?['audioData'];

      if (!snapshot.exists || rawAudio is! Blob) {
        throw StateError('Voice evidence is not available.');
      }

      final Uint8List bytes = rawAudio.bytes;
      if (bytes.isEmpty) {
        throw StateError('Voice message is empty.');
      }

      await _player.play(
        BytesSource(
          bytes,
          mimeType: 'audio/wav',
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _sourceLoaded = true;
        _playing = true;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not play voice message: '
            '${error.toString().replaceFirst('Bad state: ', '')}',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  String get _durationText {
    final int safeSeconds = widget.durationSeconds < 0
        ? 0
        : widget.durationSeconds;
    final int minutes = safeSeconds ~/ 60;
    final int seconds = safeSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          width: widget.compact ? 38 : 42,
          height: widget.compact ? 38 : 42,
          child: IconButton.filledTonal(
            tooltip: _playing ? 'Pause voice message' : 'Play voice message',
            onPressed: _loading ? null : _togglePlayback,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    _playing
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                  ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Voice message',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                _durationText,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
