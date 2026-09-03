import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';

import 'ride_voice_message_player.dart';

class RideChatPage extends StatefulWidget {
  const RideChatPage({
    required this.rideRequestId,
    required this.senderRole,
    required this.senderName,
    required this.otherPartyName,
    super.key,
  });

  final String rideRequestId;
  final String senderRole;
  final String senderName;
  final String otherPartyName;

  @override
  State<RideChatPage> createState() => _RideChatPageState();
}

class _RideChatPageState extends State<RideChatPage> {
  static const int _voiceSampleRate = 16000;
  static const int _voiceChannels = 1;
  static const int _voiceBitsPerSample = 16;
  static const int _maxVoiceSeconds = 20;
  static const int _maxPcmBytes =
      _voiceSampleRate * (_voiceBitsPerSample ~/ 8) * _maxVoiceSeconds;

  final TextEditingController _messageController = TextEditingController();
  final AudioRecorder _recorder = AudioRecorder();

  bool _sending = false;
  bool _sendingVoice = false;
  bool _recording = false;
  bool _stoppingRecording = false;
  int _recordSeconds = 0;

  BytesBuilder? _pcmBuilder;
  StreamSubscription<Uint8List>? _recordSubscription;
  Completer<void>? _recordDoneCompleter;
  Timer? _recordTimer;

  String get _rideRequestId => widget.rideRequestId.trim();

  String get _senderRole {
    final String value = widget.senderRole.trim().toLowerCase();
    if (value == 'driver' || value == 'admin') {
      return value;
    }
    return 'customer';
  }

  String get _senderName {
    final String value = widget.senderName.trim();
    if (value.isNotEmpty) {
      return value;
    }

    switch (_senderRole) {
      case 'driver':
        return 'Ride Driver';
      case 'admin':
        return 'RD Admin';
      case 'customer':
      default:
        return 'Customer';
    }
  }

  DocumentReference<Map<String, dynamic>> get _rideRef =>
      FirebaseFirestore.instance.collection('ride_requests').doc(_rideRequestId);

  CollectionReference<Map<String, dynamic>> get _messages =>
      _rideRef.collection('messages');

  CollectionReference<Map<String, dynamic>> get _audioMessages =>
      _rideRef.collection('message_audio');

  @override
  void dispose() {
    _recordTimer?.cancel();
    _recordSubscription?.cancel();
    unawaited(_recorder.cancel());
    unawaited(_recorder.dispose());
    _messageController.dispose();
    super.dispose();
  }

  Future<bool> _rideChatIsActive() async {
    final DocumentSnapshot<Map<String, dynamic>> rideSnapshot =
        await _rideRef.get();
    final String status = rideSnapshot.data()?['status']
            ?.toString()
            .trim()
            .toLowerCase() ??
        '';
    return status == 'accepted' || status == 'in_progress';
  }

  Timestamp _evidenceExpiry() {
    return Timestamp.fromDate(
      DateTime.now().toUtc().add(const Duration(days: 90)),
    );
  }

