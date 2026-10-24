import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'services.dart';
import 'die_correction_screens.dart';
import 'solution_shipments_screens.dart'; 

String _s(dynamic v, [String fallback = '']) => v?.toString() ?? fallback;
int _i(dynamic v, [int fallback = 0]) => v is int ? v : int.tryParse(v?.toString() ?? '') ?? fallback;
double _d(dynamic v, [double fallback = 0]) => v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? fallback;
DateTime _dt(dynamic v, [DateTime? fallback]) => DateTime.tryParse(v?.toString() ?? '') ?? fallback ?? DateTime.now();

enum QualityStatus { accepted, rejected, repaired, stopped }
extension QualityStatusX on QualityStatus {
  String get label {
    switch (this) {
      case QualityStatus.accepted: return 'مقبول';
      case QualityStatus.rejected: return 'مرفوض';
      case QualityStatus.repaired: return 'تم إصلاحه';
      case QualityStatus.stopped: return 'متوقف لحين الإصلاح';
    }
  }
}
QualityStatus _quality(dynamic v) => QualityStatus.values.firstWhere((e) => e.name == _s(v), orElse: () => QualityStatus.accepted);

class PackagingPackageV2 {
  final String id; final String orderId; final String factoryId; final String status; final DateTime createdAt; final String createdBy;
  PackagingPackageV2({required this.id, required this.orderId, required this.factoryId, this.status = 'packed', DateTime? createdAt, this.createdBy = ''}) : createdAt = createdAt ?? DateTime.now();
  factory PackagingPackageV2.fromJson(String id, Map<dynamic, dynamic> j) => PackagingPackageV2(id: id, orderId: _s(j['orderId']), factoryId: _s(j['factoryId']), status: _s(j['status'], 'packed'), createdAt: _dt(j['createdAt']), createdBy: _s(j['createdBy']));
  Map<String, dynamic> toJson() => {'orderId': orderId, 'factoryId': factoryId, 'status': status, 'createdAt': createdAt.toIso8601String(), 'createdBy': createdBy};
}

class PackagingItemV2 {
  final String id; final String packageId; final String orderId; final String factoryId; final String shipmentId; final String cageId; final int sectorIndex; final int groupIndex; final String profileCode; final String designCode; final String clientCode; final String dieName; final String alloy; final double lengthM; final double metricWeightKgPerM; final int barCount; final double totalWeightKg; final String solutionType;
  PackagingItemV2({required this.id, required this.packageId, required this.orderId, required this.factoryId, required this.shipmentId, required this.cageId, required this.sectorIndex, required this.groupIndex, this.profileCode = '', this.designCode = '', this.clientCode = '', this.dieName = '', this.alloy = '6063', this.lengthM = 0, this.metricWeightKgPerM = 0, this.barCount = 0, this.solutionType = 'T5'}) : totalWeightKg = lengthM * metricWeightKgPerM * barCount;
  factory PackagingItemV2.fromJson(String id, Map<dynamic, dynamic> j) => PackagingItemV2(id: id, packageId: _s(j['packageId']), orderId: _s(j['orderId']), factoryId: _s(j['factoryId']), shipmentId: _s(j['shipmentId']), cageId: _s(j['cageId']), sectorIndex: _i(j['sectorIndex']), groupIndex: _i(j['groupIndex']), profileCode: _s(j['profileCode']), designCode: _s(j['designCode']), clientCode: _s(j['clientCode']), dieName: _s(j['dieName']), alloy: _s(j['alloy'], '6063'), lengthM: _d(j['lengthM']), metricWeightKgPerM: _d(j['metricWeightKgPerM']), barCount: _i(j['barCount']), solutionType: _s(j['solutionType']));
  Map<String, dynamic> toJson() => {'packageId': packageId, 'orderId': orderId, 'factoryId': factoryId, 'shipmentId': shipmentId, 'cageId': cageId, 'sectorIndex': sectorIndex, 'groupIndex': groupIndex, 'profileCode': profileCode, 'designCode': designCode, 'clientCode': clientCode, 'dieName': dieName, 'alloy': alloy, 'lengthM': lengthM, 'metricWeightKgPerM': metricWeightKgPerM, 'barCount': barCount, 'totalWeightKg': totalWeightKg, 'solutionType': solutionType};
}

