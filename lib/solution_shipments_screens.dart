import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'services.dart';
import 'package:intl/intl.dart';
import 'app_localization.dart';
import 'planning_screen.dart';

String _s(dynamic v, [String fallback = '']) => v?.toString() ?? fallback;
int _i(dynamic v, [int fallback = 0]) => v is int ? v : int.tryParse(v?.toString() ?? '') ?? fallback;
double _d(dynamic v, [double fallback = 0]) => v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? fallback;
DateTime _dt(dynamic v, [DateTime? fallback]) => DateTime.tryParse(v?.toString() ?? '') ?? fallback ?? DateTime.now();

String _fmtRemaining(DateTime t) {
  final d = t.difference(DateTime.now());
  if (d.isNegative) return LocaleProvider.currentLanguage == AppLanguage.ar ? '0د' : '0m';
  final h = d.inHours, m = d.inMinutes % 60;
  if (LocaleProvider.currentLanguage == AppLanguage.ar) return h > 0 ? '${h}س ${m}د' : '${m}د';
  return h > 0 ? '${h}h ${m}m' : '${m}m';
}
String _sol(dynamic v) => v?.toString().trim().isNotEmpty == true ? v.toString().trim().toUpperCase() : 'T5';

enum SolutionShipmentStatus { loading, heating, soaking, cooling, completed }

extension SolutionShipmentStatusX on SolutionShipmentStatus {
  String get label {
    switch (this) {
      case SolutionShipmentStatus.loading: return AppStrings.trStatic('st_loading');
      case SolutionShipmentStatus.heating: return AppStrings.trStatic('st_heating');
      case SolutionShipmentStatus.soaking: return AppStrings.trStatic('st_soaking');
      case SolutionShipmentStatus.cooling: return AppStrings.trStatic('st_cooling');
      case SolutionShipmentStatus.completed: return AppStrings.trStatic('st_completed');
    }
  }
}

class SolutionBarGroupModel {
  final double lengthM; final int barCount; final double metricWeightKgPerM; final double totalWeightKg; final String solutionType; final int packedBarCount;
  SolutionBarGroupModel({required this.lengthM, required this.barCount, required this.metricWeightKgPerM, required this.solutionType, this.packedBarCount = 0}) : totalWeightKg = lengthM * barCount * metricWeightKgPerM;
  int get availableBarCount => barCount - packedBarCount;
  factory SolutionBarGroupModel.fromJson(Map<dynamic, dynamic> json) => SolutionBarGroupModel(lengthM: _d(json['lengthM']), barCount: _i(json['barCount']), metricWeightKgPerM: _d(json['metricWeightKgPerM']), solutionType: _sol(json['solutionType']), packedBarCount: _i(json['packedBarCount']));
  Map<String, dynamic> toJson() => {'lengthM': lengthM, 'barCount': barCount, 'metricWeightKgPerM': metricWeightKgPerM, 'totalWeightKg': totalWeightKg, 'solutionType': solutionType, 'packedBarCount': packedBarCount};
}

class SolutionCageSectorModel {
  final String profileCode; final String designCode; final String clientCode; final String dieName; final List<SolutionBarGroupModel> groups;
  SolutionCageSectorModel({this.profileCode = '', this.designCode = '', this.clientCode = '', this.dieName = '', this.groups = const []});
  factory SolutionCageSectorModel.fromJson(Map<dynamic, dynamic> json) {
    final list = <SolutionBarGroupModel>[];
    final g = json['groups'];
    if (g is List) { for (final e in g) { if (e is Map) list.add(SolutionBarGroupModel.fromJson(e)); } }
    return SolutionCageSectorModel(profileCode: _s(json['profileCode']), designCode: _s(json['designCode']), clientCode: _s(json['clientCode']), dieName: _s(json['dieName']), groups: list);
  }
  int get totalBars => groups.fold<int>(0, (sum, g) => sum + g.barCount);
  double get totalWeightKg => groups.fold<double>(0, (sum, g) => sum + g.totalWeightKg);
  String get solutionTypes => groups.map((g) => g.solutionType).toSet().join(' / ');
  Map<String, dynamic> toJson() => {'profileCode': profileCode, 'designCode': designCode, 'clientCode': clientCode, 'dieName': dieName, 'groups': groups.map((e) => e.toJson()).toList(), 'totalBars': totalBars, 'totalWeightKg': totalWeightKg};
}