  Future<void> _sendMessage() async {
    if (_sending || _sendingVoice || _recording) {
      return;
    }

    final User? user = FirebaseAuth.instance.currentUser;
    final String text = _messageController.text.trim();

    if (user == null) {
      _showMessage('Your session is not available. Please reopen the ride.');
      return;
    }

    if (_rideRequestId.isEmpty || text.isEmpty) {
      return;
    }

    if (text.length > 1000) {
      _showMessage('Message is too long. Maximum is 1000 characters.');
      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      if (!await _rideChatIsActive()) {
        _showMessage(
          'This ride chat is closed. The completed conversation is archived securely for Admin evidence.',
        );
        return;
      }

      final DocumentReference<Map<String, dynamic>> ref = _messages.doc();
      final Timestamp evidenceExpiresAt = _evidenceExpiry();

      await ref.set(
        <String, dynamic>{
          'messageId': ref.id,
          'rideRequestId': _rideRequestId,
          'senderUid': user.uid,
          'senderRole': _senderRole,
          'senderName': _senderName,
          'messageType': 'text',
          'text': text,
          'createdAt': FieldValue.serverTimestamp(),
          'evidenceExpiresAt': evidenceExpiresAt,
        },
      );

      if (!mounted) {
        return;
      }

      _messageController.clear();
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage('Could not send message: $error');
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  Future<void> _startVoiceRecording() async {
    if (_sending ||
        _sendingVoice ||
        _recording ||
        _stoppingRecording ||
        _rideRequestId.isEmpty) {
      return;
    }

    try {
      if (!await _rideChatIsActive()) {
        _showMessage('Voice message is available only while the ride is active.');
        return;
      }

      final bool permission = await _recorder.hasPermission();
      if (!permission) {
        _showMessage('Microphone permission is required for voice messages.');
        return;
      }

      final bool supported =
          await _recorder.isEncoderSupported(AudioEncoder.pcm16bits);
      if (!supported) {
        _showMessage('Voice recording is not supported on this device.');
        return;
      }

      final Stream<Uint8List> stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: _voiceSampleRate,
          numChannels: _voiceChannels,
        ),
      );

      _pcmBuilder = BytesBuilder(copy: false);
      _recordDoneCompleter = Completer<void>();

      _recordSubscription = stream.listen(
        (Uint8List chunk) {
          final BytesBuilder? builder = _pcmBuilder;
          if (builder == null || _stoppingRecording) {
            return;
          }

          final int remaining = _maxPcmBytes - builder.length;
          if (remaining <= 0) {
            unawaited(_finishVoiceRecording(send: true));
            return;
          }

          if (chunk.length <= remaining) {
            builder.add(chunk);
          } else {
            builder.add(chunk.sublist(0, remaining));
            unawaited(_finishVoiceRecording(send: true));
          }
        },
        onDone: () {
          final Completer<void>? completer = _recordDoneCompleter;
          if (completer != null && !completer.isCompleted) {
            completer.complete();
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          final Completer<void>? completer = _recordDoneCompleter;
          if (completer != null && !completer.isCompleted) {
            completer.complete();
          }
          if (mounted) {
            _showMessage('Voice recording stopped: $error');
          }
        },
      );

      if (!mounted) {
        await _recorder.cancel();
        return;
      }

      setState(() {
        _recording = true;
        _recordSeconds = 0;
      });

      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
        if (!mounted || !_recording) {
          timer.cancel();
          return;
        }

        setState(() {
          _recordSeconds += 1;
        });

        if (_recordSeconds >= _maxVoiceSeconds) {
          timer.cancel();
          unawaited(_finishVoiceRecording(send: true));
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage('Could not start voice recording: $error');
    }
  }

  Future<void> _finishVoiceRecording({required bool send}) async {
    if (!_recording || _stoppingRecording) {
      return;
    }

    _stoppingRecording = true;
    _recordTimer?.cancel();

    try {
      if (send) {
        await _recorder.stop();
      } else {
        await _recorder.cancel();
      }

      final Completer<void>? completer = _recordDoneCompleter;
      if (completer != null && !completer.isCompleted) {
        try {
          await completer.future.timeout(const Duration(milliseconds: 700));
        } on TimeoutException {
          // Enough audio has already been collected in memory.
        }
      }

      await _recordSubscription?.cancel();
      _recordSubscription = null;

      final Uint8List pcm = _pcmBuilder?.takeBytes() ?? Uint8List(0);
      final int seconds = _recordSeconds <= 0 ? 1 : _recordSeconds;

      _pcmBuilder = null;
      _recordDoneCompleter = null;

      if (mounted) {
        setState(() {
          _recording = false;
          _recordSeconds = 0;
        });
      }

      if (!send) {
        return;
      }

      if (pcm.length < 1600) {
        _showMessage('Voice message is too short. Please record again.');
        return;
      }

      final Uint8List wav = _buildWav(pcm);
      await _sendVoiceMessage(
        wavBytes: wav,
        durationSeconds: seconds > _maxVoiceSeconds
            ? _maxVoiceSeconds
            : seconds,
      );
    } catch (error) {
      if (mounted) {
        _showMessage('Could not finish voice message: $error');
      }
    } finally {
      _stoppingRecording = false;
      if (mounted && _recording) {
        setState(() {
          _recording = false;
          _recordSeconds = 0;
        });
      }
    }
  }

  Future<void> _sendVoiceMessage({
    required Uint8List wavBytes,
    required int durationSeconds,
  }) async {
    if (_sendingVoice || wavBytes.isEmpty) {
      return;
    }

    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showMessage('Your session is not available. Please reopen the ride.');
      return;
    }

    setState(() {
      _sendingVoice = true;
    });

    try {
      if (!await _rideChatIsActive()) {
        _showMessage('This ride chat is already closed.');
        return;
      }

      final DocumentReference<Map<String, dynamic>> messageRef =
          _messages.doc();
      final DocumentReference<Map<String, dynamic>> audioRef =
          _audioMessages.doc(messageRef.id);
      final Timestamp evidenceExpiresAt = _evidenceExpiry();
      final WriteBatch batch = FirebaseFirestore.instance.batch();

      batch.set(
        messageRef,
        <String, dynamic>{
          'messageId': messageRef.id,
          'rideRequestId': _rideRequestId,
          'senderUid': user.uid,
          'senderRole': _senderRole,
          'senderName': _senderName,
          'messageType': 'voice',
          'text': '',
          'voicePayloadId': messageRef.id,
          'voiceDurationSeconds': durationSeconds,
          'voiceByteLength': wavBytes.length,
          'voiceMimeType': 'audio/wav',
          'createdAt': FieldValue.serverTimestamp(),
          'evidenceExpiresAt': evidenceExpiresAt,
        },
      );

      batch.set(
        audioRef,
        <String, dynamic>{
          'messageId': messageRef.id,
          'rideRequestId': _rideRequestId,
          'senderUid': user.uid,
          'senderRole': _senderRole,
          'audioData': Blob(wavBytes),
          'contentType': 'audio/wav',
          'byteLength': wavBytes.length,
          'createdAt': FieldValue.serverTimestamp(),
          'evidenceExpiresAt': evidenceExpiresAt,
        },
      );

      await batch.commit();
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage('Could not send voice message: $error');
    } finally {
      if (mounted) {
        setState(() {
          _sendingVoice = false;
        });
      }
    }
  }

  Uint8List _buildWav(Uint8List pcm) {
    final int dataLength = pcm.length;
    final int byteRate =
        _voiceSampleRate * _voiceChannels * (_voiceBitsPerSample ~/ 8);
    final int blockAlign =
        _voiceChannels * (_voiceBitsPerSample ~/ 8);

    final Uint8List output = Uint8List(44 + dataLength);
    final ByteData header = ByteData.sublistView(output, 0, 44);

    void writeAscii(int offset, String value) {
      final List<int> bytes = ascii.encode(value);
      for (int index = 0; index < bytes.length; index++) {
        header.setUint8(offset + index, bytes[index]);
      }
    }

    writeAscii(0, 'RIFF');
    header.setUint32(4, 36 + dataLength, Endian.little);
    writeAscii(8, 'WAVE');
    writeAscii(12, 'fmt ');
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, _voiceChannels, Endian.little);
    header.setUint32(24, _voiceSampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, _voiceBitsPerSample, Endian.little);
    writeAscii(36, 'data');
    header.setUint32(40, dataLength, Endian.little);

    output.setRange(44, output.length, pcm);
    return output;
  }

