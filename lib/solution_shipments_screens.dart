
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'services.dart';

// ============================================================
// 🧪 شحنات فرن الصلادة: شحنة → أقفاص → قطاعات → مجموعات أطوال
// ============================================================

String _s(dynamic v, [String fallback = '']) => v?.toString() ?? fallback;
int _i(dynamic v, [int fallback = 0]) => v is int ? v : int.tryParse(v?.toString() ?? '') ?? fallback;
double _d(dynamic v, [double fallback = 0]) => v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? fallback;
DateTime _dt(dynamic v, [DateTime? fallback]) => DateTime.tryParse(v?.toString() ?? '') ?? fallback ?? DateTime.now();
String _sol(dynamic v) => v?.toString().trim().isNotEmpty == true ? v.toString().trim().toUpperCase() : 'T5';

enum SolutionShipmentStatus { loading, heating, soaking, cooling, completed }

extension SolutionShipmentStatusX on SolutionShipmentStatus {
  String get label {
    switch (this) {
      case SolutionShipmentStatus.loading: return 'تحميل أقفاص';
      case SolutionShipmentStatus.heating: return 'تسخين';
      case SolutionShipmentStatus.soaking: return 'نقع/صلادة';
      case SolutionShipmentStatus.cooling: return 'تبريد';
      case SolutionShipmentStatus.completed: return 'انتهت الشحنة';
    }
  }
}

class SolutionBarGroupModel {
  final double lengthM;
  final int barCount;
  final double metricWeightKgPerM;
  final double totalWeightKg;
  final String solutionType;
  final int packedBarCount;

  SolutionBarGroupModel({required this.lengthM, required this.barCount, required this.metricWeightKgPerM, required this.solutionType, this.packedBarCount = 0}) : totalWeightKg = lengthM * barCount * metricWeightKgPerM;

  int get availableBarCount => barCount - packedBarCount;

  factory SolutionBarGroupModel.fromJson(Map<dynamic, dynamic> json) => SolutionBarGroupModel(
        lengthM: _d(json['lengthM']),
        barCount: _i(json['barCount']),
        metricWeightKgPerM: _d(json['metricWeightKgPerM']),
        solutionType: _sol(json['solutionType']),
        packedBarCount: _i(json['packedBarCount']),
      );

  Map<String, dynamic> toJson() => {'lengthM': lengthM, 'barCount': barCount, 'metricWeightKgPerM': metricWeightKgPerM, 'totalWeightKg': totalWeightKg, 'solutionType': solutionType, 'packedBarCount': packedBarCount};
}

class SolutionCageSectorModel {
  final String profileCode;
  final String designCode;
  final String clientCode;
  final String dieName;
  final List<SolutionBarGroupModel> groups;

  SolutionCageSectorModel({this.profileCode = '', this.designCode = '', this.clientCode = '', this.dieName = '', this.groups = const []});

  factory SolutionCageSectorModel.fromJson(Map<dynamic, dynamic> json) {
    final list = <SolutionBarGroupModel>[];
    final g = json['groups'];
    if (g is List) {
      for (final e in g) {
        if (e is Map) list.add(SolutionBarGroupModel.fromJson(e));
      }
    }
    return SolutionCageSectorModel(profileCode: _s(json['profileCode']), designCode: _s(json['designCode']), clientCode: _s(json['clientCode']), dieName: _s(json['dieName']), groups: list);
  }

  int get totalBars => groups.fold<int>(0, (sum, g) => sum + g.barCount);
  double get totalWeightKg => groups.fold<double>(0, (sum, g) => sum + g.totalWeightKg);
  String get solutionTypes => groups.map((g) => g.solutionType).toSet().join(' / ');

  Map<String, dynamic> toJson() => {'profileCode': profileCode, 'designCode': designCode, 'clientCode': clientCode, 'dieName': dieName, 'groups': groups.map((e) => e.toJson()).toList(), 'totalBars': totalBars, 'totalWeightKg': totalWeightKg};
}

