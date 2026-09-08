import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:url_launcher/url_launcher.dart';

class BusTicketBookingPage extends StatefulWidget {
  const BusTicketBookingPage({super.key});

  @override
  State<BusTicketBookingPage> createState() =>
      _BusTicketBookingPageState();
}

class _BusTicketBookingPageState
    extends State<BusTicketBookingPage> {
  static const Color _rdBlue = Color(0xFF1565C0);
  static const Color _rdGreen = Color(0xFF2E7D32);

  final stt.SpeechToText _speech = stt.SpeechToText();

  final TextEditingController _quickSearchController =
      TextEditingController();
  final TextEditingController _fromController =
      TextEditingController();
  final TextEditingController _toController =
      TextEditingController();
  final TextEditingController _emailController =
      TextEditingController();

  final List<TextEditingController> _passengerNameControllers =
      <TextEditingController>[
    TextEditingController(),
  ];

  final List<TextEditingController> _passengerPhoneControllers =
      <TextEditingController>[
    TextEditingController(),
  ];

  DateTime _travelDate =
      DateTime.now().add(const Duration(days: 1));
  int _passengerCount = 1;
  String _busTypeFilter = 'Any';
  String _paymentOption = 'pay_on_bus';
  String _onlinePaymentMethod = 'eSewa';

  bool _loadingAllBuses = true;
  bool _searching = false;
  bool _submitting = false;
  bool _isListening = false;
  bool _termsAccepted = false;

  List<_DemoBusSchedule> _allBuses = <_DemoBusSchedule>[];
  List<_DemoBusSchedule> _buses = <_DemoBusSchedule>[];
  _DemoBusSchedule? _selectedBus;
  final Set<String> _selectedSeats = <String>{};
  Set<String> _liveLockedSeats = <String>{};

  String? _boardingPoint;
  String? _dropPoint;

  @override
  void initState() {
    super.initState();
    _loadAllBuses();
  }

  @override
  void dispose() {
    _speech.cancel();
    _quickSearchController.dispose();
    _fromController.dispose();
    _toController.dispose();
    _emailController.dispose();

    for (final TextEditingController controller
        in _passengerNameControllers) {
      controller.dispose();
    }

    for (final TextEditingController controller
        in _passengerPhoneControllers) {
      controller.dispose();
    }

    super.dispose();
  }

  String _two(int value) =>
      value.toString().padLeft(2, '0');

  String _dateText(DateTime value) =>
      '${_two(value.day)}/${_two(value.month)}/${value.year}';

  String _timeText(DateTime value) {
    final int hour24 = value.hour;
    final int hour12 =
        hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
    final String amPm = hour24 >= 12 ? 'PM' : 'AM';

    return '${_two(hour12)}:${_two(value.minute)} $amPm';
  }

  String _durationText(
    DateTime departure,
    DateTime arrival,
  ) {
    final Duration duration =
        arrival.difference(departure);

    final int hours = duration.inHours;
    final int minutes = duration.inMinutes.remainder(60);

    if (hours <= 0) {
      return '$minutes min';
    }

    if (minutes == 0) {
      return '$hours hr';
    }

    return '$hours hr $minutes min';
  }

  String _lockId(
    String scheduleId,
    String seat,
  ) {
    return sha256
        .convert(
          utf8.encode('$scheduleId|$seat'),
        )
        .toString();
  }

  String _normalizeBusSearch(String value) {
    String search = value.trim().toLowerCase();

    const Map<String, String> aliases =
        <String, String>{
      'काठमाडौं': 'kathmandu',
      'काठमाण्डौं': 'kathmandu',
      'काठमाण्डौ': 'kathmandu',
      'पोखरा': 'pokhara',
      'चितवन': 'chitwan',
      'नारायणगढ': 'narayangadh',
      'बुटवल': 'butwal',
      'भैरहवा': 'bhairahawa',
      'विराटनगर': 'biratnagar',
      'धरान': 'dharan',
      'जनकपुर': 'janakpur',
      'नेपालगञ्ज': 'nepalgunj',
      'नेपालगंज': 'nepalgunj',
      'धनगढी': 'dhangadhi',
      'गोरखा': 'gorkha',
      'दमौली': 'damauli',
      'तनहुँ': 'tanahun',
      'हेटौडा': 'hetauda',
      'हेटौँडा': 'hetauda',
      'टु': ' to ',
      'देखि': ' ',
      'बाट': ' ',
      'सम्म': ' ',
    };

    for (final MapEntry<String, String> entry
        in aliases.entries) {
      search = search.replaceAll(
        entry.key,
        entry.value,
      );
    }

    return search
        .replaceAll('→', ' ')
        .replaceAll('-', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  List<_DemoBusSchedule> _filterAllBuses(
    String query,
  ) {
    final String search =
        _normalizeBusSearch(query);

    final Iterable<_DemoBusSchedule> source =
        _allBuses.where(
      (_DemoBusSchedule bus) =>
          _busTypeFilter == 'Any' ||
          bus.busType == _busTypeFilter,
    );

    if (search.isEmpty) {
      return source.toList();
    }

    return source.where(
      (_DemoBusSchedule bus) {
        final String searchable =
            '${bus.from} to ${bus.to} '
            '${bus.from} ${bus.to} '
            '${bus.operatorName} '
            '${bus.busName} '
            '${bus.busNumber} '
            '${bus.busType} '
            '${bus.busStaffName} '
            '${bus.busStaffPhone} '
            '${bus.operatorPhone}'
                .toLowerCase();

        final List<String> words = search
            .split(RegExp(r'\s+'))
            .where(
              (String word) =>
                  word.isNotEmpty &&
                  word != 'to',
            )
            .toList();

        return words.every(searchable.contains);
      },
    ).toList();
  }

  Future<void> _loadAllBuses() async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await FirebaseFirestore.instance
              .collection('bus_schedules')
              .get();

      final DateTime today = DateTime.now();
      final DateTime todayStart = DateTime(
        today.year,
        today.month,
        today.day,
      );

      final List<_DemoBusSchedule> buses =
          snapshot.docs
              .map(_DemoBusSchedule.fromDoc)
              .where(
                (_DemoBusSchedule bus) =>
                    bus.isActive &&
                    bus.isFareApproved &&
                    bus.operatorId.isNotEmpty &&
                    bus.seatCodes.isNotEmpty &&
                    !bus.arrivalAt.isBefore(todayStart),
              )
              .toList()
            ..sort(
              (
                _DemoBusSchedule first,
                _DemoBusSchedule second,
              ) =>
                  first.departureAt
                      .compareTo(second.departureAt),
            );

      if (!mounted) {
        return;
      }

      setState(() {
        _allBuses = buses;
        _buses = _filterAllBuses(
          _quickSearchController.text,
        );
      });
    } on FirebaseException catch (error) {
      if (mounted) {
        _message(
          'Could not load buses: '
          '${error.message ?? error.code}',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingAllBuses = false;
        });
      }
    }
  }

  Future<void> _toggleVoiceSearch() async {
    if (_isListening) {
      await _speech.stop();

      if (mounted) {
        setState(() {
          _isListening = false;
        });
      }
      return;
    }

    final bool available = await _speech.initialize(
      onStatus: (String status) {
        if (!mounted) {
          return;
        }

        if (status == 'done' ||
            status == 'notListening') {
          setState(() {
            _isListening = false;
          });
        }
      },
      onError: (error) {
        if (!mounted) {
          return;
        }

        setState(() {
          _isListening = false;
        });

        _message(
          'Voice search error: ${error.errorMsg}',
        );
      },
    );

    if (!available) {
      if (mounted) {
        _message(
          'Microphone / speech recognition is not available. Please allow microphone permission and try again.',
        );
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isListening = true;
      });
    }

    await _speech.listen(
      onResult: (result) {
        final String words =
            result.recognizedWords.trim();

        if (words.isEmpty || !mounted) {
          return;
        }

        _quickSearchController.value =
            TextEditingValue(
          text: words,
          selection: TextSelection.collapsed(
            offset: words.length,
          ),
        );

        _applyQuickSearch(words);
      },
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.search,
      ),
    );
  }

  void _applyQuickSearch(String value) {
    setState(() {
      _buses = _filterAllBuses(value);
      _selectedBus = null;
      _selectedSeats.clear();
      _liveLockedSeats = <String>{};
      _boardingPoint = null;
      _dropPoint = null;
      _termsAccepted = false;
    });
  }

  void _resetResults() {
    _buses = _filterAllBuses(
      _quickSearchController.text,
    );
    _selectedBus = null;
    _selectedSeats.clear();
    _boardingPoint = null;
    _dropPoint = null;
    _termsAccepted = false;
  }

  void _syncPassengerControllers() {
    while (_passengerNameControllers.length < _passengerCount) {
      _passengerNameControllers.add(
        TextEditingController(),
      );
    }

    while (_passengerPhoneControllers.length < _passengerCount) {
      _passengerPhoneControllers.add(
        TextEditingController(),
      );
    }

    while (_passengerNameControllers.length > _passengerCount) {
      final TextEditingController removed =
          _passengerNameControllers.removeLast();
      removed.dispose();
    }

    while (_passengerPhoneControllers.length > _passengerCount) {
      final TextEditingController removed =
          _passengerPhoneControllers.removeLast();
      removed.dispose();
    }
  }

  Future<void> _pickTravelDate() async {
    final DateTime now = DateTime.now();

    final DateTime? selected = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2, 12, 31),
      initialDate: _travelDate,
    );

    if (!mounted || selected == null) {
      return;
    }

    setState(() {
      _travelDate = selected;
      _resetResults();
    });
  }

  void _swapRoute() {
    final String from = _fromController.text;
    _fromController.text = _toController.text;
    _toController.text = from;

    setState(_resetResults);
  }

  Future<void> _searchBuses() async {
    final String from = _fromController.text.trim();
    final String to = _toController.text.trim();

    if (from.isEmpty || to.isEmpty) {
      _message('Please enter both From and To.');
      return;
    }

    if (from.toLowerCase() == to.toLowerCase()) {
      _message('From and To cannot be the same.');
      return;
    }

    setState(() {
      _searching = true;
      _selectedBus = null;
      _selectedSeats.clear();
      _liveLockedSeats = <String>{};
      _boardingPoint = null;
      _dropPoint = null;
      _termsAccepted = false;
    });

    try {
      final String routeDateKey =
          '${from.toLowerCase()}__${to.toLowerCase()}__'
          '${_travelDate.year}'
          '${_two(_travelDate.month)}'
          '${_two(_travelDate.day)}';

      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await FirebaseFirestore.instance
              .collection('bus_schedules')
              .where(
                'routeDateKey',
                isEqualTo: routeDateKey,
              )
              .get();

      final List<_DemoBusSchedule> buses =
          snapshot.docs
              .map(_DemoBusSchedule.fromDoc)
              .where(
                (_DemoBusSchedule bus) =>
                    bus.isActive &&
                    bus.isFareApproved &&
                    bus.operatorId.isNotEmpty &&
                    bus.seatCodes.isNotEmpty &&
                    (_busTypeFilter == 'Any' ||
                        bus.busType ==
                            _busTypeFilter),
              )
              .toList()
            ..sort(
              (
                _DemoBusSchedule first,
                _DemoBusSchedule second,
              ) =>
                  first.departureAt
                      .compareTo(second.departureAt),
            );

      if (!mounted) {
        return;
      }

      setState(() {
        _buses = buses;
      });

      if (buses.isEmpty) {
        _message(
          'No active bus found for this route/date.',
        );
      }
    } on FirebaseException catch (error) {
      if (mounted) {
        _message(
          'Could not search buses: '
          '${error.message ?? error.code}',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _searching = false;
        });
      }
    }
  }

  Future<void> _selectBus(_DemoBusSchedule bus) async {
    setState(() {
      _selectedBus = bus;
      _selectedSeats.clear();
      _liveLockedSeats = <String>{};
      _boardingPoint = bus.boardingPoints.first;
      _dropPoint = bus.dropPoints.first;
      _termsAccepted = false;
    });

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await FirebaseFirestore.instance
              .collection('bus_seat_locks')
              .where('scheduleId', isEqualTo: bus.scheduleId)
              .get();

      final Set<String> locked = snapshot.docs
          .where(
            (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                doc.data()['active'] == true,
          )
          .map(
            (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                doc.data()['seat']?.toString() ?? '',
          )
          .where((String seat) => seat.isNotEmpty)
          .toSet();

      if (!mounted || _selectedBus?.scheduleId != bus.scheduleId) {
        return;
      }

      setState(() {
        _liveLockedSeats = locked;
      });
    } on FirebaseException catch (error) {
      if (mounted) {
        _message(
          'Could not refresh seat locks: ${error.message ?? error.code}',
        );
      }
    }
  }

  void _toggleSeat(
    _DemoBusSchedule bus,
    String seat,
  ) {
    if (bus.unavailableSeats.contains(seat) ||
        _liveLockedSeats.contains(seat)) {
      return;
    }

    setState(() {
      if (_selectedSeats.contains(seat)) {
        _selectedSeats.remove(seat);
        _termsAccepted = false;
        return;
      }

      if (_selectedSeats.length >= _passengerCount) {
        _message(
          'You can select only $_passengerCount seat(s).',
        );
        return;
      }

      _selectedSeats.add(seat);
      _termsAccepted = false;
    });
  }

  bool _isValidEmail(String value) {
    final String email = value.trim();

    if (email.isEmpty) {
      return true;
    }

    return RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    ).hasMatch(email);
  }

  String _optionalEmailValue() {
    final String email =
        _emailController.text.trim();

    if (email.isEmpty || !_isValidEmail(email)) {
      return '';
    }

    return email;
  }

  bool _validateBooking() {
    final _DemoBusSchedule? bus = _selectedBus;

    if (bus == null) {
      _message('Please select a bus.');
      return false;
    }

    if (_selectedSeats.length != _passengerCount) {
      _message(
        'Please select exactly $_passengerCount seat(s).',
      );
      return false;
    }

    if (_boardingPoint == null || _dropPoint == null) {
      _message(
        'Please select boarding and drop points.',
      );
      return false;
    }

    for (int index = 0;
        index < _passengerNameControllers.length;
        index++) {
      if (_passengerNameControllers[index].text.trim().length <
          2) {
        _message(
          'Please enter passenger ${index + 1} full name.',
        );
        return false;
      }

      final String phone =
          _passengerPhoneControllers[index].text.trim();

      if (phone.length < 7 || phone.length > 30) {
        _message(
          'Please enter a valid mobile number for '
          'passenger ${index + 1}.',
        );
        return false;
      }
    }

    if (!_termsAccepted) {
      _message(
        'Please accept the booking safety declaration.',
      );
      return false;
    }

    return true;
  }

  Future<void> _submitBookingRequest() async {
    final User? user = FirebaseAuth.instance.currentUser;
    final _DemoBusSchedule? bus = _selectedBus;

    if (user == null) {
      _message('Customer session is not available.');
      return;
    }

    if (bus == null || !_validateBooking()) {
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      String customerId = '';

      try {
        final DocumentSnapshot<Map<String, dynamic>>
            customerDoc = await FirebaseFirestore.instance
                .collection('customers')
                .doc(user.uid)
                .get();

        customerId =
            customerDoc.data()?['customerId']
                    ?.toString()
                    .trim() ??
                '';
      } catch (_) {
        customerId = '';
      }

      final DocumentReference<Map<String, dynamic>>
          bookingRef = FirebaseFirestore.instance
              .collection('bus_ticket_bookings')
              .doc();

      final List<String> passengerNames =
          _passengerNameControllers
              .map(
                (TextEditingController controller) =>
                    controller.text.trim(),
              )
              .toList();

      final List<String> passengerPhones =
          _passengerPhoneControllers
              .map(
                (TextEditingController controller) =>
                    controller.text.trim(),
              )
              .toList();

      final List<String> selectedSeats =
          _selectedSeats.toList()..sort();

      final double baseFare =
          bus.farePerSeat * selectedSeats.length;
      final double totalFare = baseFare;
      final double rdCommissionAmount =
          baseFare * bus.commissionPercent / 100;
      final double operatorNetAmount =
          baseFare - rdCommissionAmount;

      final String bookingCode =
          'RDBUS-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

      final List<
              DocumentReference<Map<String, dynamic>>>
          lockRefs =
          <DocumentReference<Map<String, dynamic>>>[
        for (final String seat in selectedSeats)
          FirebaseFirestore.instance
              .collection('bus_seat_locks')
              .doc(
                _lockId(
                  bus.scheduleId,
                  seat,
                ),
              ),
      ];

      await FirebaseFirestore.instance.runTransaction(
        (Transaction transaction) async {
          final List<
                  DocumentSnapshot<Map<String, dynamic>>>
              lockDocs =
              <DocumentSnapshot<Map<String, dynamic>>>[];

          // All reads first.
          for (final DocumentReference<
                  Map<String, dynamic>>
              lockRef in lockRefs) {
            lockDocs.add(
              await transaction.get(lockRef),
            );
          }

          // Reject any seat already reserved/locked.
          for (int index = 0;
              index < selectedSeats.length;
              index++) {
            final DocumentSnapshot<Map<String, dynamic>>
                lockDoc = lockDocs[index];

            if (lockDoc.exists &&
                lockDoc.data()?['active'] == true) {
              throw StateError(
                'Seat ${selectedSeats[index]} has just been reserved by another customer.',
              );
            }
          }

          transaction.set(
            bookingRef,
            <String, dynamic>{
              'bookingId': bookingRef.id,
              'bookingCode': bookingCode,
              'bookingVersion': 2,
              'serviceType': 'bus',
              'customerAuthUid': user.uid,
              'customerId': customerId,
              'from': bus.from,
              'to': bus.to,
              'travelDate':
                  Timestamp.fromDate(bus.travelDate),
              'passengerCount': _passengerCount,
              'passengerNames': passengerNames,
              'passengerPhones': passengerPhones,
              'contactPhone': passengerPhones.first,
              'contactEmail':
                  _optionalEmailValue(),
              'scheduleId': bus.scheduleId,
              'operatorId': bus.operatorId,
              'operatorName': bus.operatorName,
              'operatorPhone': bus.operatorPhone,
              'busStaffName': bus.busStaffName,
              'busStaffPhone': bus.busStaffPhone,
              'busName': bus.busName,
              'busNumber': bus.busNumber,
              'busType': bus.busType,
              'departureAt':
                  Timestamp.fromDate(bus.departureAt),
              'arrivalAt':
                  Timestamp.fromDate(bus.arrivalAt),
              'boardingPoint': _boardingPoint,
              'dropPoint': _dropPoint,
              'selectedSeats': selectedSeats,
              'farePerSeat': bus.farePerSeat,
              'baseFare': baseFare,
              'serviceFee': 0.0,
              'commissionPercent': bus.commissionPercent,
              'rdCommissionAmount': rdCommissionAmount,
              'operatorNetAmount': operatorNetAmount,
              'totalFare': totalFare,
              'currency': 'Rs.',
              'scheduleSource': 'operator',
              'operatorVerified': false,
              'seatLockStatus': 'reserved',
              'paymentOption': _paymentOption,
              'paymentMethod':
                  _paymentOption == 'online'
                      ? _onlinePaymentMethod
                      : 'Pay on Bus',
              'paymentReference': '',
              'paymentStatus':
                  _paymentOption == 'online'
                      ? 'online_pending'
                      : 'pay_on_bus_pending',
              'bookingStatus':
                  'request_submitted',
              'ticketStatus': 'not_issued',
              'qrVerificationToken': '',
              'createdAt':
                  FieldValue.serverTimestamp(),
              'updatedAt':
                  FieldValue.serverTimestamp(),
            },
          );

          for (int index = 0;
              index < selectedSeats.length;
              index++) {
            transaction.set(
              lockRefs[index],
              <String, dynamic>{
                'lockId': lockRefs[index].id,
                'operatorId': bus.operatorId,
                'scheduleId': bus.scheduleId,
                'bookingId': bookingRef.id,
                'customerAuthUid': user.uid,
                'seat': selectedSeats[index],
                'status': 'reserved',
                'active': true,
                'reservedAt':
                    FieldValue.serverTimestamp(),
              },
            );
          }
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _liveLockedSeats.addAll(selectedSeats);
      });

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            icon: const Icon(
              Icons.event_seat_rounded,
              color: _rdGreen,
              size: 44,
            ),
            title: const Text(
              'Seats Reserved',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w900,
              ),
            ),
            content: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                children: <Widget>[
                  _summaryLine(
                    'Booking Code',
                    bookingCode,
                  ),
                  _summaryLine(
                    'Bus',
                    '${bus.operatorName} • ${bus.busName}',
                  ),
                  _summaryLine(
                    'Route',
                    '${bus.from} → ${bus.to}',
                  ),
                  _summaryLine(
                    'Departure',
                    _timeText(bus.departureAt),
                  ),
                  _summaryLine(
                    'Arrival',
                    _timeText(bus.arrivalAt),
                  ),
                  _summaryLine(
                    'Seats',
                    selectedSeats.join(', '),
                  ),
                  _summaryLine(
                    'Payment',
                    _paymentOption == 'online'
                        ? 'Online • $_onlinePaymentMethod'
                        : 'Pay on Bus',
                  ),
                  _summaryLine(
                    'Total',
                    'Rs. ${totalFare.toStringAsFixed(0)}',
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green
                          .withValues(alpha: 0.08),
                      borderRadius:
                          BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Your selected seats are reserved immediately in RD. Another customer cannot reserve the same seats while this reservation is active. The final travel ticket is issued after the required operator/payment confirmation.',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _openMyBusTickets();
                },
                child:
                    const Text('My Bus Tickets'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(dialogContext),
                child: const Text('Done'),
              ),
            ],
          );
        },
      );
    } on StateError catch (error) {
      if (!mounted) {
        return;
      }

      await _selectBus(bus);

      _message(error.message);
    } on FirebaseException catch (error) {
      if (mounted) {
        _message(
          'Could not reserve seats: '
          '${error.message ?? error.code}',
        );
      }
    } catch (error) {
      if (mounted) {
        _message(
          'Could not reserve seats: $error',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Widget _summaryLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 115,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(value),
          ),
        ],
      ),
    );
  }

  Future<void> _callPhone(String phone) async {
    final String number = phone.trim();

    if (number.isEmpty) {
      _message('Phone number is not available.');
      return;
    }

    final Uri uri = Uri(
      scheme: 'tel',
      path: number,
    );

    final bool opened = await launchUrl(uri);

    if (!opened && mounted) {
      _message('Could not open the phone dialer.');
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _openMyBusTickets() {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const MyBusTicketsPage(),
      ),
    );
  }

  void _openVerifyTicket() {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const BusTicketVerifyPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'Bus Ticket',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
        actions: <Widget>[
          IconButton(
            tooltip: 'Verify Ticket',
            onPressed: _openVerifyTicket,
            icon: const Icon(Icons.verified_outlined),
          ),
          IconButton(
            tooltip: 'My Bus Tickets',
            onPressed: _openMyBusTickets,
            icon: const Icon(
              Icons.confirmation_number_outlined,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 960,
            ),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                _quickSearchBar(),
                const SizedBox(height: 14),
                _securityBanner(),
                const SizedBox(height: 14),
                _searchCard(),
                if (_loadingAllBuses) ...<Widget>[
                  const SizedBox(height: 18),
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
                ],
                if (_searching) ...<Widget>[
                  const SizedBox(height: 24),
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
                ],
                if (!_searching && _buses.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 22),
                  const Text(
                    'Bus List • Choose Your Bus',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Compare route, departure/arrival time, fare, staff contact and live available seats. Then choose the bus you want.',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ..._buses.map(_busCard),
                ],
                if (!_searching &&
                    _buses.isEmpty &&
                    _fromController.text.trim().isNotEmpty &&
                    _toController.text.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 20),
                  const Center(
                    child: Text(
                      'No bus matched the selected filter.',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
                if (_selectedBus != null) ...<Widget>[
                  const SizedBox(height: 16),
                  _passengerCountCard(),
                  const SizedBox(height: 14),
                  _boardingDropCard(),
                  const SizedBox(height: 14),
                  _seatSelectionCard(),
                  const SizedBox(height: 14),
                  _passengerCard(),
                  const SizedBox(height: 14),
                  _reviewCard(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _quickSearchBar() {
    return Card(
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              'Find Your Bus',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'All published buses are shown below. Type or use the microphone to search by route, bus name, number, operator or staff contact.',
              style: TextStyle(
                color: Colors.grey.shade700,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _quickSearchController,
              textInputAction: TextInputAction.search,
              onChanged: _applyQuickSearch,
              decoration: InputDecoration(
                labelText: 'Quick Search / Voice Search',
                hintText:
                    'Type or say: Kathmandu to Pokhara',
                prefixIcon:
                    const Icon(Icons.search_rounded),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    IconButton(
                      tooltip: _isListening
                          ? 'Stop Voice Search'
                          : 'Voice Search',
                      onPressed: _toggleVoiceSearch,
                      icon: Icon(
                        _isListening
                            ? Icons.mic_rounded
                            : Icons.mic_none_rounded,
                        color: _isListening
                            ? Colors.red
                            : _rdBlue,
                      ),
                    ),
                    if (_quickSearchController
                        .text.isNotEmpty)
                      IconButton(
                        tooltip: 'Clear Search',
                        onPressed: () {
                          _quickSearchController.clear();
                          _applyQuickSearch('');
                        },
                        icon: const Icon(
                          Icons.close_rounded,
                        ),
                      ),
                  ],
                ),
                border: const OutlineInputBorder(),
              ),
            ),
            if (_isListening) ...<Widget>[
              const SizedBox(height: 8),
              const Row(
                children: <Widget>[
                  Icon(
                    Icons.graphic_eq_rounded,
                    color: Colors.red,
                    size: 20,
                  ),
                  SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Listening... Say a route, bus name or bus number.',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _securityBanner() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _rdBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _rdBlue.withValues(alpha: 0.22),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.shield_outlined,
            color: _rdBlue,
            size: 27,
          ),
          SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'RD Bus Ticket Safety',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'All active buses can be viewed before booking. When a booking is submitted, selected seats are reserved immediately to reduce double booking. Final ticket issuance still requires the official RD/operator flow.',
                  style: TextStyle(
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchCard() {
    return Card(
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              'Exact Route / Date Filter',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (
                BuildContext context,
                BoxConstraints constraints,
              ) {
                final bool wide = constraints.maxWidth >= 650;

                final Widget from = TextField(
                  controller: _fromController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'From',
                    hintText: 'City / Bus Park',
                    prefixIcon: Icon(
                      Icons.trip_origin_rounded,
                    ),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) {
                    if (_buses.isNotEmpty) {
                      setState(_resetResults);
                    }
                  },
                );

                final Widget to = TextField(
                  controller: _toController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'To',
                    hintText: 'City / Bus Park',
                    prefixIcon: Icon(
                      Icons.location_on_outlined,
                    ),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) {
                    if (_buses.isNotEmpty) {
                      setState(_resetResults);
                    }
                  },
                );

                final Widget swap = IconButton.filledTonal(
                  tooltip: 'Swap route',
                  onPressed: _swapRoute,
                  icon: const Icon(
                    Icons.swap_horiz_rounded,
                  ),
                );

                if (wide) {
                  return Row(
                    children: <Widget>[
                      Expanded(child: from),
                      const SizedBox(width: 8),
                      swap,
                      const SizedBox(width: 8),
                      Expanded(child: to),
                    ],
                  );
                }

                return Column(
                  children: <Widget>[
                    from,
                    const SizedBox(height: 8),
                    swap,
                    const SizedBox(height: 8),
                    to,
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: _pickTravelDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Travel Date',
                  prefixIcon: Icon(
                    Icons.calendar_month_rounded,
                  ),
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  _dateText(_travelDate),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _busTypeFilter,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Bus Type (optional)',
                prefixIcon: Icon(
                  Icons.directions_bus_rounded,
                ),
                border: OutlineInputBorder(),
              ),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem<String>(
                  value: 'Any',
                  child: Text('Any Bus Type'),
                ),
                DropdownMenuItem<String>(
                  value: 'AC Deluxe',
                  child: Text('AC Deluxe'),
                ),
                DropdownMenuItem<String>(
                  value: 'Sofa',
                  child: Text('Sofa'),
                ),
                DropdownMenuItem<String>(
                  value: 'EV',
                  child: Text('EV'),
                ),
                DropdownMenuItem<String>(
                  value: 'Night Bus',
                  child: Text('Night Bus'),
                ),
                DropdownMenuItem<String>(
                  value: 'Local',
                  child: Text('Local'),
                ),
              ],
              onChanged: (String? value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  _busTypeFilter = value;
                  _buses = _filterAllBuses(
                    _quickSearchController.text,
                  );
                  _selectedBus = null;
                  _selectedSeats.clear();
                  _liveLockedSeats = <String>{};
                  _boardingPoint = null;
                  _dropPoint = null;
                  _termsAccepted = false;
                });
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed:
                    _searching ? null : _searchBuses,
                icon: const Icon(Icons.search_rounded),
                label: const Text(
                  'Search Buses',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _busCard(_DemoBusSchedule bus) {
    final bool selected =
        _selectedBus?.scheduleId == bus.scheduleId;

    return Card(
      elevation: selected ? 3 : 1,
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: selected
            ? BoxDecoration(
                border: Border.all(
                  color: _rdBlue,
                  width: 1.6,
                ),
              )
            : null,
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleAvatar(
                  backgroundColor:
                      _rdBlue.withValues(alpha: 0.10),
                  child: const Icon(
                    Icons.directions_bus_rounded,
                    color: _rdBlue,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        bus.operatorName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '${bus.busName} • ${bus.busType}',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: _rdGreen,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        bus.from,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _timeText(bus.departureAt),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'Departure • ${_dateText(bus.departureAt)}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 8,
                  ),
                  child: Column(
                    children: <Widget>[
                      const Icon(
                        Icons.arrow_forward_rounded,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _durationText(
                          bus.departureAt,
                          bus.arrivalAt,
                        ),
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        bus.to,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _timeText(bus.arrivalAt),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'Arrival • ${_dateText(bus.arrivalAt)}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Bus No: ${bus.busNumber}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  'Rs. ${bus.farePerSeat.toStringAsFixed(0)} / seat',
                  style: const TextStyle(
                    color: _rdBlue,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            StreamBuilder<
                QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('bus_seat_locks')
                  .where(
                    'scheduleId',
                    isEqualTo: bus.scheduleId,
                  )
                  .snapshots(),
              builder: (
                BuildContext context,
                AsyncSnapshot<
                        QuerySnapshot<Map<String, dynamic>>>
                    snapshot,
              ) {
                final Set<String> locked =
                    <String>{};

                for (final QueryDocumentSnapshot<
                        Map<String, dynamic>>
                    doc in snapshot.data?.docs ??
                        <QueryDocumentSnapshot<
                            Map<String, dynamic>>>[]) {
                  final Map<String, dynamic> data =
                      doc.data();

                  if (data['active'] == true) {
                    final String seat =
                        data['seat']?.toString() ?? '';

                    if (seat.isNotEmpty) {
                      locked.add(seat);
                    }
                  }
                }

                final int total =
                    bus.seatCodes.length;
                final int remaining =
                    total - locked.length;
                final int available =
                    remaining < 0 ? 0 : remaining;

                return Row(
                  children: <Widget>[
                    Icon(
                      available > 0
                          ? Icons.event_seat_rounded
                          : Icons.block_rounded,
                      size: 19,
                      color: available > 0
                          ? _rdGreen
                          : Colors.red,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        available > 0
                            ? '$available of $total seats available now'
                            : 'FULL • No seats available',
                        style: TextStyle(
                          color: available > 0
                              ? _rdGreen
                              : Colors.red,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 9),
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Bus Staff: ${bus.busStaffName}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SelectableText(
                        bus.busStaffPhone,
                        style: TextStyle(
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Call Bus Staff',
                  onPressed: () =>
                      _callPhone(bus.busStaffPhone),
                  icon:
                      const Icon(Icons.call_rounded),
                ),
              ],
            ),
            Text(
              'Operator Office: ${bus.operatorPhone}',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 46,
              child: selected
                  ? FilledButton.tonalIcon(
                      onPressed: null,
                      icon: const Icon(
                        Icons.check_circle_rounded,
                      ),
                      label: const Text(
                        'Bus Selected',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    )
                  : FilledButton.icon(
                      onPressed: () =>
                          _selectBus(bus),
                      icon: const Icon(
                        Icons.check_rounded,
                      ),
                      label: const Text(
                        'Choose This Bus',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _passengerCountCard() {
    return Card(
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              'Booking • Passenger Count',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose how many people are travelling. Then select exactly the same number of available seats.',
              style: TextStyle(
                color: Colors.grey.shade700,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _passengerCount,
              decoration: const InputDecoration(
                labelText: 'Passengers',
                prefixIcon:
                    Icon(Icons.people_alt_rounded),
                border: OutlineInputBorder(),
              ),
              items: List<DropdownMenuItem<int>>.generate(
                6,
                (int index) {
                  final int value = index + 1;
                  return DropdownMenuItem<int>(
                    value: value,
                    child: Text(
                      '$value passenger${value == 1 ? '' : 's'}',
                    ),
                  );
                },
              ),
              onChanged: (int? value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  _passengerCount = value;
                  _syncPassengerControllers();
                  _selectedSeats.clear();
                  _termsAccepted = false;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _boardingDropCard() {
    final _DemoBusSchedule bus = _selectedBus!;

    return Card(
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              'Boarding & Drop Point',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _boardingPoint,
              decoration: const InputDecoration(
                labelText: 'Boarding Point',
                prefixIcon: Icon(
                  Icons.directions_walk_rounded,
                ),
                border: OutlineInputBorder(),
              ),
              items: bus.boardingPoints
                  .map(
                    (String point) =>
                        DropdownMenuItem<String>(
                      value: point,
                      child: Text(point),
                    ),
                  )
                  .toList(),
              onChanged: (String? value) {
                setState(() {
                  _boardingPoint = value;
                  _termsAccepted = false;
                });
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _dropPoint,
              decoration: const InputDecoration(
                labelText: 'Drop Point',
                prefixIcon: Icon(
                  Icons.location_on_outlined,
                ),
                border: OutlineInputBorder(),
              ),
              items: bus.dropPoints
                  .map(
                    (String point) =>
                        DropdownMenuItem<String>(
                      value: point,
                      child: Text(point),
                    ),
                  )
                  .toList(),
              onChanged: (String? value) {
                setState(() {
                  _dropPoint = value;
                  _termsAccepted = false;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _seatSelectionCard() {
    final _DemoBusSchedule bus = _selectedBus!;

    return Card(
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Select Seats • ${bus.seatLayout}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '${_selectedSeats.length}/$_passengerCount',
                  style: const TextStyle(
                    color: _rdBlue,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 5,
              children: <Widget>[
                _seatLegend(
                  Colors.white,
                  'Available',
                  border: Colors.grey,
                ),
                _seatLegend(
                  _rdBlue.withValues(alpha: 0.18),
                  'Selected',
                  border: _rdBlue,
                ),
                _seatLegend(
                  Colors.grey.shade300,
                  'Locked',
                  border: Colors.grey.shade400,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey
                    .withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: <Widget>[
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: 16,
                        bottom: 10,
                      ),
                      child: Icon(
                        Icons.airline_seat_recline_normal_rounded,
                        size: 28,
                      ),
                    ),
                  ),
                  for (int row = 1;
                      row <= bus.seatRows;
                      row++)
                    Padding(
                      padding:
                          const EdgeInsets.only(bottom: 8),
                      child: _seatRow(bus, row),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Selected: '
              '${_selectedSeats.isEmpty ? 'None' : (_selectedSeats.toList()..sort()).join(', ')}',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _seatRow(
    _DemoBusSchedule bus,
    int row,
  ) {
    Widget seat(String code) =>
        _seatButton(bus, code);

    bool has(String code) =>
        bus.seatCodes.contains(code);

    if (bus.seatLayout == '2+1') {
      final String a = '${row}A';
      final String b = '${row}B';
      final String c = '${row}C';

      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          if (has(a)) seat(a),
          const SizedBox(width: 7),
          if (has(b)) seat(b),
          const SizedBox(width: 32),
          if (has(c)) seat(c),
        ],
      );
    }

    if (bus.seatLayout == '1+1') {
      final String a = '${row}A';
      final String b = '${row}B';

      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          if (has(a)) seat(a),
          const SizedBox(width: 42),
          if (has(b)) seat(b),
        ],
      );
    }

    final String a = '${row}A';
    final String b = '${row}B';
    final String c = '${row}C';
    final String d = '${row}D';

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (has(a)) seat(a),
        const SizedBox(width: 7),
        if (has(b)) seat(b),
        const SizedBox(width: 28),
        if (has(c)) seat(c),
        const SizedBox(width: 7),
        if (has(d)) seat(d),
      ],
    );
  }

  Widget _seatLegend(
    Color color,
    String label, {
    required Color border,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: border),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _seatButton(
    _DemoBusSchedule bus,
    String seat,
  ) {
    final bool unavailable =
        bus.unavailableSeats.contains(seat) ||
        _liveLockedSeats.contains(seat);
    final bool selected =
        _selectedSeats.contains(seat);

    final Color background = unavailable
        ? Colors.grey.shade300
        : selected
            ? _rdBlue.withValues(alpha: 0.18)
            : Colors.white;

    final Color border = selected
        ? _rdBlue
        : Colors.grey.shade400;

    return InkWell(
      borderRadius: BorderRadius.circular(7),
      onTap:
          unavailable ? null : () => _toggleSeat(bus, seat),
      child: Container(
        width: 52,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: border,
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Text(
          seat,
          style: TextStyle(
            color: unavailable
                ? Colors.grey.shade600
                : selected
                    ? _rdBlue
                    : Colors.black87,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _passengerCard() {
    return Card(
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              'Passenger Details',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            for (int index = 0;
                index < _passengerNameControllers.length;
                index++) ...<Widget>[
              Text(
                'Passenger ${index + 1}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller:
                    _passengerNameControllers[index],
                textCapitalization:
                    TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Passenger ${index + 1} • Full Name',
                  prefixIcon:
                      const Icon(Icons.person_rounded),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller:
                    _passengerPhoneControllers[index],
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Passenger ${index + 1} • Mobile Number',
                  prefixIcon:
                      const Icon(Icons.phone_rounded),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
            ],
            const Divider(height: 22),
            TextField(
              controller: _emailController,
              keyboardType:
                  TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email (optional — can leave blank)',
                hintText: 'Optional',
                prefixIcon: Icon(Icons.email_rounded),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reviewCard() {
    final _DemoBusSchedule bus = _selectedBus!;
    final double baseFare =
        bus.farePerSeat * _selectedSeats.length;
    final double totalFare = baseFare;

    return Card(
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              'Review & Fare',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            _fareRow(
              'Seat Fare',
              'Rs. ${baseFare.toStringAsFixed(0)}',
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'No separate RD booking/service fee is added to the customer fare.',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const Divider(height: 20),
            _fareRow(
              'Requested Total',
              'Rs. ${totalFare.toStringAsFixed(0)}',
              strong: true,
            ),
            const SizedBox(height: 14),
            const Text(
              'Payment Option',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                ChoiceChip(
                  label: const Text('Pay on Bus'),
                  avatar: const Icon(
                    Icons.directions_bus_rounded,
                    size: 18,
                  ),
                  selected:
                      _paymentOption == 'pay_on_bus',
                  onSelected: (_) {
                    setState(() {
                      _paymentOption = 'pay_on_bus';
                      _termsAccepted = false;
                    });
                  },
                ),
                ChoiceChip(
                  label: const Text('Online Payment'),
                  avatar: const Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 18,
                  ),
                  selected:
                      _paymentOption == 'online',
                  onSelected: (_) {
                    setState(() {
                      _paymentOption = 'online';
                      _termsAccepted = false;
                    });
                  },
                ),
              ],
            ),
            if (_paymentOption == 'online') ...<Widget>[
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _onlinePaymentMethod,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Online Payment Method',
                  prefixIcon:
                      Icon(Icons.payments_rounded),
                  border: OutlineInputBorder(),
                ),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem<String>(
                    value: 'eSewa',
                    child: Text('eSewa'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'Khalti',
                    child: Text('Khalti'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'connectIPS',
                    child: Text('connectIPS'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'Bank',
                    child: Text('Bank / eBanking'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'Card',
                    child: Text('Debit / Credit Card'),
                  ),
                ],
                onChanged: (String? value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    _onlinePaymentMethod = value;
                    _termsAccepted = false;
                  });
                },
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: Colors.blue
                      .withValues(alpha: 0.07),
                  borderRadius:
                      BorderRadius.circular(10),
                ),
                child: const Text(
                  'Online payment is saved as Pending until '
                  'RD/Admin verifies the real payment. '
                  'The customer cannot mark it Paid.',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ),
            ] else ...<Widget>[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: Colors.green
                      .withValues(alpha: 0.07),
                  borderRadius:
                      BorderRadius.circular(10),
                ),
                child: const Text(
                  'Pay on Bus: the Bus Operator collects the amount '
                  'when the passenger travels and marks it collected.',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red
                    .withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Text(
                'Anti-Scam: Seat selection is protected by RD seat locks, '
                'but a booking is not a travel ticket until verified/issued. '
                'Do not trust screenshots, chat messages or personal payment '
                'requests outside the official RD flow.',
                style: TextStyle(
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity:
                  ListTileControlAffinity.leading,
              value: _termsAccepted,
              onChanged: (bool? value) {
                setState(() {
                  _termsAccepted = value ?? false;
                });
              },
              title: const Text(
                'I understand the selected seat is a booking request '
                'until operator/admin confirmation.',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _submitting
                    ? null
                    : _submitBookingRequest,
                icon: _submitting
                    ? const SizedBox.square(
                        dimension: 19,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.security_rounded,
                      ),
                label: const Text(
                  'Submit Secure Bus Booking',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fareRow(
    String label,
    String value, {
    bool strong = false,
  }) {
    final TextStyle style = TextStyle(
      fontSize: strong ? 18 : 14,
      fontWeight:
          strong ? FontWeight.w900 : FontWeight.w700,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(label, style: style),
          ),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class MyBusTicketsPage extends StatelessWidget {
  const MyBusTicketsPage({super.key});

  DateTime? _date(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toLocal();
    }

    return null;
  }

  double _number(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0.0;
  }

  String _two(int value) =>
      value.toString().padLeft(2, '0');

  String _dateTimeText(DateTime? value) {
    if (value == null) {
      return 'Not available';
    }

    final int hour24 = value.hour;
    final int hour12 =
        hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
    final String amPm = hour24 >= 12 ? 'PM' : 'AM';

    return '${_two(value.day)}/${_two(value.month)}/${value.year} '
        '${_two(hour12)}:${_two(value.minute)} $amPm';
  }

  String _label(String raw) {
    return raw
        .replaceAll('_', ' ')
        .split(' ')
        .where((String part) => part.isNotEmpty)
        .map(
          (String part) =>
              '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'My Bus Tickets',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
      ),
      body: user == null
          ? const Center(
              child: Text(
                'Customer session is not available.',
              ),
            )
          : StreamBuilder<
              QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('bus_ticket_bookings')
                  .where(
                    'customerAuthUid',
                    isEqualTo: user.uid,
                  )
                  .snapshots(),
              builder: (
                BuildContext context,
                AsyncSnapshot<
                        QuerySnapshot<Map<String, dynamic>>>
                    snapshot,
              ) {
                if (snapshot.connectionState ==
                        ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Could not load bus tickets.\n'
                        '${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final List<
                        QueryDocumentSnapshot<
                            Map<String, dynamic>>>
                    docs = <QueryDocumentSnapshot<
                        Map<String, dynamic>>>[
                  ...?snapshot.data?.docs,
                ];

                docs.sort(
                  (
                    QueryDocumentSnapshot<
                            Map<String, dynamic>>
                        first,
                    QueryDocumentSnapshot<
                            Map<String, dynamic>>
                        second,
                  ) {
                    final int firstMs = _date(
                              first.data()['createdAt'],
                            )
                            ?.millisecondsSinceEpoch ??
                        0;
                    final int secondMs = _date(
                              second.data()['createdAt'],
                            )
                            ?.millisecondsSinceEpoch ??
                        0;

                    return secondMs.compareTo(firstMs);
                  },
                );

                if (docs.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No bus booking requests yet.',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (
                    BuildContext context,
                    int index,
                  ) =>
                      const SizedBox(height: 10),
                  itemBuilder: (
                    BuildContext context,
                    int index,
                  ) {
                    final Map<String, dynamic> data =
                        docs[index].data();

                    final String bookingCode =
                        data['bookingCode']?.toString() ??
                            docs[index].id;
                    final String operatorName =
                        data['operatorName']?.toString() ??
                            'Bus Operator';
                    final String operatorPhone =
                        data['operatorPhone']?.toString() ?? '';
                    final String busStaffName =
                        data['busStaffName']?.toString() ?? '';
                    final String busStaffPhone =
                        data['busStaffPhone']?.toString() ?? '';
                    final String busName =
                        data['busName']?.toString() ??
                            'Bus';
                    final String from =
                        data['from']?.toString() ?? '';
                    final String to =
                        data['to']?.toString() ?? '';
                    final String status =
                        data['bookingStatus']?.toString() ??
                            'request_submitted';
                    final String paymentStatus =
                        data['paymentStatus']?.toString() ??
                            'not_started';
                    final String paymentOption =
                        data['paymentOption']?.toString() ??
                            'pay_on_bus';
                    final String paymentMethod =
                        data['paymentMethod']?.toString() ??
                            '';
                    final String ticketStatus =
                        data['ticketStatus']?.toString() ??
                            'not_issued';
                    final bool operatorVerified =
                        data['operatorVerified'] == true;
                    final String qrToken =
                        data['qrVerificationToken']
                                ?.toString()
                                .trim() ??
                            '';
                    final List<dynamic> rawSeats =
                        data['selectedSeats'] is List
                            ? data['selectedSeats'] as List<dynamic>
                            : <dynamic>[];
                    final String seats = rawSeats
                        .map((dynamic item) => item.toString())
                        .join(', ');

                    final List<dynamic> rawNames =
                        data['passengerNames'] is List
                            ? data['passengerNames'] as List<dynamic>
                            : <dynamic>[];
                    final List<dynamic> rawPhones =
                        data['passengerPhones'] is List
                            ? data['passengerPhones'] as List<dynamic>
                            : <dynamic>[];
                    final double total =
                        _number(data['totalFare']);

                    final bool issued =
                        operatorVerified &&
                        ticketStatus == 'issued' &&
                        qrToken.isNotEmpty;

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(15),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                CircleAvatar(
                                  child: Icon(
                                    issued
                                        ? Icons.verified_rounded
                                        : Icons
                                            .directions_bus_rounded,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        operatorName,
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight:
                                              FontWeight.w900,
                                        ),
                                      ),
                                      Text(
                                        busName,
                                        style: TextStyle(
                                          color:
                                              Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (issued)
                                  StreamBuilder<
                                      DocumentSnapshot<
                                          Map<String, dynamic>>>(
                                    stream: FirebaseFirestore
                                        .instance
                                        .collection(
                                          'bus_ticket_public_verify',
                                        )
                                        .doc(qrToken)
                                        .snapshots(),
                                    builder: (
                                      BuildContext context,
                                      AsyncSnapshot<
                                              DocumentSnapshot<
                                                  Map<String, dynamic>>>
                                          verifySnapshot,
                                    ) {
                                      final Map<String, dynamic>
                                          verifyData =
                                          verifySnapshot.data
                                                  ?.data() ??
                                              <String, dynamic>{};

                                      final bool
                                          boardingConfirmed =
                                          verifyData[
                                                  'boardingStatus'] ==
                                              'confirmed';

                                      return Chip(
                                        avatar: Icon(
                                          boardingConfirmed
                                              ? Icons
                                                  .how_to_reg_rounded
                                              : Icons
                                                  .confirmation_number_rounded,
                                          size: 17,
                                        ),
                                        label: Text(
                                          boardingConfirmed
                                              ? 'CONFIRMED'
                                              : 'ISSUED',
                                          style:
                                              const TextStyle(
                                            fontSize: 10,
                                            fontWeight:
                                                FontWeight.w900,
                                          ),
                                        ),
                                      );
                                    },
                                  )
                                else
                                  const Chip(
                                    label: Text(
                                      'NOT ISSUED',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight:
                                            FontWeight.w900,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const Divider(height: 24),
                            Text(
                              '$from → $to',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Departure: '
                              '${_dateTimeText(_date(data['departureAt']))}',
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Bus Staff: $busStaffName • $busStaffPhone',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Operator Office: $operatorPhone',
                            ),
                            const SizedBox(height: 5),
                            Text('Seats: $seats'),
                            const SizedBox(height: 8),
                            for (int passengerIndex = 0;
                                passengerIndex < rawNames.length;
                                passengerIndex++)
                              Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  'Passenger ${passengerIndex + 1}: '
                                  '${rawNames[passengerIndex]}'
                                  '${passengerIndex < rawPhones.length ? ' • ${rawPhones[passengerIndex]}' : ''}',
                                ),
                              ),
                            const SizedBox(height: 5),
                            Text(
                              'Booking: ${_label(status)}',
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Payment Option: '
                              '${paymentOption == 'online' ? 'Online' : 'Pay on Bus'}',
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Payment Method: $paymentMethod',
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Payment Status: '
                              '${_label(paymentStatus)}',
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Total: Rs. '
                              '${total.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(11),
                              decoration: BoxDecoration(
                                color: issued
                                    ? Colors.green.withValues(
                                        alpha: 0.08,
                                      )
                                    : Colors.orange.withValues(
                                        alpha: 0.09,
                                      ),
                                borderRadius:
                                    BorderRadius.circular(10),
                              ),
                              child: issued
                                  ? Column(
                                      children: <Widget>[
                                        StreamBuilder<
                                            DocumentSnapshot<
                                                Map<String, dynamic>>>(
                                          stream: FirebaseFirestore
                                              .instance
                                              .collection(
                                                'bus_ticket_public_verify',
                                              )
                                              .doc(qrToken)
                                              .snapshots(),
                                          builder: (
                                            BuildContext context,
                                            AsyncSnapshot<
                                                    DocumentSnapshot<
                                                        Map<String,
                                                            dynamic>>>
                                                verifySnapshot,
                                          ) {
                                            final Map<String, dynamic>
                                                verifyData =
                                                verifySnapshot.data
                                                        ?.data() ??
                                                    <String, dynamic>{};

                                            final bool
                                                boardingConfirmed =
                                                verifyData[
                                                        'boardingStatus'] ==
                                                    'confirmed';

                                            return Column(
                                              children: <Widget>[
                                                Text(
                                                  boardingConfirmed
                                                      ? 'BOARDING CONFIRMED ✅'
                                                      : 'Verified RD Bus Ticket',
                                                  textAlign:
                                                      TextAlign.center,
                                                  style: const TextStyle(
                                                    color: Colors.green,
                                                    fontWeight:
                                                        FontWeight.w900,
                                                  ),
                                                ),
                                                if (boardingConfirmed &&
                                                    verifyData[
                                                            'boardingConfirmedAt']
                                                        is Timestamp) ...<
                                                    Widget>[
                                                  const SizedBox(
                                                    height: 4,
                                                  ),
                                                  Text(
                                                    'Checked by Bus Staff • '
                                                    '${_dateTimeText(
                                                      (verifyData[
                                                                  'boardingConfirmedAt']
                                                              as Timestamp)
                                                          .toDate()
                                                          .toLocal(),
                                                    )}',
                                                    textAlign:
                                                        TextAlign.center,
                                                    style: TextStyle(
                                                      color: Colors
                                                          .grey.shade700,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 10),
                                        QrImageView(
                                          data: 'RDBUS|$qrToken',
                                          size: 170,
                                        ),
                                        const SizedBox(height: 8),
                                        SelectableText(
                                          'Verify Token: $qrToken',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    )
                                  : const Text(
                                      'Seat/ticket is not operator-confirmed '
                                      'yet. Do not treat this request as '
                                      'a travel ticket.',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        height: 1.35,
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 8),
                            SelectableText(
                              'Booking Code: $bookingCode',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 12,
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
    );
  }
}


class BusTicketVerifyPage extends StatefulWidget {
  const BusTicketVerifyPage({super.key});

  @override
  State<BusTicketVerifyPage> createState() =>
      _BusTicketVerifyPageState();
}

class _BusTicketVerifyPageState
    extends State<BusTicketVerifyPage> {
  final TextEditingController _controller =
      TextEditingController();

  bool _loading = false;
  bool _confirmingBoarding = false;
  Map<String, dynamic>? _result;
  String? _error;
  String? _verifiedToken;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _token(String raw) {
    final String value = raw.trim();
    return value.startsWith('RDBUS|')
        ? value.substring(6).trim()
        : value;
  }

  Future<void> _verify({
    String? rawToken,
    bool confirmBoardingIfAuthorized = false,
  }) async {
    final String token = _token(
      rawToken ?? _controller.text,
    );

    if (token.isEmpty) {
      setState(() {
        _error = 'Enter the RD verification token.';
        _result = null;
        _verifiedToken = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
      _verifiedToken = null;
    });

    try {
      final DocumentSnapshot<Map<String, dynamic>> doc =
          await FirebaseFirestore.instance
              .collection('bus_ticket_public_verify')
              .doc(token)
              .get();

      if (!mounted) {
        return;
      }

      if (!doc.exists) {
        setState(() {
          _error =
              'No valid RD bus ticket was found for this token.';
        });
        return;
      }

      final Map<String, dynamic> data =
          doc.data() ?? <String, dynamic>{};

      setState(() {
        _result = data;
        _verifiedToken = token;
      });

      if (confirmBoardingIfAuthorized &&
          data['status'] == 'issued' &&
          data['boardingStatus'] != 'confirmed') {
        await _confirmBoarding(
          token: token,
          verificationData: data,
          silentIfNotAuthorized: true,
        );
      }
    } on FirebaseException catch (error) {
      if (mounted) {
        setState(() {
          _error =
              'Verification failed: ${error.message ?? error.code}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<bool> _isOwningActiveBusOperator(
    Map<String, dynamic> verificationData,
  ) async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null || user.isAnonymous) {
      return false;
    }

    String ticketOperatorId =
        verificationData['operatorId']
                ?.toString()
                .trim() ??
            '';

    if (ticketOperatorId.isEmpty) {
      final String bookingId =
          verificationData['bookingId']?.toString().trim() ?? '';
      if (bookingId.isNotEmpty) {
        final DocumentSnapshot<Map<String, dynamic>> bookingDoc =
            await FirebaseFirestore.instance
                .collection('bus_ticket_bookings')
                .doc(bookingId)
                .get();
        ticketOperatorId =
            bookingDoc.data()?['operatorId']?.toString().trim() ?? '';
      }
    }

    if (ticketOperatorId != user.uid) {
      return false;
    }

    final DocumentSnapshot<Map<String, dynamic>>
        operatorDoc = await FirebaseFirestore.instance
            .collection('bus_operators')
            .doc(user.uid)
            .get();

    final Map<String, dynamic> operator =
        operatorDoc.data() ?? <String, dynamic>{};

    return operatorDoc.exists &&
        operator['role']?.toString() == 'busOperator' &&
        operator['isApproved'] == true &&
        operator['isActive'] == true;
  }

  Future<void> _confirmBoarding({
    required String token,
    required Map<String, dynamic> verificationData,
    bool silentIfNotAuthorized = false,
  }) async {
    if (_confirmingBoarding) {
      return;
    }

    if (verificationData['status'] != 'issued') {
      if (!silentIfNotAuthorized && mounted) {
        setState(() {
          _error =
              'Only an issued valid ticket can be boarding-confirmed.';
        });
      }
      return;
    }

    if (verificationData['boardingStatus'] == 'confirmed') {
      return;
    }

    setState(() {
      _confirmingBoarding = true;
    });

    try {
      final bool authorized =
          await _isOwningActiveBusOperator(
        verificationData,
      );

      if (!authorized) {
        if (!silentIfNotAuthorized && mounted) {
          setState(() {
            _error =
                'Ticket is valid. Boarding confirmation can only be done by the owning active Bus Operator.';
          });
        }
        return;
      }

      final DocumentReference<Map<String, dynamic>>
          verifyRef = FirebaseFirestore.instance
              .collection('bus_ticket_public_verify')
              .doc(token);

      await FirebaseFirestore.instance.runTransaction(
        (Transaction transaction) async {
          final DocumentSnapshot<Map<String, dynamic>>
              currentDoc =
              await transaction.get(verifyRef);

          if (!currentDoc.exists) {
            throw StateError(
              'Verification record no longer exists.',
            );
          }

          final Map<String, dynamic> current =
              currentDoc.data() ??
                  <String, dynamic>{};

          if (current['status'] != 'issued') {
            throw StateError(
              'This ticket is no longer valid for boarding.',
            );
          }

          if (current['boardingStatus'] == 'confirmed') {
            return;
          }

          final User? user =
              FirebaseAuth.instance.currentUser;

          if (user == null ||
              current['operatorId']?.toString() !=
                  user.uid) {
            throw StateError(
              'This ticket belongs to another Bus Operator.',
            );
          }

          transaction.update(
            verifyRef,
            <String, dynamic>{
              'operatorId': user.uid,
              'boardingStatus': 'confirmed',
              'boardingConfirmedAt':
                  FieldValue.serverTimestamp(),
              'boardingConfirmedBy': user.uid,
              'boardingConfirmationMethod':
                  'camera_qr_scan',
              'updatedAt':
                  FieldValue.serverTimestamp(),
            },
          );
        },
      );

      final DocumentSnapshot<Map<String, dynamic>>
          refreshed = await verifyRef.get();

      if (!mounted) {
        return;
      }

      setState(() {
        _result =
            refreshed.data() ?? verificationData;
        _verifiedToken = token;
        _error = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Boarding confirmed. This QR is now marked as checked.',
          ),
        ),
      );
    } on StateError catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
        });
      }
    } on FirebaseException catch (error) {
      if (mounted) {
        setState(() {
          _error =
              'Could not confirm boarding: ${error.message ?? error.code}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _confirmingBoarding = false;
        });
      }
    }
  }

  bool get _cameraScannerSupported {
    if (kIsWeb) {
      return true;
    }

    return defaultTargetPlatform !=
        TargetPlatform.windows;
  }

  Future<void> _scanQr() async {
    if (!_cameraScannerSupported) {
      setState(() {
        _error =
            'QR camera scanning is not available on Windows. Enter the verification token manually.';
      });
      return;
    }

    final String? raw = await Navigator.push<String>(
      context,
      MaterialPageRoute<String>(
        builder: (_) =>
            const _BusTicketQrScannerPage(),
      ),
    );

    if (!mounted ||
        raw == null ||
        raw.trim().isEmpty) {
      return;
    }

    final String token = _token(raw);

    _controller.value = TextEditingValue(
      text: token,
      selection: TextSelection.collapsed(
        offset: token.length,
      ),
    );

    await _verify(
      rawToken: raw,
      confirmBoardingIfAuthorized: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic>? data = _result;
    final bool valid =
        data != null && data['status'] == 'issued';
    final bool boardingConfirmed =
        data != null &&
            data['boardingStatus'] == 'confirmed';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Verify Bus Ticket',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: <Widget>[
              const Text(
                'Scan the RD Bus Ticket QR with the camera, or enter the verification token manually.',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  labelText: 'RD Verification Token',
                  prefixIcon:
                      Icon(Icons.verified_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 50,
                child: FilledButton.icon(
                  onPressed:
                      _loading ? null : _scanQr,
                  icon: const Icon(
                    Icons.qr_code_scanner_rounded,
                  ),
                  label: const Text(
                    'Scan QR with Camera',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed:
                    _loading ? null : () => _verify(),
                icon: _loading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.search_rounded),
                label: const Text(
                  'Verify Token Manually',
                ),
              ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
              if (data != null) ...<Widget>[
                const SizedBox(height: 18),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Icon(
                          valid
                              ? (boardingConfirmed
                                  ? Icons
                                      .how_to_reg_rounded
                                  : Icons
                                      .verified_rounded)
                              : Icons.cancel_rounded,
                          size: 58,
                          color:
                              valid ? Colors.green : Colors.red,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          valid
                              ? (boardingConfirmed
                                  ? 'BOARDING CONFIRMED ✅'
                                  : 'VALID RD BUS TICKET')
                              : 'TICKET NOT VALID',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: valid
                                ? Colors.green
                                : Colors.red,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Divider(height: 28),
                        Text(
                          'Booking: ${data['bookingCode'] ?? ''}',
                        ),
                        Text(
                          'Route: ${data['from'] ?? ''} → ${data['to'] ?? ''}',
                        ),
                        Text(
                          'Bus: ${data['operatorName'] ?? ''} • '
                          '${data['busNumber'] ?? ''}',
                        ),
                        Text(
                          'Seats: ${(data['seats'] is List ? data['seats'] as List<dynamic> : <dynamic>[]).join(', ')}',
                        ),
                        if (valid) ...<Widget>[
                          const SizedBox(height: 10),
                          Text(
                            boardingConfirmed
                                ? 'Status: Already checked / boarding confirmed'
                                : 'Status: Issued • not boarded yet',
                            style: TextStyle(
                              color: boardingConfirmed
                                  ? Colors.green
                                  : Colors.orange.shade800,
                              fontWeight:
                                  FontWeight.w900,
                            ),
                          ),
                          if (boardingConfirmed &&
                              data['boardingConfirmedAt']
                                  is Timestamp)
                            Text(
                              'Confirmed: '
                              '${(data['boardingConfirmedAt'] as Timestamp).toDate().toLocal()}',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 12,
                              ),
                            ),
                          if (!boardingConfirmed) ...<Widget>[
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed:
                                  _confirmingBoarding ||
                                          _verifiedToken ==
                                              null
                                      ? null
                                      : () =>
                                          _confirmBoarding(
                                            token:
                                                _verifiedToken!,
                                            verificationData:
                                                data,
                                          ),
                              icon: _confirmingBoarding
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child:
                                          CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons
                                          .how_to_reg_rounded,
                                    ),
                              label: const Text(
                                'Confirm Boarding',
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}


class _BusTicketQrScannerPage extends StatefulWidget {
  const _BusTicketQrScannerPage();

  @override
  State<_BusTicketQrScannerPage> createState() =>
      _BusTicketQrScannerPageState();
}

class _BusTicketQrScannerPageState
    extends State<_BusTicketQrScannerPage> {
  final MobileScannerController _scannerController =
      MobileScannerController();

  bool _resultReturned = false;

  void _handleDetection(
    BarcodeCapture capture,
  ) {
    if (_resultReturned ||
        capture.barcodes.isEmpty) {
      return;
    }

    final String value =
        capture.barcodes.first.rawValue
                ?.trim() ??
            '';

    if (value.isEmpty) {
      return;
    }

    final bool rdBusQr =
        value.startsWith('RDBUS|') ||
        RegExp(
          r'^[A-Fa-f0-9]{20,}$',
        ).hasMatch(value);

    if (!rdBusQr) {
      return;
    }

    _resultReturned = true;

    Navigator.of(context).pop<String>(
      value,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Scan RD Bus Ticket QR',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
        actions: <Widget>[
          IconButton(
            tooltip: 'Torch',
            onPressed: () {
              _scannerController.toggleTorch();
            },
            icon: const Icon(
              Icons.flashlight_on_rounded,
            ),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          MobileScanner(
            controller: _scannerController,
            onDetect: _handleDetection,
          ),
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(22),
                border: Border.all(
                  color: Colors.white,
                  width: 4,
                ),
              ),
            ),
          ),
          const Positioned(
            left: 24,
            right: 24,
            bottom: 36,
            child: Card(
              color: Colors.black87,
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  'Ask the passenger to show the RD Bus Ticket QR and place it inside the frame. An owning active Bus Operator can confirm boarding only once.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }
}


class _DemoBusSchedule {
  const _DemoBusSchedule({
    required this.scheduleId,
    required this.operatorId,
    required this.from,
    required this.to,
    required this.travelDate,
    required this.operatorName,
    required this.operatorPhone,
    required this.busStaffName,
    required this.busStaffPhone,
    required this.busName,
    required this.busNumber,
    required this.busType,
    required this.departureAt,
    required this.arrivalAt,
    required this.farePerSeat,
    required this.commissionPercent,
    required this.isFareApproved,
    required this.boardingPoints,
    required this.dropPoints,
    required this.unavailableSeats,
    required this.seatLayout,
    required this.seatRows,
    required this.seatCodes,
    required this.isActive,
  });

  factory _DemoBusSchedule.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data();

    DateTime readDate(dynamic value) {
      if (value is Timestamp) {
        return value.toDate().toLocal();
      }

      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    List<String> readList(dynamic value) {
      if (value is! List) {
        return <String>[];
      }

      return value
          .map((dynamic item) => item.toString())
          .where(
            (String item) => item.trim().isNotEmpty,
          )
          .toList();
    }

    double readNumber(dynamic value) {
      if (value is num) {
        return value.toDouble();
      }

      return double.tryParse(
            value?.toString() ?? '',
          ) ??
          0.0;
    }

    return _DemoBusSchedule(
      scheduleId: doc.id,
      operatorId:
          data['operatorId']?.toString() ?? '',
      from:
          data['from']?.toString() ?? '',
      to:
          data['to']?.toString() ?? '',
      travelDate:
          readDate(data['travelDate']),
      operatorName:
          data['operatorName']?.toString() ??
              'Bus Operator',
      operatorPhone:
          data['operatorPhone']?.toString() ?? '',
      busStaffName:
          (data['busStaffName']?.toString().trim().isNotEmpty ??
                  false)
              ? data['busStaffName'].toString().trim()
              : (data['operatorName']?.toString() ??
                  'Bus Operator'),
      busStaffPhone:
          (data['busStaffPhone']?.toString().trim().isNotEmpty ??
                  false)
              ? data['busStaffPhone'].toString().trim()
              : (data['operatorPhone']?.toString() ?? ''),
      busName:
          data['busName']?.toString() ?? 'Bus',
      busNumber:
          data['busNumber']?.toString() ?? '',
      busType:
          data['busType']?.toString() ?? '',
      departureAt:
          readDate(data['departureAt']),
      arrivalAt:
          readDate(data['arrivalAt']),
      farePerSeat:
          readNumber(data['farePerSeat']),
      commissionPercent:
          readNumber(data['commissionPercent']).clamp(0, 100).toDouble(),
      isFareApproved:
          (data['fareApprovalStatus']?.toString() ?? 'approved') ==
              'approved',
      boardingPoints:
          readList(data['boardingPoints']),
      dropPoints:
          readList(data['dropPoints']),
      unavailableSeats: <String>{},
      seatLayout:
          data['seatLayout']?.toString() ?? '2+2',
      seatRows: data['seatRows'] is int
          ? data['seatRows'] as int
          : 8,
      seatCodes: readList(data['seatCodes']),
      isActive: data['isActive'] == true,
    );
  }

  final String scheduleId;
  final String operatorId;
  final String from;
  final String to;
  final DateTime travelDate;
  final String operatorName;
  final String operatorPhone;
  final String busStaffName;
  final String busStaffPhone;
  final String busName;
  final String busNumber;
  final String busType;
  final DateTime departureAt;
  final DateTime arrivalAt;
  final double farePerSeat;
  final double commissionPercent;
  final bool isFareApproved;
  final List<String> boardingPoints;
  final List<String> dropPoints;
  final Set<String> unavailableSeats;
  final String seatLayout;
  final int seatRows;
  final List<String> seatCodes;
  final bool isActive;
}
