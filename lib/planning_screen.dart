import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'services.dart';
import 'die_correction_screens.dart';
import 'die_template_model.dart'; // ✅ تم إضافة هذا السطر لحل المشكلة

String _s(dynamic v, [String fallback = '']) => v?.toString() ?? fallback;
int _i(dynamic v, [int fallback = 0]) => v is int ? v : int.tryParse(v?.toString() ?? '') ?? fallback;
double _d(dynamic v, [double fallback = 0]) => v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? fallback;
bool _b(dynamic v, [bool fallback = false]) => v is bool ? v : v?.toString() == 'true';
DateTime _dt(dynamic v, [DateTime? fallback]) => DateTime.tryParse(v?.toString() ?? '') ?? fallback ?? DateTime.now();
T _enum<T extends Enum>(List<T> values, dynamic v, T fallback) { final n=v?.toString(); for(final e in values){ if(e.name==n) return e; } return fallback; }

enum PlanningFinishType { millFinish, paint, anodize, other }
extension PlanningFinishTypeX on PlanningFinishType {
  String get label {
    switch (this) {
      case PlanningFinishType.millFinish: return 'ميل فينش';
      case PlanningFinishType.paint: return 'دهان';
      case PlanningFinishType.anodize: return 'أنوده';
      case PlanningFinishType.other: return 'أخرى';
    }
  }
}

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
  final String alloy;
  final String solutionType;
  final PlanningFinishType finishType;
  final double barLengthM;
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

  PlanningOrderModel({required this.id, required this.factoryId, required this.customerName, this.orderNumber = '', this.dieAssetId = '', this.dieName = '', this.profileCode = '', this.designCode = '', this.clientCode = '', this.alloy = '6063', this.solutionType = 'T5', this.finishType = PlanningFinishType.millFinish, this.barLengthM = 0, this.requiredBarCount = 0, this.producedBarCount = 0, this.packedBarCount = 0, this.status = PlanningStatus.active, this.comments = '', this.analysisRequired = false, this.tensileStretchRequired = false, this.dueDate, this.createdBy = '', DateTime? createdAt, DateTime? updatedAt}) : createdAt = createdAt ?? DateTime.now(), updatedAt = updatedAt ?? DateTime.now();

  int get remainingBarCount => requiredBarCount - producedBarCount;

  factory PlanningOrderModel.fromJson(String id, Map<dynamic, dynamic> j) => PlanningOrderModel(
        id: id,
        factoryId: _s(j['factoryId']),
        customerName: _s(j['customerName'], 'عميل'),
        orderNumber: _s(j['orderNumber']),
        dieAssetId: _s(j['dieAssetId']),
        dieName: _s(j['dieName']),
        profileCode: _s(j['profileCode']),
        designCode: _s(j['designCode']),
        clientCode: _s(j['clientCode']),
        alloy: _s(j['alloy'], '6063'),
        solutionType: _s(j['solutionType'], 'T5'),
        finishType: _enum(PlanningFinishType.values, j['finishType'], PlanningFinishType.millFinish),
        barLengthM: _d(j['barLengthM']),
        requiredBarCount: _i(j['requiredBarCount']),
        producedBarCount: _i(j['producedBarCount']),
        packedBarCount: _i(j['packedBarCount']),
        status: _enum(PlanningStatus.values, j['status'], PlanningStatus.active),
        comments: _s(j['comments']),
        analysisRequired: _b(j['analysisRequired']),
        tensileStretchRequired: _b(j['tensileStretchRequired']),
        dueDate: j['dueDate'] == null ? null : _dt(j['dueDate']),
        createdBy: _s(j['createdBy']),
        createdAt: _dt(j['createdAt']),
        updatedAt: _dt(j['updatedAt']),
      );

  Map<String, dynamic> toJson() => {
        'factoryId': factoryId,
        'customerName': customerName,
        'orderNumber': orderNumber,
        'dieAssetId': dieAssetId,
        'dieName': dieName,
        'profileCode': profileCode,
        'designCode': designCode,
        'clientCode': clientCode,
        'alloy': alloy,
        'solutionType': solutionType,
        'finishType': finishType.name,
        'barLengthM': barLengthM,
        'requiredBarCount': requiredBarCount,
        'producedBarCount': producedBarCount,
        'packedBarCount': packedBarCount,
        'remainingBarCount': remainingBarCount,
        'status': status.name,
        'comments': comments,
        'analysisRequired': analysisRequired,
        'tensileStretchRequired': tensileStretchRequired,
        'dueDate': dueDate?.toIso8601String(),
        'createdBy': createdBy,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}