class QualityInspectionModel {
  final String id; final String factoryId; final String dieAssetId; final String dieName; final String codesDisplay; final String shiftId; final String pressName; final int billetCount; final QualityStatus status; final int defectiveBarCount; final String notes; final String inspectorName; final DateTime createdAt;
  QualityInspectionModel({required this.id, required this.factoryId, required this.dieAssetId, required this.dieName, this.codesDisplay = '', this.shiftId = '', this.pressName = '', this.billetCount = 0, this.status = QualityStatus.accepted, this.defectiveBarCount = 0, this.notes = '', this.inspectorName = '', DateTime? createdAt}) : createdAt = createdAt ?? DateTime.now();
  factory QualityInspectionModel.fromJson(String id, Map<dynamic, dynamic> j) => QualityInspectionModel(id: id, factoryId: _s(j['factoryId']), dieAssetId: _s(j['dieAssetId']), dieName: _s(j['dieName']), codesDisplay: _s(j['codesDisplay']), shiftId: _s(j['shiftId']), pressName: _s(j['pressName']), billetCount: _i(j['billetCount']), status: _quality(j['status']), defectiveBarCount: _i(j['defectiveBarCount']), notes: _s(j['notes']), inspectorName: _s(j['inspectorName']), createdAt: _dt(j['createdAt']));
  Map<String, dynamic> toJson() => {'factoryId': factoryId, 'dieAssetId': dieAssetId, 'dieName': dieName, 'codesDisplay': codesDisplay, 'shiftId': shiftId, 'pressName': pressName, 'billetCount': billetCount, 'status': status.name, 'defectiveBarCount': defectiveBarCount, 'notes': notes, 'inspectorName': inspectorName, 'createdAt': createdAt.toIso8601String()};
}

class SolutionHardnessModel {
  final String id; final String factoryId; final String shipmentId; final String cageId; final String cageNumber; final String profileCode; final String groupLabel; final String websterValue; final String notes; final String inspectorName; final DateTime createdAt;
  SolutionHardnessModel({required this.id, required this.factoryId, required this.shipmentId, required this.cageId, this.cageNumber = '', this.profileCode = '', this.groupLabel = '', this.websterValue = '', this.notes = '', this.inspectorName = '', DateTime? createdAt}) : createdAt = createdAt ?? DateTime.now();
  Map<String, dynamic> toJson() => {'factoryId': factoryId, 'shipmentId': shipmentId, 'cageId': cageId, 'cageNumber': cageNumber, 'profileCode': profileCode, 'groupLabel': groupLabel, 'websterValue': websterValue, 'notes': notes, 'inspectorName': inspectorName, 'createdAt': createdAt.toIso8601String()};
}