  bool _messageIsMine(Map<String, dynamic> data) {
    final String role =
        data['senderRole']?.toString().trim().toLowerCase() ?? '';

    // Role-based alignment is intentional. It keeps Customer, Driver and
    // Admin messages on the correct side even if the same physical test
    // device has switched Firebase sessions during development.
    if (role == 'customer' || role == 'driver' || role == 'admin') {
      return role == _senderRole;
    }

    final String currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return currentUid.isNotEmpty &&
        data['senderUid']?.toString() == currentUid;
  }

  String _timeText(dynamic value) {
    if (value is! Timestamp) {
      return 'Sending...';
    }

    final DateTime time = value.toDate().toLocal();
    final String hour = time.hour.toString().padLeft(2, '0');
    final String minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _recordTimeText(int seconds) {
    final int minutes = seconds ~/ 60;
    final int remainder = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${remainder.toString().padLeft(2, '0')}';
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Ride Chat',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            Text(
              widget.otherPartyName.trim().isEmpty
                  ? 'Ride conversation'
                  : widget.otherPartyName.trim(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: _rideRequestId.isEmpty
            ? const Center(child: Text('Ride request is not available.'))
            : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: _rideRef.snapshots(),
                builder: (
                  BuildContext context,
                  AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>>
                      rideSnapshot,
                ) {
                  if (rideSnapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Could not verify ride chat status: '
                          '${rideSnapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  if (!rideSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final String status = rideSnapshot.data!.data()?['status']
                          ?.toString()
                          .trim()
                          .toLowerCase() ??
                      '';
                  final bool active =
                      status == 'accepted' || status == 'in_progress';

                  if (!active) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 58,
                              color: Colors.blueGrey,
                            ),
                            SizedBox(height: 14),
                            Text(
                              'Ride Chat Closed',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'After the ride ends, chat is no longer shown to the customer or driver. The original text and voice evidence remains securely available to Admin for the retention period.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return _activeChatBody();
                },
              ),
      ),
    );
  }

