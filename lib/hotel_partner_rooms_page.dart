import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'hotel_cloudinary_service.dart';

class HotelPartnerRoomsPage extends StatefulWidget {
  const HotelPartnerRoomsPage({super.key});

  @override
  State<HotelPartnerRoomsPage> createState() =>
      _HotelPartnerRoomsPageState();
}

class _HotelPartnerRoomsPageState
    extends State<HotelPartnerRoomsPage> {
  static const Color _rdGreen =
      Color(0xFF2E7D32);
  static const Color _rdBlue =
      Color(0xFF1565C0);

  User? get _user =>
      FirebaseAuth.instance.currentUser;

  Future<Map<String, dynamic>>
      _loadHotel() async {
    final User? user = _user;

    if (user == null || user.isAnonymous) {
      return <String, dynamic>{};
    }

    final DocumentSnapshot<Map<String, dynamic>>
        doc = await FirebaseFirestore.instance
            .collection('hotels')
            .doc(user.uid)
            .get();

    return <String, dynamic>{
      '_exists': doc.exists,
      ...?doc.data(),
    };
  }

  Future<void> _openEditor({
    QueryDocumentSnapshot<
            Map<String, dynamic>>?
        roomDoc,
  }) async {
    final User? user = _user;

    if (user == null || user.isAnonymous) {
      _message(
        'Hotel Partner login is required.',
      );
      return;
    }

    final Map<String, dynamic> hotel =
        await _loadHotel();

    if (!mounted) {
      return;
    }

    if (hotel['_exists'] != true) {
      _message(
        'Please create Hotel Profile first.',
      );
      return;
    }

    if (hotel['isApproved'] != true ||
        hotel['isActive'] != true) {
      _message(
        'Hotel must be approved and active '
        'before room types can be added.',
      );
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder:
          (BuildContext dialogContext) =>
              _RoomEditorDialog(
        partnerId: user.uid,
        hotelId: user.uid,
        existing: roomDoc,
      ),
    );
  }

  void _message(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  String _money(dynamic value) {
    final double amount =
        (value as num?)?.toDouble() ?? 0;

    return 'Rs. '
        '${amount.toStringAsFixed(0)}';
  }

  Widget _roomImage(String url) {
    if (url.trim().isEmpty) {
      return Container(
        color:
            _rdBlue.withValues(alpha: 0.08),
        alignment: Alignment.center,
        child: const Icon(
          Icons.bed_rounded,
          color: _rdBlue,
          size: 52,
        ),
      );
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) =>
          Container(
        color:
            _rdBlue.withValues(alpha: 0.08),
        alignment: Alignment.center,
        child: const Icon(
          Icons.bed_rounded,
          color: _rdBlue,
          size: 52,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = _user;

    if (user == null || user.isAnonymous) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Hotel Partner login required.',
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor:
          const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'Rooms',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
      ),
      floatingActionButton:
          FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(
          Icons.add_rounded,
        ),
        label: const Text(
          'Add Room Type',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<
            QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('hotel_rooms')
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
                      const EdgeInsets.all(24),
                  child: Text(
                    'Could not load rooms.\n'
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
                                Map<String,
                                    dynamic>>
                            doc,
                      ) =>
                          doc.data()[
                              'hotelId'] ==
                          user.uid,
                    )
                    .toList();

            docs.sort(
              (
                QueryDocumentSnapshot<
                        Map<String, dynamic>>
                    first,
                QueryDocumentSnapshot<
                        Map<String, dynamic>>
                    second,
              ) =>
                  (first.data()['name']
                              ?.toString() ??
                          '')
                      .compareTo(
                    second.data()['name']
                            ?.toString() ??
                        '',
                  ),
            );

            return Center(
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(
                  maxWidth: 950,
                ),
                child: ListView(
                  padding:
                      const EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    100,
                  ),
                  children: <Widget>[
                    Container(
                      padding:
                          const EdgeInsets.all(
                        14,
                      ),
                      decoration:
                          BoxDecoration(
                        color: _rdGreen
                            .withValues(
                          alpha: 0.08,
                        ),
                        borderRadius:
                            BorderRadius
                                .circular(14),
                      ),
                      child: const Text(
                        'Add each room type separately. '
                        'Every room type can have its own photos, '
                        'price, AC/Non-AC setting, bed, guest capacity, '
                        'facilities and total room count.',
                        style: TextStyle(
                          fontWeight:
                              FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 14,
                    ),
                    Text(
                      'Room Types '
                      '(${docs.length})',
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    if (docs.isEmpty)
                      const Card(
                        child: Padding(
                          padding:
                              EdgeInsets.all(
                            24,
                          ),
                          child: Text(
                            'No room type added yet.',
                            textAlign:
                                TextAlign.center,
                          ),
                        ),
                      )
                    else
                      ...docs.map(_roomCard),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _roomCard(
    QueryDocumentSnapshot<
            Map<String, dynamic>>
        doc,
  ) {
    final Map<String, dynamic> data =
        doc.data();

    final bool active =
        data['isActive'] == true;

    final List<dynamic> photos =
        data['photoUrls'] is List
            ? data['photoUrls']
                as List<dynamic>
            : <dynamic>[];

    final String mainPhoto =
        data['photoUrl']
                ?.toString()
                .trim() ??
            (photos.isNotEmpty
                ? photos.first
                    .toString()
                    .trim()
                : '');

    final Widget details = Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                data['name']?.toString() ??
                    'Room',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
            ),
            Chip(
              avatar: Icon(
                active
                    ? Icons
                        .check_circle_rounded
                    : Icons
                        .pause_circle_rounded,
                size: 17,
                color: active
                    ? _rdGreen
                    : Colors.grey,
              ),
              label: Text(
                active
                    ? 'ACTIVE'
                    : 'INACTIVE',
                style: const TextStyle(
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        Text(
          '${data['roomClass'] ?? ''} • '
          '${data['isAc'] == true ? 'AC' : 'Non-AC'} • '
          '${data['bed'] ?? ''}',
        ),
        const SizedBox(height: 5),
        Text(
          '${_money(data['pricePerNight'])} / night',
          style: const TextStyle(
            color: _rdBlue,
            fontSize: 16,
            fontWeight:
                FontWeight.w900,
          ),
        ),
        Text(
          'Total rooms: '
          '${data['totalRooms'] ?? 0} • '
          'Max guests: '
          '${data['maxGuests'] ?? 0}',
          style: const TextStyle(
            fontWeight:
                FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            OutlinedButton.icon(
              onPressed: () =>
                  _openEditor(
                roomDoc: doc,
              ),
              icon: const Icon(
                Icons.edit_rounded,
              ),
              label: const Text('Edit'),
            ),
            FilledButton.tonalIcon(
              onPressed: () async {
                try {
                  await doc.reference.update(
                    <String, dynamic>{
                      'isActive': !active,
                      'updatedAt': FieldValue
                          .serverTimestamp(),
                    },
                  );
                } catch (error) {
                  _message(
                    'Could not update room.\n'
                    '$error',
                  );
                }
              },
              icon: Icon(
                active
                    ? Icons
                        .pause_circle_rounded
                    : Icons
                        .play_circle_rounded,
              ),
              label: Text(
                active
                    ? 'Deactivate'
                    : 'Activate',
              ),
            ),
          ],
        ),
      ],
    );

    return Card(
      margin:
          const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding:
            const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (
            BuildContext context,
            BoxConstraints constraints,
          ) {
            final Widget photo =
                ClipRRect(
              borderRadius:
                  BorderRadius.circular(12),
              child: SizedBox(
                width:
                    constraints.maxWidth <
                            560
                        ? double.infinity
                        : 190,
                height: 160,
                child:
                    _roomImage(mainPhoto),
              ),
            );

            if (constraints.maxWidth <
                560) {
              return Column(
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                children: <Widget>[
                  photo,
                  const SizedBox(
                    height: 10,
                  ),
                  details,
                ],
              );
            }

            return Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: <Widget>[
                photo,
                const SizedBox(width: 12),
                Expanded(child: details),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RoomEditorDialog
    extends StatefulWidget {
  const _RoomEditorDialog({
    required this.partnerId,
    required this.hotelId,
    this.existing,
  });

  final String partnerId;
  final String hotelId;
  final QueryDocumentSnapshot<
      Map<String, dynamic>>? existing;

  @override
  State<_RoomEditorDialog> createState() =>
      _RoomEditorDialogState();
}

class _RoomEditorDialogState
    extends State<_RoomEditorDialog> {
  static const Color _rdBlue =
      Color(0xFF1565C0);

  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController
      _description;
  late final TextEditingController
      _roomClass;
  late final TextEditingController _bed;
  late final TextEditingController
      _maxGuests;
  late final TextEditingController _price;
  late final TextEditingController
      _totalRooms;
  late final TextEditingController
      _facilities;

  final List<String> _photoUrls =
      <String>[];

  bool _isAc = false;
  bool _breakfastIncluded = false;
  bool _freeCancellation = false;
  bool _active = true;
  bool _uploading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();

    final Map<String, dynamic> data =
        widget.existing?.data() ??
            <String, dynamic>{};

    _name = TextEditingController(
      text:
          data['name']?.toString() ?? '',
    );

    _description =
        TextEditingController(
      text: data['description']
              ?.toString() ??
          '',
    );

    _roomClass = TextEditingController(
      text: data['roomClass']
              ?.toString() ??
          '',
    );

    _bed = TextEditingController(
      text:
          data['bed']?.toString() ?? '',
    );

    _maxGuests =
        TextEditingController(
      text: (data['maxGuests'] ?? 2)
          .toString(),
    );

    _price = TextEditingController(
      text: data['pricePerNight']
              ?.toString() ??
          '',
    );

    _totalRooms =
        TextEditingController(
      text: (data['totalRooms'] ?? 1)
          .toString(),
    );

    final List<dynamic> facilities =
        data['facilities'] is List
            ? data['facilities']
                as List<dynamic>
            : <dynamic>[];

    _facilities =
        TextEditingController(
      text: facilities
          .map(
            (dynamic value) =>
                value.toString(),
          )
          .join(', '),
    );

    final List<dynamic> photos =
        data['photoUrls'] is List
            ? data['photoUrls']
                as List<dynamic>
            : <dynamic>[];

    _photoUrls.addAll(
      photos
          .map(
            (dynamic value) =>
                value.toString().trim(),
          )
          .where(
            (String value) =>
                value.isNotEmpty,
          ),
    );

    final String singlePhoto =
        data['photoUrl']
                ?.toString()
                .trim() ??
            '';

    if (singlePhoto.isNotEmpty &&
        !_photoUrls
            .contains(singlePhoto)) {
      _photoUrls.insert(
        0,
        singlePhoto,
      );
    }

    _isAc =
        data['isAc'] == true;
    _breakfastIncluded =
        data['breakfastIncluded'] ==
            true;
    _freeCancellation =
        data['freeCancellation'] ==
            true;

    _active = widget.existing == null
        ? true
        : data['isActive'] == true;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _roomClass.dispose();
    _bed.dispose();
    _maxGuests.dispose();
    _price.dispose();
    _totalRooms.dispose();
    _facilities.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    if (_uploading) {
      return;
    }

    if (_photoUrls.length >= 5) {
      _message(
        'Maximum 5 photos per room type.',
      );
      return;
    }

    setState(() {
      _uploading = true;
    });

    try {
      final String? url =
          await HotelCloudinaryService
              .pickAndUploadImage();

      if (!mounted || url == null) {
        return;
      }

      setState(() {
        if (!_photoUrls.contains(url)) {
          _photoUrls.add(url);
        }
      });
    } catch (error) {
      _message(
        'Photo upload failed.\n$error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }

    if (!(_formKey.currentState
            ?.validate() ??
        false)) {
      return;
    }

    final double? price =
        double.tryParse(
      _price.text.trim(),
    );

    final int? total =
        int.tryParse(
      _totalRooms.text.trim(),
    );

    final int? guests =
        int.tryParse(
      _maxGuests.text.trim(),
    );

    if (price == null ||
        price < 0) {
      _message(
        'Enter a valid room price.',
      );
      return;
    }

    if (total == null ||
        total < 1) {
      _message(
        'Total rooms must be at least 1.',
      );
      return;
    }

    if (guests == null ||
        guests < 1) {
      _message(
        'Max guests must be at least 1.',
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final CollectionReference<
              Map<String, dynamic>>
          collection =
          FirebaseFirestore.instance
              .collection('hotel_rooms');

      final DocumentReference<
              Map<String, dynamic>>
          reference =
          widget.existing?.reference ??
              collection.doc();

      final List<String> facilities =
          _facilities.text
              .split(',')
              .map(
                (String value) =>
                    value.trim(),
              )
              .where(
                (String value) =>
                    value.isNotEmpty,
              )
              .toSet()
              .toList();

      final Map<String, dynamic> editable =
          <String, dynamic>{
        'name': _name.text.trim(),
        'description':
            _description.text.trim(),
        'roomClass':
            _roomClass.text.trim(),
        'isAc': _isAc,
        'bed': _bed.text.trim(),
        'maxGuests': guests,
        'pricePerNight': price,
        'totalRooms': total,
        'photoUrl':
            _photoUrls.isEmpty
                ? ''
                : _photoUrls.first,
        'photoUrls':
            List<String>.from(
          _photoUrls,
        ),
        'facilities': facilities,
        'breakfastIncluded':
            _breakfastIncluded,
        'freeCancellation':
            _freeCancellation,
        'isActive':
            widget.existing == null
                ? true
                : _active,
        'updatedAt':
            FieldValue.serverTimestamp(),
      };

      if (widget.existing == null) {
        await reference.set(
          <String, dynamic>{
            'roomId': reference.id,
            'hotelId': widget.hotelId,
            'partnerId':
                widget.partnerId,
            ...editable,
            'createdAt':
                FieldValue
                    .serverTimestamp(),
          },
        );
      } else {
        await reference.update(editable);
      }

      if (!mounted) {
        return;
      }

      Navigator.pop(context);
    } catch (error) {
      _message(
        'Could not save room.\n$error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _message(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  String? _required(
    String? value,
    String label,
  ) {
    if ((value ?? '').trim().isEmpty) {
      return '$label is required';
    }

    return null;
  }

  Widget _field({
    required TextEditingController
        controller,
    required String label,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border:
            const OutlineInputBorder(),
      ),
    );
  }

  Widget _photos() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Expanded(
              child: Text(
                'Room Photos',
                style: TextStyle(
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
            ),
            Text(
              '${_photoUrls.length}/5',
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_photoUrls.isNotEmpty)
          SizedBox(
            height: 125,
            child: ListView.separated(
              scrollDirection:
                  Axis.horizontal,
              itemCount:
                  _photoUrls.length,
              separatorBuilder:
                  (_, __) =>
                      const SizedBox(
                width: 8,
              ),
              itemBuilder:
                  (
                BuildContext context,
                int index,
              ) {
                return Stack(
                  children: <Widget>[
                    ClipRRect(
                      borderRadius:
                          BorderRadius
                              .circular(10),
                      child: Image.network(
                        _photoUrls[index],
                        width: 155,
                        height: 125,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (_, __, ___) =>
                                Container(
                          width: 155,
                          height: 125,
                          color: _rdBlue
                              .withValues(
                            alpha: 0.08,
                          ),
                          child: const Icon(
                            Icons
                                .bed_rounded,
                            size: 45,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 3,
                      right: 3,
                      child:
                          IconButton.filledTonal(
                        tooltip:
                            'Remove Photo',
                        onPressed: () {
                          setState(() {
                            _photoUrls
                                .removeAt(
                              index,
                            );
                          });
                        },
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          )
        else
          const Text(
            'No room photo added yet.',
          ),
        const SizedBox(height: 8),
        FilledButton.tonalIcon(
          onPressed:
              _uploading
                  ? null
                  : _addPhoto,
          icon: _uploading
              ? const SizedBox.square(
                  dimension: 18,
                  child:
                      CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : const Icon(
                  Icons
                      .add_photo_alternate_rounded,
                ),
          label: const Text(
            'Add Room Photo',
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existing == null
            ? 'Add Room Type'
            : 'Edit Room Type',
        style: const TextStyle(
          fontWeight: FontWeight.w900,
        ),
      ),
      content: SizedBox(
        width: 620,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                _photos(),
                const SizedBox(height: 12),
                _field(
                  controller: _name,
                  label: 'Room Name',
                  hint:
                      'Standard Room / Deluxe AC Room',
                  validator:
                      (String? value) =>
                          _required(
                    value,
                    'Room Name',
                  ),
                ),
                const SizedBox(height: 9),
                _field(
                  controller: _roomClass,
                  label: 'Room Class',
                  hint:
                      'Economy / Standard / Deluxe / Suite',
                  validator:
                      (String? value) =>
                          _required(
                    value,
                    'Room Class',
                  ),
                ),
                const SizedBox(height: 9),
                _field(
                  controller: _description,
                  label: 'Description',
                  maxLines: 3,
                ),
                const SizedBox(height: 9),
                _field(
                  controller: _bed,
                  label: 'Bed',
                  hint:
                      '1 Queen Bed / 2 Single Beds',
                  validator:
                      (String? value) =>
                          _required(
                    value,
                    'Bed',
                  ),
                ),
                const SizedBox(height: 9),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _field(
                        controller:
                            _maxGuests,
                        label: 'Max Guests',
                        keyboardType:
                            TextInputType
                                .number,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: _field(
                        controller:
                            _totalRooms,
                        label: 'Total Rooms',
                        keyboardType:
                            TextInputType
                                .number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                _field(
                  controller: _price,
                  label:
                      'Price Per Night (Rs.)',
                  keyboardType:
                      const TextInputType
                          .numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 9),
                _field(
                  controller: _facilities,
                  label:
                      'Room Facilities (comma separated)',
                  hint:
                      'Wi-Fi, TV, Hot Water, Balcony',
                  maxLines: 2,
                ),
                SwitchListTile(
                  contentPadding:
                      EdgeInsets.zero,
                  value: _isAc,
                  title:
                      const Text('AC Room'),
                  onChanged: (bool value) {
                    setState(() {
                      _isAc = value;
                    });
                  },
                ),
                SwitchListTile(
                  contentPadding:
                      EdgeInsets.zero,
                  value:
                      _breakfastIncluded,
                  title: const Text(
                    'Breakfast Included',
                  ),
                  onChanged: (bool value) {
                    setState(() {
                      _breakfastIncluded =
                          value;
                    });
                  },
                ),
                SwitchListTile(
                  contentPadding:
                      EdgeInsets.zero,
                  value:
                      _freeCancellation,
                  title: const Text(
                    'Free Cancellation',
                  ),
                  onChanged: (bool value) {
                    setState(() {
                      _freeCancellation =
                          value;
                    });
                  },
                ),
                if (widget.existing !=
                    null)
                  SwitchListTile(
                    contentPadding:
                        EdgeInsets.zero,
                    value: _active,
                    title: const Text(
                      'Room Active',
                    ),
                    onChanged:
                        (bool value) {
                      setState(() {
                        _active = value;
                      });
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _saving
              ? null
              : () =>
                  Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
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
            'Save Room',
          ),
        ),
      ],
    );
  }
}