class PackagingOrdersHomeScreen extends StatefulWidget { const PackagingOrdersHomeScreen({super.key}); @override State<PackagingOrdersHomeScreen> createState() => _PackagingOrdersHomeScreenState(); }
class _PackagingOrdersHomeScreenState extends State<PackagingOrdersHomeScreen> {
  late final String _factoryId; @override void initState() { super.initState(); _factoryId = Provider.of<ShiftProvider>(context, listen: false).currentFactoryId; }
  DatabaseReference get _ordersRef => FirebaseDatabase.instance.ref('factories/$_factoryId/packagingOrdersV2');
  Future<void> _addOrder() async { final customer = TextEditingController(); final order = TextEditingController(); final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('أمر تغليف جديد'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: customer, decoration: const InputDecoration(labelText: 'اسم العميل')), TextField(controller: order, decoration: const InputDecoration(labelText: 'رقم الطلب'))]), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('حفظ'))])); if (ok == true && customer.text.trim().isNotEmpty) { final ref = _ordersRef.push(); await ref.set({'factoryId': _factoryId, 'customerName': customer.text.trim(), 'orderNumber': order.text.trim(), 'status': 'new', 'createdAt': DateTime.now().toIso8601String(), 'createdBy': FirebaseAuth.instance.currentUser?.email ?? ''}); } }
  @override Widget build(BuildContext context) { return Scaffold(appBar: AppBar(title: const Text('📦 قسم التغليف')), floatingActionButton: FloatingActionButton.extended(onPressed: _addOrder, icon: const Icon(Icons.add), label: const Text('أمر تغليف')), body: StreamBuilder<DatabaseEvent>(stream: _ordersRef.onValue, builder: (context, snap) { if (!snap.hasData) return const Center(child: CircularProgressIndicator()); final val = snap.data!.snapshot.value; final orders = <MapEntry<String, Map>>[]; if (val is Map) val.forEach((k, v) { if (v is Map) orders.add(MapEntry(k.toString(), Map<String, dynamic>.from(v))); }); orders.sort((a, b) => _s(b.value['createdAt']).compareTo(_s(a.value['createdAt']))); if (orders.isEmpty) return const Center(child: Text('لا توجد أوامر تغليف')); return ListView.builder(padding: const EdgeInsets.all(12), itemCount: orders.length, itemBuilder: (context, i) { final o = orders[i]; return Card(child: ListTile(leading: const Icon(Icons.inventory_2), title: Text(_s(o.value['customerName'], 'عميل'), style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('الطلب: ${_s(o.value['orderNumber'])}\nالحالة: ${_s(o.value['status'], 'new')}'), isThreeLine: true, trailing: const Icon(Icons.chevron_left), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PackagingOrderDetailV2Screen(orderId: o.key, customerName: _s(o.value['customerName'], 'عميل'), orderNumber: _s(o.value['orderNumber'])))))); }); })); }
}

class PackagingOrderDetailV2Screen extends StatefulWidget { final String orderId; final String customerName; final String orderNumber; const PackagingOrderDetailV2Screen({super.key, required this.orderId, required this.customerName, this.orderNumber = ''}); @override State<PackagingOrderDetailV2Screen> createState() => _PackagingOrderDetailV2ScreenState(); }
class _PackagingOrderDetailV2ScreenState extends State<PackagingOrderDetailV2Screen> {
  late final String _factoryId; 
  @override void initState() { super.initState(); _factoryId = Provider.of<ShiftProvider>(context, listen: false).currentFactoryId; }
  DatabaseReference get _packagesRef => FirebaseDatabase.instance.ref('factories/$_factoryId/packagingPackagesV2');
  DatabaseReference get _itemsRef => FirebaseDatabase.instance.ref('factories/$_factoryId/packagingItemsV2');

  Future<void> _startPackingCage(SolutionCageModel cage) async {
    final packageRef = _packagesRef.push();
    final packageId = packageRef.key ?? '';
    
    final Map<String, dynamic> updates = {};
    updates['factories/$_factoryId/packagingPackagesV2/$packageId'] = PackagingPackageV2(
      id: packageId, orderId: widget.orderId, factoryId: _factoryId, createdBy: FirebaseAuth.instance.currentUser?.email ?? ''
    ).toJson();

    for (var sector in cage.sectors) {
      for (var group in sector.groups) {
        final itemRef = _itemsRef.push();
        final itemId = itemRef.key ?? '';
        updates['factories/$_factoryId/packagingItemsV2/$itemId'] = PackagingItemV2(
          id: itemId, packageId: packageId, orderId: widget.orderId, factoryId: _factoryId, shipmentId: cage.shipmentId, cageId: cage.id, sectorIndex: 0, groupIndex: 0,
          profileCode: sector.profileCode, designCode: sector.designCode, clientCode: sector.clientCode, dieName: sector.dieName, lengthM: group.lengthM, metricWeightKgPerM: group.metricWeightKgPerM, barCount: group.barCount, solutionType: group.solutionType
        ).toJson();
      }
    }
    updates['factories/$_factoryId/solutionCages/${cage.id}/status'] = 'packed';
    await FirebaseDatabase.instance.ref().update(updates);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم بدء تغليف القفص')));
  }