class SolutionCageModel {
  final String id;
  final String shipmentId;
  final String cageNumber;
  final DateTime entryTime;
  final DateTime? exitTime;
  final List<SolutionCageSectorModel> sectors;

  SolutionCageModel({required this.id, required this.shipmentId, required this.cageNumber, DateTime? entryTime, this.exitTime, this.sectors = const []}) : entryTime = entryTime ?? DateTime.now();

  factory SolutionCageModel.fromJson(String id, Map<dynamic, dynamic> json) {
    final list = <SolutionCageSectorModel>[];
    final s = json['sectors'];
    if (s is List) {
      for (final e in s) {
        if (e is Map) list.add(SolutionCageSectorModel.fromJson(e));
      }
    }
    return SolutionCageModel(id: id, shipmentId: _s(json['shipmentId']), cageNumber: _s(json['cageNumber'], id), entryTime: _dt(json['entryTime']), exitTime: json['exitTime'] == null ? null : _dt(json['exitTime']), sectors: list);
  }

  int get totalBars => sectors.fold<int>(0, (sum, s) => sum + s.totalBars);
  double get totalWeightKg => sectors.fold<double>(0, (sum, s) => sum + s.totalWeightKg);

  Map<String, dynamic> toJson() => {'shipmentId': shipmentId, 'cageNumber': cageNumber, 'entryTime': entryTime.toIso8601String(), 'exitTime': exitTime?.toIso8601String(), 'sectors': sectors.map((e) => e.toJson()).toList(), 'totalBars': totalBars, 'totalWeightKg': totalWeightKg};
}

class SolutionShipmentModel {
  final String id;
  final String furnaceId;
  final String furnaceName;
  final String factoryId;
  final String alloy;
  final SolutionShipmentStatus status;
  final DateTime entryTime;
  final DateTime? exitTime;
  final double targetTemperature;
  final double actualTemperature;
  final String notes;

  SolutionShipmentModel({required this.id, required this.furnaceId, this.furnaceName = '', required this.factoryId, this.alloy = '6063', this.status = SolutionShipmentStatus.loading, DateTime? entryTime, this.exitTime, this.targetTemperature = 0, this.actualTemperature = 0, this.notes = ''}) : entryTime = entryTime ?? DateTime.now();

  factory SolutionShipmentModel.fromJson(String id, Map<dynamic, dynamic> json) => SolutionShipmentModel(
        id: id,
        furnaceId: _s(json['furnaceId']),
        furnaceName: _s(json['furnaceName']),
        factoryId: _s(json['factoryId']),
        alloy: _s(json['alloy'], '6063'),
        status: SolutionShipmentStatus.values.firstWhere((e) => e.name == _s(json['status']), orElse: () => SolutionShipmentStatus.loading),
        entryTime: _dt(json['entryTime']),
        exitTime: json['exitTime'] == null ? null : _dt(json['exitTime']),
        targetTemperature: _d(json['targetTemperature']),
        actualTemperature: _d(json['actualTemperature']),
        notes: _s(json['notes']),
      );

  Map<String, dynamic> toJson() => {'furnaceId': furnaceId, 'furnaceName': furnaceName, 'factoryId': factoryId, 'alloy': alloy, 'status': status.name, 'entryTime': entryTime.toIso8601String(), 'exitTime': exitTime?.toIso8601String(), 'targetTemperature': targetTemperature, 'actualTemperature': actualTemperature, 'notes': notes};
}

class SolutionShipmentsScreen extends StatefulWidget {
  const SolutionShipmentsScreen({super.key});
  @override
  State<SolutionShipmentsScreen> createState() => _SolutionShipmentsScreenState();
}

class _SolutionShipmentsScreenState extends State<SolutionShipmentsScreen> {
  late final String _factoryId;
  @override
  void initState() {
    super.initState();
    _factoryId = Provider.of<ShiftProvider>(context, listen: false).currentFactoryId;
  }

