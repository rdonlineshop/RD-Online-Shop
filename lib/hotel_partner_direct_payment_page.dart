import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'hotel_cloudinary_service.dart';

class HotelPartnerDirectPaymentPage
    extends StatefulWidget {
  const HotelPartnerDirectPaymentPage({
    super.key,
  });

  @override
  State<HotelPartnerDirectPaymentPage>
      createState() =>
          _HotelPartnerDirectPaymentPageState();
}

class _HotelPartnerDirectPaymentPageState
    extends State<HotelPartnerDirectPaymentPage> {
  static const Color _rdGreen =
      Color(0xFF2E7D32);
  static const Color _rdRed =
      Color(0xFFD32F2F);

  final TextEditingController _esewaName =
      TextEditingController();
  final TextEditingController _esewaNumber =
      TextEditingController();

  final TextEditingController _khaltiName =
      TextEditingController();
  final TextEditingController _khaltiNumber =
      TextEditingController();

  final TextEditingController _bankName =
      TextEditingController();
  final TextEditingController _bankAccountName =
      TextEditingController();
  final TextEditingController _bankAccountNumber =
      TextEditingController();

  final TextEditingController _connectIpsId =
      TextEditingController();
  final TextEditingController
      _mobileBankingDetails =
      TextEditingController();

  final TextEditingController _instructions =
      TextEditingController();

  bool _enabled = false;
  bool _loading = true;
  bool _saving = false;
  bool _uploadingQr = false;

  String _hotelName = '';
  String _paymentQrUrl = '';

  User? get _user =>
      FirebaseAuth.instance.currentUser;

  String get _partnerId =>
      _user?.uid ?? '';

  DocumentReference<Map<String, dynamic>>
      get _settingsRef =>
          FirebaseFirestore.instance
              .collection(
                'hotel_direct_payment_accounts',
              )
              .doc(_partnerId);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _esewaName.dispose();
    _esewaNumber.dispose();
    _khaltiName.dispose();
    _khaltiNumber.dispose();
    _bankName.dispose();
    _bankAccountName.dispose();
    _bankAccountNumber.dispose();
    _connectIpsId.dispose();
    _mobileBankingDetails.dispose();
    _instructions.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final User? user = _user;

    if (user == null || user.isAnonymous) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
      return;
    }

    try {
      final List<
              DocumentSnapshot<
                  Map<String, dynamic>>>
          docs = await Future.wait(
        <Future<
            DocumentSnapshot<
                Map<String, dynamic>>>>[
          FirebaseFirestore.instance
              .collection('hotels')
              .doc(user.uid)
              .get(),
          FirebaseFirestore.instance
              .collection(
                'hotel_direct_payment_accounts',
              )
              .doc(user.uid)
              .get(),
        ],
      );

      final Map<String, dynamic> hotel =
          docs[0].data() ??
              <String, dynamic>{};

      final Map<String, dynamic> data =
          docs[1].data() ??
              <String, dynamic>{};

      if (!mounted) {
        return;
      }

      setState(() {
        _hotelName =
            hotel['name']?.toString().trim() ??
                '';

        _enabled =
            data['enabled'] == true;

        _esewaName.text =
            data['esewaName']
                    ?.toString() ??
                '';

        _esewaNumber.text =
            data['esewaNumber']
                    ?.toString() ??
                '';

        _khaltiName.text =
            data['khaltiName']
                    ?.toString() ??
                '';

        _khaltiNumber.text =
            data['khaltiNumber']
                    ?.toString() ??
                '';

        _bankName.text =
            data['bankName']
                    ?.toString() ??
                '';

        _bankAccountName.text =
            data['bankAccountName']
                    ?.toString() ??
                '';

        _bankAccountNumber.text =
            data['bankAccountNumber']
                    ?.toString() ??
                '';

        _connectIpsId.text =
            data['connectIpsId']
                    ?.toString() ??
                '';

        _mobileBankingDetails.text =
            data['mobileBankingDetails']
                    ?.toString() ??
                '';

        _instructions.text =
            data['instructions']
                    ?.toString() ??
                '';

        _paymentQrUrl =
            data['paymentQrUrl']
                    ?.toString() ??
                '';
      });
    } catch (error) {
      _message(
        'Could not load direct payment settings.\n'
        '$error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  bool get _hasAtLeastOneMethod {
    final bool esewa =
        _esewaNumber.text.trim().isNotEmpty;

    final bool khalti =
        _khaltiNumber.text.trim().isNotEmpty;

    final bool bank =
        _bankName.text.trim().isNotEmpty &&
            _bankAccountName.text
                .trim()
                .isNotEmpty &&
            _bankAccountNumber.text
                .trim()
                .isNotEmpty;

    final bool connectIps =
        _connectIpsId.text.trim().isNotEmpty;

    final bool mobileBanking =
        _mobileBankingDetails.text
            .trim()
            .isNotEmpty;

    final bool qr =
        _paymentQrUrl.trim().isNotEmpty;

    return esewa ||
        khalti ||
        bank ||
        connectIps ||
        mobileBanking ||
        qr;
  }

  Future<void> _uploadQr() async {
    if (_uploadingQr) {
      return;
    }

    setState(() {
      _uploadingQr = true;
    });

    try {
      final String? url =
          await HotelCloudinaryService
              .pickAndUploadImage(
        imageQuality: 90,
      );

      if (!mounted || url == null) {
        return;
      }

      setState(() {
        _paymentQrUrl = url;
      });

      _message(
        'Hotel payment QR is ready. '
        'Press Save Direct Payment.',
      );
    } catch (error) {
      _message(
        'Could not upload payment QR.\n'
        '$error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploadingQr = false;
        });
      }
    }
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }

    final User? user = _user;

    if (user == null ||
        user.isAnonymous) {
      _message(
        'Hotel Partner login is required.',
      );
      return;
    }

    if (_enabled &&
        !_hasAtLeastOneMethod) {
      _message(
        'Add at least one Hotel payment '
        'method before enabling direct payment.',
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await _settingsRef.set(
        <String, dynamic>{
          'partnerId': user.uid,
          'hotelId': user.uid,
          'hotelName': _hotelName,
          'enabled': _enabled,
          'esewaName':
              _esewaName.text.trim(),
          'esewaNumber':
              _esewaNumber.text.trim(),
          'khaltiName':
              _khaltiName.text.trim(),
          'khaltiNumber':
              _khaltiNumber.text.trim(),
          'bankName':
              _bankName.text.trim(),
          'bankAccountName':
              _bankAccountName.text.trim(),
          'bankAccountNumber':
              _bankAccountNumber.text.trim(),
          'connectIpsId':
              _connectIpsId.text.trim(),
          'mobileBankingDetails':
              _mobileBankingDetails.text
                  .trim(),
          'paymentQrUrl':
              _paymentQrUrl.trim(),
          'instructions':
              _instructions.text.trim(),
          'updatedAt':
              FieldValue.serverTimestamp(),
          'createdAt':
              FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      _message(
        _enabled
            ? 'Direct Online Payment is enabled for this Hotel.'
            : 'Direct Online Payment settings saved. It is currently disabled.',
      );
    } catch (error) {
      _message(
        'Could not save direct payment settings.\n'
        '$error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _verifyPayment(
    QueryDocumentSnapshot<
            Map<String, dynamic>>
        bookingDoc,
  ) async {
    final User? user = _user;

    if (user == null ||
        user.isAnonymous) {
      return;
    }

    final Map<String, dynamic> data =
        bookingDoc.data();

    final bool? confirm =
        await showDialog<bool>(
      context: context,
      builder:
          (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text(
            'Verify Payment Received',
            style: TextStyle(
              fontWeight:
                  FontWeight.w900,
            ),
          ),
          content: Text(
            'Confirm only after checking your '
            'Hotel bank / eSewa / Khalti / '
            'connectIPS / Mobile Banking account '
            'and confirming that Rs. '
            '${((data['totalAmount'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)} '
            'was actually received.\n\n'
            'Transaction reference: '
            '${data['paymentReference'] ?? ''}',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                dialogContext,
                false,
              ),
              child:
                  const Text('Not Yet'),
            ),
            FilledButton.icon(
              onPressed: () =>
                  Navigator.pop(
                dialogContext,
                true,
              ),
              icon: const Icon(
                Icons.verified_rounded,
              ),
              label: const Text(
                'Money Received',
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    try {
      await FirebaseFirestore.instance
          .runTransaction(
        (Transaction transaction) async {
          final DocumentSnapshot<
                  Map<String, dynamic>>
              live =
              await transaction.get(
            bookingDoc.reference,
          );

          if (!live.exists) {
            throw StateError(
              'Booking not found.',
            );
          }

          final Map<String, dynamic>
              current =
              live.data()!;

          if (current['partnerId'] !=
              user.uid) {
            throw StateError(
              'This payment does not belong to your Hotel.',
            );
          }

          if (current['paymentOption'] !=
              'direct_hotel_online') {
            throw StateError(
              'This is not a direct Hotel payment.',
            );
          }

          if (current['paymentStatus'] ==
              'paid') {
            throw StateError(
              'Payment is already verified.',
            );
          }

          if (current['paymentStatus'] !=
              'submitted_to_hotel') {
            throw StateError(
              'Customer payment proof is not waiting for verification.',
            );
          }

          transaction.update(
            bookingDoc.reference,
            <String, dynamic>{
              'paymentStatus': 'paid',
              'paidAt':
                  FieldValue.serverTimestamp(),
              'updatedAt':
                  FieldValue.serverTimestamp(),
            },
          );
        },
      );

      _message(
        'Hotel payment verified and marked PAID.',
      );
    } catch (error) {
      _message(
        'Could not verify payment.\n'
        '$error',
      );
    }
  }

  Future<void> _showProof(
    String proofUrl,
  ) async {
    if (proofUrl.trim().isEmpty) {
      _message(
        'Customer payment proof is missing.',
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder:
          (BuildContext dialogContext) {
        return Dialog(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth: 760,
              maxHeight: 760,
            ),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: <Widget>[
                AppBar(
                  automaticallyImplyLeading:
                      false,
                  title: const Text(
                    'Customer Payment Proof',
                  ),
                  actions: <Widget>[
                    IconButton(
                      onPressed: () =>
                          Navigator.pop(
                        dialogContext,
                      ),
                      icon: const Icon(
                        Icons.close_rounded,
                      ),
                    ),
                  ],
                ),
                Flexible(
                  child:
                      InteractiveViewer(
                    child: Image.network(
                      proofUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (
                        BuildContext context,
                        Object error,
                        StackTrace? stackTrace,
                      ) {
                        return const Padding(
                          padding:
                              EdgeInsets.all(
                            30,
                          ),
                          child: Text(
                            'Could not load payment proof image.',
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _message(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
  }

  Widget _field(
    TextEditingController controller, {
    required String label,
    IconData? icon,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon:
            icon == null
                ? null
                : Icon(icon),
        border:
            const OutlineInputBorder(),
      ),
    );
  }

  Widget _settingsTab() {
    if (_loading) {
      return const Center(
        child:
            CircularProgressIndicator(),
      );
    }

    return ListView(
      padding:
          const EdgeInsets.all(16),
      children: <Widget>[
        Card(
          child: SwitchListTile(
            value: _enabled,
            onChanged: (bool value) {
              setState(() {
                _enabled = value;
              });
            },
            secondary: const Icon(
              Icons
                  .account_balance_wallet_rounded,
              color: _rdGreen,
            ),
            title: const Text(
              'Enable Direct Online Payment',
              style: TextStyle(
                fontWeight:
                    FontWeight.w900,
              ),
            ),
            subtitle: const Text(
              'Customer booking payment goes directly to this Hotel account. '
              'RD does not receive the customer booking payment.',
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding:
                const EdgeInsets.all(
              14,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .stretch,
              children: <Widget>[
                const Text(
                  'eSewa',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                _field(
                  _esewaName,
                  label:
                      'eSewa Account Name',
                  icon:
                      Icons.person_rounded,
                ),
                const SizedBox(height: 10),
                _field(
                  _esewaNumber,
                  label:
                      'eSewa Number / ID',
                  icon:
                      Icons.phone_rounded,
                  keyboardType:
                      TextInputType.phone,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding:
                const EdgeInsets.all(
              14,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .stretch,
              children: <Widget>[
                const Text(
                  'Khalti',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                _field(
                  _khaltiName,
                  label:
                      'Khalti Account Name',
                  icon:
                      Icons.person_rounded,
                ),
                const SizedBox(height: 10),
                _field(
                  _khaltiNumber,
                  label:
                      'Khalti Number / ID',
                  icon:
                      Icons.phone_rounded,
                  keyboardType:
                      TextInputType.phone,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding:
                const EdgeInsets.all(
              14,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .stretch,
              children: <Widget>[
                const Text(
                  'Bank Account',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                _field(
                  _bankName,
                  label: 'Bank Name',
                  icon: Icons
                      .account_balance_rounded,
                ),
                const SizedBox(height: 10),
                _field(
                  _bankAccountName,
                  label:
                      'Account Holder Name',
                  icon:
                      Icons.person_rounded,
                ),
                const SizedBox(height: 10),
                _field(
                  _bankAccountNumber,
                  label:
                      'Bank Account Number',
                  icon:
                      Icons.numbers_rounded,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding:
                const EdgeInsets.all(
              14,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .stretch,
              children: <Widget>[
                const Text(
                  'Other Direct Payment',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                _field(
                  _connectIpsId,
                  label:
                      'connectIPS ID / Details',
                  icon: Icons
                      .currency_exchange_rounded,
                ),
                const SizedBox(height: 10),
                _field(
                  _mobileBankingDetails,
                  label:
                      'Mobile Banking Details',
                  icon:
                      Icons.phone_android_rounded,
                  maxLines: 2,
                ),
                const SizedBox(height: 10),
                _field(
                  _instructions,
                  label:
                      'Payment Instructions',
                  icon:
                      Icons.info_outline_rounded,
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding:
                const EdgeInsets.all(
              14,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .stretch,
              children: <Widget>[
                const Text(
                  'Hotel Payment QR',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                if (_paymentQrUrl
                    .trim()
                    .isNotEmpty)
                  ClipRRect(
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                    child: Image.network(
                      _paymentQrUrl,
                      height: 220,
                      fit: BoxFit.contain,
                    ),
                  ),
                if (_paymentQrUrl
                    .trim()
                    .isNotEmpty)
                  const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  onPressed: _uploadingQr
                      ? null
                      : _uploadQr,
                  icon: _uploadingQr
                      ? const SizedBox.square(
                          dimension: 18,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons
                              .qr_code_2_rounded,
                        ),
                  label: Text(
                    _paymentQrUrl
                            .trim()
                            .isEmpty
                        ? 'Upload Hotel Payment QR'
                        : 'Replace Payment QR',
                  ),
                ),
                if (_paymentQrUrl
                    .trim()
                    .isNotEmpty)
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _paymentQrUrl = '';
                      });
                    },
                    icon: const Icon(
                      Icons.delete_outline,
                    ),
                    label: const Text(
                      'Remove QR',
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding:
              const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: Colors.orange
                .withValues(alpha: 0.10),
            borderRadius:
                BorderRadius.circular(12),
          ),
          child: const Text(
            'Security: Only enter receiving details. '
            'Never save eSewa/Khalti PIN, OTP, bank password, API secret, '
            'merchant secret or card PIN in RD Online Shop.',
            style: TextStyle(
              fontWeight:
                  FontWeight.w800,
              height: 1.35,
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed:
                _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(
                    Icons.save_rounded,
                  ),
            label: const Text(
              'Save Direct Payment',
              style: TextStyle(
                fontWeight:
                    FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _paymentsTab() {
    final User? user = _user;

    if (user == null ||
        user.isAnonymous) {
      return const Center(
        child: Text(
          'Hotel Partner login required.',
        ),
      );
    }

    return StreamBuilder<
        QuerySnapshot<
            Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('hotel_bookings')
          .where(
            'partnerId',
            isEqualTo: user.uid,
          )
          .snapshots(),
      builder: (
        BuildContext context,
        AsyncSnapshot<
                QuerySnapshot<
                    Map<String, dynamic>>>
            snapshot,
      ) {
        if (snapshot.connectionState ==
                ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child:
                CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding:
                  const EdgeInsets.all(
                24,
              ),
              child: Text(
                'Could not load direct Hotel payments.\n'
                '${snapshot.error}',
                textAlign:
                    TextAlign.center,
              ),
            ),
          );
        }

        final List<
                QueryDocumentSnapshot<
                    Map<String, dynamic>>>
            docs =
            (snapshot.data?.docs ??
                    <QueryDocumentSnapshot<
                        Map<String,
                            dynamic>>>[])
                .where(
          (
            QueryDocumentSnapshot<
                    Map<String, dynamic>>
                doc,
          ) =>
              doc.data()[
                  'paymentOption'] ==
              'direct_hotel_online',
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
            final Timestamp? a =
                first.data()['createdAt']
                    as Timestamp?;

            final Timestamp? b =
                second.data()['createdAt']
                    as Timestamp?;

            return (b
                        ?.millisecondsSinceEpoch ??
                    0)
                .compareTo(
              a?.millisecondsSinceEpoch ??
                  0,
            );
          },
        );

        if (docs.isEmpty) {
          return const Center(
            child: Padding(
              padding:
                  EdgeInsets.all(24),
              child: Text(
                'No direct Hotel payment submission yet.',
                textAlign:
                    TextAlign.center,
              ),
            ),
          );
        }

        return ListView.builder(
          padding:
              const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (
            BuildContext context,
            int index,
          ) {
            final QueryDocumentSnapshot<
                    Map<String, dynamic>>
                doc = docs[index];

            final Map<String, dynamic>
                data = doc.data();

            final String status =
                data['paymentStatus']
                        ?.toString() ??
                    '';

            final String proofUrl =
                data['paymentProofUrl']
                        ?.toString() ??
                    '';

            final bool waiting =
                status ==
                    'submitted_to_hotel';

            final bool paid =
                status == 'paid';

            return Card(
              margin:
                  const EdgeInsets.only(
                bottom: 12,
              ),
              child: Padding(
                padding:
                    const EdgeInsets.all(
                  14,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .stretch,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            data['guestName']
                                    ?.toString() ??
                                'Customer',
                            style:
                                const TextStyle(
                              fontSize: 18,
                              fontWeight:
                                  FontWeight
                                      .w900,
                            ),
                          ),
                        ),
                        Chip(
                          label: Text(
                            paid
                                ? 'PAID'
                                : waiting
                                    ? 'VERIFY'
                                    : status
                                        .replaceAll(
                                          '_',
                                          ' ',
                                        )
                                        .toUpperCase(),
                            style:
                                TextStyle(
                              color: paid
                                  ? _rdGreen
                                  : waiting
                                      ? Colors
                                          .orange
                                      : _rdRed,
                              fontWeight:
                                  FontWeight
                                      .w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${data['roomName'] ?? 'Room'} • '
                      '${data['roomCount'] ?? 0} room(s)',
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    Text(
                      'Amount: Rs. '
                      '${((data['totalAmount'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}',
                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Method: '
                      '${data['paymentMethod'] ?? ''}',
                    ),
                    SelectableText(
                      'Transaction / Reference: '
                      '${data['paymentReference'] ?? ''}',
                    ),
                    Text(
                      'Booking ID: ${doc.id}',
                      style: TextStyle(
                        color: Colors
                            .grey.shade600,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        if (proofUrl
                            .trim()
                            .isNotEmpty)
                          OutlinedButton.icon(
                            onPressed: () =>
                                _showProof(
                              proofUrl,
                            ),
                            icon: const Icon(
                              Icons
                                  .receipt_long_rounded,
                            ),
                            label:
                                const Text(
                              'View Proof',
                            ),
                          ),
                        if (waiting)
                          FilledButton.icon(
                            onPressed: () =>
                                _verifyPayment(
                              doc,
                            ),
                            icon: const Icon(
                              Icons
                                  .verified_rounded,
                            ),
                            label:
                                const Text(
                              'Verify Money Received',
                            ),
                          ),
                      ],
                    ),
                    if (waiting) ...<
                        Widget>[
                      const SizedBox(
                        height: 8,
                      ),
                      const Text(
                        'Do not verify from screenshot alone. '
                        'Check the real Hotel receiving account first.',
                        style: TextStyle(
                          color:
                              Colors.orange,
                          fontWeight:
                              FontWeight
                                  .w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = _user;

    if (user == null ||
        user.isAnonymous) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Hotel Partner login required.',
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor:
            const Color(0xFFF7F8FA),
        appBar: AppBar(
          title: const Text(
            'Direct Online Payment',
            style: TextStyle(
              fontWeight:
                  FontWeight.w900,
            ),
          ),
          centerTitle: true,
          bottom: const TabBar(
            tabs: <Widget>[
              Tab(
                icon: Icon(
                  Icons
                      .account_balance_wallet_rounded,
                ),
                text: 'Receiving Details',
              ),
              Tab(
                icon: Icon(
                  Icons.verified_rounded,
                ),
                text: 'Verify Payments',
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: <Widget>[
            _settingsTab(),
            _paymentsTab(),
          ],
        ),
      ),
    );
  }
}