  @override Widget build(BuildContext context) { return Scaffold(appBar: AppBar(title: Text('📦 ${widget.customerName}')), floatingActionButton: FloatingActionButton.extended(onPressed: () async { await showDialog(context: context, builder: (_) => SelectSolutionPackageDialog(orderId: widget.orderId)); }, icon: const Icon(Icons.add), label: const Text('طرد من شحنة صلادة')), body: Column(children: [
    Expanded(
      child: StreamBuilder<DatabaseEvent>(
        stream: FirebaseDatabase.instance.ref('factories/$_factoryId/solutionCages').onValue, 
        builder: (context, cageSnap) {
          if (!cageSnap.hasData) return const Center(child: CircularProgressIndicator());
          final cageVal = cageSnap.data!.snapshot.value;
          final allCages = <SolutionCageModel>[];
          if (cageVal is Map) {
            cageVal.forEach((k, v) { if (v is Map) { final c = SolutionCageModel.fromJson(k.toString(), v); if (c.shipmentId.isNotEmpty) allCages.add(c); } });
          }
          return ListView(padding: const EdgeInsets.all(12), children: [
            const Text('📦 أقفاص الشحنة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (allCages.isEmpty) const Center(child: Text('لا توجد أقفاص في هذه الشحنة')),
            ...allCages.map((cage) => Card(child: ExpansionTile(leading: const Icon(Icons.inventory, color: Colors.blue), title: Text('قفص ${cage.cageNumber}'), subtitle: Text('${cage.totalBars} عود • ${cage.totalWeightKg.toStringAsFixed(3)} كجم'), children: [
              ...cage.sectors.map((sector) => ListTile(title: Text(sector.dieName.isNotEmpty ? sector.dieName : sector.profileCode), subtitle: Text('${sector.totalBars} عود • ${sector.totalWeightKg.toStringAsFixed(3)} كجم'))),
              Padding(padding: const EdgeInsets.all(8.0), child: ElevatedButton.icon(onPressed: () => _startPackingCage(cage), icon: const Icon(Icons.check), label: const Text('بدء التغليف'))),
            ]))),
          ]);
        }
      ),
    ),
    Expanded(
      child: StreamBuilder<DatabaseEvent>(
        stream: _packagesRef.onValue, 
        builder: (context, snap) { 
          final val = snap.data?.snapshot.value; 
          final packages = <PackagingPackageV2>[]; 
          if (val is Map) { val.forEach((k, v) { if (v is Map && _s(v['orderId']) == widget.orderId) packages.add(PackagingPackageV2.fromJson(k.toString(), v)); }); }
          packages.sort((a, b) => b.createdAt.compareTo(a.createdAt)); 
          return ListView.builder(padding: const EdgeInsets.all(12), itemCount: packages.length, itemBuilder: (context, i) { 
            final p = packages[i]; 
            return Card(child: ExpansionTile(leading: const Icon(Icons.local_shipping), title: Text('طرد ${p.id.substring(0, p.id.length > 6 ? 6 : p.id.length)} - ${p.status}'), subtitle: Text(p.createdAt.toString()), children: [
              StreamBuilder<DatabaseEvent>(stream: _itemsRef.onValue, builder: (context, isnap) { 
                final ival = isnap.data?.snapshot.value; 
                final items = <PackagingItemV2>[]; 
                if (ival is Map) { ival.forEach((k, v) { if (v is Map && _s(v['packageId']) == p.id) items.add(PackagingItemV2.fromJson(k.toString(), v)); }); }
                final bars = items.fold<int>(0, (s, e) => s + e.barCount); 
                final weight = items.fold<double>(0, (s, e) => s + e.totalWeightKg); 
                return Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('إجمالي الطرد: $bars عود - ${weight.toStringAsFixed(3)} كجم', style: const TextStyle(fontWeight: FontWeight.bold)), 
                  ...items.map((e) => ListTile(dense: true, title: Text('${e.profileCode} ${e.lengthM}م ${e.solutionType}'), subtitle: Text('${e.barCount} عود - ${e.totalWeightKg.toStringAsFixed(3)} كجم - قفص ${e.cageId}')))
                ])); 
              })
            ])); 
          }); 
        }
      ),
    ),
  ])); }
}