  DatabaseReference get _shipmentsRef => FirebaseDatabase.instance.ref('factories/$_factoryId/solutionShipments');
  DatabaseReference get _furnacesRef => FirebaseDatabase.instance.ref('factories/$_factoryId/solutionFurnaces');

  Future<void> _addShipment() async {
    final furnSnap = await _furnacesRef.get();
    final furnaces = <MapEntry<String, String>>[];
    if (furnSnap.value is Map) {
      (furnSnap.value as Map).forEach((key, value) {
        if (value is Map) furnaces.add(MapEntry(key.toString(), _s(value['name'], 'فرن')));
      });
    }
    if (furnaces.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أضف فرن صلادة أولًا من شاشة أفران الصلادة القديمة')));
      return;
    }
    String furnaceId = furnaces.first.key;
    final alloy = TextEditingController(text: '6063');
    final target = TextEditingController();
    final actual = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (context) => StatefulBuilder(builder: (context, setDlg) => AlertDialog(
      title: const Text('بدء شحنة صلادة'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(value: furnaceId, decoration: const InputDecoration(labelText: 'الفرن'), items: furnaces.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(), onChanged: (v) => setDlg(() => furnaceId = v ?? furnaceId)),
        TextField(controller: alloy, decoration: const InputDecoration(labelText: 'السبيكة')),
        TextField(controller: target, decoration: const InputDecoration(labelText: 'درجة الحرارة المطلوبة'), keyboardType: TextInputType.number),
        TextField(controller: actual, decoration: const InputDecoration(labelText: 'درجة الحرارة الفعلية'), keyboardType: TextInputType.number),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('بدء الشحنة'))],
    )));
    if (ok == true) {
      final ref = _shipmentsRef.push();
      await ref.set(SolutionShipmentModel(id: ref.key ?? '', furnaceId: furnaceId, furnaceName: furnaces.firstWhere((e) => e.key == furnaceId, orElse: () => furnaces.first).value, factoryId: _factoryId, alloy: alloy.text.trim(), targetTemperature: double.tryParse(target.text) ?? 0, actualTemperature: double.tryParse(actual.text) ?? 0).toJson());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🧪 شحنات فرن الصلادة')),
      floatingActionButton: FloatingActionButton.extended(onPressed: _addShipment, icon: const Icon(Icons.add), label: const Text('شحنة جديدة')),
      body: StreamBuilder<DatabaseEvent>(stream: _shipmentsRef.onValue, builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final val = snapshot.data!.snapshot.value;
        final shipments = <SolutionShipmentModel>[];
        if (val is Map) val.forEach((key, value) { if (value is Map) shipments.add(SolutionShipmentModel.fromJson(key.toString(), value)); });
        shipments.sort((a, b) => b.entryTime.compareTo(a.entryTime));
        if (shipments.isEmpty) return const Center(child: Text('لا توجد شحنات صلادة'));
        return ListView.builder(padding: const EdgeInsets.all(12), itemCount: shipments.length, itemBuilder: (context, index) {
          final s = shipments[index];
          return Card(child: ListTile(leading: const Icon(Icons.heat_pump, color: Colors.deepOrange), title: Text('شحنة ${s.id.substring(0, s.id.length > 6 ? 6 : s.id.length)} - ${s.furnaceName}'), subtitle: Text('${s.status.label}\nالسبيكة: ${s.alloy} • الحرارة: ${s.targetTemperature}° • الدخول: ${s.entryTime}'), isThreeLine: true, trailing: const Icon(Icons.chevron_left), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SolutionShipmentDetailScreen(shipment: s)))));
        });
      }),
    );
  }
}

class SolutionShipmentDetailScreen extends StatefulWidget {
  final SolutionShipmentModel shipment;
  const SolutionShipmentDetailScreen({super.key, required this.shipment});
  @override
  State<SolutionShipmentDetailScreen> createState() => _SolutionShipmentDetailScreenState();
}

