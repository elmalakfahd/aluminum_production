
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'services.dart';

// ============================================================
// 🧪 نماذج فرن الصلادة والتغليف
// ============================================================

enum SolutionFurnaceStatus { idle, loading, heating, soaking, cooling, completed, hold }

enum SolutionCageStatus { waiting, insideSolution, completed, transferredToPackaging, stored, delivered }

enum PackagingOrderStatus { newOrder, packing, completed, movedToWarehouse, delivered, cancelled }

enum PackageBundleStatus { packed, movedToWarehouse, delivered, returned }

String _s(dynamic v, [String fallback = '']) => v?.toString() ?? fallback;
int _i(dynamic v, [int fallback = 0]) => v is int ? v : int.tryParse(v?.toString() ?? '') ?? fallback;
double _d(dynamic v, [double fallback = 0]) => v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? fallback;
bool _b(dynamic v, [bool fallback = false]) => v is bool ? v : v?.toString() == 'true';
DateTime _dt(dynamic v, [DateTime? fallback]) {
  if (v == null) return fallback ?? DateTime.now();
  return DateTime.tryParse(v.toString()) ?? fallback ?? DateTime.now();
}
List<String> _strList(dynamic v) {
  if (v is List) return v.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
  if (v is String && v.trim().isNotEmpty) return v.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  return const [];
}

extension SolutionFurnaceStatusX on SolutionFurnaceStatus {
  String get label {
    switch (this) {
      case SolutionFurnaceStatus.idle: return 'فاضي';
      case SolutionFurnaceStatus.loading: return 'تحميل أقفاص';
      case SolutionFurnaceStatus.heating: return 'تسخين';
      case SolutionFurnaceStatus.soaking: return 'نقع/صلادة';
      case SolutionFurnaceStatus.cooling: return 'تبريد';
      case SolutionFurnaceStatus.completed: return 'انتهت الدورة';
      case SolutionFurnaceStatus.hold: return 'متوقف';
    }
  }
}

extension SolutionCageStatusX on SolutionCageStatus {
  String get label {
    switch (this) {
      case SolutionCageStatus.waiting: return 'بانتظار الدخول';
      case SolutionCageStatus.insideSolution: return 'داخل فرن الصلادة';
      case SolutionCageStatus.completed: return 'تمت الصلادة';
      case SolutionCageStatus.transferredToPackaging: return 'انتقل للتغليف';
      case SolutionCageStatus.stored: return 'مخزن';
      case SolutionCageStatus.delivered: return 'تم التسليم';
    }
  }
}

extension PackagingOrderStatusX on PackagingOrderStatus {
  String get label {
    switch (this) {
      case PackagingOrderStatus.newOrder: return 'جديد';
      case PackagingOrderStatus.packing: return 'قيد التغليف';
      case PackagingOrderStatus.completed: return 'اكتمل التغليف';
      case PackagingOrderStatus.movedToWarehouse: return 'انتقل للمخزن';
      case PackagingOrderStatus.delivered: return 'تم التسليم';
      case PackagingOrderStatus.cancelled: return 'ملغي';
    }
  }
}

extension PackageBundleStatusX on PackageBundleStatus {
  String get label {
    switch (this) {
      case PackageBundleStatus.packed: return 'مغلف';
      case PackageBundleStatus.movedToWarehouse: return 'في المخزن';
      case PackageBundleStatus.delivered: return 'تم التسليم';
      case PackageBundleStatus.returned: return 'مرتجع';
    }
  }
}

T _enumFromName<T extends Enum>(List<T> values, dynamic name, T fallback) {
  final n = name?.toString();
  for (final v in values) {
    if (v.name == n) return v;
  }
  return fallback;
}

class SolutionFurnaceModel {
  final String id;
  final String name;
  final String factoryId;
  final bool isActive;
  final double targetTemperature;
  final double currentTemperature;
  final SolutionFurnaceStatus status;
  final DateTime createdAt;