class _SourceRow { final SolutionCageModel cage; final int sectorIndex; final SolutionCageSectorModel sector; final int groupIndex; final SolutionBarGroupModel group; final TextEditingController qty = TextEditingController(); _SourceRow(this.cage, this.sectorIndex, this.sector, this.groupIndex, this.group); String get label => 'قفص ${cage.cageNumber} - ${sector.dieName.isNotEmpty ? sector.dieName : sector.profileCode} - ${group.lengthM}م - ${group.solutionType} - متاح ${group.availableBarCount}'; }

class SelectSolutionPackageDialog extends StatefulWidget { final String orderId; const SelectSolutionPackageDialog({super.key, required this.orderId}); @override State<SelectSolutionPackageDialog> createState() => _SelectSolutionPackageDialogState(); }
class _SelectSolutionPackageDialogState extends State<SelectSolutionPackageDialog> {
  late final String _factoryId; String? _shipmentId; late Future<List<SolutionShipmentModel>> _shipmentsFuture; List<_SourceRow> _rows = [];
  @override void initState() { super.initState(); _factoryId = Provider.of<ShiftProvider>(context, listen: false).currentFactoryId; _shipmentsFuture = _loadShipments(); }
  Future<List<SolutionShipmentModel>> _loadShipments() async { final snap = await FirebaseDatabase.instance.ref('factories/$_factoryId/solutionShipments').get(); final list = <SolutionShipmentModel>[]; if (snap.value is Map) (snap.value as Map).forEach((k, v) { if (v is Map) { final s = SolutionShipmentModel.fromJson(k.toString(), v); if (s.status == SolutionShipmentStatus.completed) list.add(s); } }); list.sort((a, b) => b.entryTime.compareTo(a.entryTime)); return list; }
  Future<List<_SourceRow>> _loadRows(String shipmentId) async { final snap = await FirebaseDatabase.instance.ref('factories/$_factoryId/solutionCages').get(); final rows = <_SourceRow>[]; if (snap.value is Map) (snap.value as Map).forEach((k, v) { if (v is Map && _s(v['shipmentId']) == shipmentId) { final cage = SolutionCageModel.fromJson(k.toString(), v); for (var si = 0; si < cage.sectors.length; si++) { final sec = cage.sectors[si]; for (var gi = 0; gi < sec.groups.length; gi++) { final g = sec.groups[gi]; if (g.availableBarCount > 0) rows.add(_SourceRow(cage, si, sec, gi, g)); } } } }); return rows; }
  Future<void> _save(List<_SourceRow> rows) async { final selected = rows.where((r) => (int.tryParse(r.qty.text) ?? 0) > 0).toList(); if (selected.isEmpty) return; for (final r in selected) { final q = int.tryParse(r.qty.text) ?? 0; if (q > r.group.availableBarCount) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('الكمية أكبر من المتاح في ${r.label}'))); return; } } final packageRef = FirebaseDatabase.instance.ref('factories/$_factoryId/packagingPackagesV2').push(); final packageId = packageRef.key ?? DateTime.now().millisecondsSinceEpoch.toString(); final updates = <String, dynamic>{}; updates['factories/$_factoryId/packagingPackagesV2/$packageId'] = PackagingPackageV2(id: packageId, orderId: widget.orderId, factoryId: _factoryId, createdBy: FirebaseAuth.instance.currentUser?.email ?? '').toJson(); for (final r in selected) { final q = int.tryParse(r.qty.text) ?? 0; final itemRef = FirebaseDatabase.instance.ref('factories/$_factoryId/packagingItemsV2').push(); final itemId = itemRef.key ?? DateTime.now().millisecondsSinceEpoch.toString(); updates['factories/$_factoryId/packagingItemsV2/$itemId'] = PackagingItemV2(id: itemId, packageId: packageId, orderId: widget.orderId, factoryId: _factoryId, shipmentId: _shipmentId!, cageId: r.cage.id, sectorIndex: r.sectorIndex, groupIndex: r.groupIndex, profileCode: r.sector.profileCode, designCode: r.sector.designCode, clientCode: r.sector.clientCode, dieName: r.sector.dieName, lengthM: r.group.lengthM, metricWeightKgPerM: r.group.metricWeightKgPerM, barCount: q, solutionType: r.group.solutionType).toJson(); updates['factories/$_factoryId/solutionCages/${r.cage.id}/sectors/${r.sectorIndex}/groups/${r.groupIndex}/packedBarCount'] = r.group.packedBarCount + q; } await FirebaseDatabase.instance.ref().update(updates); if (mounted) Navigator.pop(context); }
  @override Widget build(BuildContext context) { return AlertDialog(title: const Text('اختيار أعواد من شحنة صلادة'), content: SizedBox(width: 520, height: 520, child: FutureBuilder<List<SolutionShipmentModel>>(future: _shipmentsFuture, builder: (context, ss) { if (!ss.hasData) return const Center(child: CircularProgressIndicator()); final shipments = ss.data!; if (shipments.isEmpty) return const Text('لا توجد شحنات منتهية'); if (_shipmentId == null) _shipmentId = shipments.first.id; return Column(children: [DropdownButtonFormField<String>(value: _shipmentId, decoration: const InputDecoration(labelText: 'الشحنة المنتهية'), items: shipments.map((s) => DropdownMenuItem(value: s.id, child: Text('${s.id.substring(0, s.id.length > 6 ? 6 : s.id.length)} - ${s.furnaceName} - ${s.entryTime}'))).toList(), onChanged: (v) => setState(() => _shipmentId = v)), const SizedBox(height: 8), Expanded(child: FutureBuilder<List<_SourceRow>>(future: _loadRows(_shipmentId!), builder: (context, rs) { if (!rs.hasData) return const Center(child: CircularProgressIndicator()); final rows = rs.data!; _rows = rows; if (rows.isEmpty) return const Text('لا يوجد متاح للتغليف'); return ListView(children: rows.map((r) => Row(children: [Expanded(flex: 3, child: Text(r.label)), Expanded(flex: 1, child: TextField(controller: r.qty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'عدد')))])).toList()); }))]); })), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')), FilledButton(onPressed: () async { await _save(_rows); }, child: const Text('حفظ الطرد'))]); }
}

