import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'property_location_picker_page.dart';

class PropertySalePostPage extends StatefulWidget {
  final String category;

  const PropertySalePostPage({
    super.key,
    required this.category,
  });

  @override
  State<PropertySalePostPage> createState() =>
      _PropertySalePostPageState();
}

class _PropertySalePostPageState
    extends State<PropertySalePostPage> {
  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _titleController =
      TextEditingController();
  final TextEditingController _priceController =
      TextEditingController();
  final TextEditingController _districtController =
      TextEditingController();
  final TextEditingController _municipalityController =
      TextEditingController();
  final TextEditingController _wardController =
      TextEditingController();
  final TextEditingController _cityController =
      TextEditingController();
  final TextEditingController _addressController =
      TextEditingController();
  final TextEditingController _landmarkController =
      TextEditingController();
  final TextEditingController _areaController =
      TextEditingController();
  final TextEditingController _kittaController =
      TextEditingController();
  final TextEditingController _roadAccessController =
      TextEditingController();
  final TextEditingController _facingController =
      TextEditingController();
  final TextEditingController _bedroomsController =
      TextEditingController();
  final TextEditingController _bathroomsController =
      TextEditingController();
  final TextEditingController _floorsController =
      TextEditingController();
  final TextEditingController _contactNameController =
      TextEditingController();
  final TextEditingController _phoneController =
      TextEditingController();
  final TextEditingController _descriptionController =
      TextEditingController();

  String _postedBy = 'Owner';
  String _negotiable = 'Yes';
  String _furnishing = 'Not specified';
  String _locationVisibility = 'Exact location';

  double? _propertyLat;
  double? _propertyLng;
  List<LatLng> _boundaryPoints = <LatLng>[];

  double? _ownerLat;
  double? _ownerLng;

  final List<XFile> _photos = <XFile>[];
  final List<XFile> _videos = <XFile>[];

  final Map<String, XFile?> _documents =
      <String, XFile?>{
    'Lalpurja / Land Ownership Certificate': null,
    'Cadastral / Kitta Map (Napi Naksa)': null,
    'Land Revenue / Property Tax Receipt': null,
    'Building Permit / Approved Drawing': null,
    'Building Completion Certificate': null,
    'Owner ID / Authorization Document': null,
    'Other Legal Document': null,
  };

  bool get _isLand {
    return widget.category
        .toLowerCase()
        .contains('land');
  }

  bool get _isHouse {
    return widget.category
        .toLowerCase()
        .contains('house');
  }

  @override
  void dispose() {
    for (final TextEditingController controller in
        <TextEditingController>[
      _titleController,
      _priceController,
      _districtController,
      _municipalityController,
      _wardController,
      _cityController,
      _addressController,
      _landmarkController,
      _areaController,
      _kittaController,
      _roadAccessController,
      _facingController,
      _bedroomsController,
      _bathroomsController,
      _floorsController,
      _contactNameController,
      _phoneController,
      _descriptionController,
    ]) {
      controller.dispose();
    }

    super.dispose();
  }

  String? _required(
    String? value,
    String label,
  ) {
    if (value == null ||
        value.trim().isEmpty) {
      return '$label is required';
    }

    return null;
  }

  InputDecoration _decoration(
    String label, {
    String? hint,
    IconData? icon,
    String? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon:
          icon == null ? null : Icon(icon),
      suffixText: suffix,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(14),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding:
          const EdgeInsets.only(
        top: 14,
        bottom: 10,
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Future<void> _pickPropertyLocation() async {
    final PropertyLocationResult? result =
        await Navigator.push<PropertyLocationResult>(
      context,
      MaterialPageRoute<PropertyLocationResult>(
        builder: (_) =>
            PropertyLocationPickerPage(
          enableBoundary: _isLand,
        ),
      ),
    );

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      _propertyLat = result.latitude;
      _propertyLng = result.longitude;
      _boundaryPoints =
          List<LatLng>.from(
        result.boundaryPoints,
      );
    });
  }

  Future<void> _pickOwnerLocation() async {
    final PropertyLocationResult? result =
        await Navigator.push<PropertyLocationResult>(
      context,
      MaterialPageRoute<PropertyLocationResult>(
        builder: (_) =>
            const PropertyLocationPickerPage(),
      ),
    );

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      _ownerLat = result.latitude;
      _ownerLng = result.longitude;
    });
  }

  Future<void> _openMap(
    double? lat,
    double? lng,
  ) async {
    if (lat == null || lng == null) {
      _showMessage(
        'Select location first.',
      );
      return;
    }

    final Uri uri = Uri.parse(
      'https://www.google.com/maps/@?api=1'
      '&map_action=map'
      '&center=$lat,$lng'
      '&zoom=20'
      '&basemap=satellite',
    );

    if (!await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    )) {
      _showMessage(
        'Could not open map.',
      );
    }
  }

  Future<void> _pickPhotos() async {
    final List<XFile> selected =
        await _picker.pickMultiImage(
      imageQuality: 90,
    );

    if (selected.isEmpty || !mounted) {
      return;
    }

    setState(() {
      for (final XFile file in selected) {
        if (!_photos.any(
          (XFile item) =>
              item.path == file.path,
        )) {
          _photos.add(file);
        }
      }
    });
  }

  Future<void> _pickVideo() async {
    final XFile? video =
        await _picker.pickVideo(
      source: ImageSource.gallery,
    );

    if (video == null || !mounted) {
      return;
    }

    setState(() {
      if (!_videos.any(
        (XFile item) =>
            item.path == video.path,
      )) {
        _videos.add(video);
      }
    });
  }

  Future<void> _pickDocument(
    String name,
  ) async {
    final XFile? file =
        await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );

    if (file == null || !mounted) {
      return;
    }

    setState(() {
      _documents[name] = file;
    });
  }

  Widget _locationCard({
    required String title,
    required String subtitle,
    required double? lat,
    required double? lng,
    required VoidCallback onSelect,
  }) {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              lat == null || lng == null
                  ? 'No location selected.'
                  : '${lat.toStringAsFixed(6)}, '
                      '${lng.toStringAsFixed(6)}',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: onSelect,
                  icon: const Icon(
                    Icons.my_location_rounded,
                  ),
                  label: Text(
                    lat == null
                        ? 'Select Location'
                        : 'Change Location',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      _openMap(lat, lng),
                  icon: const Icon(
                    Icons.satellite_alt_rounded,
                  ),
                  label: const Text(
                    'Satellite / Map',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _documentTile(String name) {
    final XFile? file =
        _documents[name];

    return Card(
      child: ListTile(
        leading: Icon(
          file == null
              ? Icons.description_outlined
              : Icons.verified_rounded,
          color: file == null
              ? Colors.grey
              : Colors.green,
        ),
        title: Text(
          name,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          file == null
              ? 'Not selected'
              : file.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: OutlinedButton(
          onPressed: () =>
              _pickDocument(name),
          child: Text(
            file == null
                ? 'Add'
                : 'Replace',
          ),
        ),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  void _continue() {
    final FormState? form =
        _formKey.currentState;

    if (form == null ||
        !form.validate()) {
      return;
    }

    if (_propertyLat == null ||
        _propertyLng == null) {
      _showMessage(
        'Property location is required.',
      );
      return;
    }

    if (_ownerLat == null ||
        _ownerLng == null) {
      _showMessage(
        'Owner / Agent / Office location is required.',
      );
      return;
    }

    if (_photos.isEmpty) {
      _showMessage(
        'Add at least one property photo.',
      );
      return;
    }

    _showMessage(
      'Sale property form is ready locally. Cloud upload, Firestore publish and Admin verification will be connected after the current rules issue is resolved.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool desktop =
        MediaQuery.sizeOf(context).width >=
            900;

    return Scaffold(
      backgroundColor:
          const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: Text(
          _isLand
              ? 'Post Land for Sale'
              : 'Post Property for Sale',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(
            maxWidth: 1000,
          ),
          child: Form(
            key: _formKey,
            child: ListView(
              padding:
                  const EdgeInsets.all(16),
              children: <Widget>[
                _sectionTitle(
                  'Sale Information',
                ),
                TextFormField(
                  controller:
                      _titleController,
                  validator: (String? value) =>
                      _required(
                    value,
                    'Property title',
                  ),
                  decoration: _decoration(
                    _isLand
                        ? 'Land Listing Title'
                        : 'Property Title',
                    icon:
                        Icons.title_rounded,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller:
                      _priceController,
                  keyboardType:
                      TextInputType.number,
                  validator: (String? value) =>
                      _required(
                    value,
                    'Sale price',
                  ),
                  decoration: _decoration(
                    'Sale Price',
                    icon:
                        Icons.payments_rounded,
                    suffix: 'Rs.',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<
                    String>(
                  initialValue: _negotiable,
                  decoration: _decoration(
                    'Negotiable',
                    icon:
                        Icons.handshake_rounded,
                  ),
                  items: const <
                      DropdownMenuItem<
                          String>>[
                    DropdownMenuItem(
                      value: 'Yes',
                      child: Text('Yes'),
                    ),
                    DropdownMenuItem(
                      value: 'No',
                      child: Text('No'),
                    ),
                  ],
                  onChanged: (String? value) {
                    if (value == null) {
                      return;
                    }

                    setState(() {
                      _negotiable = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<
                    String>(
                  initialValue: _postedBy,
                  decoration: _decoration(
                    'Posted By',
                    icon: Icons
                        .account_circle_rounded,
                  ),
                  items: const <
                      DropdownMenuItem<
                          String>>[
                    DropdownMenuItem(
                      value: 'Owner',
                      child: Text('Owner'),
                    ),
                    DropdownMenuItem(
                      value: 'Agent',
                      child: Text(
                        'Real Estate Agent',
                      ),
                    ),
                  ],
                  onChanged: (String? value) {
                    if (value == null) {
                      return;
                    }

                    setState(() {
                      _postedBy = value;
                    });
                  },
                ),

                _sectionTitle('Address'),
                if (desktop)
                  Row(
                    children: <Widget>[
                      Expanded(
                        child:
                            TextFormField(
                          controller:
                              _districtController,
                          validator:
                              (String? value) =>
                                  _required(
                            value,
                            'District',
                          ),
                          decoration:
                              _decoration(
                            'District',
                            icon: Icons
                                .map_rounded,
                          ),
                        ),
                      ),
                      const SizedBox(
                        width: 12,
                      ),
                      Expanded(
                        child:
                            TextFormField(
                          controller:
                              _municipalityController,
                          validator:
                              (String? value) =>
                                  _required(
                            value,
                            'Municipality',
                          ),
                          decoration:
                              _decoration(
                            'Municipality / Rural Municipality',
                            icon: Icons
                                .account_balance_rounded,
                          ),
                        ),
                      ),
                    ],
                  )
                else ...<Widget>[
                  TextFormField(
                    controller:
                        _districtController,
                    validator:
                        (String? value) =>
                            _required(
                      value,
                      'District',
                    ),
                    decoration: _decoration(
                      'District',
                      icon:
                          Icons.map_rounded,
                    ),
                  ),
                  const SizedBox(
                    height: 12,
                  ),
                  TextFormField(
                    controller:
                        _municipalityController,
                    validator:
                        (String? value) =>
                            _required(
                      value,
                      'Municipality',
                    ),
                    decoration: _decoration(
                      'Municipality / Rural Municipality',
                      icon: Icons
                          .account_balance_rounded,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextFormField(
                        controller:
                            _wardController,
                        decoration: _decoration(
                          'Ward No.',
                          icon: Icons
                              .numbers_rounded,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller:
                            _cityController,
                        decoration: _decoration(
                          'City / Area',
                          icon: Icons
                              .location_city_rounded,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller:
                      _addressController,
                  validator: (String? value) =>
                      _required(
                    value,
                    'Address',
                  ),
                  decoration: _decoration(
                    'Full Address',
                    icon:
                        Icons.place_rounded,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller:
                      _landmarkController,
                  decoration: _decoration(
                    'Nearby Landmark',
                    icon:
                        Icons.flag_rounded,
                  ),
                ),

                _sectionTitle(
                  'Property Location',
                ),
                _locationCard(
                  title:
                      'Real Property Location',
                  subtitle:
                      'Exact house/land location. Land can also mark boundary points.',
                  lat: _propertyLat,
                  lng: _propertyLng,
                  onSelect:
                      _pickPropertyLocation,
                ),
                if (_isLand &&
                    _boundaryPoints.isNotEmpty)
                  Padding(
                    padding:
                        const EdgeInsets.only(
                      top: 8,
                    ),
                    child: Text(
                      'Land boundary points: ${_boundaryPoints.length}',
                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                DropdownButtonFormField<
                    String>(
                  initialValue:
                      _locationVisibility,
                  decoration: _decoration(
                    'Public Property Location',
                    icon: Icons
                        .visibility_rounded,
                  ),
                  items: const <
                      DropdownMenuItem<
                          String>>[
                    DropdownMenuItem(
                      value:
                          'Exact location',
                      child: Text(
                        'Exact location',
                      ),
                    ),
                    DropdownMenuItem(
                      value:
                          'Approximate area',
                      child: Text(
                        'Approximate area only',
                      ),
                    ),
                  ],
                  onChanged: (String? value) {
                    if (value == null) {
                      return;
                    }

                    setState(() {
                      _locationVisibility =
                          value;
                    });
                  },
                ),

                _sectionTitle(
                  'Owner / Agent Location',
                ),
                _locationCard(
                  title:
                      'Owner / Agent / Office Location',
                  subtitle:
                      'Where the buyer can meet the owner, land dealer or real-estate office.',
                  lat: _ownerLat,
                  lng: _ownerLng,
                  onSelect:
                      _pickOwnerLocation,
                ),

                _sectionTitle(
                  _isLand
                      ? 'Land Details'
                      : 'Property Details',
                ),
                TextFormField(
                  controller:
                      _areaController,
                  validator: (String? value) =>
                      _required(
                    value,
                    'Area / size',
                  ),
                  decoration: _decoration(
                    'Area / Size',
                    hint:
                        'Example: 4 aana, 1 ropani, 1200 sq.ft.',
                    icon:
                        Icons.square_foot_rounded,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller:
                      _kittaController,
                  decoration: _decoration(
                    'Kitta Number',
                    icon:
                        Icons.pin_outlined,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller:
                      _roadAccessController,
                  decoration: _decoration(
                    'Road Access',
                    hint:
                        'Example: 20 ft blacktop road',
                    icon:
                        Icons.add_road_rounded,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller:
                      _facingController,
                  decoration: _decoration(
                    'Facing / Direction',
                    hint:
                        'East, west, north, south, etc.',
                    icon:
                        Icons.explore_rounded,
                  ),
                ),
                if (_isHouse) ...<Widget>[
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child:
                            TextFormField(
                          controller:
                              _bedroomsController,
                          keyboardType:
                              TextInputType
                                  .number,
                          decoration:
                              _decoration(
                            'Bedrooms',
                            icon:
                                Icons.bed_rounded,
                          ),
                        ),
                      ),
                      const SizedBox(
                        width: 12,
                      ),
                      Expanded(
                        child:
                            TextFormField(
                          controller:
                              _bathroomsController,
                          keyboardType:
                              TextInputType
                                  .number,
                          decoration:
                              _decoration(
                            'Bathrooms',
                            icon: Icons
                                .bathroom_rounded,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller:
                        _floorsController,
                    keyboardType:
                        TextInputType.number,
                    decoration: _decoration(
                      'Floors',
                      icon:
                          Icons.layers_rounded,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<
                      String>(
                    initialValue:
                        _furnishing,
                    decoration: _decoration(
                      'Furnishing',
                      icon:
                          Icons.chair_rounded,
                    ),
                    items: const <
                        DropdownMenuItem<
                            String>>[
                      DropdownMenuItem(
                        value:
                            'Not specified',
                        child: Text(
                          'Not specified',
                        ),
                      ),
                      DropdownMenuItem(
                        value:
                            'Furnished',
                        child: Text(
                          'Furnished',
                        ),
                      ),
                      DropdownMenuItem(
                        value:
                            'Semi-furnished',
                        child: Text(
                          'Semi-furnished',
                        ),
                      ),
                      DropdownMenuItem(
                        value:
                            'Unfurnished',
                        child: Text(
                          'Unfurnished',
                        ),
                      ),
                    ],
                    onChanged:
                        (String? value) {
                      if (value == null) {
                        return;
                      }

                      setState(() {
                        _furnishing =
                            value;
                      });
                    },
                  ),
                ],

                _sectionTitle(
                  'Photos & Videos',
                ),
                Card(
                  child: Column(
                    children: <Widget>[
                      ListTile(
                        leading: const Icon(
                          Icons
                              .photo_library_rounded,
                        ),
                        title: const Text(
                          'Property Photos',
                          style: TextStyle(
                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),
                        subtitle: Text(
                          '${_photos.length} photo(s) selected. No app-side count limit.',
                        ),
                        trailing:
                            OutlinedButton(
                          onPressed:
                              _pickPhotos,
                          child: const Text(
                            'Add Photos',
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(
                          Icons
                              .video_library_rounded,
                        ),
                        title: const Text(
                          'Property Videos',
                          style: TextStyle(
                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),
                        subtitle: Text(
                          '${_videos.length} video(s) selected. Add more anytime.',
                        ),
                        trailing:
                            OutlinedButton(
                          onPressed:
                              _pickVideo,
                          child: const Text(
                            'Add Video',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                _sectionTitle(
                  'Legal / Verification Documents',
                ),
                const Card(
                  color: Color(0xFFFFF8E1),
                  child: Padding(
                    padding:
                        EdgeInsets.all(12),
                    child: Text(
                      'Verification documents are private by default. Exact required documents can vary by property type and local authority.',
                      style: TextStyle(
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                ..._documents.keys
                    .map(_documentTile),

                _sectionTitle(
                  'Contact Information',
                ),
                TextFormField(
                  controller:
                      _contactNameController,
                  validator: (String? value) =>
                      _required(
                    value,
                    'Contact name',
                  ),
                  decoration: _decoration(
                    _postedBy == 'Agent'
                        ? 'Agent Name'
                        : 'Owner Name',
                    icon:
                        Icons.person_rounded,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller:
                      _phoneController,
                  keyboardType:
                      TextInputType.phone,
                  validator: (String? value) =>
                      _required(
                    value,
                    'Phone number',
                  ),
                  decoration: _decoration(
                    'Phone Number',
                    icon:
                        Icons.phone_rounded,
                  ),
                ),

                _sectionTitle('Description'),
                TextFormField(
                  controller:
                      _descriptionController,
                  minLines: 4,
                  maxLines: 8,
                  decoration: _decoration(
                    'Property Description',
                    icon: Icons
                        .description_rounded,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _continue,
                  icon: const Icon(
                    Icons
                        .check_circle_rounded,
                  ),
                  label: const Padding(
                    padding:
                        EdgeInsets.symmetric(
                      vertical: 14,
                    ),
                    child: Text(
                      'Continue',
                      style: TextStyle(
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