  SolutionFurnaceModel({
    required this.id,
    required this.name,
    required this.factoryId,
    this.isActive = true,
    this.targetTemperature = 0,
    this.currentTemperature = 0,
    this.status = SolutionFurnaceStatus.idle,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory SolutionFurnaceModel.fromJson(String id, Map<dynamic, dynamic> json) => SolutionFurnaceModel(
        id: id,
        name: _s(json['name'], 'فرن صلادة'),
        factoryId: _s(json['factoryId']),
        isActive: json.containsKey('isActive') ? _b(json['isActive'], true) : true,
        targetTemperature: _d(json['targetTemperature']),
        currentTemperature: _d(json['currentTemperature']),
        status: _enumFromName(SolutionFurnaceStatus.values, json['status'], SolutionFurnaceStatus.idle),
        createdAt: _dt(json['createdAt']),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'factoryId': factoryId,
        'isActive': isActive,
        'targetTemperature': targetTemperature,
        'currentTemperature': currentTemperature,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
      };

  SolutionFurnaceModel copyWith({
    String? name,
    bool? isActive,
    double? targetTemperature,
    double? currentTemperature,
    SolutionFurnaceStatus? status,
  }) =>
      SolutionFurnaceModel(
        id: id,
        name: name ?? this.name,
        factoryId: factoryId,
        isActive: isActive ?? this.isActive,
        targetTemperature: targetTemperature ?? this.targetTemperature,
        currentTemperature: currentTemperature ?? this.currentTemperature,
        status: status ?? this.status,
        createdAt: createdAt,
      );
}

class SolutionCycleModel {
  final String id;
  final String furnaceId;
  final String factoryId;
  final SolutionFurnaceStatus status;
  final DateTime startedAt;
  final DateTime? endedAt;
  final double targetTemperature;
  final double soakMinutes;
  final String supervisorId;
  final String supervisorName;
  final String notes;

  SolutionCycleModel({
    required this.id,
    required this.furnaceId,
    required this.factoryId,
    this.status = SolutionFurnaceStatus.heating,
    DateTime? startedAt,
    this.endedAt,
    this.targetTemperature = 0,
    this.soakMinutes = 0,
    this.supervisorId = '',
    this.supervisorName = '',
    this.notes = '',
  }) : startedAt = startedAt ?? DateTime.now();

  factory SolutionCycleModel.fromJson(String id, Map<dynamic, dynamic> json) => SolutionCycleModel(
        id: id,
        furnaceId: _s(json['furnaceId']),
        factoryId: _s(json['factoryId']),
        status: _enumFromName(SolutionFurnaceStatus.values, json['status'], SolutionFurnaceStatus.heating),
        startedAt: _dt(json['startedAt']),
        endedAt: json['endedAt'] == null ? null : _dt(json['endedAt']),
        targetTemperature: _d(json['targetTemperature']),
        soakMinutes: _d(json['soakMinutes']),
        supervisorId: _s(json['supervisorId']),
        supervisorName: _s(json['supervisorName']),
        notes: _s(json['notes']),
      );

  Map<String, dynamic> toJson() => {
        'furnaceId': furnaceId,
        'factoryId': factoryId,
        'status': status.name,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt?.toIso8601String(),
        'targetTemperature': targetTemperature,
        'soakMinutes': soakMinutes,
        'supervisorId': supervisorId,
        'supervisorName': supervisorName,
        'notes': notes,
      };

  SolutionCycleModel copyWith({
    SolutionFurnaceStatus? status,
    DateTime? endedAt,
    double? targetTemperature,
    double? soakMinutes,
    String? notes,
  }) =>
      SolutionCycleModel(
        id: id,
        furnaceId: furnaceId,
        factoryId: factoryId,
        status: status ?? this.status,
        startedAt: startedAt,
        endedAt: endedAt ?? this.endedAt,
        targetTemperature: targetTemperature ?? this.targetTemperature,
        soakMinutes: soakMinutes ?? this.soakMinutes,
        supervisorId: supervisorId,
        supervisorName: supervisorName,
        notes: notes ?? this.notes,
      );
}

class SolutionCageModel {
  final String id;
  final String furnaceId;
  final String cycleId;
  final String factoryId;
  final String cageNumber;
  final String alloy;
  final double diameterInInches;
  final int barCount;
  final double totalWeightKg;
  final double metricWeightPerBarKg;
  final List<String> dieNames;
  final String pressId;
  final String pressName;
  final String shiftId;
  final DateTime entryTime;
  final DateTime? exitTime;
  final SolutionCageStatus status;
  final String notes;

  SolutionCageModel({
    required this.id,
    required this.furnaceId,
    required this.cycleId,
    required this.factoryId,
    required this.cageNumber,
    this.alloy = '6063',
    this.diameterInInches = 0,
    this.barCount = 0,
    this.totalWeightKg = 0,
    this.metricWeightPerBarKg = 0,
    this.dieNames = const [],
    this.pressId = '',
    this.pressName = '',
    this.shiftId = '',
    DateTime? entryTime,
    this.exitTime,
    this.status = SolutionCageStatus.waiting,
    this.notes = '',
  }) : entryTime = entryTime ?? DateTime.now();

  factory SolutionCageModel.fromJson(String id, Map<dynamic, dynamic> json) => SolutionCageModel(
        id: id,
        furnaceId: _s(json['furnaceId']),
        cycleId: _s(json['cycleId']),
        factoryId: _s(json['factoryId']),
        cageNumber: _s(json['cageNumber'], id),
        alloy: _s(json['alloy'], '6063'),
        diameterInInches: _d(json['diameterInInches']),
        barCount: _i(json['barCount']),
        totalWeightKg: _d(json['totalWeightKg']),
        metricWeightPerBarKg: _d(json['metricWeightPerBarKg']),
        dieNames: _strList(json['dieNames']),
        pressId: _s(json['pressId']),
        pressName: _s(json['pressName']),
        shiftId: _s(json['shiftId']),
        entryTime: _dt(json['entryTime']),
        exitTime: json['exitTime'] == null ? null : _dt(json['exitTime']),
        status: _enumFromName(SolutionCageStatus.values, json['status'], SolutionCageStatus.waiting),
        notes: _s(json['notes']),
      );

  Map<String, dynamic> toJson() => {
        'furnaceId': furnaceId,
        'cycleId': cycleId,
        'factoryId': factoryId,
        'cageNumber': cageNumber,
        'alloy': alloy,
        'diameterInInches': diameterInInches,
        'barCount': barCount,
        'totalWeightKg': totalWeightKg,
        'metricWeightPerBarKg': metricWeightPerBarKg,
        'dieNames': dieNames,
        'pressId': pressId,
        'pressName': pressName,
        'shiftId': shiftId,
        'entryTime': entryTime.toIso8601String(),
        'exitTime': exitTime?.toIso8601String(),
        'status': status.name,
        'notes': notes,
      };

  SolutionCageModel copyWith({
    DateTime? exitTime,
    SolutionCageStatus? status,
    String? notes,
  }) =>
      SolutionCageModel(
        id: id,
        furnaceId: furnaceId,
        cycleId: cycleId,
        factoryId: factoryId,
        cageNumber: cageNumber,
        alloy: alloy,
        diameterInInches: diameterInInches,
        barCount: barCount,
        totalWeightKg: totalWeightKg,
        metricWeightPerBarKg: metricWeightPerBarKg,
        dieNames: dieNames,
        pressId: pressId,
        pressName: pressName,
        shiftId: shiftId,
        entryTime: entryTime,
        exitTime: exitTime ?? this.exitTime,
        status: status ?? this.status,
        notes: notes ?? this.notes,
      );
}

class PackagingOrderModel {
  final String id;
  final String factoryId;
  final String customerName;
  final String orderNumber;
  final PackagingOrderStatus status;
  final DateTime createdAt;
  final String createdBy;
  final String notes;

  PackagingOrderModel({
    required this.id,
    required this.factoryId,
    required this.customerName,
    this.orderNumber = '',
    this.status = PackagingOrderStatus.newOrder,
    DateTime? createdAt,
    this.createdBy = '',
    this.notes = '',
  }) : createdAt = createdAt ?? DateTime.now();

  factory PackagingOrderModel.fromJson(String id, Map<dynamic, dynamic> json) => PackagingOrderModel(
        id: id,
        factoryId: _s(json['factoryId']),
        customerName: _s(json['customerName'], 'عميل'),
        orderNumber: _s(json['orderNumber']),
        status: _enumFromName(PackagingOrderStatus.values, json['status'], PackagingOrderStatus.newOrder),
        createdAt: _dt(json['createdAt']),
        createdBy: _s(json['createdBy']),
        notes: _s(json['notes']),
      );

  Map<String, dynamic> toJson() => {
        'factoryId': factoryId,
        'customerName': customerName,
        'orderNumber': orderNumber,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'createdBy': createdBy,
        'notes': notes,
      };

  PackagingOrderModel copyWith({PackagingOrderStatus? status, String? notes}) => PackagingOrderModel(
        id: id,
        factoryId: factoryId,
        customerName: customerName,
        orderNumber: orderNumber,
        status: status ?? this.status,
        createdAt: createdAt,
        createdBy: createdBy,
        notes: notes ?? this.notes,
      );
}

class PackageBundleModel {
  final String id;
  final String orderId;
  final String factoryId;
  final String alloy;
  final double diameterInInches;
  final double lengthMm;
  final int barCount;
  final double totalWeightKg;
  final double metricWeightPerBarKg;
  final List<String> dieNames;
  final String pressId;
  final String pressName;
  final String shiftId;
  final String solutionCycleId;
  final String solutionCageId;
  final String warehouseLocation;
  final PackageBundleStatus status;
  final DateTime packedAt;
  final DateTime? deliveredAt;
  final String notes;

  PackageBundleModel({
    required this.id,
    required this.orderId,
    required this.factoryId,
    this.alloy = '6063',
    this.diameterInInches = 0,
    this.lengthMm = 0,
    this.barCount = 0,
    this.totalWeightKg = 0,
    this.metricWeightPerBarKg = 0,
    this.dieNames = const [],
    this.pressId = '',
    this.pressName = '',
    this.shiftId = '',
    this.solutionCycleId = '',
    this.solutionCageId = '',
    this.warehouseLocation = '',
    this.status = PackageBundleStatus.packed,
    DateTime? packedAt,
    this.deliveredAt,
    this.notes = '',
  }) : packedAt = packedAt ?? DateTime.now();

  factory PackageBundleModel.fromJson(String id, Map<dynamic, dynamic> json) => PackageBundleModel(
        id: id,
        orderId: _s(json['orderId']),
        factoryId: _s(json['factoryId']),
        alloy: _s(json['alloy'], '6063'),
        diameterInInches: _d(json['diameterInInches']),
        lengthMm: _d(json['lengthMm']),
        barCount: _i(json['barCount']),
        totalWeightKg: _d(json['totalWeightKg']),
        metricWeightPerBarKg: _d(json['metricWeightPerBarKg']),
        dieNames: _strList(json['dieNames']),
        pressId: _s(json['pressId']),
        pressName: _s(json['pressName']),
        shiftId: _s(json['shiftId']),
        solutionCycleId: _s(json['solutionCycleId']),
        solutionCageId: _s(json['solutionCageId']),
        warehouseLocation: _s(json['warehouseLocation']),
        status: _enumFromName(PackageBundleStatus.values, json['status'], PackageBundleStatus.packed),
        packedAt: _dt(json['packedAt']),
        deliveredAt: json['deliveredAt'] == null ? null : _dt(json['deliveredAt']),
        notes: _s(json['notes']),
      );

  Map<String, dynamic> toJson() => {
        'orderId': orderId,
        'factoryId': factoryId,
        'alloy': alloy,
        'diameterInInches': diameterInInches,
        'lengthMm': lengthMm,
        'barCount': barCount,
        'totalWeightKg': totalWeightKg,
        'metricWeightPerBarKg': metricWeightPerBarKg,
        'dieNames': dieNames,
        'pressId': pressId,
        'pressName': pressName,
        'shiftId': shiftId,
        'solutionCycleId': solutionCycleId,
        'solutionCageId': solutionCageId,
        'warehouseLocation': warehouseLocation,
        'status': status.name,
        'packedAt': packedAt.toIso8601String(),
        'deliveredAt': deliveredAt?.toIso8601String(),
        'notes': notes,
      };

  PackageBundleModel copyWith({
    String? warehouseLocation,
    PackageBundleStatus? status,
    DateTime? deliveredAt,
    String? notes,
  }) =>
      PackageBundleModel(
        id: id,
        orderId: orderId,
        factoryId: factoryId,
        alloy: alloy,
        diameterInInches: diameterInInches,
        lengthMm: lengthMm,
        barCount: barCount,
        totalWeightKg: totalWeightKg,
        metricWeightPerBarKg: metricWeightPerBarKg,
        dieNames: dieNames,
        pressId: pressId,
        pressName: pressName,
        shiftId: shiftId,
        solutionCycleId: solutionCycleId,
        solutionCageId: solutionCageId,
        warehouseLocation: warehouseLocation ?? this.warehouseLocation,
        status: status ?? this.status,
        packedAt: packedAt,
        deliveredAt: deliveredAt ?? this.deliveredAt,
        notes: notes ?? this.notes,
      );
}

// ============================================================
// 🧪 شاشة أفران الصلادة
// ============================================================

class SolutionFurnacesScreen extends StatefulWidget {
  const SolutionFurnacesScreen({super.key});

  @override
  State<SolutionFurnacesScreen> createState() => _SolutionFurnacesScreenState();
}

class _SolutionFurnacesScreenState extends State<SolutionFurnacesScreen> {
  late final String _factoryId;

  @override
  void initState() {
    super.initState();
    _factoryId = Provider.of<ShiftProvider>(context, listen: false).currentFactoryId;
  }

  DatabaseReference get _ref => FirebaseDatabase.instance.ref('factories/$_factoryId/solutionFurnaces');

  List<SolutionFurnaceModel> _parseFurnaces(DatabaseEvent event) {
    final list = <SolutionFurnaceModel>[];
    final val = event.snapshot.value;
    if (val is Map) {
      val.forEach((key, value) {
        if (value is Map) list.add(SolutionFurnaceModel.fromJson(key.toString(), value));
      });
    }
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  Future<void> _addFurnace() async {
    final name = TextEditingController();
    final temp = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة فرن صلادة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم الفرن')),
            TextField(controller: temp, decoration: const InputDecoration(labelText: 'درجة الحرارة المستهدفة'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حفظ')),
        ],
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      final newRef = _ref.push();
      await newRef.set(SolutionFurnaceModel(
        id: newRef.key ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: name.text.trim(),
        factoryId: _factoryId,
        targetTemperature: double.tryParse(temp.text) ?? 0,
      ).toJson());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🔥 أفران الصلادة')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addFurnace,
        icon: const Icon(Icons.add),
        label: const Text('إضافة فرن'),
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: _ref.onValue,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final furnaces = _parseFurnaces(snapshot.data!);
          if (furnaces.isEmpty) return const Center(child: Text('لا توجد أفران صلادة مضافة'));
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: furnaces.length,
            itemBuilder: (context, index) {
              final f = furnaces[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.heat_pump, color: Colors.deepOrange),
                  title: Text(f.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('الحالة: ${f.status.label} • المستهدف: ${f.targetTemperature}°'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SolutionFurnaceDetailScreen(furnace: f))),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ============================================================
// 🧪 تفاصيل فرن الصلادة + الأقفاص
// ============================================================

class SolutionFurnaceDetailScreen extends StatefulWidget {
  final SolutionFurnaceModel furnace;
  const SolutionFurnaceDetailScreen({super.key, required this.furnace});

  @override
  State<SolutionFurnaceDetailScreen> createState() => _SolutionFurnaceDetailScreenState();
}

class _SolutionFurnaceDetailScreenState extends State<SolutionFurnaceDetailScreen> {
  late final String _factoryId;
  late SolutionFurnaceModel furnace;

  @override
  void initState() {
    super.initState();
    furnace = widget.furnace;
    _factoryId = Provider.of<ShiftProvider>(context, listen: false).currentFactoryId;
  }

  DatabaseReference get _cyclesRef => FirebaseDatabase.instance.ref('factories/$_factoryId/solutionCycles');
  DatabaseReference get _cagesRef => FirebaseDatabase.instance.ref('factories/$_factoryId/solutionCages');
  DatabaseReference get _furnaceRef => FirebaseDatabase.instance.ref('factories/$_factoryId/solutionFurnaces/${furnace.id}');

  List<SolutionCycleModel> _parseCycles(DatabaseEvent event) {
    final list = <SolutionCycleModel>[];
    final val = event.snapshot.value;
    if (val is Map) {
      val.forEach((key, value) {
        if (value is Map && _s(value['furnaceId']) == furnace.id) {
          list.add(SolutionCycleModel.fromJson(key.toString(), value));
        }
      });
    }
    list.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return list;
  }

  List<SolutionCageModel> _parseCages(DatabaseEvent event, String cycleId) {
    final list = <SolutionCageModel>[];
    final val = event.snapshot.value;
    if (val is Map) {
      val.forEach((key, value) {
        if (value is Map && _s(value['cycleId']) == cycleId) {
          list.add(SolutionCageModel.fromJson(key.toString(), value));
        }
      });
    }
    list.sort((a, b) => a.entryTime.compareTo(b.entryTime));
    return list;
  }

  Future<void> _startCycle() async {
    final temp = TextEditingController(text: furnace.targetTemperature == 0 ? '' : furnace.targetTemperature.toStringAsFixed(0));
    final soak = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('بدء دورة صلادة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: temp, decoration: const InputDecoration(labelText: 'درجة الحرارة'), keyboardType: TextInputType.number),
            TextField(controller: soak, decoration: const InputDecoration(labelText: 'زمن النقع بالدقائق'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('بدء')),
        ],
      ),
    );
    if (ok == true) {
      final user = FirebaseAuth.instance.currentUser;
      final newRef = _cyclesRef.push();
      final cycle = SolutionCycleModel(
        id: newRef.key ?? DateTime.now().millisecondsSinceEpoch.toString(),
        furnaceId: furnace.id,
        factoryId: _factoryId,
        status: SolutionFurnaceStatus.heating,
        targetTemperature: double.tryParse(temp.text) ?? furnace.targetTemperature,
        soakMinutes: double.tryParse(soak.text) ?? 0,
        supervisorId: user?.uid ?? '',
        supervisorName: user?.email ?? '',
      );
      await newRef.set(cycle.toJson());
      await _furnaceRef.update({'status': SolutionFurnaceStatus.heating.name});
    }
  }

  Future<void> _addCage(SolutionCycleModel cycle) async {
    final cageNumber = TextEditingController();
    final alloy = TextEditingController(text: '6063');
    final diameter = TextEditingController();
    final barCount = TextEditingController();
    final totalWeight = TextEditingController();
    final metricWeight = TextEditingController();
    final dieNames = TextEditingController();
    final pressName = TextEditingController();
    final shiftId = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة قفص للفرن'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: cageNumber, decoration: const InputDecoration(labelText: 'رقم القفص')),
              TextField(controller: alloy, decoration: const InputDecoration(labelText: 'السبيكة')),
              TextField(controller: diameter, decoration: const InputDecoration(labelText: 'القطر بالبوصة'), keyboardType: TextInputType.number),
              TextField(controller: barCount, decoration: const InputDecoration(labelText: 'عدد الأعواد'), keyboardType: TextInputType.number),
              TextField(controller: totalWeight, decoration: const InputDecoration(labelText: 'الوزن الكلي كجم'), keyboardType: TextInputType.number),
              TextField(controller: metricWeight, decoration: const InputDecoration(labelText: 'الوزن المتري للعود كجم')),
              TextField(controller: dieNames, decoration: const InputDecoration(labelText: 'أسماء القوالب - افصل بفاصلة')),
              TextField(controller: pressName, decoration: const InputDecoration(labelText: 'المكبس')),
              TextField(controller: shiftId, decoration: const InputDecoration(labelText: 'رقم الوردية/المرجع')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('دخول القفص')),
        ],
      ),
    );
    if (ok == true && cageNumber.text.trim().isNotEmpty) {
      final count = int.tryParse(barCount.text) ?? 0;
      final total = double.tryParse(totalWeight.text) ?? 0;
      final metric = double.tryParse(metricWeight.text) ?? (count > 0 ? total / count : 0);
      final newRef = _cagesRef.push();
      final cage = SolutionCageModel(
        id: newRef.key ?? DateTime.now().millisecondsSinceEpoch.toString(),
        furnaceId: furnace.id,
        cycleId: cycle.id,
        factoryId: _factoryId,
        cageNumber: cageNumber.text.trim(),
        alloy: alloy.text.trim().isEmpty ? '6063' : alloy.text.trim(),
        diameterInInches: double.tryParse(diameter.text) ?? 0,
        barCount: count,
        totalWeightKg: total,
        metricWeightPerBarKg: metric,
        dieNames: _strList(dieNames.text),
        pressName: pressName.text.trim(),
        shiftId: shiftId.text.trim(),
        status: SolutionCageStatus.insideSolution,
      );
      await newRef.set(cage.toJson());
      await _furnaceRef.update({'status': SolutionFurnaceStatus.loading.name});
    }
  }

  Future<void> _exitCage(SolutionCageModel cage) async {
    await _cagesRef.child(cage.id).update({
      'exitTime': DateTime.now().toIso8601String(),
      'status': SolutionCageStatus.completed.name,
    });
  }

  Future<void> _endCycle(SolutionCycleModel cycle) async {
    await _cyclesRef.child(cycle.id).update({'status': SolutionFurnaceStatus.completed.name, 'endedAt': DateTime.now().toIso8601String()});
    await _furnaceRef.update({'status': SolutionFurnaceStatus.idle.name});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('🧪 ${furnace.name}')),
      body: StreamBuilder<DatabaseEvent>(
        stream: _cyclesRef.onValue,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final cycles = _parseCycles(snapshot.data!);
          final active = cycles.where((c) => c.status != SolutionFurnaceStatus.completed && c.endedAt == null).toList();
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              ElevatedButton.icon(onPressed: active.isEmpty ? _startCycle : null, icon: const Icon(Icons.play_arrow), label: const Text('بدء دورة صلادة جديدة')),
              const SizedBox(height: 12),
              ...cycles.map((cycle) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text('دورة ${cycle.id.substring(0, cycle.id.length > 6 ? 6 : cycle.id.length)} • ${cycle.status.label}', style: const TextStyle(fontWeight: FontWeight.bold))),
                              if (cycle.endedAt == null)
                                TextButton.icon(onPressed: () => _endCycle(cycle), icon: const Icon(Icons.stop), label: const Text('إنهاء الدورة')),
                            ],
                          ),
                          Text('بدأت: ${cycle.startedAt} • الحرارة: ${cycle.targetTemperature}° • النقع: ${cycle.soakMinutes} دقيقة'),
                          const SizedBox(height: 8),
                          if (cycle.endedAt == null)
                            ElevatedButton.icon(onPressed: () => _addCage(cycle), icon: const Icon(Icons.add_box), label: const Text('إضافة قفص')),
                          const SizedBox(height: 8),
                          StreamBuilder<DatabaseEvent>(
                            stream: _cagesRef.onValue,
                            builder: (context, cageSnap) {
                              if (!cageSnap.hasData) return const SizedBox.shrink();
                              final cages = _parseCages(cageSnap.data!, cycle.id);
                              if (cages.isEmpty) return const Text('لا توجد أقفاص في هذه الدورة');
                              return Column(
                                children: cages.map((cage) => Card(
                                      color: Colors.grey.shade100,
                                      child: ListTile(
                                        title: Text('قفص ${cage.cageNumber} - ${cage.barCount} عود'),
                                        subtitle: Text('القوالب: ${cage.dieNames.join('، ')}\nالوزن: ${cage.totalWeightKg} كجم • المتري/عود: ${cage.metricWeightPerBarKg}\nالحالة: ${cage.status.label}'),
                                        isThreeLine: true,
                                        trailing: cage.exitTime == null
                                            ? IconButton(icon: const Icon(Icons.logout, color: Colors.red), onPressed: () => _exitCage(cage), tooltip: 'خروج القفص')
                                            : const Icon(Icons.check_circle, color: Colors.green),
                                      ),
                                    )).toList(),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  )),
            ],
          );
        },
      ),
    );
  }
}