class _SolutionShipmentDetailScreenState extends State<SolutionShipmentDetailScreen> {
  late final String _factoryId;
  @override
  void initState() {
    super.initState();
    _factoryId = Provider.of<ShiftProvider>(context, listen: false).currentFactoryId;
  }

  DatabaseReference get _cagesRef => FirebaseDatabase.instance.ref('factories/$_factoryId/solutionCages');
  DatabaseReference get _shipmentRef => FirebaseDatabase.instance.ref('factories/$_factoryId/solutionShipments/${widget.shipment.id}');

  Future<void> _addCage() async {
    final cageNo = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('إضافة قفص'), content: TextField(controller: cageNo, decoration: const InputDecoration(labelText: 'رقم القفص')), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('إضافة'))]));
    if (ok == true && cageNo.text.trim().isNotEmpty) {
      final ref = _cagesRef.push();
      await ref.set(SolutionCageModel(id: ref.key ?? '', shipmentId: widget.shipment.id, cageNumber: cageNo.text.trim()).toJson());
    }
  }

  Future<void> _addSector(SolutionCageModel cage) async {
    final sector = await showDialog<SolutionCageSectorModel>(context: context, builder: (context) => const _AddSolutionSectorDialog());
    if (sector != null) {
      final updated = SolutionCageModel(id: cage.id, shipmentId: cage.shipmentId, cageNumber: cage.cageNumber, entryTime: cage.entryTime, exitTime: cage.exitTime, sectors: [...cage.sectors, sector]);
      await _cagesRef.child(cage.id).set(updated.toJson());
    }
  }

  Future<void> _exitCage(SolutionCageModel cage) async {
    final updated = SolutionCageModel(id: cage.id, shipmentId: cage.shipmentId, cageNumber: cage.cageNumber, entryTime: cage.entryTime, exitTime: DateTime.now(), sectors: cage.sectors);
    await _cagesRef.child(cage.id).set(updated.toJson());
  }

  Future<void> _endShipment() async {
    await _shipmentRef.update({'status': SolutionShipmentStatus.completed.name, 'exitTime': DateTime.now().toIso8601String()});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('🧪 شحنة ${widget.shipment.id.substring(0, widget.shipment.id.length > 6 ? 6 : widget.shipment.id.length)}')),
      body: StreamBuilder<DatabaseEvent>(stream: _cagesRef.onValue, builder: (context, snapshot) {
        final val = snapshot.data?.snapshot.value;
        final cages = <SolutionCageModel>[];
        if (val is Map) {
          val.forEach((key, value) { if (value is Map && _s(value['shipmentId']) == widget.shipment.id) cages.add(SolutionCageModel.fromJson(key.toString(), value)); });
        }
        cages.sort((a, b) => a.cageNumber.compareTo(b.cageNumber));
        final totalBars = cages.fold<int>(0, (sum, c) => sum + c.totalBars);
        final totalWeight = cages.fold<double>(0, (sum, c) => sum + c.totalWeightKg);
        return ListView(padding: const EdgeInsets.all(12), children: [
          Card(child: ListTile(leading: const Icon(Icons.summarize, color: Colors.green), title: const Text('ملخص الشحنة'), subtitle: Text('عدد الأقفاص: ${cages.length}\nإجمالي الأعواد: $totalBars\nالوزن الإجمالي: ${totalWeight.toStringAsFixed(3)} كجم\nالسبيكة: ${widget.shipment.alloy} • الحرارة: ${widget.shipment.targetTemperature}° • ${widget.shipment.status.label}'), isThreeLine: true)),
          Row(children: [Expanded(child: ElevatedButton.icon(onPressed: _addCage, icon: const Icon(Icons.add_box), label: const Text('إضافة قفص'))), const SizedBox(width: 8), if (widget.shipment.exitTime == null) Expanded(child: OutlinedButton.icon(onPressed: _endShipment, icon: const Icon(Icons.stop), label: const Text('إنهاء الشحنة')))]),
          const SizedBox(height: 8),
          ...cages.map((cage) => Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Expanded(child: Text('قفص ${cage.cageNumber} • ${cage.totalBars} عود • ${cage.totalWeightKg.toStringAsFixed(3)} كجم', style: const TextStyle(fontWeight: FontWeight.bold))), TextButton.icon(onPressed: () => _addSector(cage), icon: const Icon(Icons.add), label: const Text('قطاع')), if (cage.exitTime == null) IconButton(onPressed: () => _exitCage(cage), icon: const Icon(Icons.logout, color: Colors.red))]),
            ...cage.sectors.map((sector) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Container(width: double.infinity, padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)), child: Text('القطاع: ${sector.dieName.isNotEmpty ? sector.dieName : sector.profileCode}\nالأكواد: ${sector.profileCode} | ${sector.designCode} | ${sector.clientCode}\nالصلادة: ${sector.solutionTypes} • الأعواد: ${sector.totalBars} • الوزن: ${sector.totalWeightKg.toStringAsFixed(3)} كجم')))),
          ]))))
        ]);
      }),
    );
  }
}