  Widget _activeChatBody() {
    return Column(
      children: <Widget>[
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text(
            'Security: sent text/voice messages cannot be edited, unsent or deleted by customer/driver.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _messages
                .orderBy('createdAt', descending: true)
                .limit(100)
                .snapshots(),
            builder: (
              BuildContext context,
              AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
            ) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Could not load ride chat: ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final List<QueryDocumentSnapshot<Map<String, dynamic>>> messages =
                  snapshot.data!.docs;

              if (messages.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No messages yet. Send a text or voice message to your ride partner.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                itemCount: messages.length,
                itemBuilder: (BuildContext context, int index) {
                  final QueryDocumentSnapshot<Map<String, dynamic>> document =
                      messages[index];
                  final Map<String, dynamic> data = document.data();
                  final bool mine = _messageIsMine(data);
                  final String senderName =
                      data['senderName']?.toString().trim() ?? '';
                  final String type =
                      data['messageType']?.toString().trim().toLowerCase() ??
                          'text';
                  final String text = data['text']?.toString().trim() ?? '';
                  final int voiceDuration =
                      data['voiceDurationSeconds'] is num
                          ? (data['voiceDurationSeconds'] as num).round()
                          : 0;

                  return Align(
                    alignment:
                        mine ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 560),
                      margin: const EdgeInsets.only(bottom: 9),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: mine
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.black.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          if (!mine && senderName.isNotEmpty) ...<Widget>[
                            Text(
                              senderName,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                          ],
                          if (type == 'voice')
                            RideVoiceMessagePlayer(
                              rideRequestId: _rideRequestId,
                              messageId: document.id,
                              durationSeconds: voiceDuration,
                            )
                          else
                            Text(
                              text,
                              style: const TextStyle(
                                fontSize: 15.5,
                                height: 1.3,
                              ),
                            ),
                          const SizedBox(height: 4),
                          Text(
                            _timeText(data['createdAt']),
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        _composer(),
      ],
    );
  }

  Widget _composer() {
    if (_recording) {
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(
            top: BorderSide(
              color: Colors.black.withValues(alpha: 0.08),
            ),
          ),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.red.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.mic_rounded, color: Colors.red),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Recording ${_recordTimeText(_recordSeconds)} / '
                        '${_recordTimeText(_maxVoiceSeconds)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'Cancel voice message',
              onPressed: _stoppingRecording
                  ? null
                  : () => _finishVoiceRecording(send: false),
              icon: const Icon(Icons.close_rounded),
            ),
            const SizedBox(width: 4),
            IconButton.filled(
              tooltip: 'Stop and send voice message',
              onPressed: _stoppingRecording
                  ? null
                  : () => _finishVoiceRecording(send: true),
              icon: const Icon(Icons.send_rounded),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: Colors.black.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: _messageController,
              minLines: 1,
              maxLines: 4,
              maxLength: 1000,
              enabled: !_sendingVoice,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Message...',
                counterText: '',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) {
                if (!_sending && !_sendingVoice) {
                  _sendMessage();
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 52,
            height: 52,
            child: IconButton.filledTonal(
              tooltip: 'Record voice message',
              onPressed: _sending || _sendingVoice
                  ? null
                  : _startVoiceRecording,
              icon: _sendingVoice
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.mic_rounded),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 52,
            height: 52,
            child: FilledButton(
              onPressed: _sending || _sendingVoice ? null : _sendMessage,
              style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: const CircleBorder(),
              ),
              child: _sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
            ),
          ),
        ],
      ),
    );
  }
}
