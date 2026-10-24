import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as excel;
import 'services.dart';
import 'die_correction_screens.dart';
import 'die_template_model.dart';
import 'app_localization.dart';

String _s(dynamic v, [String fallback = '']) => v?.toString() ?? fallback;
int _i(dynamic v, [int fallback = 0]) => v is int ? v : int.tryParse(v?.toString() ?? '') ?? fallback;
double _d(dynamic v, [double fallback = 0]) => v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? fallback;
bool _b(dynamic v, [bool fallback = false]) => v is bool ? v : v?.toString() == 'true';
DateTime _dt(dynamic v, [DateTime? fallback]) => DateTime.tryParse(v?.toString() ?? '') ?? fallback ?? DateTime.now();
T _enum<T extends Enum>(List<T> values, dynamic v, T fallback) { final n=v?.toString(); for(final e in values){ if(e.name==n) return e; } return fallback; }

enum PlanningStatus { active, inProgress, completed, cancelled }
extension PlanningStatusX on PlanningStatus {
  String get label {
    switch (this) {
      case PlanningStatus.active: return 'جديد';
      case PlanningStatus.inProgress: return 'قيد التنفيذ';
      case PlanningStatus.completed: return 'مكتمل';
      case PlanningStatus.cancelled: return 'ملغي';
    }
  }
}

class PlanningOrderModel {
  final String id;
  final String factoryId;
  final String customerName;
  final String orderNumber;
  final String dieAssetId;
  final String dieName;
  final String profileCode;
  final String designCode;
  final String clientCode;
  final String color;
  final String hardness;
  final String weightType;
  final int bars;
  final double length;
  final double weight;
  final String alloy;
  final String solutionType;
  final int requiredBarCount;
  final int producedBarCount;
  final int packedBarCount;
  final PlanningStatus status;
  final String comments;
  final bool analysisRequired;
  final bool tensileStretchRequired;
  final DateTime? dueDate;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  PlanningOrderModel({
    required this.id, required this.factoryId, required this.customerName, 
    this.orderNumber = '', this.dieAssetId = '', this.dieName = '', 
    this.profileCode = '', this.designCode = '', this.clientCode = '', 
    this.color = 'MF', this.hardness = 'T6', this.weightType = 'Actual', 
    this.bars = 0, this.length = 0, this.weight = 0, 
    this.alloy = '6063', this.solutionType = 'T5', 
    this.requiredBarCount = 0, this.producedBarCount = 0, this.packedBarCount = 0, 
    this.status = PlanningStatus.active, this.comments = '', 
    this.analysisRequired = false, this.tensileStretchRequired = false, 
    this.dueDate, this.createdBy = '', DateTime? createdAt, DateTime? updatedAt
  }) : createdAt = createdAt ?? DateTime.now(), updatedAt = updatedAt ?? DateTime.now();

  int get remainingBarCount => requiredBarCount - producedBarCount;

  factory PlanningOrderModel.fromJson(String id, Map<dynamic, dynamic> j) => PlanningOrderModel(
        id: id, factoryId: _s(j['factoryId']), customerName: _s(j['customerName'], 'عميل'),
        orderNumber: _s(j['orderNumber']), dieAssetId: _s(j['dieAssetId']), dieName: _s(j['dieName']),
        profileCode: _s(j['profileCode']), designCode: _s(j['designCode']), clientCode: _s(j['clientCode']),
        color: _s(j['color'], 'MF'), hardness: _s(j['hardness'], 'T6'), weightType: _s(j['weightType'], 'Actual'),
        bars: _i(j['bars']), length: _d(j['length']), weight: _d(j['weight']),
        alloy: _s(j['alloy'], '6063'), solutionType: _s(j['solutionType'], 'T5'),
        requiredBarCount: _i(j['requiredBarCount']), producedBarCount: _i(j['producedBarCount']), packedBarCount: _i(j['packedBarCount']),
        status: _enum(PlanningStatus.values, j['status'], PlanningStatus.active), comments: _s(j['comments']),
        analysisRequired: _b(j['analysisRequired']), tensileStretchRequired: _b(j['tensileStretchRequired']),
        dueDate: j['dueDate'] == null ? null : _dt(j['dueDate']), createdBy: _s(j['createdBy']),
        createdAt: _dt(j['createdAt']), updatedAt: _dt(j['updatedAt']),
      );

