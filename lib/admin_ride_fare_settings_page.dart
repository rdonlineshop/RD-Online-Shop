import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'services/ride_fare_service.dart';

class AdminRideFareSettingsPage extends StatefulWidget {
  const AdminRideFareSettingsPage({super.key});

  @override
  State<AdminRideFareSettingsPage> createState() =>
      _AdminRideFareSettingsPageState();
}

class _AdminRideFareSettingsPageState
    extends State<AdminRideFareSettingsPage> {
  final RideFareService _fareService = RideFareService();

  bool _refreshing = false;
  bool _saving = false;
  String? _error;
  List<RideFareRule> _rules =
      List<RideFareRule>.of(RideFareService.defaultRules);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_refreshing) return;

    if (mounted) {
      setState(() {
        _refreshing = true;
        _error = null;
      });
    }

    // Keep local default fare cards visible while Firestore loads.
    // This prevents a blank Admin page on slow/offline connections.
    try {
      final List<RideFareRule> firstRules =
          await _fareService.loadAllFareRules();

      if (!mounted) return;
      setState(() {
        _rules = firstRules;
      });

      final String? uid = FirebaseAuth.instance.currentUser?.uid;
      await _fareService.ensureDefaults(updatedByUid: uid);

      final List<RideFareRule> latestRules =
          await _fareService.loadAllFareRules();

      if (!mounted) return;
      setState(() {
        _rules = latestRules;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _refreshing = false;
        });
      }
    }
  }

  Future<void> _toggleActive(RideFareRule rule, bool value) async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      await _fareService.saveFareRule(
        rule.copyWith(isActive: value),
        updatedByUid: FirebaseAuth.instance.currentUser?.uid,
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update fare: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editRule(RideFareRule rule) async {
    final RideFareRule? updated = await showDialog<RideFareRule>(
      context: context,
      builder: (BuildContext dialogContext) {
        return _RideFareEditDialog(rule: rule);
      },
    );

    if (updated == null || !mounted) return;

    setState(() => _saving = true);
    try {
      await _fareService.saveFareRule(
        updated,
        updatedByUid: FirebaseAuth.instance.currentUser?.uid,
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${updated.vehicleType} fare saved.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save fare: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Ride Fare Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: <Widget>[
          if (_refreshing)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            )
          else
            IconButton(
              tooltip: 'Refresh',
              onPressed: _saving ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final int columns = width >= 1100
            ? 3
            : width >= 720
                ? 2
                : 1;

        return RefreshIndicator(
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: <Widget>[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'RD Ride Fare Control',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'These rates are read by the customer booking page. '
                            'Existing ride requests keep their original fare snapshot.',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              height: 1.35,
                            ),
                          ),
                          if (_refreshing) ...<Widget>[
                            const SizedBox(height: 10),
                            const Text(
                              'Loading latest fare settings...',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          if (_error != null) ...<Widget>[
                            const SizedBox(height: 10),
                            Text(
                              'Firestore sync unavailable. Showing safe local fare defaults.\n$_error',
                              style: TextStyle(
                                color: Colors.orange.shade800,
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                sliver: columns == 1
                    ? SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (BuildContext context, int index) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _fareCard(_rules[index]),
                            );
                          },
                          childCount: _rules.length,
                        ),
                      )
                    : SliverGrid(
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.15,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (BuildContext context, int index) {
                            return _fareCard(_rules[index]);
                          },
                          childCount: _rules.length,
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _fareCard(RideFareRule rule) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    rule.vehicleType,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Switch.adaptive(
                  value: rule.isActive,
                  onChanged: _saving
                      ? null
                      : (bool value) => _toggleActive(rule, value),
                ),
              ],
            ),
            Text(
              rule.isActive ? 'ACTIVE' : 'INACTIVE',
              style: TextStyle(
                color: rule.isActive ? Colors.green : Colors.red,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            _valueRow('Base Fare', '${rule.currency} ${_money(rule.baseFare)}'),
            _valueRow('Per KM', '${rule.currency} ${_money(rule.perKm)}'),
            _valueRow(
              'Minimum Fare',
              '${rule.currency} ${_money(rule.minimumFare)}',
            ),
            _valueRow(
              '10 km Fare',
              '${rule.currency} ${_money(_previewFare(rule, 10))}',
            ),
            _valueRow(
              'Fallback speed',
              '${_money(rule.fallbackAverageSpeedKmh)} km/h',
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _saving ? null : () => _editRule(rule),
              icon: const Icon(Icons.edit_rounded),
              label: const Text('Edit Fare'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _valueRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  double _previewFare(RideFareRule rule, double distanceKm) {
    final double rawFare = rule.baseFare + (distanceKm * rule.perKm);
    final double minimumApplied =
        rawFare < rule.minimumFare ? rule.minimumFare : rawFare;
    return (minimumApplied / 5).ceil() * 5.0;
  }

  String _money(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }
}

class _RideFareEditDialog extends StatefulWidget {
  const _RideFareEditDialog({required this.rule});

  final RideFareRule rule;

  @override
  State<_RideFareEditDialog> createState() => _RideFareEditDialogState();
}

class _RideFareEditDialogState extends State<_RideFareEditDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _baseController;
  late final TextEditingController _perKmController;
  late final TextEditingController _minimumController;
  late final TextEditingController _speedController;
  late final TextEditingController _currencyController;
  late final TextEditingController _previewDistanceController;

  @override
  void initState() {
    super.initState();
    _baseController = TextEditingController(
      text: widget.rule.baseFare.toStringAsFixed(0),
    );
    _perKmController = TextEditingController(
      text: widget.rule.perKm.toStringAsFixed(0),
    );
    _minimumController = TextEditingController(
      text: widget.rule.minimumFare.toStringAsFixed(0),
    );
    _speedController = TextEditingController(
      text: widget.rule.fallbackAverageSpeedKmh.toStringAsFixed(0),
    );
    _currencyController = TextEditingController(
      text: widget.rule.currency,
    );
    _previewDistanceController = TextEditingController(text: '10');

    _baseController.addListener(_refreshPreview);
    _perKmController.addListener(_refreshPreview);
    _minimumController.addListener(_refreshPreview);
    _currencyController.addListener(_refreshPreview);
    _previewDistanceController.addListener(_refreshPreview);
  }

  void _refreshPreview() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _baseController.dispose();
    _perKmController.dispose();
    _minimumController.dispose();
    _speedController.dispose();
    _currencyController.dispose();
    _previewDistanceController.dispose();
    super.dispose();
  }

  String? _validatePositiveNumber(String? value) {
    final double? number = double.tryParse(value?.trim() ?? '');
    if (number == null || number <= 0) {
      return 'Enter a value greater than zero';
    }
    return null;
  }

  double? _numberFrom(TextEditingController controller) {
    return double.tryParse(controller.text.trim());
  }

  double? get _previewDistanceKm => _numberFrom(_previewDistanceController);

  double? get _previewTotalFare {
    final double? base = _numberFrom(_baseController);
    final double? perKm = _numberFrom(_perKmController);
    final double? minimum = _numberFrom(_minimumController);
    final double? distance = _previewDistanceKm;

    if (base == null ||
        perKm == null ||
        minimum == null ||
        distance == null ||
        base <= 0 ||
        perKm <= 0 ||
        minimum <= 0 ||
        distance <= 0) {
      return null;
    }

    final double rawFare = base + (distance * perKm);
    final double minimumApplied = rawFare < minimum ? minimum : rawFare;
    return (minimumApplied / 5).ceil() * 5.0;
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  void _save() {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    final String currency = _currencyController.text.trim();
    if (currency.isEmpty) {
      return;
    }

    final RideFareRule updated = widget.rule.copyWith(
      baseFare: double.parse(_baseController.text.trim()),
      perKm: double.parse(_perKmController.text.trim()),
      minimumFare: double.parse(_minimumController.text.trim()),
      fallbackAverageSpeedKmh: double.parse(_speedController.text.trim()),
      currency: currency,
      isFallback: false,
    );

    Navigator.of(context).pop(updated);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.rule.vehicleType} Fare'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _numberField(_baseController, 'Base Fare'),
                const SizedBox(height: 12),
                _numberField(_perKmController, 'Per KM Rate'),
                const SizedBox(height: 12),
                _numberField(_minimumController, 'Minimum Fare'),
                const SizedBox(height: 12),
                _numberField(
                  _speedController,
                  'Fallback Average Speed (km/h)',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _currencyController,
                  decoration: const InputDecoration(
                    labelText: 'Currency label',
                    hintText: 'Rs.',
                    border: OutlineInputBorder(),
                  ),
                  validator: (String? value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter a currency label';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _numberField(
                  _previewDistanceController,
                  'Preview Distance (km)',
                ),
                const SizedBox(height: 12),
                _farePreviewCard(),
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _farePreviewCard() {
    final double? distance = _previewDistanceKm;
    final double? base = _numberFrom(_baseController);
    final double? perKm = _numberFrom(_perKmController);
    final double? total = _previewTotalFare;
    final String currency = _currencyController.text.trim().isEmpty
        ? 'Rs.'
        : _currencyController.text.trim();

    final String formula = base == null || perKm == null || distance == null
        ? 'Enter valid fare values to see the total.'
        : '$currency ${_formatNumber(base)} + '
            '(${_formatNumber(distance)} km × '
            '$currency ${_formatNumber(perKm)})';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(
              alpha: 0.45,
            ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Auto Total Fare Preview',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            formula,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            total == null
                ? 'Total Amount: --'
                : 'Total Amount: $currency ${_formatNumber(total)}',
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (total != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              'Minimum fare is applied automatically when needed. '
              'Final fare is rounded up to the next 5.',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 11.5,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _numberField(
    TextEditingController controller,
    String label,
  ) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: _validatePositiveNumber,
    );
  }
}