// ============================================================
// 📦 شاشة أوامر التغليف
// ============================================================

class PackagingOrdersScreen extends StatefulWidget {
  const PackagingOrdersScreen({super.key});

  @override
  State<PackagingOrdersScreen> createState() => _PackagingOrdersScreenState();
}

class _PackagingOrdersScreenState extends State<PackagingOrdersScreen> {
  late final String _factoryId;

  @override
  void initState() {
    super.initState();
    _factoryId = Provider.of<ShiftProvider>(context, listen: false).currentFactoryId;
  }

  DatabaseReference get _ordersRef => FirebaseDatabase.instance.ref('factories/$_factoryId/packagingOrders');

  List<PackagingOrderModel> _parseOrders(DatabaseEvent event) {
    final list = <PackagingOrderModel>[];
    final val = event.snapshot.value;
    if (val is Map) {
      val.forEach((key, value) {
        if (value is Map) list.add(PackagingOrderModel.fromJson(key.toString(), value));
      });
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<void> _addOrder() async {
    final customer = TextEditingController();
    final orderNumber = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إنشاء أمر تغليف'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: customer, decoration: const InputDecoration(labelText: 'اسم العميل')),
            TextField(controller: orderNumber, decoration: const InputDecoration(labelText: 'رقم الطلب/الفاتورة')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حفظ')),
        ],
      ),
    );
    if (ok == true && customer.text.trim().isNotEmpty) {
      final user = FirebaseAuth.instance.currentUser;
      final newRef = _ordersRef.push();
      await newRef.set(PackagingOrderModel(
        id: newRef.key ?? DateTime.now().millisecondsSinceEpoch.toString(),
        factoryId: _factoryId,
        customerName: customer.text.trim(),
        orderNumber: orderNumber.text.trim(),
        createdBy: user?.email ?? '',
      ).toJson());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('📦 قسم التغليف')),
      floatingActionButton: FloatingActionButton.extended(onPressed: _addOrder, icon: const Icon(Icons.add), label: const Text('أمر تغليف')),
      body: StreamBuilder<DatabaseEvent>(
        stream: _ordersRef.onValue,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final orders = _parseOrders(snapshot.data!);
          if (orders.isEmpty) return const Center(child: Text('لا توجد أوامر تغليف'));
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final o = orders[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.inventory_2, color: Colors.blue),
                  title: Text(o.customerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('الطلب: ${o.orderNumber}\nالحالة: ${o.status.label}'),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PackagingOrderDetailScreen(order: o))),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ============================================================
// 📦 تفاصيل أمر التغليف + الطرود
// ============================================================

class PackagingOrderDetailScreen extends StatefulWidget {
  final PackagingOrderModel order;
  const PackagingOrderDetailScreen({super.key, required this.order});

  @override
  State<PackagingOrderDetailScreen> createState() => _PackagingOrderDetailScreenState();
}

class _PackagingOrderDetailScreenState extends State<PackagingOrderDetailScreen> {
  late final String _factoryId;

  @override
  void initState() {
    super.initState();
    _factoryId = Provider.of<ShiftProvider>(context, listen: false).currentFactoryId;
  }

  DatabaseReference get _bundlesRef => FirebaseDatabase.instance.ref('factories/$_factoryId/packages');
  DatabaseReference get _orderRef => FirebaseDatabase.instance.ref('factories/$_factoryId/packagingOrders/${widget.order.id}');

  List<PackageBundleModel> _parseBundles(DatabaseEvent event) {
    final list = <PackageBundleModel>[];
    final val = event.snapshot.value;
    if (val is Map) {
      val.forEach((key, value) {
        if (value is Map && _s(value['orderId']) == widget.order.id) {
          list.add(PackageBundleModel.fromJson(key.toString(), value));
        }
      });
    }
    list.sort((a, b) => b.packedAt.compareTo(a.packedAt));
    return list;
  }

  Future<void> _addBundle() async {
    final alloy = TextEditingController(text: '6063');
    final diameter = TextEditingController();
    final length = TextEditingController();
    final barCount = TextEditingController();
    final totalWeight = TextEditingController();
    final metricWeight = TextEditingController();
    final dieNames = TextEditingController();
    final pressName = TextEditingController();
    final cageId = TextEditingController();
    final warehouse = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة طرد/تغليف'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: alloy, decoration: const InputDecoration(labelText: 'السبيكة')),
              TextField(controller: diameter, decoration: const InputDecoration(labelText: 'القطر بالبوصة'), keyboardType: TextInputType.number),
              TextField(controller: length, decoration: const InputDecoration(labelText: 'الطول مم'), keyboardType: TextInputType.number),
              TextField(controller: barCount, decoration: const InputDecoration(labelText: 'عدد الأعواد'), keyboardType: TextInputType.number),
              TextField(controller: totalWeight, decoration: const InputDecoration(labelText: 'الوزن الكلي كجم'), keyboardType: TextInputType.number),
              TextField(controller: metricWeight, decoration: const InputDecoration(labelText: 'الوزن المتري للعود كجم')),
              TextField(controller: dieNames, decoration: const InputDecoration(labelText: 'أسماء القوالب - افصل بفاصلة')),
              TextField(controller: pressName, decoration: const InputDecoration(labelText: 'المكبس')),
              TextField(controller: cageId, decoration: const InputDecoration(labelText: 'رقم قفص الصلادة إن وجد')),
              TextField(controller: warehouse, decoration: const InputDecoration(labelText: 'مكان التخزين إن انتقل للمخزن')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حفظ الطرد')),
        ],
      ),
    );
    if (ok == true) {
      final count = int.tryParse(barCount.text) ?? 0;
      final total = double.tryParse(totalWeight.text) ?? 0;
      final metric = double.tryParse(metricWeight.text) ?? (count > 0 ? total / count : 0);
      final newRef = _bundlesRef.push();
      await newRef.set(PackageBundleModel(
        id: newRef.key ?? DateTime.now().millisecondsSinceEpoch.toString(),
        orderId: widget.order.id,
        factoryId: _factoryId,
        alloy: alloy.text.trim().isEmpty ? '6063' : alloy.text.trim(),
        diameterInInches: double.tryParse(diameter.text) ?? 0,
        lengthMm: double.tryParse(length.text) ?? 0,
        barCount: count,
        totalWeightKg: total,
        metricWeightPerBarKg: metric,
        dieNames: _strList(dieNames.text),
        pressName: pressName.text.trim(),
        solutionCageId: cageId.text.trim(),
        warehouseLocation: warehouse.text.trim(),
      ).toJson());
      await _orderRef.update({'status': PackagingOrderStatus.packing.name});
    }
  }