  Map<String, dynamic> toJson() => {
        'factoryId': factoryId, 'customerName': customerName, 'orderNumber': orderNumber,
        'dieAssetId': dieAssetId, 'dieName': dieName, 'profileCode': profileCode, 'designCode': designCode, 'clientCode': clientCode,
        'color': color, 'hardness': hardness, 'weightType': weightType, 'bars': bars, 'length': length, 'weight': weight,
        'alloy': alloy, 'solutionType': solutionType, 'requiredBarCount': requiredBarCount,
        'producedBarCount': producedBarCount, 'packedBarCount': packedBarCount, 'remainingBarCount': remainingBarCount,
        'status': status.name, 'comments': comments, 'analysisRequired': analysisRequired,
        'tensileStretchRequired': tensileStretchRequired, 'dueDate': dueDate?.toIso8601String(),
        'createdBy': createdBy, 'createdAt': createdAt.toIso8601String(), 'updatedAt': updatedAt.toIso8601String(),
      };
}

class PlanningService {
  static Future<void> deductFromProduction({
    required String factoryId,
    required String dieName,
    required double barLengthM,
    required int producedBars,
  }) async {
    if (producedBars <= 0) return;
    final template = await DieTracking.findTemplate(factoryId, [dieName]);
    if (template == null) return;
    
    final snap = await FirebaseDatabase.instance.ref('factories/$factoryId/planningOrders').get();
    if (snap.value is! Map) return;
    
    final orders = <PlanningOrderModel>[];
    (snap.value as Map).forEach((k, v) {
      if (v is Map) {
        final o = PlanningOrderModel.fromJson(k.toString(), v);
        final active = o.status == PlanningStatus.active || o.status == PlanningStatus.inProgress;
        final lengthOk = o.length <= 0 || (barLengthM > 0 && o.length == barLengthM);
        if (active && o.remainingBarCount > 0 && o.dieAssetId == template.id && lengthOk) {
          orders.add(o);
        }
      }
    });
    
    if (orders.isEmpty) return;
    
    orders.sort((a, b) {
      final ad = a.dueDate ?? a.createdAt;
      final bd = b.dueDate ?? b.createdAt;
      return ad.compareTo(bd);
    });
    
    final updates = <String, dynamic>{};
    int left = producedBars;
    
    for (final o in orders) {
      if (left <= 0) break;
      final take = left < o.remainingBarCount ? left : o.remainingBarCount;
      left -= take;
      final newProduced = o.producedBarCount + take;
      
      updates['factories/$factoryId/planningOrders/${o.id}/producedBarCount'] = newProduced;
      updates['factories/$factoryId/planningOrders/${o.id}/remainingBarCount'] = o.requiredBarCount - newProduced;
      updates['factories/$factoryId/planningOrders/${o.id}/status'] = (o.requiredBarCount - newProduced) <= 0 ? PlanningStatus.completed.name : PlanningStatus.inProgress.name;
      updates['factories/$factoryId/planningOrders/${o.id}/updatedAt'] = DateTime.now().toIso8601String();
    }
    
    if (updates.isNotEmpty) {
      await FirebaseDatabase.instance.ref().update(updates);
    }
  }
}

class PlanningOrdersScreen extends StatefulWidget {
  const PlanningOrdersScreen({super.key});
  @override
  State<PlanningOrdersScreen> createState() => _PlanningOrdersScreenState();
}

class _PlanningOrdersScreenState extends State<PlanningOrdersScreen> {
  late final String _factoryId;
  String _filter = '';
  bool _isImporting = false;

  @override
  void initState() { super.initState(); _factoryId = Provider.of<ShiftProvider>(context, listen: false).currentFactoryId; }

  DatabaseReference get _ref => FirebaseDatabase.instance.ref('factories/$_factoryId/planningOrders');