class SolutionCageModel {
  final String id; final String shipmentId; final String cageNumber; final DateTime entryTime; final DateTime? exitTime; final List<SolutionCageSectorModel> sectors;
  SolutionCageModel({required this.id, required this.shipmentId, required this.cageNumber, DateTime? entryTime, this.exitTime, this.sectors = const []}) : entryTime = entryTime ?? DateTime.now();
  factory SolutionCageModel.fromJson(String id, Map<dynamic, dynamic> json) {
    final list = <SolutionCageSectorModel>[];
    final s = json['sectors'];
    if (s is List) { for (final e in s) { if (e is Map) list.add(SolutionCageSectorModel.fromJson(e)); } }
    return SolutionCageModel(id: id, shipmentId: _s(json['shipmentId']), cageNumber: _s(json['cageNumber'], id), entryTime: _dt(json['entryTime']), exitTime: json['exitTime'] == null ? null : _dt(json['exitTime']), sectors: list);
  }
  int get totalBars => sectors.fold<int>(0, (sum, s) => sum + s.totalBars);
  double get totalWeightKg => sectors.fold<double>(0, (sum, s) => sum + s.totalWeightKg);
  Map<String, dynamic> toJson() => {'shipmentId': shipmentId, 'cageNumber': cageNumber, 'entryTime': entryTime.toIso8601String(), 'exitTime': exitTime?.toIso8601String(), 'sectors': sectors.map((e) => e.toJson()).toList(), 'totalBars': totalBars, 'totalWeightKg': totalWeightKg};
}