  Future<void> _updateBundle(PackageBundleModel bundle, PackageBundleStatus status) async {
    await _bundlesRef.child(bundle.id).update({
      'status': status.name,
      if (status == PackageBundleStatus.delivered) 'deliveredAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('📦 ${widget.order.customerName}')),
      floatingActionButton: FloatingActionButton.extended(onPressed: _addBundle, icon: const Icon(Icons.add), label: const Text('إضافة طرد')),
      body: StreamBuilder<DatabaseEvent>(
        stream: _bundlesRef.onValue,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final bundles = _parseBundles(snapshot.data!);
          final totalBars = bundles.fold<int>(0, (sum, b) => sum + b.barCount);
          final totalWeight = bundles.fold<double>(0, (sum, b) => sum + b.totalWeightKg);
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.summarize, color: Colors.green),
                  title: Text('إجمالي أمر التغليف'),
                  subtitle: Text('عدد الأعواد: $totalBars\nالوزن الكلي: ${totalWeight.toStringAsFixed(2)} كجم'),
                  isThreeLine: true,
                ),
              ),
              const SizedBox(height: 8),
              ...bundles.map((b) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('طرد ${b.id.substring(0, b.id.length > 6 ? 6 : b.id.length)} • ${b.status.label}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text('${b.barCount} عود • ${b.totalWeightKg} كجم • متري/عود ${b.metricWeightPerBarKg}\nالقوالب: ${b.dieNames.join('، ')}\nالقفص: ${b.solutionCageId} • مكان التخزين: ${b.warehouseLocation}'),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              OutlinedButton.icon(onPressed: () => _updateBundle(b, PackageBundleStatus.packed), icon: const Icon(Icons.check), label: const Text('مغلف')),
                              OutlinedButton.icon(onPressed: () => _updateBundle(b, PackageBundleStatus.movedToWarehouse), icon: const Icon(Icons.warehouse), label: const Text('للمخزن')),
                              OutlinedButton.icon(onPressed: () => _updateBundle(b, PackageBundleStatus.delivered), icon: const Icon(Icons.local_shipping), label: const Text('تسليم')),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )),
            ],
          );
        },
      ),
    );
  }
}
