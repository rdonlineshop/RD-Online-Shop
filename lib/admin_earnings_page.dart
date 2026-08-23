import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

class AdminEarningsPage extends StatefulWidget {
  const AdminEarningsPage({super.key});

  @override
  State<AdminEarningsPage> createState() => _AdminEarningsPageState();
}

class _AdminEarningsPageState extends State<AdminEarningsPage> {
  String _filter = 'Day';
  DateTime? _customStart;
  DateTime? _customEnd;

  double _money(dynamic value) {
    if (value is num) return value.toDouble();
    if (value == null) return 0;
    final String cleaned = value
        .toString()
        .replaceAll('Rs.', '')
        .replaceAll(',', '')
        .trim();
    return double.tryParse(cleaned) ?? 0;
  }

  String _formatMoney(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2);
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  DateTime _dayStart(DateTime value) => DateTime(value.year, value.month, value.day);

  DateTime _dayEnd(DateTime value) =>
      DateTime(value.year, value.month, value.day, 23, 59, 59, 999);

  bool _matchesFilter(_SettlementRow row) {
    if (_filter == 'All') return true;
    final DateTime? date = row.date;
    if (date == null) return false;
    final DateTime now = DateTime.now();

    if (_filter == 'Day') {
      return date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    }
    if (_filter == 'Month') {
      return date.year == now.year && date.month == now.month;
    }
    if (_filter == 'Year') return date.year == now.year;
    if (_filter == 'Custom' && _customStart != null && _customEnd != null) {
      return !date.isBefore(_dayStart(_customStart!)) &&
          !date.isAfter(_dayEnd(_customEnd!));
    }
    return true;
  }

  String _two(int value) => value.toString().padLeft(2, '0');

  String _dateText(DateTime date) =>
      '${_two(date.day)}/${_two(date.month)}/${date.year}';

  String _dateTimeText(DateTime? date) {
    if (date == null) return '';
    return '${_dateText(date)} ${_two(date.hour)}:${_two(date.minute)}';
  }

  String _filterTitle() {
    final DateTime now = DateTime.now();
    switch (_filter) {
      case 'Day':
        return 'Today - ${_dateText(now)}';
      case 'Month':
        return '${_two(now.month)}/${now.year}';
      case 'Year':
        return '${now.year}';
      case 'Custom':
        if (_customStart != null && _customEnd != null) {
          return '${_dateText(_customStart!)} - ${_dateText(_customEnd!)}';
        }
        return 'Custom Date Range';
      default:
        return 'All Records';
    }
  }