class SolutionShipmentModel {
  final String id; final String furnaceId; final String furnaceName; final String factoryId; final String alloy; final SolutionShipmentStatus status; final DateTime entryTime; final DateTime? exitTime; final double targetTemperature; final double actualTemperature; final String notes;
  final DateTime? scheduledStartTime;
  final DateTime? actualStartTime;
  SolutionShipmentModel({required this.id, required this.furnaceId, this.furnaceName = '', required this.factoryId, this.alloy = '6063', this.status = SolutionShipmentStatus.loading, DateTime? entryTime, this.exitTime, this.targetTemperature = 0, this.actualTemperature = 0, this.notes = '', this.scheduledStartTime, this.actualStartTime}) : entryTime = entryTime ?? DateTime.now();
  factory SolutionShipmentModel.fromJson(String id, Map<dynamic, dynamic> json) => SolutionShipmentModel(id: id, furnaceId: _s(json['furnaceId']), furnaceName: _s(json['furnaceName']), factoryId: _s(json['factoryId']), alloy: _s(json['alloy'], '6063'), status: SolutionShipmentStatus.values.firstWhere((e) => e.name == _s(json['status']), orElse: () => SolutionShipmentStatus.loading), entryTime: _dt(json['entryTime']), exitTime: json['exitTime'] == null ? null : _dt(json['exitTime']), targetTemperature: _d(json['targetTemperature']), actualTemperature: _d(json['actualTemperature']), notes: _s(json['notes']), scheduledStartTime: json['scheduledStartTime'] == null ? null : _dt(json['scheduledStartTime']), actualStartTime: json['actualStartTime'] == null ? null : _dt(json['actualStartTime']));
  Map<String, dynamic> toJson() => {'furnaceId': furnaceId, 'furnaceName': furnaceName, 'factoryId': factoryId, 'alloy': alloy, 'status': status.name, 'entryTime': entryTime.toIso8601String(), 'exitTime': exitTime?.toIso8601String(), 'targetTemperature': targetTemperature, 'actualTemperature': actualTemperature, 'notes': notes, 'scheduledStartTime': scheduledStartTime?.toIso8601String(), 'actualStartTime': actualStartTime?.toIso8601String()};
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
      final newFurnaceRef = _furnacesRef.push();
      await newFurnaceRef.set({
        'name': 'فرن صلادة رئيسي',
        'factoryId': _factoryId,
        'isActive': true,
        'status': 'idle',
        'createdAt': DateTime.now().toIso8601String(),
      });
      furnaces.add(MapEntry(newFurnaceRef.key!, 'فرن صلادة رئيسي'));
    }

    String furnaceId = furnaces.first.key;
    final alloy = TextEditingController(text: '6063');
    final target = TextEditingController();
    final actual = TextEditingController();
    
    DateTime? pickedStart;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDlg) => AlertDialog(
          title: Text(context.tr('start_shipment_title')),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              value: furnaceId,
              decoration: InputDecoration(labelText: context.tr('furnace_word')),
              items: furnaces.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
              onChanged: (v) => setDlg(() => furnaceId = v ?? furnaceId)
            ),
            TextField(controller: alloy, decoration: InputDecoration(labelText: context.tr('alloy_word'))),
            TextField(controller: target, decoration: InputDecoration(labelText: context.tr('target_temp_word')), keyboardType: TextInputType.number),
            TextField(controller: actual, decoration: InputDecoration(labelText: context.tr('actual_temp_word')), keyboardType: TextInputType.number),
            ListTile(
              leading: const Icon(Icons.schedule, color: Colors.deepOrange),
              title: Text(pickedStart == null
                  ? '${context.tr('scheduled_start_label')}: ${context.tr('no_scheduled')}'
                  : '${context.tr('scheduled_start_label')}: ${DateFormat('yyyy-MM-dd HH:mm').format(pickedStart!)}'),
              trailing: const Icon(Icons.edit_calendar),
              onTap: () async {
                final d = await showDatePicker(context: context, initialDate: DateTime.now().add(const Duration(hours: 2)), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 30)));
                if (d == null) return;
                final t = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 8, minute: 0));
                if (t == null) return;
                setDlg(() => pickedStart = DateTime(d.year, d.month, d.day, t.hour, t.minute));
              },
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.tr('cancel'))), 
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(context.tr('start_shipment_btn')))
          ],
        ),
      ),
    );
    
    if (ok == true) {
      final ref = _shipmentsRef.push();
      await ref.set(SolutionShipmentModel(
        id: ref.key ?? '', 
        furnaceId: furnaceId, 
        furnaceName: furnaces.firstWhere((e) => e.key == furnaceId, orElse: () => furnaces.first).value, 
        factoryId: _factoryId, 
        alloy: alloy.text.trim(), 
        targetTemperature: double.tryParse(target.text) ?? 0, 
        actualTemperature: double.tryParse(actual.text) ?? 0,
        scheduledStartTime: pickedStart
      ).toJson());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('solution_shipments_title'))),
      floatingActionButton: FloatingActionButton.extended(onPressed: _addShipment, icon: const Icon(Icons.add), label: Text(context.tr('new_shipment'))),
      body: StreamBuilder<DatabaseEvent>(stream: _shipmentsRef.onValue, builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final val = snapshot.data!.snapshot.value;
        final shipments = <SolutionShipmentModel>[];
        if (val is Map) val.forEach((key, value) { if (value is Map) shipments.add(SolutionShipmentModel.fromJson(key.toString(), value)); });
        shipments.sort((a, b) => b.entryTime.compareTo(a.entryTime));
        if (shipments.isEmpty) return Center(child: Text(context.tr('no_shipments')));
        return ListView.builder(padding: const EdgeInsets.all(12), itemCount: shipments.length, itemBuilder: (context, index) {
          final s = shipments[index];
          return Card(child: ListTile(leading: const Icon(Icons.heat_pump, color: Colors.deepOrange), title: Text('${context.tr('shipment_word')} ${s.id.substring(0, s.id.length > 6 ? 6 : s.id.length)} - ${s.furnaceName}'), subtitle: Text('${s.status.label}\n${context.tr('alloy_word')}: ${s.alloy} • ${context.tr('target_temp_word')}: ${s.targetTemperature}°\n'
              '${s.actualStartTime != null
                  ? context.trP('started_at', {'v': DateFormat('MM-dd HH:mm').format(s.actualStartTime!)})
                  : s.scheduledStartTime != null
                      ? context.trP('starts_in', {'v': _fmtRemaining(s.scheduledStartTime!)})
                      : "${context.tr('entry_label')}: ${DateFormat('MM-dd HH:mm').format(s.entryTime)}"}'), isThreeLine: true, trailing: const Icon(Icons.chevron_left), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SolutionShipmentDetailScreen(shipment: s)))));
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

  Future<void> _startShipmentNow(String shipmentId) async {
    await _shipmentRef.update({
      'actualStartTime': DateTime.now().toIso8601String(),
      'status': SolutionShipmentStatus.heating.name,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('shipment_started_msg'))));
    }
  }

  Future<void> _addCage() async {
    final cageNo = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: Text(context.tr('add_cage_dialog_title')), content: TextField(controller: cageNo, decoration: InputDecoration(labelText: context.tr('cage_number_label'))), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.tr('cancel'))), FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(context.tr('add_word')))]));
    if (ok == true && cageNo.text.trim().isNotEmpty) {
      final ref = _cagesRef.push();
      await ref.set(SolutionCageModel(id: ref.key ?? '', shipmentId: widget.shipment.id, cageNumber: cageNo.text.trim()).toJson());
    }
  }

  Future<void> _addSector(SolutionCageModel cage) async {
    final sector = await showDialog<SolutionCageSectorModel>(
      context: context, 
      builder: (context) => _AddSolutionSectorDialog(existingCage: cage),
    );
    if (sector != null) {
      final updated = SolutionCageModel(id: cage.id, shipmentId: cage.shipmentId, cageNumber: cage.cageNumber, entryTime: cage.entryTime, exitTime: cage.exitTime, sectors: [...cage.sectors, sector]);
      await _cagesRef.child(cage.id).set(updated.toJson());
    }
  }

  Future<void> _excludeCage(SolutionCageModel cage) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ إزالة القفص من الشحنة'),
        content: const Text('هل تريد إزالة هذا القفص من الشحنة الحالية؟\n(سيظل محفوظاً في قاعدة البيانات ويمكنك إضافته لشحنة أخرى)'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('إزالة')),
        ],
      ),
    );
    if (confirmed == true) {
      await _cagesRef.child(cage.id).update({'shipmentId': ''}); 
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم إزالة القفص من الشحنة، ويمكنك إضافته لاحقاً')));
      }
    }
  }

  Future<void> _endShipment() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد إنهاء الشحنة'),
        content: const Text('هل أنت متأكد من إنهاء هذه الشحنة؟\nستنتقل الشحنة إلى قسم التغليف.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('إنهاء')),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _shipmentRef.update({
          'status': SolutionShipmentStatus.completed.name,
          'exitTime': DateTime.now().toIso8601String(),
        });

        final packagingRef = FirebaseDatabase.instance.ref('factories/$_factoryId/packagingOrdersV2').push();
        await packagingRef.set({
          'factoryId': _factoryId,
          'customerName': 'شحنة صلادة ${widget.shipment.id.substring(0, 6)}',
          'orderNumber': 'SOL-${widget.shipment.id.substring(0, 6)}',
          'status': 'new',
          'createdAt': DateTime.now().toIso8601String(),
          'createdBy': FirebaseAuth.instance.currentUser?.email ?? '',
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم إنهاء الشحنة وإرسالها للتغليف')));
          Navigator.pop(context); 
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ خطأ: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${context.tr('solution_shipments_title')} - ${widget.shipment.id.substring(0, widget.shipment.id.length > 6 ? 6 : widget.shipment.id.length)}')),
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
          Card(child: ListTile(leading: const Icon(Icons.summarize, color: Colors.green), title: Text(context.tr('shipment_summary')), subtitle: Text('${context.tr('cages_count_label')}: ${cages.length}\n${context.tr('total_bars_label')}: $totalBars\n${context.tr('total_weight_label')}: ${totalWeight.toStringAsFixed(3)} ${context.tr('weight_kg_hint')}\n${context.tr('alloy_word')}: ${widget.shipment.alloy} • ${context.tr('target_temp_word')}: ${widget.shipment.targetTemperature}° • ${widget.shipment.status.label}\n'
                '${widget.shipment.actualStartTime != null ? context.trP('started_at', {'v': DateFormat('yyyy-MM-dd HH:mm').format(widget.shipment.actualStartTime!)}) : (widget.shipment.scheduledStartTime != null ? '${context.tr('scheduled_start_label')}: ${DateFormat('yyyy-MM-dd HH:mm').format(widget.shipment.scheduledStartTime!)}' : "${context.tr('entry_label')}: ${DateFormat('yyyy-MM-dd HH:mm').format(widget.shipment.entryTime)}")}'), isThreeLine: true)),
          Row(children: [
              if (widget.shipment.actualStartTime == null)
                Expanded(child: ElevatedButton.icon(
                  onPressed: () => _startShipmentNow(widget.shipment.id),
                  icon: const Icon(Icons.play_arrow, color: Colors.green),
                  label: Text(context.tr('start_now')),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade50),
                )),
              if (widget.shipment.actualStartTime == null) const SizedBox(width: 8),
              Expanded(child: ElevatedButton.icon(onPressed: _addCage, icon: const Icon(Icons.add_box), label: Text(context.tr('add_cage_btn')))),
              const SizedBox(width: 8),
              if (widget.shipment.exitTime == null) Expanded(child: OutlinedButton.icon(onPressed: _endShipment, icon: const Icon(Icons.stop), label: Text(context.tr('end_shipment_btn'))))
            ]),
          const SizedBox(height: 8),
          ...cages.map((cage) => Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('${context.tr('cage_word')} ${cage.cageNumber} • ${cage.totalBars} ${context.tr('bars_count_word')} • ${cage.totalWeightKg.toStringAsFixed(3)} ${context.tr('weight_kg_hint')}', style: const TextStyle(fontWeight: FontWeight.bold))),
              TextButton.icon(onPressed: () => _addSector(cage), icon: const Icon(Icons.add), label: Text(context.tr('add_sector_btn'))),
              if (cage.exitTime == null) IconButton(onPressed: () => _excludeCage(cage), icon: const Icon(Icons.delete_outline, color: Colors.red), tooltip: 'إزالة القفص من الشحنة'),
            ]),
            ...cage.sectors.map((sector) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Container(width: double.infinity, padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)), child: Text('${context.tr('add_sector_btn')}: ${sector.dieName.isNotEmpty ? sector.dieName : sector.profileCode}\n${context.tr('sector_codes_label')}: ${sector.profileCode} | ${sector.designCode} | ${sector.clientCode}\n${context.tr('temper_word2')}: ${sector.solutionTypes} • ${context.tr('bars_count_word')}: ${sector.totalBars} • ${context.tr('weight_kg_hint')}: ${sector.totalWeightKg.toStringAsFixed(3)}')))),
          ]))))
        ]);
      }),
    );
  }
}