  Future<void> _addOrder() async {
    if (_factoryId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('no_factory_selected'))));
      return;
    }
    final order = await showDialog<PlanningOrderModel>(context: context, builder: (_) => PlanningOrderDialog(factoryId: _factoryId));
    if (order != null) {
      try {
        final ref = _ref.push();
        await ref.set(order.copyWith(id: ref.key ?? '', createdBy: FirebaseAuth.instance.currentUser?.email ?? '').toJson());
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('order_saved'))));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.trP('order_save_failed', {'e': e.toString()}))));
      }
    }
  }

  // ✅ دالة استيراد ملف Excel
  Future<void> _importFromExcel() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result == null) return;

      setState(() => _isImporting = true);

      final bytes = result.files.first.bytes;
      if (bytes == null) {
        setState(() => _isImporting = false);
        return;
      }

      final excelFile = excel.Excel.decodeBytes(bytes);
      final sheet = excelFile.tables[excelFile.tables.keys.first];
      if (sheet == null) {
        setState(() => _isImporting = false);
        return;
      }

      int addedCount = 0;

      for (var row in sheet.rows.skip(1)) {
        if (row.length < 4) continue;

        final dieCode = row[0]?.value?.toString().trim() ?? '';
        final customer = row[1]?.value?.toString().trim() ?? '';
        final orderNo = row[2]?.value?.toString().trim() ?? '';
        final count = int.tryParse(row[3]?.value?.toString() ?? '0') ?? 0;
        final length = double.tryParse(row[4]?.value?.toString() ?? '0') ?? 0;

        if (dieCode.isEmpty || customer.isEmpty) continue;

        // البحث عن القالب في قاعدة البيانات
        final template = await DieTracking.findTemplate(_factoryId, [dieCode]);

        if (template != null) {
          final newOrder = PlanningOrderModel(
            id: '',
            factoryId: _factoryId,
            customerName: customer,
            orderNumber: orderNo,
            dieAssetId: template.id,
            dieName: template.name,
            profileCode: template.dieCode,
            designCode: template.designCode,
            clientCode: template.clientCode,
            requiredBarCount: count,
            length: length,
            createdBy: FirebaseAuth.instance.currentUser?.email ?? '',
          );

          final ref = _ref.push();
          await ref.set(newOrder.copyWith(id: ref.key ?? '').toJson());
          addedCount++;
        }
      }

      setState(() => _isImporting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ تم استيراد $addedCount أوردر بنجاح')));
      }
    } catch (e) {
      setState(() => _isImporting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ خطأ في الاستيراد: $e')));
      }
    }
  }

  Future<void> _setStatus(PlanningOrderModel o, PlanningStatus status) async {
    await _ref.child(o.id).update({'status': status.name, 'updatedAt': DateTime.now().toIso8601String()});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('planning_title'))),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'import_btn',
            onPressed: _isImporting ? null : _importFromExcel,
            icon: _isImporting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.upload_file),
            label: Text(_isImporting ? 'جاري الاستيراد...' : 'استيراد Excel'),
            backgroundColor: Colors.teal,
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'add_btn',
            onPressed: _addOrder, 
            icon: const Icon(Icons.add), 
            label: Text(context.tr('add_planning_order'))
          ),
        ],
      ),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: TextField(decoration: InputDecoration(labelText: context.tr('search_by_code_hint'), prefixIcon: const Icon(Icons.search), border: const OutlineInputBorder()), onChanged: (v) => setState(() => _filter = v.trim()))),
        Expanded(child: StreamBuilder<DatabaseEvent>(stream: _ref.onValue, builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final val = snap.data!.snapshot.value;
          var orders = <PlanningOrderModel>[];
          if (val is Map) val.forEach((k, v) { if (v is Map) orders.add(PlanningOrderModel.fromJson(k.toString(), v)); });
          if (_filter.isNotEmpty) orders = orders.where((o) => o.customerName.contains(_filter) || o.orderNumber.contains(_filter) || o.profileCode.contains(_filter) || o.dieName.contains(_filter)).toList();
          orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          if (orders.isEmpty) return Center(child: Text(context.tr('no_planning_orders')));
          return ListView.builder(padding: const EdgeInsets.all(12), itemCount: orders.length, itemBuilder: (context, i) {
            final o = orders[i];
            return Card(child: ListTile(
              leading: Icon(Icons.assignment, color: o.status == PlanningStatus.completed ? Colors.green : o.status == PlanningStatus.cancelled ? Colors.red : Colors.blue),
              title: Text('${o.customerName} • ${o.dieName}', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('الأوردر: ${o.orderNumber}\nالقطاع: ${o.profileCode} | التصميم: ${o.designCode} | العميل: ${o.clientCode}\nاللون: ${o.color} | الصلادة: ${o.hardness}\nالمطلوب: ${o.requiredBarCount} • المنتج: ${o.producedBarCount} • المتبقي: ${o.remainingBarCount}\n${o.length}م • ${o.weightType} • ${o.alloy}\n${o.status.label}'),
              isThreeLine: false,
              trailing: PopupMenuButton<String>(onSelected: (v) async { if (v == 'complete') await _setStatus(o, PlanningStatus.completed); if (v == 'cancel') await _setStatus(o, PlanningStatus.cancelled); }, itemBuilder: (context) => [PopupMenuItem(value: 'complete', child: Text(context.tr('status_completed'))), PopupMenuItem(value: 'cancel', child: Text(context.tr('status_cancelled')))]),
            ));
          });
        })),
      ]),
    );
  }
}