  Future<void> _pickCustomRange() async {
    final DateTime now = DateTime.now();
    final DateTimeRange? range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 5, 12, 31),
      initialDateRange: _customStart != null && _customEnd != null
          ? DateTimeRange(start: _customStart!, end: _customEnd!)
          : DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now),
    );
    if (range == null || !mounted) return;
    setState(() {
      _customStart = range.start;
      _customEnd = range.end;
      _filter = 'Custom';
    });
  }

  Future<void> _showExportOptions(List<_SettlementRow> rows) async {
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No records to export for this filter.')),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Wrap(
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Export PDF Report'),
              onTap: () {
                Navigator.pop(sheetContext);
                _exportPdf(rows);
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart_outlined),
              title: const Text('Export Excel Report'),
              onTap: () {
                Navigator.pop(sheetContext);
                _exportExcel(rows);
              },
            ),
          ],
        ),
      ),
    );
  }

  _Totals _totals(List<_SettlementRow> rows) {
    double gross = 0;
    double commission = 0;
    double payable = 0;
    double paid = 0;
    double ready = 0;
    for (final _SettlementRow row in rows) {
      gross += row.gross;
      commission += row.commission;
      payable += row.payable;
      if (row.status == 'Paid') paid += row.settlementAmount;
      if (row.status == 'Ready to Pay') ready += row.settlementAmount;
    }
    return _Totals(gross, commission, payable, paid, ready);
  }

  Future<void> _exportPdf(List<_SettlementRow> rows) async {
    try {
      final _Totals totals = _totals(rows);
      final pw.Document pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          build: (pw.Context context) => <pw.Widget>[
            pw.Text('RD Online Shop - Earnings & Commission Report',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Text('Filter: ${_filterTitle()}'),
            pw.SizedBox(height: 14),
            pw.TableHelper.fromTextArray(
              headers: const <String>['Summary', 'Amount'],
              data: <List<String>>[
                <String>['Settlement Gross', 'Rs. ${_formatMoney(totals.gross)}'],
                <String>['RD Commission', 'Rs. ${_formatMoney(totals.commission)}'],
                <String>['Seller Payable', 'Rs. ${_formatMoney(totals.payable)}'],
                <String>['Seller Paid', 'Rs. ${_formatMoney(totals.paid)}'],
                <String>['Ready to Pay', 'Rs. ${_formatMoney(totals.ready)}'],
              ],
            ),
            pw.SizedBox(height: 18),
            pw.Text('Commission & Settlement History',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
              cellStyle: const pw.TextStyle(fontSize: 6.5),
              headers: const <String>[
                'Order ID', 'Seller', 'Status', 'Gross', 'Commission',
                'Payable', 'Settlement', 'Paid Via', 'Reference', 'Date'
              ],
              data: rows.map((row) => <String>[
                row.orderId,
                row.sellerName,
                row.status,
                _formatMoney(row.gross),
                '${_formatMoney(row.commission)} (${_formatMoney(row.commissionPercent)}%)',
                _formatMoney(row.payable),
                _formatMoney(row.settlementAmount),
                row.paymentMethod,
                row.referenceId,
                _dateTimeText(row.date),
              ]).toList(),
            ),
          ],
        ),
      );
      final Uint8List bytes = await pdf.save();
      final Directory directory = await getTemporaryDirectory();
      final String fileName = 'RD_Earnings_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final File file = File('${directory.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(
        ShareParams(files: <XFile>[XFile(file.path)], text: 'RD Earnings & Commission Report'),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF export failed: $e')),
      );
    }
  }

  Future<void> _exportExcel(List<_SettlementRow> rows) async {
    try {
      final _Totals totals = _totals(rows);
      final Excel excel = Excel.createExcel();
      final Sheet sheet = excel['RD Earnings'];
      sheet.appendRow(<CellValue?>[TextCellValue('RD Online Shop - Earnings & Commission Report')]);
      sheet.appendRow(<CellValue?>[TextCellValue('Filter'), TextCellValue(_filterTitle())]);
      sheet.appendRow(<CellValue?>[]);
      sheet.appendRow(<CellValue?>[TextCellValue('Settlement Gross'), DoubleCellValue(totals.gross)]);
      sheet.appendRow(<CellValue?>[TextCellValue('RD Commission'), DoubleCellValue(totals.commission)]);
      sheet.appendRow(<CellValue?>[TextCellValue('Seller Payable'), DoubleCellValue(totals.payable)]);
      sheet.appendRow(<CellValue?>[TextCellValue('Seller Paid'), DoubleCellValue(totals.paid)]);
      sheet.appendRow(<CellValue?>[TextCellValue('Ready to Pay'), DoubleCellValue(totals.ready)]);
      sheet.appendRow(<CellValue?>[]);
      sheet.appendRow(<CellValue?>[
        TextCellValue('Order ID'), TextCellValue('Seller'), TextCellValue('Status'),
        TextCellValue('Gross Sale'), TextCellValue('Commission %'), TextCellValue('RD Commission'),
        TextCellValue('Seller Payable'), TextCellValue('Settlement Amount'),
        TextCellValue('RD Paid Via'), TextCellValue('Reference ID'), TextCellValue('Date'),
      ]);
      for (final _SettlementRow row in rows) {
        sheet.appendRow(<CellValue?>[
          TextCellValue(row.orderId), TextCellValue(row.sellerName), TextCellValue(row.status),
          DoubleCellValue(row.gross), DoubleCellValue(row.commissionPercent),
          DoubleCellValue(row.commission), DoubleCellValue(row.payable),
          DoubleCellValue(row.settlementAmount), TextCellValue(row.paymentMethod),
          TextCellValue(row.referenceId), TextCellValue(_dateTimeText(row.date)),
        ]);
      }
      if (excel.sheets.containsKey('Sheet1') && excel.sheets.length > 1) {
        excel.delete('Sheet1');
      }
      final List<int>? bytes = excel.encode();
      if (bytes == null) throw Exception('Could not create Excel file.');
      final Directory directory = await getTemporaryDirectory();
      final String fileName = 'RD_Earnings_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final File file = File('${directory.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(
        ShareParams(files: <XFile>[XFile(file.path)], text: 'RD Earnings & Commission Excel Report'),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Excel export failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RD Earnings & Commission', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('orders').snapshots(),
        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Could not load earnings.\n${snapshot.error}', textAlign: TextAlign.center),
            ));
          }

          final List<_SettlementRow> allRows = <_SettlementRow>[];
          for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
              in snapshot.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[]) {
            final Map<String, dynamic> order = doc.data();
            final dynamic rawSettlements = order['sellerSettlements'];
            if (rawSettlements is! Map) continue;
            rawSettlements.forEach((dynamic key, dynamic rawValue) {
              if (rawValue is! Map) return;
              final Map<String, dynamic> settlement = Map<String, dynamic>.from(rawValue);
              final double gross = settlement['grossAmount'] != null
                  ? _money(settlement['grossAmount']) : _money(settlement['amount']);
              final double commissionPercent = _money(settlement['commissionPercent']);
              final double commission = settlement['commissionAmount'] != null
                  ? _money(settlement['commissionAmount']) : gross * commissionPercent / 100;
              final double payable = settlement['sellerPayable'] != null
                  ? _money(settlement['sellerPayable']) : gross - commission;
              final double settlementAmount = _money(settlement['amount']);
              final String status = settlement['status']?.toString().trim().isNotEmpty == true
                  ? settlement['status'].toString().trim() : 'Pending';
              final String sellerName = settlement['sellerName']?.toString().trim().isNotEmpty == true
                  ? settlement['sellerName'].toString().trim() : key.toString();
              final dynamic rawDate = settlement['updatedAt'] ??
                  settlement['settlementDate'] ?? settlement['createdAt'] ?? order['orderDateTime'];
              allRows.add(_SettlementRow(
                orderId: order['orderId']?.toString().trim().isNotEmpty == true
                    ? order['orderId'].toString().trim() : doc.id,
                sellerName: sellerName,
                status: status,
                gross: gross,
                commissionPercent: commissionPercent,
                commission: commission,
                payable: payable,
                settlementAmount: settlementAmount,
                paymentMethod: settlement['paymentMethod']?.toString().trim() ?? '',
                referenceId: settlement['referenceId']?.toString().trim() ?? '',
                date: _parseDate(rawDate),
              ));
            });
          }
          allRows.sort((_SettlementRow a, _SettlementRow b) {
            final DateTime ad = a.date ?? DateTime.fromMillisecondsSinceEpoch(0);
            final DateTime bd = b.date ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bd.compareTo(ad);
          });
          final List<_SettlementRow> rows = allRows.where(_matchesFilter).toList();
          final _Totals totals = _totals(rows);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              const Text(
                'Report Filter',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: <Widget>[
                  _filterButton('All'),
                  _filterButton('Day'),
                  _filterButton('Month'),
                  _filterButton('Year'),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      selected: _filter == 'Custom',
                      avatar: _filter == 'Custom' ? const Icon(Icons.check, size: 18) : const Icon(Icons.date_range, size: 18),
                      label: Text(_filter == 'Custom' && _customStart != null && _customEnd != null
                          ? '${_dateText(_customStart!)} - ${_dateText(_customEnd!)}' : 'Custom'),
                      onSelected: (_) => _pickCustomRange(),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              Row(children: <Widget>[
                Expanded(child: Text(_filterTitle(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                FilledButton.icon(
                  onPressed: () => _showExportOptions(rows),
                  icon: const Icon(Icons.ios_share),
                  label: const Text('Export Report'),
                ),
              ]),
              const SizedBox(height: 16),
              LayoutBuilder(builder: (BuildContext context, BoxConstraints constraints) {
                final int columns = constraints.maxWidth >= 900 ? 4 : constraints.maxWidth >= 560 ? 3 : 2;
                return GridView.count(
                  crossAxisCount: columns,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: constraints.maxWidth < 380 ? 1.05 : 1.25,
                  children: <Widget>[
                    _summaryCard(Icons.shopping_bag_outlined, 'Settlement Gross', totals.gross),
                    _summaryCard(Icons.percent, 'RD Commission', totals.commission),
                    _summaryCard(Icons.account_balance_wallet_outlined, 'Seller Payable', totals.payable),
                    _summaryCard(Icons.payments_outlined, 'Seller Paid', totals.paid),
                    _summaryCard(Icons.schedule, 'Ready to Pay', totals.ready),
                  ],
                );
              }),
              const SizedBox(height: 24),
              const Text('Commission & Settlement History', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              if (rows.isEmpty)
                const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No settlement records for this filter.'))))
              else
                ...rows.map(_historyCard),
            ],
          );
        },
      ),
    );
  }

  Widget _filterButton(String value) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      selected: _filter == value,
      avatar: _filter == value ? const Icon(Icons.check, size: 18) : null,
      label: Text(value),
      onSelected: (_) => setState(() => _filter = value),
    ),
  );

  Widget _summaryCard(IconData icon, String title, double amount) => Card(
    elevation: 2,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
        Icon(icon, size: 34),
        const SizedBox(height: 8),
        Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        FittedBox(fit: BoxFit.scaleDown, child: Text('Rs. ${_formatMoney(amount)}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
      ]),
    ),
  );

  Widget _historyCard(_SettlementRow row) {
    Color statusColor = Colors.orange;
    if (row.status == 'Paid') statusColor = Colors.green;
    if (row.status == 'Ready to Pay') statusColor = Colors.blue;
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Expanded(child: Text('Order ID: ${row.orderId}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(border: Border.all(color: statusColor), borderRadius: BorderRadius.circular(20)),
              child: Text(row.status, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 10),
          Text('Seller: ${row.sellerName}', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.25)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Text('Gross Sale: Rs. ${_formatMoney(row.gross)}'),
              const SizedBox(height: 4),
              Text('RD Commission (${_formatMoney(row.commissionPercent)}%): Rs. ${_formatMoney(row.commission)}',
                  style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('Seller Payable: Rs. ${_formatMoney(row.payable)}',
                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              const Divider(),
              Text('Settlement Amount: Rs. ${_formatMoney(row.settlementAmount)}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ]),
          ),
          if (row.paymentMethod.isNotEmpty) ...<Widget>[const SizedBox(height: 8), Text('RD Paid Via: ${row.paymentMethod}')],
          if (row.referenceId.isNotEmpty) ...<Widget>[const SizedBox(height: 3), Text('Reference ID: ${row.referenceId}')],
          if (row.date != null) ...<Widget>[const SizedBox(height: 3), Text('Date: ${_dateTimeText(row.date)}')],
        ]),
      ),
    );
  }
}

class _SettlementRow {
  const _SettlementRow({
    required this.orderId,
    required this.sellerName,
    required this.status,
    required this.gross,
    required this.commissionPercent,
    required this.commission,
    required this.payable,
    required this.settlementAmount,
    required this.paymentMethod,
    required this.referenceId,
    required this.date,
  });

  final String orderId;
  final String sellerName;
  final String status;
  final double gross;
  final double commissionPercent;
  final double commission;
  final double payable;
  final double settlementAmount;
  final String paymentMethod;
  final String referenceId;
  final DateTime? date;
}

class _Totals {
  const _Totals(this.gross, this.commission, this.payable, this.paid, this.ready);
  final double gross;
  final double commission;
  final double payable;
  final double paid;
  final double ready;
}
