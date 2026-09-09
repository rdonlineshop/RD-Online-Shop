import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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

  final TextEditingController _fromController =
      TextEditingController();
  final TextEditingController _toController =
      TextEditingController();
  final TextEditingController _phoneController =
      TextEditingController();
  final TextEditingController _emailController =
      TextEditingController();

  final List<TextEditingController> _passengerNameControllers =
      <TextEditingController>[
    TextEditingController(),
  ];

  DateTime _departureDate =
      DateTime.now().add(const Duration(days: 1));
  DateTime? _returnDate;

  String _tripType = 'one_way';
  String _cabinClass = 'Economy';

  int _adultCount = 1;
  int _childCount = 0;
  int _infantCount = 0;

  bool _directOnly = false;
  bool _flexibleDates = false;
  bool _termsAccepted = false;
  bool _searching = false;
  bool _submitting = false;

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


  void _resetSearch() {
    _quotes = <_DemoFlightQuote>[];
    _selectedQuote = null;
    _termsAccepted = false;
  }

  void _syncPassengerControllers() {
    final int needed = _passengerCount;

    while (_passengerNameControllers.length < needed) {
      _passengerNameControllers.add(
        TextEditingController(),
      );
    }

    while (_passengerNameControllers.length > needed) {
      final TextEditingController removed =
          _passengerNameControllers.removeLast();
      removed.dispose();
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
      _resetSearch();
    });

    await Future<void>.delayed(
      const Duration(milliseconds: 450),
    );

    if (!mounted) {
      return;
    }

    final double classMultiplier = switch (_cabinClass) {
      'Premium Economy' => 1.30,
      'Business' => 1.90,
      _ => 1.0,
    };

    final double tripMultiplier =
        _tripType == 'round_trip' ? 1.90 : 1.0;

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
      required int seatsLeft,
    }) {
      final DateTime outboundDeparture = DateTime(
        _departureDate.year,
        _departureDate.month,
        _departureDate.day,
        departureHour,
        departureMinute,
      );

      final DateTime outboundArrival =
          outboundDeparture.add(
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
            '$id-${DateTime.now().millisecondsSinceEpoch}',
        airlineName: airline,
        flightNumber: flightNumber,
        outboundDeparture: outboundDeparture,
        outboundArrival: outboundArrival,
        returnDeparture: returnDeparture,
        returnArrival: returnArrival,
        baseFarePerTraveler:
            baseFare * classMultiplier * tripMultiplier,
        taxPerTraveler:
            tax * tripMultiplier,
        serviceFee:
            serviceFee * tripMultiplier,
        baggage: baggage,
        refundable: refundable,
        seatsLeft: seatsLeft,
        quoteExpiresAt:
            DateTime.now().add(const Duration(minutes: 15)),
      );
    }

    final List<_DemoFlightQuote> results =
        <_DemoFlightQuote>[
      makeQuote(
        id: 'RDQ101',
        airline: 'RD Demo Air',
        flightNumber: 'RD 101',
        departureHour: 7,
        departureMinute: 30,
        durationMinutes: 75,
        baseFare: 3900,
        tax: 550,
        serviceFee: 250,
        baggage: '15 kg checked + 5 kg cabin',
        refundable: false,
        seatsLeft: 7,
      ),
      makeQuote(
        id: 'RDQ205',
        airline: 'RD Demo Air',
        flightNumber: 'RD 205',
        departureHour: 13,
        departureMinute: 15,
        durationMinutes: 70,
        baseFare: 4400,
        tax: 600,
        serviceFee: 250,
        baggage: '20 kg checked + 7 kg cabin',
        refundable: true,
        seatsLeft: 4,
      ),
      makeQuote(
        id: 'RDQ309',
        airline: 'RD Demo Air',
        flightNumber: 'RD 309',
        departureHour: 18,
        departureMinute: 45,
        durationMinutes: 80,
        baseFare: 5000,
        tax: 650,
        serviceFee: 250,
        baggage: '20 kg checked + 7 kg cabin',
        refundable: true,
        seatsLeft: 3,
      ),
    ];

    setState(() {
      _quotes = results;
      _searching = false;
    });
  }

  List<String> _passengerNames() =>
      _passengerNameControllers
          .map(
            (TextEditingController controller) =>
                controller.text.trim(),
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

      await ref.set(
        <String, dynamic>{
          'bookingId': ref.id,
          'bookingVersion': 2,
          'serviceType': 'flight',
          'customerAuthUid': user.uid,
          'customerId': customerId,
          'tripType': _tripType,
          'from': _fromController.text.trim(),
          'to': _toController.text.trim(),
          'departureDate':
              Timestamp.fromDate(_departureDate),
          'returnDate': _returnDate == null
              ? null
              : Timestamp.fromDate(_returnDate!),
          'adultCount': _adultCount,
          'childCount': _childCount,
          'infantCount': _infantCount,
          'passengerCount': _passengerCount,
          'passengerNames': passengerNames,
          'passengerTypes': passengerTypes,
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
          'baseFare': baseFare,
          'taxes': taxes,
          'serviceFee': quote.serviceFee,
          'totalFare': totalFare,
          'currency': 'Rs.',
          'quoteId': quote.quoteId,
          'quoteSource': 'demo',
          'quoteExpiresAt':
              Timestamp.fromDate(quote.quoteExpiresAt),
          'providerVerified': false,
          'providerName': '',
          'providerBookingReference': '',
          'pnr': '',
          'eTicketNumber': '',
          'bookingStatus': 'request_submitted',
          'paymentStatus': 'not_started',
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
              'Booking Request Submitted',
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
                  _summaryLine('Booking ID', ref.id),
                  _summaryLine(
                    'Route',
                    '${_fromController.text.trim()} → '
                        '${_toController.text.trim()}',
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
                if (!_searching && _quotes.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 22),
                  _resultsHeader(),
                  const SizedBox(height: 10),
                  ..._quotes.map(_quoteCard),
                ],
                if (_selectedQuote != null) ...<Widget>[
                  const SizedBox(height: 18),
                  _passengerCard(),
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
            const SizedBox(height: 13),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
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
                    hintText: 'City or airport',
                    prefixIcon: Icon(
                      Icons.flight_takeoff_rounded,
                    ),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) {
                    if (_quotes.isNotEmpty) {
                      setState(_resetSearch);
                    }
                  },
                );

                final Widget toField = TextField(
                  controller: _toController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'To',
                    hintText: 'City or airport',
                    prefixIcon: Icon(
                      Icons.flight_land_rounded,
                    ),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) {
                    if (_quotes.isNotEmpty) {
                      setState(_resetSearch);
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
                    Align(
                      alignment: Alignment.center,
                      child: swap,
                    ),
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
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _directOnly,
              title: const Text(
                'Direct flights only',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
              onChanged: (bool value) {
                setState(() {
                  _directOnly = value;
                  _resetSearch();
                });
              },
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _flexibleDates,
              title: const Text(
                'Flexible travel dates',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                ),
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
                onPressed:
                    _searching ? null : _searchFlights,
                icon: const Icon(Icons.search_rounded),
                label: const Text(
                  'Search Flights',
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
                          '${quote.flightNumber} • $_cabinClass',
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
              'Enter names exactly as they should appear '
              'for airline verification.',
              style: TextStyle(
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 14),
            for (int index = 0;
                index < _passengerNameControllers.length;
                index++) ...<Widget>[
              TextField(
                controller:
                    _passengerNameControllers[index],
                textCapitalization:
                    TextCapitalization.words,
                textInputAction:
                    index ==
                            _passengerNameControllers.length -
                                1
                        ? TextInputAction.next
                        : TextInputAction.next,
                decoration: InputDecoration(
                  labelText:
                      '${_passengerTypeAt(index)} '
                      'Passenger ${index + 1} • Full Name',
                  prefixIcon:
                      const Icon(Icons.person_rounded),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
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
              keyboardType:
                  TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email (optional)',
                prefixIcon: Icon(Icons.email_rounded),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: Colors.amber
                    .withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Passport/ID numbers are intentionally NOT stored '
                'in this demo client flow. Sensitive identity data '
                'should be collected only through a secured provider/'
                'server workflow when real airline booking is connected.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
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
    final double total =
        _number(data['totalFare']);

    final bool validIssuedTicket =
        providerVerified &&
        ticketStatus == 'issued' &&
        pnr.isNotEmpty &&
        eTicket.isNotEmpty;

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
                        : 'NOT ISSUED',
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
                    const SizedBox(height: 5),
                    SelectableText('PNR: $pnr'),
                    SelectableText(
                      'E-ticket: $eTicket',
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
            const SizedBox(height: 9),
            SelectableText(
              'Booking ID: $bookingId',
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
    required this.seatsLeft,
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
  final int seatsLeft;
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