class _AddSolutionSectorDialog extends StatefulWidget {
  final SolutionCageModel? existingCage;
  const _AddSolutionSectorDialog({this.existingCage});
  @override
  State<_AddSolutionSectorDialog> createState() => _AddSolutionSectorDialogState();
}

class _AddSolutionSectorDialogState extends State<_AddSolutionSectorDialog> {
  final profile = TextEditingController();
  final design = TextEditingController();
  final client = TextEditingController();
  final dieName = TextEditingController();
  final version = TextEditingController();
  
  final length = TextEditingController();
  final count = TextEditingController();
  final metric = TextEditingController();
  final barWeight = TextEditingController();
  final scrapCount = TextEditingController();
  String solutionType = 'T5';

  bool _isSearching = false;
  Timer? _debounce;
  double _currentCageWeight = 0;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    profile.addListener(_onProfileChanged);
    length.addListener(_onLengthChanged);
    metric.addListener(_onMetricChanged);
    barWeight.addListener(_onBarWeightChanged);
    if (widget.existingCage != null) _currentCageWeight = widget.existingCage!.totalWeightKg;
  }

  @override
  void dispose() {
    profile.removeListener(_onProfileChanged);
    length.removeListener(_onLengthChanged);
    metric.removeListener(_onMetricChanged);
    barWeight.removeListener(_onBarWeightChanged);
    _debounce?.cancel();
    profile.dispose(); design.dispose(); client.dispose(); dieName.dispose(); version.dispose();
    length.dispose(); count.dispose(); metric.dispose(); barWeight.dispose(); scrapCount.dispose();
    super.dispose();
  }

  double _getLengthMeters() {
    final val = double.tryParse(length.text) ?? 0;
    if (val > 100) return val / 1000;
    return val;
  }

  void _onLengthChanged() {
    if (_isUpdating) return;
    _isUpdating = true;
    final l = _getLengthMeters();
    final m = double.tryParse(metric.text) ?? 0;
    final bw = double.tryParse(barWeight.text) ?? 0;
    if (m > 0 && l > 0) barWeight.text = (m * l).toStringAsFixed(3);
    else if (bw > 0 && l > 0) metric.text = (bw / l).toStringAsFixed(3);
    _isUpdating = false;
    setState(() {});
  }

  void _onMetricChanged() {
    if (_isUpdating) return;
    _isUpdating = true;
    final l = _getLengthMeters();
    final m = double.tryParse(metric.text) ?? 0;
    if (l > 0 && m > 0) barWeight.text = (m * l).toStringAsFixed(3);
    _isUpdating = false;
    setState(() {});
  }

  void _onBarWeightChanged() {
    if (_isUpdating) return;
    _isUpdating = true;
    final l = _getLengthMeters();
    final bw = double.tryParse(barWeight.text) ?? 0;
    if (l > 0 && bw > 0) metric.text = (bw / l).toStringAsFixed(3);
    _isUpdating = false;
    setState(() {});
  }

  void _onProfileChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      if (profile.text.trim().length >= 3) _autoFill();
    });
  }

  Future<void> _autoFill() async {
    setState(() => _isSearching = true);
    try {
      final factoryId = Provider.of<ShiftProvider>(context, listen: false).currentFactoryId;
      final templates = await Provider.of<ShiftProvider>(context, listen: false).service.getDieTemplates(factoryId);
      final query = profile.text.trim().toLowerCase();
      final match = templates.where((t) => 
        t.dieCode.toLowerCase() == query || 
        t.designCode.toLowerCase() == query || 
        t.clientCode.toLowerCase() == query ||
        t.fullCode.toLowerCase() == query
      ).firstOrNull;
      if (match != null && mounted) {
        setState(() {
          profile.text = match.dieCode; design.text = match.designCode; client.text = match.clientCode; dieName.text = match.name;
          if (match.version != null) version.text = match.version!;
        });
      }
    } finally { if (mounted) setState(() => _isSearching = false); }
  }

  @override
  Widget build(BuildContext context) {
    final inputDecoration = InputDecoration(border: const OutlineInputBorder(), isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8));
    final c = int.tryParse(count.text) ?? 0;
    final l = _getLengthMeters();
    final m = double.tryParse(metric.text) ?? 0;
    final totalCageWeight = _currentCageWeight + (c * l * m);

    return AlertDialog(
      title: Row(children: [
        Text(context.tr('add_sector_dialog_title')),
        if (_isSearching) ...[const SizedBox(width: 8), const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))],
      ]),
      content: SizedBox(
        width: 550,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('⚖️ الوزن الإجمالي للقفص:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('${totalCageWeight.toStringAsFixed(3)} كجم', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
              ]),
            ),
            const SizedBox(height: 12),
            TextField(controller: profile, decoration: inputDecoration.copyWith(labelText: context.tr('sector_search_hint'), suffixIcon: const Icon(Icons.search, size: 16))),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: design, decoration: inputDecoration.copyWith(labelText: context.tr('die_design_code_label')))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: client, decoration: inputDecoration.copyWith(labelText: context.tr('die_client_code_label')))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: version, decoration: inputDecoration.copyWith(labelText: 'رقم النسخة'))),
            ]),
            const SizedBox(height: 8),
            TextField(controller: dieName, decoration: inputDecoration.copyWith(labelText: context.tr('die_name_optional'))),
            const Divider(height: 24),
            Row(children: [
              Expanded(child: TextField(controller: length, decoration: inputDecoration.copyWith(labelText: context.tr('length_m_label'), hintText: '6 أو 6000'), keyboardType: TextInputType.number)),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: count, decoration: inputDecoration.copyWith(labelText: context.tr('count_label')), keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: metric, decoration: inputDecoration.copyWith(labelText: context.tr('kg_per_m_label')), keyboardType: TextInputType.number)),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: barWeight, decoration: inputDecoration.copyWith(labelText: 'وزن العود (كجم)'), keyboardType: TextInputType.number)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: scrapCount, decoration: inputDecoration.copyWith(labelText: 'عدد السكراب (اختياري)'), keyboardType: TextInputType.number)),
              const SizedBox(width: 8),
              Expanded(child: DropdownButtonFormField<String>(
                value: solutionType, 
                decoration: inputDecoration.copyWith(labelText: context.tr('temper_label')),
                items: const ['T4', 'T5', 'T6', 'أخرى'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), 
                onChanged: (v) => setState(() => solutionType = v ?? 'T5')
              )),
            ]),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final groups = (double.tryParse(length.text) ?? 0) > 0 && (int.tryParse(count.text) ?? 0) > 0 && (double.tryParse(metric.text) ?? 0) > 0 
                      ? [SolutionBarGroupModel(lengthM: _getLengthMeters(), barCount: int.parse(count.text), metricWeightKgPerM: double.parse(metric.text), solutionType: solutionType)]
                      : <SolutionBarGroupModel>[];
                  if (groups.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ املأ بيانات القطاع أولاً'))); return; }
                  final factoryId = Provider.of<ShiftProvider>(context, listen: false).currentFactoryId;
                  await PlanningService.deductFromProduction(factoryId: factoryId, dieName: profile.text.trim(), barLengthM: groups.first.lengthM, producedBars: groups.first.barCount);
                  if (mounted) Navigator.pop(context, SolutionCageSectorModel(profileCode: profile.text.trim(), designCode: design.text.trim(), clientCode: client.text.trim(), dieName: dieName.text.trim(), groups: groups));
                },
                icon: const Icon(Icons.add_box, size: 18),
                label: const Text('حفظ هذا القطاع وإضافة قطاع آخر'),
              ),
            ),
          ]),
        )
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(context.tr('cancel'))), 
        FilledButton(
          onPressed: () async {
            final groups = (double.tryParse(length.text) ?? 0) > 0 && (int.tryParse(count.text) ?? 0) > 0 && (double.tryParse(metric.text) ?? 0) > 0 
                ? [SolutionBarGroupModel(lengthM: _getLengthMeters(), barCount: int.parse(count.text), metricWeightKgPerM: double.parse(metric.text), solutionType: solutionType)]
                : <SolutionBarGroupModel>[];
            if (groups.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ املأ بيانات القطاع أولاً'))); return; }
            final factoryId = Provider.of<ShiftProvider>(context, listen: false).currentFactoryId;
            final totalScrapBars = int.tryParse(scrapCount.text) ?? 0;
            final totalGoodBars = groups.fold<int>(0, (sum, g) => sum + g.barCount);
            if (totalGoodBars > 0) await PlanningService.deductFromProduction(factoryId: factoryId, dieName: profile.text.trim(), barLengthM: groups.first.lengthM, producedBars: totalGoodBars);
            if (totalScrapBars > 0) await PlanningService.deductFromProduction(factoryId: factoryId, dieName: profile.text.trim(), barLengthM: groups.first.lengthM, producedBars: totalScrapBars);
            if (mounted) Navigator.pop(context, SolutionCageSectorModel(profileCode: profile.text.trim(), designCode: design.text.trim(), clientCode: client.text.trim(), dieName: dieName.text.trim(), groups: groups));
          }, 
          child: Text(context.tr('save_word'))
        )
      ],
    );
  }
}