class _AddSolutionSectorDialog extends StatefulWidget {
  const _AddSolutionSectorDialog();
  @override
  State<_AddSolutionSectorDialog> createState() => _AddSolutionSectorDialogState();
}

class _GroupRow {
  final TextEditingController length = TextEditingController();
  final TextEditingController count = TextEditingController();
  final TextEditingController metric = TextEditingController();
  String solutionType = 'T5';
}

class _AddSolutionSectorDialogState extends State<_AddSolutionSectorDialog> {
  final profile = TextEditingController();
  final design = TextEditingController();
  final client = TextEditingController();
  final dieName = TextEditingController();
  final List<_GroupRow> rows = [_GroupRow()];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة قطاع للقفص'),
      content: SizedBox(width: 420, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: profile, decoration: const InputDecoration(labelText: 'كود القطاع')),
        TextField(controller: design, decoration: const InputDecoration(labelText: 'كود التصميم')),
        TextField(controller: client, decoration: const InputDecoration(labelText: 'كود العميل')),
        TextField(controller: dieName, decoration: const InputDecoration(labelText: 'اسم القالب')),
        const SizedBox(height: 8),
        Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: () => setState(() => rows.add(_GroupRow())), icon: const Icon(Icons.add), label: const Text('إضافة طول/عدد'))),
        ...rows.map((r) => Row(children: [
          Expanded(child: TextField(controller: r.length, decoration: const InputDecoration(labelText: 'الطول م'), keyboardType: TextInputType.number)),
          const SizedBox(width: 6),
          Expanded(child: TextField(controller: r.count, decoration: const InputDecoration(labelText: 'عدد'), keyboardType: TextInputType.number)),
          const SizedBox(width: 6),
          Expanded(child: TextField(controller: r.metric, decoration: const InputDecoration(labelText: 'كجم/م'), keyboardType: TextInputType.number)),
          const SizedBox(width: 6),
          DropdownButton<String>(value: r.solutionType, items: const ['T4', 'T5', 'T6', 'أخرى'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => r.solutionType = v ?? 'T5')),
          IconButton(onPressed: rows.length > 1 ? () => setState(() => rows.remove(r)) : null, icon: const Icon(Icons.remove_circle)),
        ])),
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')), FilledButton(onPressed: () {
        final groups = rows.where((r) => (double.tryParse(r.length.text) ?? 0) > 0 && (int.tryParse(r.count.text) ?? 0) > 0 && (double.tryParse(r.metric.text) ?? 0) > 0).map((r) => SolutionBarGroupModel(lengthM: double.parse(r.length.text), barCount: int.parse(r.count.text), metricWeightKgPerM: double.parse(r.metric.text), solutionType: r.solutionType)).toList();
        if (groups.isEmpty) return;
        Navigator.pop(context, SolutionCageSectorModel(profileCode: profile.text.trim(), designCode: design.text.trim(), clientCode: client.text.trim(), dieName: dieName.text.trim(), groups: groups));
      }, child: const Text('حفظ'))],
    );
  }
}
