import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class FlightTicketBookingPage extends StatefulWidget {
  const FlightTicketBookingPage({super.key});

  @override
  State<FlightTicketBookingPage> createState() =>
      _FlightTicketBookingPageState();
}

class _FlightTicketBookingPageState
    extends State<FlightTicketBookingPage> {
  static const Color _rdBlue = Color(0xFF1565C0);
  static const Color _rdGreen = Color(0xFF2E7D32);

  static const Map<String, String> _airportCodes = <String, String>{
    'kathmandu': 'KTM',
    'pokhara': 'PKR',
    'bharatpur': 'BHR',
    'bhairahawa': 'BWA',
    'biratnagar': 'BIR',
    'nepalgunj': 'KEP',
    'janakpur': 'JKR',
    'simara': 'SIF',
    'dhangadhi': 'DHI',
    'bhadrapur': 'BDP',
    'lukla': 'LUA',
    'jomsom': 'JMO',
    'delhi': 'DEL',
    'new delhi': 'DEL',
    'dubai': 'DXB',
    'doha': 'DOH',
    'riyadh': 'RUH',
    'jeddah': 'JED',
    'dammam': 'DMM',
    'bangkok': 'BKK',
    'singapore': 'SIN',
    'kuala lumpur': 'KUL',
    'seoul': 'ICN',
    'tokyo': 'NRT',
    'london': 'LHR',
  };

  final TextEditingController _fromController =
      TextEditingController();
  final TextEditingController _toController =
      TextEditingController();
  final TextEditingController _phoneController =
      TextEditingController();
  final TextEditingController _emailController =
      TextEditingController();

  final List<TextEditingController> _passengerNameControllers =
      <TextEditingController>[TextEditingController()];
  final List<TextEditingController> _documentNumberControllers =
      <TextEditingController>[TextEditingController()];
  final List<DateTime?> _passengerDob = <DateTime?>[null];
  final List<DateTime?> _passportExpiry = <DateTime?>[null];
  final List<String> _passengerGender = <String>['Male'];
  final List<String> _passengerNationality = <String>['Nepal'];
  final List<String> _documentType =
      <String>['Citizenship / National ID'];
  final List<String> _seatPreference = <String>['Any'];
  final List<String> _mealPreference = <String>['Standard'];
  final List<bool> _specialAssistance = <bool>[false];

  DateTime _departureDate =
      DateTime.now().add(const Duration(days: 1));
  DateTime? _returnDate;

  String _travelScope = 'domestic';
  String _tripType = 'one_way';
  String _cabinClass = 'Economy';
  String _sortBy = 'Recommended';
  String _airlineFilter = 'All Airlines';
  String _maxStops = 'Any';
  String _timeFilter = 'Any Time';
  String _paymentOption = 'online';
  String _paymentMethod = 'eSewa';

  int _adultCount = 1;
  int _childCount = 0;
  int _infantCount = 0;

  bool _directOnly = false;
  bool _refundableOnly = false;
  bool _flexibleDates = false;
  bool _termsAccepted = false;
  bool _searching = false;
  bool _submitting = false;

  List<_DemoFlightQuote> _allQuotes = <_DemoFlightQuote>[];
  List<_DemoFlightQuote> _quotes = <_DemoFlightQuote>[];
  _DemoFlightQuote? _selectedQuote;

  int get _passengerCount =>
      _adultCount + _childCount + _infantCount;

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    _phoneController.dispose();
    _emailController.dispose();

    for (final TextEditingController controller
        in _passengerNameControllers) {
      controller.dispose();
    }

    for (final TextEditingController controller
        in _documentNumberControllers) {
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

  String _durationText(int minutes) {
    final int hours = minutes ~/ 60;
    final int rest = minutes % 60;
    return rest == 0 ? '${hours}h' : '${hours}h ${rest}m';
  }

  String _airportCode(String value) {
    final String trimmed = value.trim();
    final String normalized = trimmed.toLowerCase();

    for (final MapEntry<String, String> entry
        in _airportCodes.entries) {
      if (normalized == entry.key ||
          normalized.contains(entry.key)) {
        return entry.value;
      }
    }

    final RegExpMatch? match =
        RegExp(r'\(([A-Za-z]{3})\)').firstMatch(trimmed);
    if (match != null) {
      return match.group(1)!.toUpperCase();
    }

    if (trimmed.length == 3) {
      return trimmed.toUpperCase();
    }

    final String letters = trimmed
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z]'), '');
    if (letters.length >= 3) {
      return letters.substring(0, 3);
    }
    return letters.padRight(3, 'X');
  }

  void _resetSearch() {
    _allQuotes = <_DemoFlightQuote>[];
    _quotes = <_DemoFlightQuote>[];
    _selectedQuote = null;
    _termsAccepted = false;
  }

  void _syncPassengerControllers() {
    final int needed = _passengerCount;

    while (_passengerNameControllers.length < needed) {
      _passengerNameControllers.add(TextEditingController());
      _documentNumberControllers.add(TextEditingController());
      _passengerDob.add(null);
      _passportExpiry.add(null);
      _passengerGender.add('Male');
      _passengerNationality.add('Nepal');
      _documentType.add(
        _travelScope == 'international'
            ? 'Passport'
            : 'Citizenship / National ID',
      );
      _seatPreference.add('Any');
      _mealPreference.add('Standard');
      _specialAssistance.add(false);
    }

    while (_passengerNameControllers.length > needed) {
      _passengerNameControllers.removeLast().dispose();
      _documentNumberControllers.removeLast().dispose();
      _passengerDob.removeLast();
      _passportExpiry.removeLast();
      _passengerGender.removeLast();
      _passengerNationality.removeLast();
      _documentType.removeLast();
      _seatPreference.removeLast();
      _mealPreference.removeLast();
      _specialAssistance.removeLast();
    }

    if (_travelScope == 'international') {
      for (int index = 0; index < _documentType.length; index++) {
        _documentType[index] = 'Passport';
      }
    }
  }

  Future<void> _pickDepartureDate() async {
    final DateTime now = DateTime.now();

    final DateTime? selected = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2, 12, 31),
      initialDate: _departureDate,
    );

    if (!mounted || selected == null) {
      return;
    }

    setState(() {
      _departureDate = selected;

      if (_returnDate != null &&
          _returnDate!.isBefore(_departureDate)) {
        _returnDate = _departureDate.add(
          const Duration(days: 1),
        );
      }

      _resetSearch();
    });
  }

  Future<void> _pickReturnDate() async {
    final DateTime minimum = _departureDate;

    final DateTime? selected = await showDatePicker(
      context: context,
      firstDate: minimum,
      lastDate: DateTime(minimum.year + 2, 12, 31),
      initialDate: _returnDate ??
          minimum.add(const Duration(days: 1)),
    );

    if (!mounted || selected == null) {
      return;
    }

    setState(() {
      _returnDate = selected;
      _resetSearch();
    });
  }

  Future<void> _pickPassengerDob(int index) async {
    final DateTime today = DateTime.now();
    final String type = _passengerTypeAt(index);

    DateTime initialDate;
    DateTime firstDate;
    DateTime lastDate;

    if (type == 'Infant') {
      initialDate = today.subtract(const Duration(days: 365));
      firstDate = DateTime(today.year - 2, today.month, today.day);
      lastDate = today;
    } else if (type == 'Child') {
      initialDate = DateTime(today.year - 7, today.month, today.day);
      firstDate = DateTime(today.year - 12, today.month, today.day);
      lastDate = DateTime(today.year - 2, today.month, today.day);
    } else {
      initialDate = DateTime(today.year - 25, today.month, today.day);
      firstDate = DateTime(today.year - 100, 1, 1);
      lastDate = DateTime(today.year - 12, today.month, today.day);
    }

    final DateTime? selected = await showDatePicker(
      context: context,
      initialDate: _passengerDob[index] ?? initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (!mounted || selected == null) {
      return;
    }

    setState(() {
      _passengerDob[index] = selected;
      _termsAccepted = false;
    });
  }

  Future<void> _pickPassportExpiry(int index) async {
    final DateTime today = DateTime.now();
    final DateTime minimum = DateTime(
      today.year,
      today.month,
      today.day,
    );

    final DateTime? selected = await showDatePicker(
      context: context,
      initialDate: _passportExpiry[index] ??
          DateTime(today.year + 5, today.month, today.day),
      firstDate: minimum,
      lastDate: DateTime(today.year + 15, 12, 31),
    );

    if (!mounted || selected == null) {
      return;
    }

    setState(() {
      _passportExpiry[index] = selected;
      _termsAccepted = false;
    });
  }

  void _swapRoute() {
    final String from = _fromController.text;
    _fromController.text = _toController.text;
    _toController.text = from;

    setState(_resetSearch);
  }

  bool _isValidEmail(String value) {
    final String email = value.trim();

    if (email.isEmpty) {
      return true;
    }

    final RegExp emailPattern = RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    );

    return emailPattern.hasMatch(email);
  }

  Future<void> _searchFlights() async {
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

    if (_tripType == 'round_trip' && _returnDate == null) {
      _message('Please select a return date.');
      return;
    }

    if (_infantCount > _adultCount) {
      _message(
        'Infant count cannot be greater than adult count.',
      );
      return;
    }

    setState(() {
      _searching = true;
      _allQuotes = <_DemoFlightQuote>[];
      _quotes = <_DemoFlightQuote>[];
      _selectedQuote = null;
      _termsAccepted = false;
    });

    await Future<void>.delayed(
      const Duration(milliseconds: 350),
    );

    if (!mounted) {
      return;
    }

    final double classMultiplier = switch (_cabinClass) {
      'Premium Economy' => 1.30,
      'Business' => 1.90,
      'First Class' => 2.70,
      _ => 1.0,
    };

    final double tripMultiplier =
        _tripType == 'round_trip' ? 1.90 : 1.0;
    final double internationalMultiplier =
        _travelScope == 'international' ? 4.5 : 1.0;
    final DateTime? returnDate = _returnDate;

    _DemoFlightQuote makeQuote({
      required String id,
      required String airline,
      required String flightNumber,
      required int departureHour,
      required int departureMinute,
      required int durationMinutes,
      required double baseFare,
      required double tax,
      required double serviceFee,
      required String baggage,
      required bool refundable,
      required bool changeable,
      required int seatsLeft,
      required int stops,
      required String aircraft,
      required String fareFamily,
      required String departureTerminal,
      required String arrivalTerminal,
      required String cancellationPolicy,
    }) {
      final DateTime outboundDeparture = DateTime(
        _departureDate.year,
        _departureDate.month,
        _departureDate.day,
        departureHour,
        departureMinute,
      );

      final DateTime outboundArrival = outboundDeparture.add(
        Duration(minutes: durationMinutes),
      );

      DateTime? returnDeparture;
      DateTime? returnArrival;

      if (_tripType == 'round_trip' && returnDate != null) {
        returnDeparture = DateTime(
          returnDate.year,
          returnDate.month,
          returnDate.day,
          departureHour + 1 > 22
              ? departureHour
              : departureHour + 1,
          departureMinute,
        );
        returnArrival = returnDeparture.add(
          Duration(minutes: durationMinutes),
        );
      }

      return _DemoFlightQuote(
        quoteId:
            '$id-${DateTime.now().microsecondsSinceEpoch}',
        airlineName: airline,
        flightNumber: flightNumber,
        outboundDeparture: outboundDeparture,
        outboundArrival: outboundArrival,
        returnDeparture: returnDeparture,
        returnArrival: returnArrival,
        baseFarePerTraveler: baseFare *
            classMultiplier *
            tripMultiplier *
            internationalMultiplier,
        taxPerTraveler:
            tax * tripMultiplier * internationalMultiplier,
        serviceFee:
            serviceFee * tripMultiplier * internationalMultiplier,
        baggage: baggage,
        refundable: refundable,
        changeable: changeable,
        seatsLeft: seatsLeft,
        stops: stops,
        aircraft: aircraft,
        fareFamily: fareFamily,
        departureTerminal: departureTerminal,
        arrivalTerminal: arrivalTerminal,
        cancellationPolicy: cancellationPolicy,
        durationMinutes: durationMinutes,
        quoteExpiresAt:
            DateTime.now().add(const Duration(minutes: 15)),
      );
    }

    final List<_DemoFlightQuote> results = <_DemoFlightQuote>[
      makeQuote(
        id: 'RDQ101',
        airline: 'RD Demo Air',
        flightNumber: 'U4 101',
        departureHour: 7,
        departureMinute: 30,
        durationMinutes:
            _travelScope == 'international' ? 260 : 35,
        baseFare: 3900,
        tax: 550,
        serviceFee: 0,
        baggage: '15 kg checked + 5 kg cabin',
        refundable: false,
        changeable: true,
        seatsLeft: 7,
        stops: 0,
        aircraft: 'ATR 72',
        fareFamily: 'Saver',
        departureTerminal:
            _travelScope == 'international' ? 'International' : 'Domestic',
        arrivalTerminal:
            _travelScope == 'international' ? 'T1' : 'Domestic',
        cancellationPolicy:
            'Cancellation charge applies as per airline fare rule.',
      ),
      makeQuote(
        id: 'RDQ205',
        airline: 'RD Demo Sky',
        flightNumber: 'YT 205',
        departureHour: 10,
        departureMinute: 15,
        durationMinutes:
            _travelScope == 'international' ? 300 : 40,
        baseFare: 4300,
        tax: 600,
        serviceFee: 0,
        baggage: '20 kg checked + 7 kg cabin',
        refundable: true,
        changeable: true,
        seatsLeft: 5,
        stops: 0,
        aircraft: 'ATR 72',
        fareFamily: 'Flex',
        departureTerminal:
            _travelScope == 'international' ? 'International' : 'Domestic',
        arrivalTerminal:
            _travelScope == 'international' ? 'T2' : 'Domestic',
        cancellationPolicy:
            'Refund permitted after airline cancellation charge.',
      ),
      makeQuote(
        id: 'RDQ309',
        airline: 'RD Demo Connect',
        flightNumber: 'SHA 309',
        departureHour: 13,
        departureMinute: 45,
        durationMinutes:
            _travelScope == 'international' ? 355 : 45,
        baseFare: 4700,
        tax: 650,
        serviceFee: 0,
        baggage: '20 kg checked + 7 kg cabin',
        refundable: true,
        changeable: true,
        seatsLeft: 3,
        stops: _travelScope == 'international' ? 1 : 0,
        aircraft: 'Dash 8 / Partner connection',
        fareFamily: 'Standard',
        departureTerminal:
            _travelScope == 'international' ? 'International' : 'Domestic',
        arrivalTerminal:
            _travelScope == 'international' ? 'T3' : 'Domestic',
        cancellationPolicy:
            'Fare difference and change/cancel fee may apply.',
      ),
      makeQuote(
        id: 'RDQ411',
        airline: 'RD Demo International',
        flightNumber: 'H9 411',
        departureHour: 18,
        departureMinute: 20,
        durationMinutes:
            _travelScope == 'international' ? 275 : 50,
        baseFare: 5200,
        tax: 700,
        serviceFee: 0,
        baggage: '25 kg checked + 7 kg cabin',
        refundable: true,
        changeable: true,
        seatsLeft: 8,
        stops: 0,
        aircraft: 'Airbus A320',
        fareFamily: 'Flex Plus',
        departureTerminal:
            _travelScope == 'international' ? 'International' : 'Domestic',
        arrivalTerminal:
            _travelScope == 'international' ? 'T1' : 'Domestic',
        cancellationPolicy:
            'Refund/change permitted subject to provider fare conditions.',
      ),
    ];

    setState(() {
      _allQuotes = results;
      _applyQuoteFilters();
      _searching = false;
    });
  }

  void _applyQuoteFilters() {
    Iterable<_DemoFlightQuote> filtered = _allQuotes;

    if (_directOnly) {
      filtered = filtered.where(
        (_DemoFlightQuote quote) => quote.stops == 0,
      );
    }

    if (_refundableOnly) {
      filtered = filtered.where(
        (_DemoFlightQuote quote) => quote.refundable,
      );
    }

    if (_airlineFilter != 'All Airlines') {
      filtered = filtered.where(
        (_DemoFlightQuote quote) =>
            quote.airlineName == _airlineFilter,
      );
    }

    if (_maxStops == 'Direct only') {
      filtered = filtered.where(
        (_DemoFlightQuote quote) => quote.stops == 0,
      );
    } else if (_maxStops == 'Up to 1 stop') {
      filtered = filtered.where(
        (_DemoFlightQuote quote) => quote.stops <= 1,
      );
    }

    if (_timeFilter != 'Any Time') {
      filtered = filtered.where(
        (_DemoFlightQuote quote) {
          final int hour = quote.outboundDeparture.hour;
          if (_timeFilter == 'Morning') {
            return hour >= 5 && hour < 12;
          }
          if (_timeFilter == 'Afternoon') {
            return hour >= 12 && hour < 17;
          }
          return hour >= 17 || hour < 5;
        },
      );
    }

    final List<_DemoFlightQuote> list = filtered.toList();

    switch (_sortBy) {
      case 'Cheapest':
        list.sort(
          (_DemoFlightQuote a, _DemoFlightQuote b) =>
              a.totalFare(_passengerCount).compareTo(
                    b.totalFare(_passengerCount),
                  ),
        );
        break;
      case 'Earliest':
        list.sort(
          (_DemoFlightQuote a, _DemoFlightQuote b) =>
              a.outboundDeparture.compareTo(
                    b.outboundDeparture,
                  ),
        );
        break;
      case 'Shortest':
        list.sort(
          (_DemoFlightQuote a, _DemoFlightQuote b) =>
              a.durationMinutes.compareTo(
                    b.durationMinutes,
                  ),
        );
        break;
      default:
        list.sort(
          (_DemoFlightQuote a, _DemoFlightQuote b) {
            final int directCompare =
                a.stops.compareTo(b.stops);
            if (directCompare != 0) {
              return directCompare;
            }
            return a.totalFare(_passengerCount).compareTo(
                  b.totalFare(_passengerCount),
                );
          },
        );
    }

    _quotes = list;
    _selectedQuote = null;
    _termsAccepted = false;
  }

  List<String> _passengerNames() =>
      _passengerNameControllers
          .map(
            (TextEditingController controller) =>
                controller.text.trim(),
          )
          .toList();

  List<String> _documentLast4() =>
      _documentNumberControllers
          .map(
            (TextEditingController controller) {
              final String raw = controller.text.trim();
              if (raw.length <= 4) {
                return raw;
              }
              return raw.substring(raw.length - 4);
            },
          )
          .toList();

  String _passengerTypeAt(int index) {
    if (index < _adultCount) {
      return 'Adult';
    }

    if (index < _adultCount + _childCount) {
      return 'Child';
    }

    return 'Infant';
  }

  bool _validatePassengerAndContact() {
    final List<String> names = _passengerNames();

    for (int index = 0; index < names.length; index++) {
      if (names[index].length < 2) {
        _message(
          'Please enter the full name for '
          '${_passengerTypeAt(index)} passenger ${index + 1}.',
        );
        return false;
      }

      if (_passengerDob[index] == null) {
        _message(
          'Please select date of birth for passenger ${index + 1}.',
        );
        return false;
      }

      final String document =
          _documentNumberControllers[index].text.trim();

      if (_travelScope == 'international' &&
          document.length < 5) {
        _message(
          'Passport number is required for international passenger ${index + 1}.',
        );
        return false;
      }

      if (_travelScope == 'international') {
        final DateTime? expiry = _passportExpiry[index];

        if (expiry == null) {
          _message(
            'Passport expiry date is required for international passenger ${index + 1}.',
          );
          return false;
        }

        final DateTime requiredValidUntil =
            _departureDate.add(const Duration(days: 180));

        if (!expiry.isAfter(requiredValidUntil)) {
          _message(
            'Passport for passenger ${index + 1} should normally remain valid for at least 6 months after departure.',
          );
          return false;
        }
      }

      if (_travelScope == 'domestic' &&
          document.isNotEmpty &&
          document.length < 4) {
        _message(
          'Please enter a valid ID number for passenger ${index + 1}.',
        );
        return false;
      }
    }

    final String phone = _phoneController.text.trim();

    if (phone.length < 7 || phone.length > 30) {
      _message('Please enter a valid contact phone number.');
      return false;
    }

    if (!_isValidEmail(_emailController.text)) {
      _message('Please enter a valid email address.');
      return false;
    }

    if (!_termsAccepted) {
      _message(
        'Please accept the booking and anti-scam declaration.',
      );
      return false;
    }

    return true;
  }

  Future<void> _submitBookingRequest() async {
    final User? user = FirebaseAuth.instance.currentUser;
    final _DemoFlightQuote? quote = _selectedQuote;

    if (user == null) {
      _message('Customer session is not available.');
      return;
    }

    if (quote == null) {
      _message('Please select a flight quote first.');
      return;
    }

    if (DateTime.now().isAfter(quote.quoteExpiresAt)) {
      _message(
        'This quote has expired. Please search again.',
      );
      setState(_resetSearch);
      return;
    }

    if (!_validatePassengerAndContact()) {
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
            customerDoc.data()?['customerId']?.toString().trim() ??
                '';
      } catch (_) {
        customerId = '';
      }

      final DocumentReference<Map<String, dynamic>> ref =
          FirebaseFirestore.instance
              .collection('ticket_bookings')
              .doc();

      final String bookingCode =
          'RDFL-${ref.id.substring(0, 8).toUpperCase()}';

      final List<String> passengerNames = _passengerNames();
      final List<String> passengerTypes =
          List<String>.generate(
        _passengerCount,
        _passengerTypeAt,
      );

      final double baseFare = quote.baseFareTotal(
        _passengerCount,
      );
      final double taxes = quote.taxTotal(
        _passengerCount,
      );
      final double totalFare = quote.totalFare(
        _passengerCount,
      );

      final List<Timestamp> passengerDob = _passengerDob
          .map(
            (DateTime? value) => Timestamp.fromDate(value!),
          )
          .toList();

      final List<Object?> passengerPassportExpiry =
          _passportExpiry
              .map<Object?>(
                (DateTime? value) => value == null
                    ? null
                    : Timestamp.fromDate(value),
              )
              .toList();

      final String paymentStatus = _paymentOption == 'online'
          ? 'online_pending'
          : 'pay_at_office_pending';
      final String paymentMethod = _paymentOption == 'online'
          ? _paymentMethod
          : 'RD Office / Authorized Agent';

      await ref.set(
        <String, dynamic>{
          'bookingId': ref.id,
          'bookingCode': bookingCode,
          'bookingVersion': 3,
          'serviceType': 'flight',
          'customerAuthUid': user.uid,
          'customerId': customerId,
          'travelScope': _travelScope,
          'tripType': _tripType,
          'from': _fromController.text.trim(),
          'to': _toController.text.trim(),
          'fromCode': _airportCode(_fromController.text),
          'toCode': _airportCode(_toController.text),
          'departureDate': Timestamp.fromDate(_departureDate),
          'returnDate': _returnDate == null
              ? null
              : Timestamp.fromDate(_returnDate!),
          'adultCount': _adultCount,
          'childCount': _childCount,
          'infantCount': _infantCount,
          'passengerCount': _passengerCount,
          'passengerNames': passengerNames,
          'passengerTypes': passengerTypes,
          'passengerDob': passengerDob,
          'passengerPassportExpiry': passengerPassportExpiry,
          'passengerGenders': List<String>.from(_passengerGender),
          'passengerNationalities':
              List<String>.from(_passengerNationality),
          'documentTypes': List<String>.from(_documentType),
          'documentLast4': _documentLast4(),
          'identityVerificationRequired':
              _travelScope == 'international',
          'seatPreferences': List<String>.from(_seatPreference),
          'mealPreferences': List<String>.from(_mealPreference),
          'specialAssistance': List<bool>.from(_specialAssistance),
          'contactPhone': _phoneController.text.trim(),
          'contactEmail': _emailController.text.trim(),
          'cabinClass': _cabinClass,
          'directOnly': _directOnly,
          'flexibleDates': _flexibleDates,
          'airlineName': quote.airlineName,
          'flightNumber': quote.flightNumber,
          'outboundDeparture':
              Timestamp.fromDate(quote.outboundDeparture),
          'outboundArrival':
              Timestamp.fromDate(quote.outboundArrival),
          'returnDeparture': quote.returnDeparture == null
              ? null
              : Timestamp.fromDate(quote.returnDeparture!),
          'returnArrival': quote.returnArrival == null
              ? null
              : Timestamp.fromDate(quote.returnArrival!),
          'baggage': quote.baggage,
          'refundable': quote.refundable,
          'changeable': quote.changeable,
          'stops': quote.stops,
          'aircraft': quote.aircraft,
          'fareFamily': quote.fareFamily,
          'departureTerminal': quote.departureTerminal,
          'arrivalTerminal': quote.arrivalTerminal,
          'durationMinutes': quote.durationMinutes,
          'cancellationPolicy': quote.cancellationPolicy,
          'baseFare': baseFare,
          'taxes': taxes,
          'serviceFee': quote.serviceFee,
          'totalFare': totalFare,
          'currency': 'Rs.',
          'paymentOption': _paymentOption,
          'paymentMethod': paymentMethod,
          'paymentReference': '',
          'quoteId': quote.quoteId,
          'quoteSource': 'demo',
          'quoteExpiresAt': Timestamp.fromDate(quote.quoteExpiresAt),
          'providerVerified': false,
          'providerName': '',
          'providerBookingReference': '',
          'pnr': '',
          'eTicketNumber': '',
          'qrVerificationToken': '',
          'bookingStatus': 'request_submitted',
          'paymentStatus': paymentStatus,
          'ticketStatus': 'not_issued',
          'fraudReviewStatus': 'unreviewed',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            icon: const Icon(
              Icons.verified_user_outlined,
              color: _rdGreen,
              size: 44,
            ),
            title: const Text(
              'Flight Booking Request Submitted',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w900,
              ),
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 460,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                children: <Widget>[
                  _summaryLine('Booking Code', bookingCode),
                  _summaryLine('Booking ID', ref.id),
                  _summaryLine(
                    'Route',
                    '${_airportCode(_fromController.text)} → '
                        '${_airportCode(_toController.text)}',
                  ),
                  _summaryLine(
                    'Flight',
                    '${quote.airlineName} '
                        '${quote.flightNumber}',
                  ),
                  _summaryLine(
                    'Passengers',
                    _passengerCount.toString(),
                  ),
                  _summaryLine(
                    'Payment',
                    paymentMethod,
                  ),
                  _summaryLine(
                    'Requested Total',
                    'Rs. ${totalFare.toStringAsFixed(0)}',
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange
                          .withValues(alpha: 0.10),
                      borderRadius:
                          BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'This is NOT an issued airline ticket yet. '
                      'A real PNR/e-ticket must only appear after '
                      'provider verification and payment confirmation.',
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
                  _openMyTickets();
                },
                child: const Text('My Tickets'),
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
    } on FirebaseException catch (error) {
      if (mounted) {
        _message(
          'Could not submit booking: '
          '${error.message ?? error.code}',
        );
      }
    } catch (error) {
      if (mounted) {
        _message('Could not submit booking: $error');
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
            width: 120,
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

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _openMyTickets() {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const MyFlightTicketsPage(),
      ),
    );
  }

  void _openVerify() {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const FlightTicketVerifyPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'Flight Ticket',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
        actions: <Widget>[
          IconButton(
            tooltip: 'Verify Flight Ticket',
            onPressed: _openVerify,
            icon: const Icon(
              Icons.qr_code_scanner_rounded,
            ),
          ),
          IconButton(
            tooltip: 'My Flight Tickets',
            onPressed: _openMyTickets,
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
                _securityBanner(),
                const SizedBox(height: 14),
                _searchCard(),
                if (_searching) ...<Widget>[
                  const SizedBox(height: 24),
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
                ],
                if (!_searching && _allQuotes.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 18),
                  _filterCard(),
                  const SizedBox(height: 14),
                  _resultsHeader(),
                  const SizedBox(height: 10),
                  if (_quotes.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'No flight matches the selected filters.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    )
                  else
                    ..._quotes.map(_quoteCard),
                ],
                if (_selectedQuote != null) ...<Widget>[
                  const SizedBox(height: 18),
                  _passengerCard(),
                  const SizedBox(height: 14),
                  _paymentCard(),
                  const SizedBox(height: 14),
                  _reviewAndSafetyCard(),
                ],
              ],
            ),
          ),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'RD Ticket Safety',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Never treat a booking request as a confirmed '
                  'airline ticket. A valid ticket must have a '
                  'verified provider, confirmed payment and real '
                  'PNR/e-ticket issued through the official provider.',
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
              'Search Flights',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                ChoiceChip(
                  label: const Text('Domestic'),
                  selected: _travelScope == 'domestic',
                  onSelected: (_) {
                    setState(() {
                      _travelScope = 'domestic';
                      _syncPassengerControllers();
                      _resetSearch();
                    });
                  },
                ),
                ChoiceChip(
                  label: const Text('International'),
                  selected: _travelScope == 'international',
                  onSelected: (_) {
                    setState(() {
                      _travelScope = 'international';
                      _syncPassengerControllers();
                      _resetSearch();
                    });
                  },
                ),
                ChoiceChip(
                  label: const Text('One Way'),
                  selected: _tripType == 'one_way',
                  onSelected: (_) {
                    setState(() {
                      _tripType = 'one_way';
                      _returnDate = null;
                      _resetSearch();
                    });
                  },
                ),
                ChoiceChip(
                  label: const Text('Round Trip'),
                  selected: _tripType == 'round_trip',
                  onSelected: (_) {
                    setState(() {
                      _tripType = 'round_trip';
                      _returnDate ??= _departureDate.add(
                        const Duration(days: 1),
                      );
                      _resetSearch();
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (
                BuildContext context,
                BoxConstraints constraints,
              ) {
                final bool wide = constraints.maxWidth >= 650;

                final Widget fromField = TextField(
                  controller: _fromController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'From',
                    hintText: 'City, airport or IATA code',
                    prefixIcon: Icon(Icons.flight_takeoff_rounded),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) {
                    if (_allQuotes.isNotEmpty) {
                      setState(_resetSearch);
                    }
                  },
                );

                final Widget toField = TextField(
                  controller: _toController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'To',
                    hintText: 'City, airport or IATA code',
                    prefixIcon: Icon(Icons.flight_land_rounded),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) {
                    if (_allQuotes.isNotEmpty) {
                      setState(_resetSearch);
                    }
                  },
                );

                final Widget swap = IconButton.filledTonal(
                  tooltip: 'Swap route',
                  onPressed: _swapRoute,
                  icon: const Icon(Icons.swap_horiz_rounded),
                );

                if (wide) {
                  return Row(
                    children: <Widget>[
                      Expanded(child: fromField),
                      const SizedBox(width: 8),
                      swap,
                      const SizedBox(width: 8),
                      Expanded(child: toField),
                    ],
                  );
                }

                return Column(
                  children: <Widget>[
                    fromField,
                    const SizedBox(height: 8),
                    swap,
                    const SizedBox(height: 8),
                    toField,
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (
                BuildContext context,
                BoxConstraints constraints,
              ) {
                final bool wide = constraints.maxWidth >= 650;
                final Widget depart = _dateField(
                  label: 'Departure',
                  value: _dateText(_departureDate),
                  onTap: _pickDepartureDate,
                );
                final Widget returning = _dateField(
                  label: 'Return',
                  value: _returnDate == null
                      ? 'Select return date'
                      : _dateText(_returnDate!),
                  onTap: _tripType == 'round_trip'
                      ? _pickReturnDate
                      : null,
                );

                if (wide) {
                  return Row(
                    children: <Widget>[
                      Expanded(child: depart),
                      if (_tripType == 'round_trip') ...<Widget>[
                        const SizedBox(width: 12),
                        Expanded(child: returning),
                      ],
                    ],
                  );
                }

                return Column(
                  children: <Widget>[
                    depart,
                    if (_tripType == 'round_trip') ...<Widget>[
                      const SizedBox(height: 12),
                      returning,
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            _travelerSelector(),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _cabinClass,
              decoration: const InputDecoration(
                labelText: 'Cabin Class',
                prefixIcon: Icon(
                  Icons.airline_seat_recline_extra_rounded,
                ),
                border: OutlineInputBorder(),
              ),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem<String>(
                  value: 'Economy',
                  child: Text('Economy'),
                ),
                DropdownMenuItem<String>(
                  value: 'Premium Economy',
                  child: Text('Premium Economy'),
                ),
                DropdownMenuItem<String>(
                  value: 'Business',
                  child: Text('Business'),
                ),
                DropdownMenuItem<String>(
                  value: 'First Class',
                  child: Text('First Class'),
                ),
              ],
              onChanged: (String? value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _cabinClass = value;
                  _resetSearch();
                });
              },
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _directOnly,
              title: const Text(
                'Direct flights only',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              onChanged: (bool value) {
                setState(() {
                  _directOnly = value;
                  if (_allQuotes.isNotEmpty) {
                    _applyQuoteFilters();
                  }
                });
              },
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _flexibleDates,
              title: const Text(
                'Flexible travel dates',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                'Provider may suggest nearby dates for a better fare.',
              ),
              onChanged: (bool value) {
                setState(() {
                  _flexibleDates = value;
                  _resetSearch();
                });
              },
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed: _searching ? null : _searchFlights,
                icon: const Icon(Icons.search_rounded),
                label: const Text(
                  'Search Flights',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterCard() {
    final Set<String> airlines = <String>{
      'All Airlines',
      ..._allQuotes.map(
        (_DemoFlightQuote quote) => quote.airlineName,
      ),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              'Filter & Sort',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _sortBy,
              decoration: const InputDecoration(
                labelText: 'Sort By',
                border: OutlineInputBorder(),
              ),
              items: const <String>[
                'Recommended',
                'Cheapest',
                'Earliest',
                'Shortest',
              ].map(
                (String value) => DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                ),
              ).toList(),
              onChanged: (String? value) {
                if (value == null) return;
                setState(() {
                  _sortBy = value;
                  _applyQuoteFilters();
                });
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _airlineFilter,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Airline',
                border: OutlineInputBorder(),
              ),
              items: airlines.map(
                (String value) => DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                ),
              ).toList(),
              onChanged: (String? value) {
                if (value == null) return;
                setState(() {
                  _airlineFilter = value;
                  _applyQuoteFilters();
                });
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _maxStops,
              decoration: const InputDecoration(
                labelText: 'Stops',
                border: OutlineInputBorder(),
              ),
              items: const <String>[
                'Any',
                'Direct only',
                'Up to 1 stop',
              ].map(
                (String value) => DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                ),
              ).toList(),
              onChanged: (String? value) {
                if (value == null) return;
                setState(() {
                  _maxStops = value;
                  _applyQuoteFilters();
                });
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _timeFilter,
              decoration: const InputDecoration(
                labelText: 'Departure Time',
                border: OutlineInputBorder(),
              ),
              items: const <String>[
                'Any Time',
                'Morning',
                'Afternoon',
                'Evening',
              ].map(
                (String value) => DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                ),
              ).toList(),
              onChanged: (String? value) {
                if (value == null) return;
                setState(() {
                  _timeFilter = value;
                  _applyQuoteFilters();
                });
              },
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _refundableOnly,
              title: const Text(
                'Refundable fares only',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              onChanged: (bool value) {
                setState(() {
                  _refundableOnly = value;
                  _applyQuoteFilters();
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateField({
    required String label,
    required String value,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(
            Icons.calendar_month_rounded,
          ),
          border: const OutlineInputBorder(),
          enabled: onTap != null,
        ),
        child: Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _travelerSelector() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.grey.shade400,
        ),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Travelers',
            style: TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          _countRow(
            label: 'Adults',
            subtitle: '12+ years',
            value: _adultCount,
            min: 1,
            max: 9,
            onChanged: (int value) {
              setState(() {
                _adultCount = value;
                _syncPassengerControllers();
                _resetSearch();
              });
            },
          ),
          _countRow(
            label: 'Children',
            subtitle: '2–11 years',
            value: _childCount,
            min: 0,
            max: 8,
            onChanged: (int value) {
              if (_adultCount + value + _infantCount > 9) {
                _message(
                  'Maximum 9 travelers are allowed per request.',
                );
                return;
              }

              setState(() {
                _childCount = value;
                _syncPassengerControllers();
                _resetSearch();
              });
            },
          ),
          _countRow(
            label: 'Infants',
            subtitle: 'Under 2 years',
            value: _infantCount,
            min: 0,
            max: _adultCount,
            onChanged: (int value) {
              if (_adultCount + _childCount + value > 9) {
                _message(
                  'Maximum 9 travelers are allowed per request.',
                );
                return;
              }

              setState(() {
                _infantCount = value;
                _syncPassengerControllers();
                _resetSearch();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _countRow({
    required String label,
    required String subtitle,
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Decrease $label',
          onPressed: value > min
              ? () => onChanged(value - 1)
              : null,
          icon: const Icon(
            Icons.remove_circle_outline_rounded,
          ),
        ),
        SizedBox(
          width: 28,
          child: Text(
            value.toString(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Increase $label',
          onPressed: value < max &&
                  _passengerCount < 9
              ? () => onChanged(value + 1)
              : null,
          icon: const Icon(
            Icons.add_circle_outline_rounded,
          ),
        ),
      ],
    );
  }

  Widget _resultsHeader() {
    return Row(
      children: <Widget>[
        const Expanded(
          child: Text(
            'Available Demo Quotes',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Chip(
          avatar: const Icon(
            Icons.schedule_rounded,
            size: 17,
          ),
          label: const Text(
            '15 min quote',
            style: TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _quoteCard(_DemoFlightQuote quote) {
    final bool selected =
        _selectedQuote?.quoteId == quote.quoteId;
    final double total = quote.totalFare(
      _passengerCount,
    );

    return Card(
      elevation: selected ? 3 : 1,
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedQuote = quote;
            _termsAccepted = false;
          });
        },
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
                      Icons.flight_rounded,
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
                          quote.airlineName,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '${quote.flightNumber} • $_cabinClass • ${quote.fareFamily}',
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
              const SizedBox(height: 13),
              _legRow(
                title: 'Outbound',
                departure: quote.outboundDeparture,
                arrival: quote.outboundArrival,
              ),
              if (quote.returnDeparture != null &&
                  quote.returnArrival != null) ...<Widget>[
                const Divider(height: 22),
                _legRow(
                  title: 'Return',
                  departure: quote.returnDeparture!,
                  arrival: quote.returnArrival!,
                ),
              ],
              const Divider(height: 22),
              Wrap(
                spacing: 10,
                runSpacing: 7,
                children: <Widget>[
                  _detailChip(
                    Icons.schedule_rounded,
                    _durationText(quote.durationMinutes),
                  ),
                  _detailChip(
                    Icons.alt_route_rounded,
                    quote.stops == 0 ? 'Direct' : '${quote.stops} stop',
                  ),
                  _detailChip(
                    Icons.airplanemode_active_rounded,
                    quote.aircraft,
                  ),
                  _detailChip(
                    Icons.luggage_rounded,
                    quote.baggage,
                  ),
                  _detailChip(
                    Icons.event_seat_rounded,
                    '${quote.seatsLeft} demo seats left',
                  ),
                  _detailChip(
                    quote.refundable
                        ? Icons.currency_exchange_rounded
                        : Icons.money_off_csred_rounded,
                    quote.refundable
                        ? 'Refundable fare'
                        : 'Non-refundable fare',
                  ),
                  _detailChip(
                    Icons.sync_alt_rounded,
                    quote.changeable ? 'Changeable' : 'No changes',
                  ),
                ],
              ),
              const SizedBox(height: 13),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      selected
                          ? 'Selected quote'
                          : 'Tap to select',
                      style: TextStyle(
                        color: selected
                            ? _rdGreen
                            : Colors.grey.shade600,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        'Rs. ${total.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: _rdBlue,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'for $_passengerCount traveler(s)',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _legRow({
    required String title,
    required DateTime departure,
    required DateTime arrival,
  }) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 70,
          child: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '${_timeText(departure)} → '
                '${_timeText(arrival)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${_dateText(departure)} • '
                '${_fromController.text.trim()} → '
                '${_toController.text.trim()}',
                style: TextStyle(
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _detailChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Enter details exactly as on the official ID/passport. '
              'For privacy, only the last 4 characters of the document '
              'number are stored in this client booking record.',
              style: TextStyle(
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 14),
            for (int index = 0;
                index < _passengerNameControllers.length;
                index++) ...<Widget>[
              _passengerPanel(index),
              const SizedBox(height: 12),
            ],
            const Divider(height: 24),
            const Text(
              'Contact Details',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Contact Phone',
                prefixIcon: Icon(Icons.phone_rounded),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email (optional)',
                prefixIcon: Icon(Icons.email_rounded),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _passengerPanel(int index) {
    final String passengerType = _passengerTypeAt(index);

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            '$passengerType Passenger ${index + 1}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _passengerNameControllers[index],
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Full Name',
              prefixIcon: Icon(Icons.person_rounded),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _passengerGender[index],
            decoration: const InputDecoration(
              labelText: 'Gender',
              border: OutlineInputBorder(),
            ),
            items: const <String>['Male', 'Female', 'Other']
                .map(
                  (String value) => DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  ),
                )
                .toList(),
            onChanged: (String? value) {
              if (value == null) return;
              setState(() {
                _passengerGender[index] = value;
                _termsAccepted = false;
              });
            },
          ),
          const SizedBox(height: 10),
          _dateField(
            label: 'Date of Birth',
            value: _passengerDob[index] == null
                ? 'Select DOB'
                : _dateText(_passengerDob[index]!),
            onTap: () => _pickPassengerDob(index),
          ),
          const SizedBox(height: 10),
          TextFormField(
            initialValue: _passengerNationality[index],
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nationality',
              prefixIcon: Icon(Icons.public_rounded),
              border: OutlineInputBorder(),
            ),
            onChanged: (String value) {
              _passengerNationality[index] =
                  value.trim().isEmpty ? 'Nepal' : value.trim();
              _termsAccepted = false;
            },
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _documentType[index],
            decoration: const InputDecoration(
              labelText: 'Travel Document',
              border: OutlineInputBorder(),
            ),
            items: (_travelScope == 'international'
                    ? <String>['Passport']
                    : <String>[
                        'Citizenship / National ID',
                        'Passport',
                        'Birth Certificate',
                      ])
                .map(
                  (String value) => DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  ),
                )
                .toList(),
            onChanged: (String? value) {
              if (value == null) return;
              setState(() {
                _documentType[index] = value;
                _termsAccepted = false;
              });
            },
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _documentNumberControllers[index],
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: _travelScope == 'international'
                  ? 'Passport Number'
                  : 'ID / Passport Number (optional for demo)',
              helperText: 'Only last 4 characters are saved.',
              prefixIcon: const Icon(Icons.badge_rounded),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          if (_travelScope == 'international') ...<Widget>[
            _dateField(
              label: 'Passport Expiry',
              value: _passportExpiry[index] == null
                  ? 'Select expiry date'
                  : _dateText(_passportExpiry[index]!),
              onTap: () => _pickPassportExpiry(index),
            ),
            const SizedBox(height: 10),
          ],
          DropdownButtonFormField<String>(
            initialValue: _seatPreference[index],
            decoration: const InputDecoration(
              labelText: 'Seat Preference',
              border: OutlineInputBorder(),
            ),
            items: const <String>[
              'Any',
              'Window',
              'Aisle',
              'Middle',
              'Front',
              'Extra Legroom',
            ]
                .map(
                  (String value) => DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  ),
                )
                .toList(),
            onChanged: (String? value) {
              if (value == null) return;
              setState(() {
                _seatPreference[index] = value;
                _termsAccepted = false;
              });
            },
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _mealPreference[index],
            decoration: const InputDecoration(
              labelText: 'Meal Preference',
              border: OutlineInputBorder(),
            ),
            items: const <String>[
              'Standard',
              'Vegetarian',
              'Vegan',
              'Halal',
              'No Meal',
            ]
                .map(
                  (String value) => DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  ),
                )
                .toList(),
            onChanged: (String? value) {
              if (value == null) return;
              setState(() {
                _mealPreference[index] = value;
                _termsAccepted = false;
              });
            },
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _specialAssistance[index],
            title: const Text(
              'Special assistance / wheelchair',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            onChanged: (bool value) {
              setState(() {
                _specialAssistance[index] = value;
                _termsAccepted = false;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _paymentCard() {
    return Card(
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              'Payment Option',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            SegmentedButton<String>(
              segments: const <ButtonSegment<String>>[
                ButtonSegment<String>(
                  value: 'online',
                  label: Text('Online'),
                  icon: Icon(Icons.payments_rounded),
                ),
                ButtonSegment<String>(
                  value: 'pay_at_office',
                  label: Text('Pay at RD Office'),
                  icon: Icon(Icons.storefront_rounded),
                ),
              ],
              selected: <String>{_paymentOption},
              onSelectionChanged: (Set<String> value) {
                setState(() {
                  _paymentOption = value.first;
                  _termsAccepted = false;
                });
              },
            ),
            if (_paymentOption == 'online') ...<Widget>[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _paymentMethod,
                decoration: const InputDecoration(
                  labelText: 'Online Payment Method',
                  prefixIcon: Icon(
                    Icons.account_balance_wallet_rounded,
                  ),
                  border: OutlineInputBorder(),
                ),
                items: const <String>[
                  'eSewa',
                  'Khalti',
                  'connectIPS',
                  'Bank',
                  'Card',
                ]
                    .map(
                      (String value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      ),
                    )
                    .toList(),
                onChanged: (String? value) {
                  if (value == null) return;
                  setState(() {
                    _paymentMethod = value;
                    _termsAccepted = false;
                  });
                },
              ),
            ],
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _paymentOption == 'online'
                    ? 'Payment remains Pending until official RD/provider verification.'
                    : 'Office payment remains Pending until an authorized RD/Admin user confirms collection.',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reviewAndSafetyCard() {
    final _DemoFlightQuote quote = _selectedQuote!;
    final double base =
        quote.baseFareTotal(_passengerCount);
    final double taxes =
        quote.taxTotal(_passengerCount);
    final double total =
        quote.totalFare(_passengerCount);

    return Card(
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              'Review & Fare Breakdown',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 13),
            _fareRow(
              'Base Fare',
              'Rs. ${base.toStringAsFixed(0)}',
            ),
            _fareRow(
              'Taxes',
              'Rs. ${taxes.toStringAsFixed(0)}',
            ),
            _fareRow(
              'RD / Booking Service Fee',
              'Rs. ${quote.serviceFee.toStringAsFixed(0)}',
            ),
            const Divider(height: 22),
            _fareRow(
              'Requested Total',
              'Rs. ${total.toStringAsFixed(0)}',
              strong: true,
            ),
            const SizedBox(height: 10),
            Text(
              'Demo quote expires at '
              '${_timeText(quote.quoteExpiresAt)}.',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red
                    .withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: Colors.red
                      .withValues(alpha: 0.18),
                ),
              ),
              child: const Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Anti-Scam Rules',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '• Do not pay to a personal bank/e-wallet number '
                    'sent by chat or phone.\n'
                    '• A booking request is not a confirmed ticket.\n'
                    '• PNR/e-ticket must come only after verified '
                    'provider confirmation.\n'
                    '• Never trust screenshots as proof of ticket '
                    'issuance; verify the PNR with the official provider.',
                    style: TextStyle(height: 1.45),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
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
                'I understand this is a booking request, not an '
                'issued airline ticket, until provider verification, '
                'payment confirmation and real PNR/e-ticket issuance.',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(height: 8),
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
                  'Submit Secure Booking Request',
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

class MyFlightTicketsPage extends StatelessWidget {
  const MyFlightTicketsPage({super.key});

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

  Future<void> _requestCancellation(
    BuildContext context,
    String bookingId,
    Map<String, dynamic> data,
  ) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String reasonText = '';

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Request Cancellation / Refund'),
        content: TextFormField(
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Reason',
            border: OutlineInputBorder(),
          ),
          onChanged: (String value) {
            reasonText = value.trim();
          },
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Submit Request'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (reasonText.length < 3) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a cancellation reason.'),
          ),
        );
      }
      return;
    }

    final DocumentReference<Map<String, dynamic>> ref =
        FirebaseFirestore.instance
            .collection('flight_cancellation_requests')
            .doc();

    try {
      await ref.set(<String, dynamic>{
        'requestId': ref.id,
        'bookingId': bookingId,
        'customerAuthUid': user.uid,
        'airlineName': data['airlineName']?.toString() ?? '',
        'flightNumber': data['flightNumber']?.toString() ?? '',
        'from': data['from']?.toString() ?? '',
        'to': data['to']?.toString() ?? '',
        'reason': reasonText,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cancellation/refund request submitted.'),
          ),
        );
      }
    } on FirebaseException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not submit request: ${error.message ?? error.code}',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'My Flight Tickets',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
        actions: <Widget>[
          IconButton(
            tooltip: 'Verify Flight Ticket',
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const FlightTicketVerifyPage(),
              ),
            ),
            icon: const Icon(Icons.qr_code_scanner_rounded),
          ),
        ],
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
                  .collection('ticket_bookings')
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
                        'Could not load tickets.\n'
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
                ].where(
                  (
                    QueryDocumentSnapshot<
                            Map<String, dynamic>>
                        doc,
                  ) =>
                      doc.data()['serviceType'] ==
                      'flight',
                ).toList();

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
                        'No flight booking requests yet.',
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

                    return _ticketCard(
                      context,
                      docs[index].id,
                      data,
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _ticketCard(
    BuildContext context,
    String documentId,
    Map<String, dynamic> data,
  ) {
    final String bookingId =
        data['bookingId']?.toString() ?? documentId;
    final String bookingCode =
        data['bookingCode']?.toString() ?? bookingId;
    final String from =
        data['from']?.toString() ?? '';
    final String to =
        data['to']?.toString() ?? '';
    final String airline =
        data['airlineName']?.toString() ?? 'Flight';
    final String flightNumber =
        data['flightNumber']?.toString() ?? '';
    final String bookingStatus =
        data['bookingStatus']?.toString() ??
            data['status']?.toString() ??
            'request_submitted';
    final String paymentStatus =
        data['paymentStatus']?.toString() ??
            'not_started';
    final String ticketStatus =
        data['ticketStatus']?.toString() ??
            'not_issued';
    final bool providerVerified =
        data['providerVerified'] == true;
    final String pnr =
        data['pnr']?.toString().trim() ?? '';
    final String eTicket =
        data['eTicketNumber']?.toString().trim() ?? '';
    final String token =
        data['qrVerificationToken']?.toString().trim() ?? '';
    final double total =
        _number(data['totalFare']);
    final bool isDemoTicket =
        data['isDemoTicket'] == true ||
        data['quoteSource']?.toString() == 'demo';
    final bool demoIssuedTicket =
        isDemoTicket &&
        providerVerified &&
        paymentStatus == 'paid' &&
        ticketStatus == 'demo_issued' &&
        pnr.isNotEmpty &&
        eTicket.isNotEmpty &&
        token.isNotEmpty;
    final bool validIssuedTicket =
        !isDemoTicket &&
        providerVerified &&
        paymentStatus == 'paid' &&
        ticketStatus == 'issued' &&
        pnr.isNotEmpty &&
        eTicket.isNotEmpty &&
        token.isNotEmpty;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleAvatar(
                  child: Icon(
                    validIssuedTicket
                        ? Icons.verified_rounded
                        : Icons.flight_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '$airline $flightNumber',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '$from → $to',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(
                    validIssuedTicket
                        ? 'ISSUED'
                        : (demoIssuedTicket
                            ? 'DEMO ISSUED'
                            : 'NOT ISSUED'),
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text(
              'Departure: '
              '${_dateTimeText(_date(data['outboundDeparture'] ?? data['departureAt']))}',
            ),
            const SizedBox(height: 5),
            Text(
              'Passengers: '
              '${data['passengerCount'] ?? 1}',
            ),
            const SizedBox(height: 5),
            Text(
              'Class: '
              '${data['cabinClass'] ?? 'Economy'}',
            ),
            const SizedBox(height: 5),
            Text(
              'Booking: ${_label(bookingStatus)}',
            ),
            const SizedBox(height: 5),
            Text(
              'Payment: ${_label(paymentStatus)}',
            ),
            const SizedBox(height: 5),
            Text(
              'Total: Rs. ${total.toStringAsFixed(0)}',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            if (validIssuedTicket)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green
                      .withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Verified Ticket',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    QrImageView(
                      data: 'RDFLIGHT|$token',
                      size: 170,
                    ),
                    const SizedBox(height: 8),
                    SelectableText('PNR: $pnr'),
                    SelectableText(
                      'E-ticket: $eTicket',
                    ),
                    SelectableText(
                      'Verify Token: $token',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              )
            else if (demoIssuedTicket)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange
                      .withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.orange
                        .withValues(alpha: 0.35),
                  ),
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'DEMO / TEST — NOT VALID FOR TRAVEL',
                      style: TextStyle(
                        color: Colors.deepOrange,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    QrImageView(
                      data: 'RDFLIGHT|$token',
                      size: 170,
                    ),
                    const SizedBox(height: 8),
                    SelectableText('Test PNR: $pnr'),
                    SelectableText(
                      'Test E-ticket: $eTicket',
                    ),
                    SelectableText(
                      'Verify Token: $token',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'This QR is only for RD app testing. The verifier '
                      'must show NOT VALID FOR TRAVEL.',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange
                      .withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'No verified airline ticket has been issued yet. '
                  'Do not travel or make an external payment based '
                  'only on this booking request.',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
                ),
              ),
            if (bookingStatus != 'cancelled' &&
                bookingStatus != 'refunded') ...<Widget>[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _requestCancellation(
                  context,
                  bookingId,
                  data,
                ),
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Request Cancellation / Refund'),
              ),
            ],
            const SizedBox(height: 9),
            SelectableText(
              'Booking Code: $bookingCode\nBooking ID: $bookingId',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminFlightTicketManagementPage extends StatefulWidget {
  const AdminFlightTicketManagementPage({super.key});

  @override
  State<AdminFlightTicketManagementPage> createState() =>
      _AdminFlightTicketManagementPageState();
}

class _AdminFlightTicketManagementPageState
    extends State<AdminFlightTicketManagementPage> {
  String _filter = 'all';

  String _token(String bookingId) {
    final Random random = Random.secure();
    final String raw =
        '$bookingId|${DateTime.now().microsecondsSinceEpoch}|'
        '${random.nextInt(1 << 32)}|${random.nextInt(1 << 32)}';
    return sha256
        .convert(utf8.encode(raw))
        .toString()
        .substring(0, 32)
        .toUpperCase();
  }

  Future<void> _verifyProvider(
    DocumentReference<Map<String, dynamic>> ref,
    Map<String, dynamic> data,
  ) async {
    String providerText =
        data['providerName']?.toString().trim() ?? '';
    String referenceText =
        data['providerBookingReference']?.toString().trim() ?? '';

    final bool? save = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Verify Official Provider'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextFormField(
              initialValue: providerText,
              decoration: const InputDecoration(
                labelText: 'Provider / Airline System',
                border: OutlineInputBorder(),
              ),
              onChanged: (String value) {
                providerText = value.trim();
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: referenceText,
              decoration: const InputDecoration(
                labelText: 'Provider Booking Reference',
                border: OutlineInputBorder(),
              ),
              onChanged: (String value) {
                referenceText = value.trim();
              },
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Verify'),
          ),
        ],
      ),
    );

    if (save != true) return;
    if (providerText.isEmpty || referenceText.isEmpty) {
      _message('Provider name and booking reference are required.');
      return;
    }

    try {
      await ref.update(<String, dynamic>{
        'providerVerified': true,
        'providerName': providerText,
        'providerBookingReference': referenceText,
        'bookingStatus': 'provider_confirmed',
        'fraudReviewStatus': 'reviewed',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _message('Provider verification saved.');
    } on FirebaseException catch (error) {
      _message(
        'Could not verify provider: ${error.message ?? error.code}',
      );
    }
  }

  Future<void> _markPaid(
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    await ref.update(<String, dynamic>{
      'paymentStatus': 'paid',
      'paymentConfirmedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _message('Payment marked Paid.');
  }

  Future<void> _issueTicket(
    DocumentReference<Map<String, dynamic>> ref,
    Map<String, dynamic> data,
  ) async {
    if (data['providerVerified'] != true) {
      _message('Verify the official provider first.');
      return;
    }
    if (data['paymentStatus'] != 'paid') {
      _message('Confirm payment before issuing ticket.');
      return;
    }

    final String quoteSource =
        data['quoteSource']?.toString().trim().toLowerCase() ?? '';
    final String airlineName =
        data['airlineName']?.toString().trim() ?? '';
    final bool isDemoBooking =
        quoteSource == 'demo' ||
        airlineName.toLowerCase().startsWith('rd demo');

    String pnrText = data['pnr']?.toString().trim() ?? '';
    String ticketText =
        data['eTicketNumber']?.toString().trim() ?? '';

    final bool? issue = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(
          isDemoBooking
              ? 'Issue Demo / Test Flight Ticket'
              : 'Issue Official Flight Ticket',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              isDemoBooking
                  ? 'This booking came from a DEMO quote. Enter test PNR '
                      'and test e-ticket values only. The resulting QR will '
                      'be marked DEMO / NOT VALID FOR TRAVEL.'
                  : 'Enter only the real PNR and e-ticket received from '
                      'the authorized airline/provider.',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: pnrText,
              decoration: InputDecoration(
                labelText: isDemoBooking ? 'Test PNR' : 'Real PNR',
                border: const OutlineInputBorder(),
              ),
              onChanged: (String value) {
                pnrText = value.trim();
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: ticketText,
              decoration: InputDecoration(
                labelText: isDemoBooking
                    ? 'Test E-ticket Number'
                    : 'Real E-ticket Number',
                border: const OutlineInputBorder(),
              ),
              onChanged: (String value) {
                ticketText = value.trim();
              },
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(isDemoBooking ? 'Issue Demo' : 'Issue'),
          ),
        ],
      ),
    );

    if (issue != true) return;
    if (pnrText.length < 4 || ticketText.length < 4) {
      _message(
        isDemoBooking
            ? 'Enter a test PNR and test e-ticket number.'
            : 'Valid PNR and e-ticket number are required.',
      );
      return;
    }

    final String token = _token(ref.id);
    final String ticketStatus =
        isDemoBooking ? 'demo_issued' : 'issued';
    final String verifyStatus =
        isDemoBooking ? 'demo_issued' : 'issued';

    try {
      final WriteBatch batch = FirebaseFirestore.instance.batch();

      batch.update(ref, <String, dynamic>{
        'pnr': pnrText,
        'eTicketNumber': ticketText,
        'qrVerificationToken': token,
        'bookingStatus': 'confirmed',
        'ticketStatus': ticketStatus,
        'isDemoTicket': isDemoBooking,
        'issuedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      batch.set(
        FirebaseFirestore.instance
            .collection('flight_ticket_public_verify')
            .doc(token),
        <String, dynamic>{
          'verifyToken': token,
          'bookingId': ref.id,
          'bookingCode':
              data['bookingCode']?.toString() ?? ref.id,
          'status': verifyStatus,
          'isDemoTicket': isDemoBooking,
          'quoteSource': quoteSource,
          'providerVerified': true,
          'paymentStatus': 'paid',
          'pnr': pnrText,
          'eTicketNumber': ticketText,
          'airlineName': airlineName,
          'flightNumber': data['flightNumber']?.toString() ?? '',
          'from': data['from']?.toString() ?? '',
          'to': data['to']?.toString() ?? '',
          'fromCode': data['fromCode']?.toString() ?? '',
          'toCode': data['toCode']?.toString() ?? '',
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await batch.commit();

      if (!mounted) return;

      _message(
        isDemoBooking
            ? 'Demo flight ticket issued for testing. NOT VALID FOR TRAVEL.'
            : 'Flight ticket issued with QR verification.',
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;
      _message(
        'Could not issue flight ticket: ${error.message ?? error.code}',
      );
    } catch (error) {
      if (!mounted) return;
      _message('Could not issue flight ticket: $error');
    }
  }

  Future<void> _cancel(
    DocumentReference<Map<String, dynamic>> ref,
    Map<String, dynamic> data,
  ) async {
    final String token =
        data['qrVerificationToken']?.toString().trim() ?? '';
    final WriteBatch batch = FirebaseFirestore.instance.batch();

    batch.update(ref, <String, dynamic>{
      'bookingStatus': 'cancelled',
      'ticketStatus': 'cancelled',
      'refundStatus': data['paymentStatus'] == 'paid'
          ? 'pending'
          : 'not_required',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (token.isNotEmpty) {
      batch.set(
        FirebaseFirestore.instance
            .collection('flight_ticket_public_verify')
            .doc(token),
        <String, dynamic>{
          'status': 'cancelled',
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
    _message('Flight booking cancelled.');
  }

  Future<void> _markRefunded(
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    await ref.update(<String, dynamic>{
      'paymentStatus': 'refunded',
      'bookingStatus': 'refunded',
      'refundedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _message('Refund marked complete.');
  }

  bool _show(Map<String, dynamic> data) {
    if (data['serviceType'] != 'flight') return false;
    final String booking = data['bookingStatus']?.toString() ?? '';
    final String ticket = data['ticketStatus']?.toString() ?? '';
    return _filter == 'all' ||
        (_filter == 'requests' && booking == 'request_submitted') ||
        (_filter == 'confirmed' && booking == 'confirmed') ||
        (_filter == 'issued' &&
            (ticket == 'issued' || ticket == 'demo_issued')) ||
        (_filter == 'cancelled' &&
            (booking == 'cancelled' || booking == 'refunded'));
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'Flight Ticket Management',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
        actions: <Widget>[
          IconButton(
            tooltip: 'Cancellation / Refund Requests',
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) =>
                    const AdminFlightCancellationRequestsPage(),
              ),
            ),
            icon: const Icon(
              Icons.assignment_return_outlined,
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('ticket_bookings')
            .snapshots(),
        builder: (
          BuildContext context,
          AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
        ) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Could not load flight bookings.\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }

          final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
              <QueryDocumentSnapshot<Map<String, dynamic>>>[
            ...?snapshot.data?.docs,
          ].where(
            (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                _show(doc.data()),
          ).toList();

          return Column(
            children: <Widget>[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: <String>[
                    'all',
                    'requests',
                    'confirmed',
                    'issued',
                    'cancelled',
                  ].map(
                    (String value) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(value.toUpperCase()),
                        selected: _filter == value,
                        onSelected: (_) {
                          setState(() {
                            _filter = value;
                          });
                        },
                      ),
                    ),
                  ).toList(),
                ),
              ),
              Expanded(
                child: docs.isEmpty
                    ? const Center(
                        child: Text('No flight bookings in this filter.'),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: docs.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (
                          BuildContext context,
                          int index,
                        ) {
                          final QueryDocumentSnapshot<Map<String, dynamic>>
                              doc = docs[index];
                          final Map<String, dynamic> data = doc.data();
                          final bool providerVerified =
                              data['providerVerified'] == true;
                          final bool paid = data['paymentStatus'] == 'paid';
                          final String ticketStatus =
                              data['ticketStatus']?.toString() ?? '';
                          final bool issued =
                              ticketStatus == 'issued' ||
                              ticketStatus == 'demo_issued';
                          final bool cancelled =
                              data['bookingStatus'] == 'cancelled';
                          final bool refunded =
                              data['paymentStatus'] == 'refunded';

                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  SelectableText(
                                    'Booking: ${data['bookingCode'] ?? doc.id}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${data['airlineName'] ?? ''} '
                                    '${data['flightNumber'] ?? ''}',
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    '${data['fromCode'] ?? data['from'] ?? ''} '
                                    '→ ${data['toCode'] ?? data['to'] ?? ''}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text('Booking: ${data['bookingStatus'] ?? ''}'),
                                  Text('Payment: ${data['paymentStatus'] ?? ''}'),
                                  Text('Provider verified: $providerVerified'),
                                  Text('Ticket: ${data['ticketStatus'] ?? ''}'),
                                  Text('Total: Rs. ${data['totalFare'] ?? 0}'),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: <Widget>[
                                      if (!providerVerified && !cancelled)
                                        FilledButton.tonalIcon(
                                          onPressed: () => _verifyProvider(
                                            doc.reference,
                                            data,
                                          ),
                                          icon: const Icon(
                                            Icons.domain_verification_rounded,
                                          ),
                                          label: const Text('Verify Provider'),
                                        ),
                                      if (!paid && !cancelled && !refunded)
                                        FilledButton.tonalIcon(
                                          onPressed: () =>
                                              _markPaid(doc.reference),
                                          icon: const Icon(Icons.payments_rounded),
                                          label: const Text('Confirm Payment'),
                                        ),
                                      if (providerVerified &&
                                          paid &&
                                          !issued &&
                                          !cancelled)
                                        FilledButton.icon(
                                          onPressed: () => _issueTicket(
                                            doc.reference,
                                            data,
                                          ),
                                          icon: const Icon(
                                            Icons.airplane_ticket_rounded,
                                          ),
                                          label: const Text('Issue Ticket'),
                                        ),
                                      if (!cancelled && !refunded)
                                        OutlinedButton.icon(
                                          onPressed: () => _cancel(
                                            doc.reference,
                                            data,
                                          ),
                                          icon: const Icon(Icons.cancel_outlined),
                                          label: const Text('Cancel'),
                                        ),
                                      if (cancelled && paid && !refunded)
                                        OutlinedButton.icon(
                                          onPressed: () =>
                                              _markRefunded(doc.reference),
                                          icon: const Icon(
                                            Icons.currency_exchange_rounded,
                                          ),
                                          label: const Text('Mark Refunded'),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}


class AdminFlightCancellationRequestsPage
    extends StatelessWidget {
  const AdminFlightCancellationRequestsPage({super.key});

  Future<void> _setRequestStatus(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> requestDoc,
    String status,
  ) async {
    final Map<String, dynamic> request = requestDoc.data();
    final String bookingId =
        request['bookingId']?.toString() ?? '';

    if (bookingId.isEmpty) {
      return;
    }

    final DocumentReference<Map<String, dynamic>> bookingRef =
        FirebaseFirestore.instance
            .collection('ticket_bookings')
            .doc(bookingId);

    try {
      final DocumentSnapshot<Map<String, dynamic>> bookingDoc =
          await bookingRef.get();
      final Map<String, dynamic> booking =
          bookingDoc.data() ?? <String, dynamic>{};
      final String token =
          booking['qrVerificationToken']?.toString().trim() ?? '';

      final WriteBatch batch =
          FirebaseFirestore.instance.batch();

      batch.update(
        requestDoc.reference,
        <String, dynamic>{
          'status': status,
          'reviewedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      if (status == 'approved' && bookingDoc.exists) {
        batch.update(
          bookingRef,
          <String, dynamic>{
            'bookingStatus': 'cancelled',
            'ticketStatus': 'cancelled',
            'refundStatus':
                booking['paymentStatus'] == 'paid'
                    ? 'pending'
                    : 'not_required',
            'cancelledAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );

        if (token.isNotEmpty) {
          batch.set(
            FirebaseFirestore.instance
                .collection('flight_ticket_public_verify')
                .doc(token),
            <String, dynamic>{
              'status': 'cancelled',
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }
      }

      await batch.commit();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'approved'
                  ? 'Cancellation request approved.'
                  : 'Cancellation request rejected.',
            ),
          ),
        );
      }
    } on FirebaseException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not update request: '
              '${error.message ?? error.code}',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Flight Cancellation / Refund',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('flight_cancellation_requests')
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
              child: Text(
                'Could not load cancellation requests.\n'
                '${snapshot.error}',
                textAlign: TextAlign.center,
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
              QueryDocumentSnapshot<Map<String, dynamic>> a,
              QueryDocumentSnapshot<Map<String, dynamic>> b,
            ) {
              final Timestamp? at =
                  a.data()['createdAt'] as Timestamp?;
              final Timestamp? bt =
                  b.data()['createdAt'] as Timestamp?;
              return (bt?.millisecondsSinceEpoch ?? 0)
                  .compareTo(
                at?.millisecondsSinceEpoch ?? 0,
              );
            },
          );

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'No flight cancellation/refund requests.',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: docs.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: 10),
            itemBuilder: (
              BuildContext context,
              int index,
            ) {
              final QueryDocumentSnapshot<
                      Map<String, dynamic>>
                  doc = docs[index];
              final Map<String, dynamic> data =
                  doc.data();
              final String status =
                  data['status']?.toString() ?? 'pending';

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        '${data['airlineName'] ?? ''} '
                        '${data['flightNumber'] ?? ''}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '${data['from'] ?? ''} → ${data['to'] ?? ''}',
                      ),
                      const SizedBox(height: 5),
                      SelectableText(
                        'Booking ID: ${data['bookingId'] ?? ''}',
                      ),
                      Text(
                        'Reason: ${data['reason'] ?? ''}',
                      ),
                      Text(
                        'Status: ${status.toUpperCase()}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (status == 'pending') ...<Widget>[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            FilledButton.icon(
                              onPressed: () =>
                                  _setRequestStatus(
                                context,
                                doc,
                                'approved',
                              ),
                              icon: const Icon(
                                Icons.check_circle_rounded,
                              ),
                              label: const Text('Approve'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () =>
                                  _setRequestStatus(
                                context,
                                doc,
                                'rejected',
                              ),
                              icon: const Icon(
                                Icons.cancel_outlined,
                              ),
                              label: const Text('Reject'),
                            ),
                          ],
                        ),
                      ],
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

class FlightTicketVerifyPage extends StatefulWidget {
  const FlightTicketVerifyPage({super.key});

  @override
  State<FlightTicketVerifyPage> createState() =>
      _FlightTicketVerifyPageState();
}

class _FlightTicketVerifyPageState
    extends State<FlightTicketVerifyPage> {
  final TextEditingController _controller = TextEditingController();
  bool _loading = false;
  Map<String, dynamic>? _result;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _cameraSupported {
    if (kIsWeb) {
      return true;
    }

    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  Future<void> _scanQr() async {
    if (!_cameraSupported) {
      setState(() {
        _error =
            'Camera QR scanning is not available on this platform. Enter the token manually.';
        _result = null;
      });
      return;
    }

    final String? raw = await Navigator.push<String>(
      context,
      MaterialPageRoute<String>(
        builder: (_) => const _FlightQrScannerPage(),
      ),
    );

    if (!mounted || raw == null || raw.trim().isEmpty) {
      return;
    }

    _controller.value = TextEditingValue(
      text: raw.trim(),
      selection: TextSelection.collapsed(
        offset: raw.trim().length,
      ),
    );

    await _verify();
  }

  String _token(String raw) {
    final String value = raw.trim();
    return value.startsWith('RDFLIGHT|')
        ? value.substring(9).trim()
        : value;
  }

  Future<void> _verify() async {
    final String token = _token(_controller.text);
    if (token.isEmpty) {
      setState(() {
        _error = 'Enter a flight verification token.';
        _result = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    try {
      final DocumentSnapshot<Map<String, dynamic>> doc =
          await FirebaseFirestore.instance
              .collection('flight_ticket_public_verify')
              .doc(token)
              .get();

      if (!mounted) return;

      if (!doc.exists) {
        setState(() {
          _error = 'Flight ticket verification record not found.';
          _loading = false;
        });
        return;
      }

      setState(() {
        _result = doc.data() ?? <String, dynamic>{};
        _loading = false;
      });
    } on FirebaseException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message ?? error.code;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic>? result = _result;
    final bool isDemoTicket =
        result?['isDemoTicket'] == true ||
        result?['quoteSource']?.toString() == 'demo';
    final bool valid = result != null &&
        !isDemoTicket &&
        result['status'] == 'issued' &&
        result['providerVerified'] == true &&
        result['paymentStatus'] == 'paid';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Verify Flight Ticket',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  labelText: 'QR / Verify Token',
                  hintText: 'Paste RDFLIGHT token',
                  prefixIcon: Icon(Icons.qr_code_scanner_rounded),
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _verify(),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  FilledButton.icon(
                    onPressed: _loading ? null : _verify,
                    icon: _loading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.verified_rounded),
                    label: const Text('Verify Ticket'),
                  ),
                  OutlinedButton.icon(
                    onPressed:
                        _loading || !_cameraSupported ? null : _scanQr,
                    icon: const Icon(
                      Icons.qr_code_scanner_rounded,
                    ),
                    label: Text(
                      _cameraSupported
                          ? 'Scan QR with Camera'
                          : 'Camera Scanner Unavailable',
                    ),
                  ),
                ],
              ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: 14),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
              if (result != null) ...<Widget>[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Icon(
                          valid
                              ? Icons.verified_rounded
                              : Icons.warning_amber_rounded,
                          size: 54,
                          color: valid ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          valid
                              ? 'VALID / ISSUED'
                              : (isDemoTicket
                                  ? 'DEMO / TEST — NOT VALID FOR TRAVEL'
                                  : 'NOT VALID FOR TRAVEL'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: valid ? Colors.green : Colors.orange,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Divider(height: 24),
                        SelectableText(
                          'Booking Code: ${result['bookingCode'] ?? ''}',
                        ),
                        SelectableText(
                          'Booking ID: ${result['bookingId'] ?? ''}',
                        ),
                        SelectableText('PNR: ${result['pnr'] ?? ''}'),
                        SelectableText(
                          'E-ticket: ${result['eTicketNumber'] ?? ''}',
                        ),
                        Text(
                          'Flight: ${result['airlineName'] ?? ''} '
                          '${result['flightNumber'] ?? ''}',
                        ),
                        Text(
                          'Route: ${result['fromCode'] ?? result['from'] ?? ''} '
                          '→ ${result['toCode'] ?? result['to'] ?? ''}',
                        ),
                        Text(
                          'Payment: ${result['paymentStatus'] ?? ''}',
                        ),
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


class _FlightQrScannerPage extends StatefulWidget {
  const _FlightQrScannerPage();

  @override
  State<_FlightQrScannerPage> createState() =>
      _FlightQrScannerPageState();
}

class _FlightQrScannerPageState
    extends State<_FlightQrScannerPage> {
  final MobileScannerController _scannerController =
      MobileScannerController(
    formats: const <BarcodeFormat>[
      BarcodeFormat.qrCode,
    ],
  );

  bool _returned = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_returned || capture.barcodes.isEmpty) {
      return;
    }

    final String? raw =
        capture.barcodes.first.rawValue;

    if (raw == null || raw.trim().isEmpty) {
      return;
    }

    _returned = true;
    Navigator.pop<String>(
      context,
      raw.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Scan Flight Ticket QR',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
          ),
          Center(
            child: IgnorePointer(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white,
                    width: 3,
                  ),
                  borderRadius:
                      BorderRadius.circular(18),
                ),
              ),
            ),
          ),
          const Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'Place the RD Flight Ticket QR inside the frame.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoFlightQuote {
  const _DemoFlightQuote({
    required this.quoteId,
    required this.airlineName,
    required this.flightNumber,
    required this.outboundDeparture,
    required this.outboundArrival,
    required this.returnDeparture,
    required this.returnArrival,
    required this.baseFarePerTraveler,
    required this.taxPerTraveler,
    required this.serviceFee,
    required this.baggage,
    required this.refundable,
    required this.changeable,
    required this.seatsLeft,
    required this.stops,
    required this.aircraft,
    required this.fareFamily,
    required this.departureTerminal,
    required this.arrivalTerminal,
    required this.cancellationPolicy,
    required this.durationMinutes,
    required this.quoteExpiresAt,
  });

  final String quoteId;
  final String airlineName;
  final String flightNumber;
  final DateTime outboundDeparture;
  final DateTime outboundArrival;
  final DateTime? returnDeparture;
  final DateTime? returnArrival;
  final double baseFarePerTraveler;
  final double taxPerTraveler;
  final double serviceFee;
  final String baggage;
  final bool refundable;
  final bool changeable;
  final int seatsLeft;
  final int stops;
  final String aircraft;
  final String fareFamily;
  final String departureTerminal;
  final String arrivalTerminal;
  final String cancellationPolicy;
  final int durationMinutes;
  final DateTime quoteExpiresAt;

  double baseFareTotal(int passengerCount) =>
      baseFarePerTraveler * passengerCount;

  double taxTotal(int passengerCount) =>
      taxPerTraveler * passengerCount;

  double totalFare(int passengerCount) =>
      baseFareTotal(passengerCount) +
      taxTotal(passengerCount) +
      serviceFee;
}