class PlanningService {
  static Future<void> deductFromProduction({required String factoryId, required String dieName, required double barLengthM, required int producedBars}) async {
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
        final lengthOk = o.barLengthM <= 0 || (barLengthM > 0 && o.barLengthM == barLengthM);
        if (active && o.remainingBarCount > 0 && o.dieAssetId == template.id && lengthOk) orders.add(o);
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
    if (updates.isNotEmpty) await FirebaseDatabase.instance.ref().update(updates);
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
  @override
  void initState() { super.initState(); _factoryId = Provider.of<ShiftProvider>(context, listen: false).currentFactoryId; }

  DatabaseReference get _ref => FirebaseDatabase.instance.ref('factories/$_factoryId/planningOrders');

  Future<void> _addOrder() async {
    final order = await showDialog<PlanningOrderModel>(context: context, builder: (_) => PlanningOrderDialog(factoryId: _factoryId));
    if (order != null) {
      final ref = _ref.push();
      await ref.set(order.copyWith(id: ref.key ?? '', createdBy: FirebaseAuth.instance.currentUser?.email ?? '').toJson());
    }
  }

  Future<void> _setStatus(PlanningOrderModel o, PlanningStatus status) async {
    await _ref.child(o.id).update({'status': status.name, 'updatedAt': DateTime.now().toIso8601String()});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🗂️ قسم التخطيط')),
      floatingActionButton: FloatingActionButton.extended(onPressed: _addOrder, icon: const Icon(Icons.add), label: const Text('أوردر تخطيط')),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: TextField(decoration: const InputDecoration(labelText: 'بحث بعميل / أوردر / كود قالب', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()), onChanged: (v) => setState(() => _filter = v.trim()))),
        Expanded(child: StreamBuilder<DatabaseEvent>(stream: _ref.onValue, builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final val = snap.data!.snapshot.value;
          var orders = <PlanningOrderModel>[];
          if (val is Map) val.forEach((k, v) { if (v is Map) orders.add(PlanningOrderModel.fromJson(k.toString(), v)); });
          if (_filter.isNotEmpty) orders = orders.where((o) => o.customerName.contains(_filter) || o.orderNumber.contains(_filter) || o.profileCode.contains(_filter) || o.dieName.contains(_filter)).toList();
          orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          if (orders.isEmpty) return const Center(child: Text('لا توجد أوامر تخطيط'));
          return ListView.builder(padding: const EdgeInsets.all(12), itemCount: orders.length, itemBuilder: (context, i) {
            final o = orders[i];
            return Card(child: ListTile(
              leading: Icon(Icons.assignment, color: o.status == PlanningStatus.completed ? Colors.green : o.status == PlanningStatus.cancelled ? Colors.red : Colors.blue),
              title: Text('${o.customerName} • ${o.dieName}', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('الأوردر: ${o.orderNumber}\n${o.profileCode} | ${o.designCode} | ${o.clientCode}\nالمطلوب: ${o.requiredBarCount} • المنتج: ${o.producedBarCount} • المتبقي: ${o.remainingBarCount}\n${o.barLengthM}م • ${o.solutionType} • ${o.alloy} • ${o.finishType.label}\n${o.status.label}${o.comments.isEmpty ? '' : ' • ملاحظة: ${o.comments}'}'),
              isThreeLine: false,
              trailing: PopupMenuButton<String>(onSelected: (v) async { if (v == 'complete') await _setStatus(o, PlanningStatus.completed); if (v == 'cancel') await _setStatus(o, PlanningStatus.cancelled); }, itemBuilder: (context) => const [PopupMenuItem(value: 'complete', child: Text('مكتمل')), PopupMenuItem(value: 'cancel', child: Text('ملغي'))]),
            ));
          });
        })),
      ]),
    );
  }
}