extension on PlanningOrderModel {
  PlanningOrderModel copyWith({String? id, String? createdBy}) => PlanningOrderModel(
        id: id ?? this.id, factoryId: factoryId, customerName: customerName, orderNumber: orderNumber,
        dieAssetId: dieAssetId, dieName: dieName, profileCode: profileCode, designCode: designCode, clientCode: clientCode,
        color: color, hardness: hardness, weightType: weightType, bars: bars, length: length, weight: weight,
        alloy: alloy, solutionType: solutionType, requiredBarCount: requiredBarCount,
        producedBarCount: producedBarCount, packedBarCount: packedBarCount, status: status, comments: comments,
        analysisRequired: analysisRequired, tensileStretchRequired: tensileStretchRequired, dueDate: dueDate,
        createdBy: createdBy ?? this.createdBy, createdAt: createdAt, updatedAt: DateTime.now(),
      );
}

class PlanningOrderDialog extends StatefulWidget {
  final String factoryId;
  const PlanningOrderDialog({super.key, required this.factoryId});
  @override
  State<PlanningOrderDialog> createState() => _PlanningOrderDialogState();
}

class _PlanningOrderDialogState extends State<PlanningOrderDialog> {
  DieTemplate? _template;
  final _code = TextEditingController();
  final _customer = TextEditingController();
  final _orderNo = TextEditingController();
  final _color = TextEditingController(text: 'MF');
  final _temper = TextEditingController(text: 'T6');
  final _weightType = TextEditingController(text: 'Actual');
  final _alloy = TextEditingController(text: '6063');
  final _length = TextEditingController();
  final _count = TextEditingController();
  final _weight = TextEditingController();
  final _comments = TextEditingController();
  bool _analysis = false;
  bool _tensile = false;
  bool _isSearching = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _code.addListener(_onCodeChanged);
  }

  @override
  void dispose() {
    _code.removeListener(_onCodeChanged);
    _debounce?.cancel();
    _code.dispose();
    _customer.dispose();
    _orderNo.dispose();
    _color.dispose();
    _temper.dispose();
    _weightType.dispose();
    _alloy.dispose();
    _length.dispose();
    _count.dispose();
    _weight.dispose();
    _comments.dispose();
    super.dispose();
  }

  void _onCodeChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      if (_code.text.trim().length >= 3) _autoSearch();
    });
  }

  Future<void> _autoSearch() async {
    setState(() => _isSearching = true);
    try {
      final t = await DieTracking.findTemplate(widget.factoryId, [_code.text]);
      if (mounted) setState(() => _template = t);
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _template;
    return AlertDialog(
      title: Row(
        children: [
          Text(context.tr('new_planning_order')),
          if (_isSearching) ...[const SizedBox(width: 12), const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))],
        ],
      ),
      content: SizedBox(
        width: 600, 
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min, 
            children: [
              TextField(controller: _code, decoration: InputDecoration(labelText: context.tr('enter_code_hint'), suffixIcon: const Icon(Icons.search, size: 16), border: const OutlineInputBorder())),
              const SizedBox(height: 8),
              if (t != null) ...[
                Card(color: Colors.green.shade50, child: ListTile(
                  leading: const Icon(Icons.check_circle, color: Colors.green),
                  title: Text('${context.tr('profile_code_word')}: ${t.dieCode}'),
                  subtitle: Text('${context.tr('client_code_word')}: ${t.clientCode} | ${context.tr('design_code_word')}: ${t.designCode}${t.version != null ? ' | ${context.tr('version_word')}: ${t.version}' : ''}\n${context.tr('die_recognized')}'),
                  isThreeLine: true,
                )),
                Row(children: [
                  Expanded(child: TextFormField(initialValue: t.dieCode, readOnly: true, decoration: InputDecoration(labelText: context.tr('die_profile_code_label'), border: const OutlineInputBorder(), isDense: true, suffixIcon: const Icon(Icons.lock_outline, size: 14)))),
                  const SizedBox(width: 6),
                  Expanded(child: TextFormField(initialValue: t.clientCode, readOnly: true, decoration: InputDecoration(labelText: context.tr('die_client_code_label'), border: const OutlineInputBorder(), isDense: true, suffixIcon: const Icon(Icons.lock_outline, size: 14)))),
                  const SizedBox(width: 6),
                  Expanded(child: TextFormField(initialValue: t.designCode, readOnly: true, decoration: InputDecoration(labelText: context.tr('die_design_code_label'), border: const OutlineInputBorder(), isDense: true, suffixIcon: const Icon(Icons.lock_outline, size: 14)))),
                ]),
              ]
              else if (_code.text.length >= 3 && !_isSearching)
                Card(color: Colors.orange.shade50, child: ListTile(leading: const Icon(Icons.warning, color: Colors.orange), title: Text(context.tr('die_not_found_msg')))),
              const SizedBox(height: 12),
              
              Row(children: [
                Expanded(child: TextField(controller: _customer, decoration: InputDecoration(labelText: context.tr('customer_name_label'), border: const OutlineInputBorder(), isDense: true))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: _orderNo, decoration: InputDecoration(labelText: context.tr('order_number_label'), border: const OutlineInputBorder(), isDense: true))),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(controller: _color, decoration: InputDecoration(labelText: context.tr('color_label'), border: const OutlineInputBorder(), isDense: true))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: _temper, decoration: InputDecoration(labelText: context.tr('temper_label'), border: const OutlineInputBorder(), isDense: true))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: _weightType, decoration: InputDecoration(labelText: context.tr('weight_type_label'), border: const OutlineInputBorder(), isDense: true))),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(controller: _alloy, decoration: InputDecoration(labelText: context.tr('alloy_word'), border: const OutlineInputBorder(), isDense: true))),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(controller: _count, decoration: InputDecoration(labelText: context.tr('bars_label'), border: const OutlineInputBorder(), isDense: true), keyboardType: TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: _length, decoration: InputDecoration(labelText: context.tr('length_label'), border: const OutlineInputBorder(), isDense: true), keyboardType: TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: _weight, decoration: InputDecoration(labelText: context.tr('weight_label'), border: const OutlineInputBorder(), isDense: true), keyboardType: TextInputType.number)),
              ]),
              const SizedBox(height: 12),
              
              SwitchListTile(value: _analysis, onChanged: (v) => setState(() => _analysis = v), title: Text(context.tr('analysis_required_label')), dense: true),
              SwitchListTile(value: _tensile, onChanged: (v) => setState(() => _tensile = v), title: Text(context.tr('tensile_required_label')), dense: true),
              
              TextField(controller: _comments, decoration: InputDecoration(labelText: context.tr('notes_label'), border: const OutlineInputBorder(), isDense: true), maxLines: 2),
            ]
          )
        )
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(context.tr('cancel'))),
        FilledButton(
          onPressed: () {
            if (t == null) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('die_not_found_msg'))));
              return;
            }
            if (_customer.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('customer_required'))));
              return;
            }
            Navigator.pop(context, PlanningOrderModel(
              id: '', factoryId: widget.factoryId, customerName: _customer.text.trim(), orderNumber: _orderNo.text.trim(),
              dieAssetId: t.id, dieName: t.name,
              profileCode: t.dieCode, designCode: t.designCode, clientCode: t.clientCode,
              color: _color.text.trim(), hardness: _temper.text.trim(), weightType: _weightType.text.trim(),
              length: double.tryParse(_length.text) ?? 0, weight: double.tryParse(_weight.text) ?? 0,
              alloy: _alloy.text.trim(), solutionType: _temper.text.trim(),
              requiredBarCount: int.tryParse(_count.text) ?? 0, comments: _comments.text.trim(),
              analysisRequired: _analysis, tensileStretchRequired: _tensile
            ));
          },
          child: Text(context.tr('save_word'))
        ),
      ],
    );
  }
}