class QualityControlScreen extends StatefulWidget { const QualityControlScreen({super.key}); @override State<QualityControlScreen> createState() => _QualityControlScreenState(); }
class _QualityControlScreenState extends State<QualityControlScreen> {
  late final String _factoryId; @override void initState() { super.initState(); _factoryId = Provider.of<ShiftProvider>(context, listen: false).currentFactoryId; }
  Future<void> _addInspection() async { final code = TextEditingController(); final billets = TextEditingController(); final defective = TextEditingController(); final notes = TextEditingController(); final status = ValueNotifier<QualityStatus>(QualityStatus.accepted); final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('تسجيل فحص قالب'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: code, decoration: const InputDecoration(labelText: 'اكتب كود القالب')), TextField(controller: billets, decoration: const InputDecoration(labelText: 'عدد البليت'), keyboardType: TextInputType.number), ValueListenableBuilder<QualityStatus>(valueListenable: status, builder: (context, v, _) => DropdownButtonFormField<QualityStatus>(value: v, decoration: const InputDecoration(labelText: 'نتيجة الفحص'), items: QualityStatus.values.map((e) => DropdownMenuItem(value: e, child: Text(e.label))).toList(), onChanged: (x) => status.value = x ?? QualityStatus.accepted)), TextField(controller: defective, decoration: const InputDecoration(labelText: 'عدد الأعواد بها مشكلة'), keyboardType: TextInputType.number), TextField(controller: notes, decoration: const InputDecoration(labelText: 'ملاحظات'))])), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('حفظ'))])); if (ok == true) { final template = await DieTracking.findTemplate(_factoryId, [code.text]); if (template == null) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لم يتم العثور على القالب'))); return; } final ref = FirebaseDatabase.instance.ref('factories/$_factoryId/qualityInspections').push(); await ref.set(QualityInspectionModel(id: ref.key ?? '', factoryId: _factoryId, dieAssetId: template.id, dieName: template.name, codesDisplay: '${template.dieCode} | ${template.designCode} | ${template.clientCode}', billetCount: int.tryParse(billets.text) ?? 0, status: status.value, defectiveBarCount: int.tryParse(defective.text) ?? 0, notes: notes.text.trim(), inspectorName: FirebaseAuth.instance.currentUser?.email ?? '').toJson()); } }
  Future<void> _addHardness() async { final shipmentsSnap = await FirebaseDatabase.instance.ref('factories/$_factoryId/solutionShipments').get(); final shipments = <SolutionShipmentModel>[]; if (shipmentsSnap.value is Map) (shipmentsSnap.value as Map).forEach((k, v) { if (v is Map) { final s = SolutionShipmentModel.fromJson(k.toString(), v); if (s.status == SolutionShipmentStatus.completed) shipments.add(s); } }); if (shipments.isEmpty) return; String shipmentId = shipments.first.id; final value = TextEditingController(); final notes = TextEditingController(); final ok = await showDialog<bool>(context: context, builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(title: const Text('قياس صلادة ويبستر'), content: SizedBox(width: 420, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [DropdownButtonFormField<String>(value: shipmentId, decoration: const InputDecoration(labelText: 'الشحنة'), items: shipments.map((s) => DropdownMenuItem(value: s.id, child: Text(s.id.substring(0, s.id.length > 6 ? 6 : s.id.length)))).toList(), onChanged: (v) => setD(() => shipmentId = v ?? shipmentId)), FutureBuilder<List<DropdownMenuItem<String>>>(future: _groupItems(shipmentId), builder: (context, gs) { if (!gs.hasData) return const LinearProgressIndicator(); String? first = gs.data!.isEmpty ? null : (gs.data!.first.value ?? ''); return DropdownButtonFormField<String>(value: _selectedGroupLabel ?? first, decoration: const InputDecoration(labelText: 'القفص/القطاع/الطول'), items: gs.data!, onChanged: (v) => setD(() => _selectedGroupLabel = v)); }), TextField(controller: value, decoration: const InputDecoration(labelText: 'قراءة الويبستر'), keyboardType: TextInputType.number), TextField(controller: notes, decoration: const InputDecoration(labelText: 'ملاحظات'))]))), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('حفظ'))]))); if (ok == true) { final snap = await FirebaseDatabase.instance.ref('factories/$_factoryId/solutionCages').get(); if (snap.value is Map) { for (final entry in (snap.value as Map).entries) { final v = entry.value; if (v is Map && _s(v['shipmentId']) == shipmentId) { final cage = SolutionCageModel.fromJson(entry.key.toString(), v); for (final sec in cage.sectors) { for (final g in sec.groups) { final label = '${cage.cageNumber} - ${sec.profileCode} - ${g.lengthM}م ${g.solutionType}'; if (label == _selectedGroupLabel) { final ref = FirebaseDatabase.instance.ref('factories/$_factoryId/solutionHardnessTests').push(); await ref.set(SolutionHardnessModel(id: ref.key ?? '', factoryId: _factoryId, shipmentId: shipmentId, cageId: cage.id, cageNumber: cage.cageNumber, profileCode: sec.profileCode, groupLabel: label, websterValue: value.text.trim(), notes: notes.text.trim(), inspectorName: FirebaseAuth.instance.currentUser?.email ?? '').toJson()); return; } } } } } } }
  }
  String? _selectedGroupLabel; Future<List<DropdownMenuItem<String>>> _groupItems(String shipmentId) async { final snap = await FirebaseDatabase.instance.ref('factories/$_factoryId/solutionCages').get(); final items = <DropdownMenuItem<String>>[]; if (snap.value is Map) (snap.value as Map).forEach((k, v) { if (v is Map && _s(v['shipmentId']) == shipmentId) { final cage = SolutionCageModel.fromJson(k.toString(), v); for (final sec in cage.sectors) { for (final g in sec.groups) { final label = '${cage.cageNumber} - ${sec.profileCode} - ${g.lengthM}م ${g.solutionType}'; items.add(DropdownMenuItem(value: label, child: Text(label))); } } } }); _selectedGroupLabel = items.isEmpty ? null : items.first.value; return items; }
  @override Widget build(BuildContext context) { return DefaultTabController(length: 2, child: Scaffold(appBar: AppBar(title: const Text('🧪 الجودة / QC'), bottom: const TabBar(tabs: [Tab(text: 'فحص القوالب'), Tab(text: 'قياس الصلادة')])), floatingActionButton: Builder(builder: (context) => FloatingActionButton.extended(onPressed: () { final idx = DefaultTabController.of(context).index; if (idx == 0) _addInspection(); else _addHardness(); }, icon: const Icon(Icons.add), label: const Text('إضافة'))), body: TabBarView(children: [StreamBuilder<DatabaseEvent>(stream: FirebaseDatabase.instance.ref('factories/$_factoryId/qualityInspections').onValue, builder: (context, snap) { final val = snap.data?.snapshot.value; final list = <QualityInspectionModel>[]; if (val is Map) val.forEach((k, v) { if (v is Map) list.add(QualityInspectionModel.fromJson(k.toString(), v)); }); list.sort((a, b) => b.createdAt.compareTo(a.createdAt)); if (list.isEmpty) return const Center(child: Text('لا توجد فحوصات')); return ListView.builder(padding: const EdgeInsets.all(12), itemCount: list.length, itemBuilder: (context, i) { final q = list[i]; return Card(child: ListTile(leading: Icon(Icons.verified, color: q.status == QualityStatus.accepted ? Colors.green : q.status == QualityStatus.rejected ? Colors.red : Colors.orange), title: Text(q.dieName), subtitle: Text('${q.codesDisplay}\nبليت: ${q.billetCount} • الحالة: ${q.status.label} • أعواد بها مشكلة: ${q.defectiveBarCount}\n${q.notes}'), isThreeLine: true)); }); }), StreamBuilder<DatabaseEvent>(stream: FirebaseDatabase.instance.ref('factories/$_factoryId/solutionHardnessTests').onValue, builder: (context, snap) { final val = snap.data?.snapshot.value; final list = <Map<String, String>>[]; if (val is Map) val.forEach((k, v) { if (v is Map) list.add({'shipment': _s(v['shipmentId']), 'label': _s(v['groupLabel']), 'value': _s(v['websterValue']), 'by': _s(v['inspectorName']), 'at': _s(v['createdAt'])}); }); if (list.isEmpty) return const Center(child: Text('لا توجد قياسات صلادة')); return ListView.builder(padding: const EdgeInsets.all(12), itemCount: list.length, itemBuilder: (context, i) { final e = list[i]; return Card(child: ListTile(leading: const Icon(Icons.speed), title: Text(e['label'] ?? ''), subtitle: Text('شحنة: ${e['shipment']}\nويبستر: ${e['value']} • بواسطة: ${e['by']} • ${e['at']}'), isThreeLine: true)); }); })]))); }
}