extension on PlanningOrderModel {
  PlanningOrderModel copyWith({String? id, String? createdBy}) => PlanningOrderModel(
        id: id ?? this.id,
        factoryId: factoryId,
        customerName: customerName,
        orderNumber: orderNumber,
        dieAssetId: dieAssetId,
        dieName: dieName,
        profileCode: profileCode,
        designCode: designCode,
        clientCode: clientCode,
        alloy: alloy,
        solutionType: solutionType,
        finishType: finishType,
        barLengthM: barLengthM,
        requiredBarCount: requiredBarCount,
        producedBarCount: producedBarCount,
        packedBarCount: packedBarCount,
        status: status,
        comments: comments,
        analysisRequired: analysisRequired,
        tensileStretchRequired: tensileStretchRequired,
        dueDate: dueDate,
        createdBy: createdBy ?? this.createdBy,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
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
  final _alloy = TextEditingController(text: '6063');
  final _solution = TextEditingController(text: 'T5');
  final _length = TextEditingController();
  final _count = TextEditingController();
  final _comments = TextEditingController();
  PlanningFinishType _finish = PlanningFinishType.millFinish;
  bool _analysis = false;
  bool _tensile = false;
  DateTime? _due;

  Future<void> _search() async {
    final t = await DieTracking.findTemplate(widget.factoryId, [_code.text]);
    setState(() => _template = t);
    if (t == null && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لم يتم العثور على القالب')));
  }

  @override
  Widget build(BuildContext context) {
    final t = _template;
    return AlertDialog(
      title: const Text('أوردر تخطيط جديد'),
      content: SizedBox(width: 520, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [Expanded(child: TextField(controller: _code, decoration: const InputDecoration(labelText: 'اكتب كود القطاع/التصميم/العميل'))), IconButton(onPressed: _search, icon: const Icon(Icons.search))]),
        if (t != null) Card(color: Colors.green.shade50, child: ListTile(title: Text(t.displayName), subtitle: Text('${t.codesDisplay}\nاكتب باقي البيانات ثم حفظ'))),
        TextField(controller: _customer, decoration: const InputDecoration(labelText: 'اسم العميل')),
        TextField(controller: _orderNo, decoration: const InputDecoration(labelText: 'رقم الأوردر')),
        TextField(controller: _alloy, decoration: const InputDecoration(labelText: 'السبيكة')),
        TextField(controller: _solution, decoration: const InputDecoration(labelText: 'نوع الصلادة T4/T5/T6')),
        DropdownButtonFormField<PlanningFinishType>(value: _finish, decoration: const InputDecoration(labelText: 'نوع التشطيب'), items: PlanningFinishType.values.map((e) => DropdownMenuItem(value: e, child: Text(e.label))).toList(), onChanged: (v) => setState(() => _finish = v ?? PlanningFinishType.millFinish)),
        TextField(controller: _length, decoration: const InputDecoration(labelText: 'طول الأعواد م'), keyboardType: TextInputType.number),
        TextField(controller: _count, decoration: const InputDecoration(labelText: 'عدد الأعواد'), keyboardType: TextInputType.number),
        SwitchListTile(value: _analysis, onChanged: (v) => setState(() => _analysis = v), title: const Text('العميل طلب تحليل')),
        SwitchListTile(value: _tensile, onChanged: (v) => setState(() => _tensile = v), title: const Text('العميل طلب شد واستطالة')),
        TextField(controller: _comments, decoration: const InputDecoration(labelText: 'كومنت / ملاحظات'), maxLines: 2),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton(onPressed: () {
          if (t == null || _customer.text.trim().isEmpty) return;
          Navigator.pop(context, PlanningOrderModel(id: '', factoryId: widget.factoryId, customerName: _customer.text.trim(), orderNumber: _orderNo.text.trim(), dieAssetId: t.id, dieName: t.name, profileCode: t.dieCode, designCode: t.designCode, clientCode: t.clientCode, alloy: _alloy.text.trim(), solutionType: _solution.text.trim(), finishType: _finish, barLengthM: double.tryParse(_length.text) ?? 0, requiredBarCount: int.tryParse(_count.text) ?? 0, comments: _comments.text.trim(), analysisRequired: _analysis, tensileStretchRequired: _tensile));
        }, child: const Text('حفظ')),
      ],
    );
  }
}