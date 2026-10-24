
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'die_template_model.dart';
import 'services.dart';

// ============================================================
// 🔧 الكوريكشن وتتبع القوالب
// ============================================================

String _s(dynamic v, [String fallback = '']) => v?.toString() ?? fallback;
int _i(dynamic v, [int fallback = 0]) => v is int ? v : int.tryParse(v?.toString() ?? '') ?? fallback;
double _d(dynamic v, [double fallback = 0]) => v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? fallback;
bool _b(dynamic v, [bool fallback = false]) => v is bool ? v : v?.toString() == 'true';
DateTime _dt(dynamic v, [DateTime? fallback]) => DateTime.tryParse(v?.toString() ?? '') ?? fallback ?? DateTime.now();
List<String> _strList(dynamic v) {
  if (v is List) return v.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
  if (v is String && v.trim().isNotEmpty) return v.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  return const [];
}

enum DieAssetLocation {
  unknown,
  onPress,
  inSoda,
  inDieFurnace,
  inCorrection,
  readyStore,
  damaged,
}

enum CorrectionPriority { normal, important, urgent }

enum DieRemovalReason { ok, defect, productionFinished, sizeChange, transferPress, other }

enum RepairWorkType { polish, bearingCut, welding, sizeAdjust, cleaning, other }

extension DieAssetLocationX on DieAssetLocation {
  String get label {
    switch (this) {
      case DieAssetLocation.unknown: return 'غير محدد';
      case DieAssetLocation.onPress: return 'على المكبس';
      case DieAssetLocation.inSoda: return 'في الصودا';
      case DieAssetLocation.inDieFurnace: return 'في فرن القوالب';
      case DieAssetLocation.inCorrection: return 'داخل الكوريكشن';
      case DieAssetLocation.readyStore: return 'جاهز في مخزن الكوريكشن';
      case DieAssetLocation.damaged: return 'تالف / سكراب';
    }
  }
}

extension CorrectionPriorityX on CorrectionPriority {
  String get label {
    switch (this) {
      case CorrectionPriority.normal: return 'عادي';
      case CorrectionPriority.important: return 'مهم';
      case CorrectionPriority.urgent: return 'عاجل';
    }
  }
}

extension DieRemovalReasonX on DieRemovalReason {
  String get label {
    switch (this) {
      case DieRemovalReason.ok: return 'أوك / سليم';
      case DieRemovalReason.defect: return 'به عيب';
      case DieRemovalReason.productionFinished: return 'انتهاء إنتاج';
      case DieRemovalReason.sizeChange: return 'تغيير مقاس';
      case DieRemovalReason.transferPress: return 'تغيير مكبس';
      case DieRemovalReason.other: return 'أخرى';
    }
  }
}

extension RepairWorkTypeX on RepairWorkType {
  String get label {
    switch (this) {
      case RepairWorkType.polish: return 'بولش / تلميع';
      case RepairWorkType.bearingCut: return 'قطع بيرنج';
      case RepairWorkType.welding: return 'لحام';
      case RepairWorkType.sizeAdjust: return 'تعديل مقاس';
      case RepairWorkType.cleaning: return 'تنظيف';
      case RepairWorkType.other: return 'أخرى';
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

class DieAssetModel {
  final String id; // غالباً id القالب من dieTemplates
  final String name;
  final String profileCode; // كود القطاع/القالب
  final String designCode; // كود التصميم
  final String clientCode; // كود العميل
  final String fullCode;
  final String factoryId;
  final String dieType;
  final double widthMm;
  final double heightMm;
  final DieAssetLocation location;
  final String locationName;
  final String pressId;
  final String pressName;
  final String pressSize;
  final int pressCount;
  final int correctionCount;
  final DieRemovalReason lastRemovalReason;
  final String lastRemovalNotes;
  final CorrectionPriority priority;
  final String technicianName;
  final List<String> repairTypes;
  final String repairNotes;
  final String damageReason;
  final DateTime? readyAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  DieAssetModel({
    required this.id,
    required this.name,
    required this.profileCode,
    required this.designCode,
    required this.clientCode,
    required this.fullCode,
    required this.factoryId,
    this.dieType = '',
    this.widthMm = 0,
    this.heightMm = 0,
    this.location = DieAssetLocation.unknown,
    this.locationName = '',
    this.pressId = '',
    this.pressName = '',
    this.pressSize = '',
    this.pressCount = 0,
    this.correctionCount = 0,
    this.lastRemovalReason = DieRemovalReason.other,
    this.lastRemovalNotes = '',
    this.priority = CorrectionPriority.normal,
    this.technicianName = '',
    this.repairTypes = const [],
    this.repairNotes = '',
    this.damageReason = '',
    this.readyAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory DieAssetModel.fromTemplate(DieTemplate t, String factoryId) => DieAssetModel(
        id: t.id,
        name: t.name,
        profileCode: t.dieCode,
        designCode: t.designCode,
        clientCode: t.clientCode,
        fullCode: t.fullCode,
        factoryId: factoryId,
        dieType: t.type ?? '',
        widthMm: t.widthMm ?? 0,
        heightMm: t.heightMm ?? 0,
      );

  factory DieAssetModel.fromJson(String id, Map<dynamic, dynamic> json) => DieAssetModel(
        id: id,
        name: _s(json['name'], id),
        profileCode: _s(json['profileCode']),
        designCode: _s(json['designCode']),
        clientCode: _s(json['clientCode']),
        fullCode: _s(json['fullCode']),
        factoryId: _s(json['factoryId']),
        dieType: _s(json['dieType']),
        widthMm: _d(json['widthMm']),
        heightMm: _d(json['heightMm']),
        location: _enumFromName(DieAssetLocation.values, json['location'], DieAssetLocation.unknown),
        locationName: _s(json['locationName']),
        pressId: _s(json['pressId']),
        pressName: _s(json['pressName']),
        pressSize: _s(json['pressSize']),
        pressCount: _i(json['pressCount']),
        correctionCount: _i(json['correctionCount']),
        lastRemovalReason: _enumFromName(DieRemovalReason.values, json['lastRemovalReason'], DieRemovalReason.other),
        lastRemovalNotes: _s(json['lastRemovalNotes']),
        priority: _enumFromName(CorrectionPriority.values, json['priority'], CorrectionPriority.normal),
        technicianName: _s(json['technicianName']),
        repairTypes: _strList(json['repairTypes']),
        repairNotes: _s(json['repairNotes']),
        damageReason: _s(json['damageReason']),
        readyAt: json['readyAt'] == null ? null : _dt(json['readyAt']),
        createdAt: _dt(json['createdAt']),
        updatedAt: _dt(json['updatedAt']),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'profileCode': profileCode,
        'designCode': designCode,
        'clientCode': clientCode,
        'fullCode': fullCode,
        'factoryId': factoryId,
        'dieType': dieType,
        'widthMm': widthMm,
        'heightMm': heightMm,
        'location': location.name,
        'locationName': locationName,
        'pressId': pressId,
        'pressName': pressName,
        'pressSize': pressSize,
        'pressCount': pressCount,
        'correctionCount': correctionCount,
        'lastRemovalReason': lastRemovalReason.name,
        'lastRemovalNotes': lastRemovalNotes,
        'priority': priority.name,
        'technicianName': technicianName,
        'repairTypes': repairTypes,
        'repairNotes': repairNotes,
        'damageReason': damageReason,
        'readyAt': readyAt?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  String get codesDisplay => 'القطاع: $profileCode | التصميم: $designCode | العميل: $clientCode';

  String get sizeDisplay {
    final type = dieType.isEmpty ? '' : '$dieType - ';
    if (widthMm > 0 && heightMm > 0) return '$type${widthMm.toStringAsFixed(0)}×${heightMm.toStringAsFixed(0)} مم';
    return type.trim();
  }

  DieAssetModel copyWith({
    String? dieType,
    double? widthMm,
    double? heightMm,
    DieAssetLocation? location,
    String? locationName,
    String? pressId,
    String? pressName,
    String? pressSize,
    int? pressCount,
    int? correctionCount,
    DieRemovalReason? lastRemovalReason,
    String? lastRemovalNotes,
    CorrectionPriority? priority,
    String? technicianName,
    List<String>? repairTypes,
    String? repairNotes,
    String? damageReason,
    DateTime? readyAt,
    DateTime? updatedAt,
  }) =>
      DieAssetModel(
        id: id,
        name: name,
        profileCode: profileCode,
        designCode: designCode,
        clientCode: clientCode,
        fullCode: fullCode,
        factoryId: factoryId,
        dieType: dieType ?? this.dieType,
        widthMm: widthMm ?? this.widthMm,
        heightMm: heightMm ?? this.heightMm,
        location: location ?? this.location,
        locationName: locationName ?? this.locationName,
        pressId: pressId ?? this.pressId,
        pressName: pressName ?? this.pressName,
        pressSize: pressSize ?? this.pressSize,
        pressCount: pressCount ?? this.pressCount,
        correctionCount: correctionCount ?? this.correctionCount,
        lastRemovalReason: lastRemovalReason ?? this.lastRemovalReason,
        lastRemovalNotes: lastRemovalNotes ?? this.lastRemovalNotes,
        priority: priority ?? this.priority,
        technicianName: technicianName ?? this.technicianName,
        repairTypes: repairTypes ?? this.repairTypes,
        repairNotes: repairNotes ?? this.repairNotes,
        damageReason: damageReason ?? this.damageReason,
        readyAt: readyAt ?? this.readyAt,
        createdAt: createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
      );
}

class DieMovementModel {
  final String id;
  final String dieAssetId;
  final String factoryId;
  final String fromLocation;
  final String toLocation;
  final String note;
  final String by;
  final DateTime at;

  DieMovementModel({required this.id, required this.dieAssetId, required this.factoryId, this.fromLocation = '', this.toLocation = '', this.note = '', this.by = '', DateTime? at}) : at = at ?? DateTime.now();

  factory DieMovementModel.fromJson(String id, Map<dynamic, dynamic> json) => DieMovementModel(
        id: id,
        dieAssetId: _s(json['dieAssetId']),
        factoryId: _s(json['factoryId']),
        fromLocation: _s(json['fromLocation']),
        toLocation: _s(json['toLocation']),
        note: _s(json['note']),
        by: _s(json['by']),
        at: _dt(json['at']),
      );

  Map<String, dynamic> toJson() => {'dieAssetId': dieAssetId, 'factoryId': factoryId, 'fromLocation': fromLocation, 'toLocation': toLocation, 'note': note, 'by': by, 'at': at.toIso8601String()};
}

class CorrectionOrderModel {
  final String id;
  final String dieAssetId;
  final String factoryId;
  final String dieName;
  final String codesDisplay;
  final DieRemovalReason removalReason;
  final String removalNotes;
  final CorrectionPriority priority;
  final String status;
  final String technicianName;
  final List<String> repairTypes;
  final String repairNotes;
  final String damageReason;
  final DateTime createdAt;
  final DateTime? readyAt;

  CorrectionOrderModel({required this.id, required this.dieAssetId, required this.factoryId, required this.dieName, this.codesDisplay = '', this.removalReason = DieRemovalReason.defect, this.removalNotes = '', this.priority = CorrectionPriority.normal, this.status = 'داخل الكوريكشن', this.technicianName = '', this.repairTypes = const [], this.repairNotes = '', this.damageReason = '', DateTime? createdAt, this.readyAt}) : createdAt = createdAt ?? DateTime.now();

  factory CorrectionOrderModel.fromJson(String id, Map<dynamic, dynamic> json) => CorrectionOrderModel(
        id: id,
        dieAssetId: _s(json['dieAssetId']),
        factoryId: _s(json['factoryId']),
        dieName: _s(json['dieName']),
        codesDisplay: _s(json['codesDisplay']),
        removalReason: _enumFromName(DieRemovalReason.values, json['removalReason'], DieRemovalReason.defect),
        removalNotes: _s(json['removalNotes']),
        priority: _enumFromName(CorrectionPriority.values, json['priority'], CorrectionPriority.normal),
        status: _s(json['status'], 'داخل الكوريكشن'),
        technicianName: _s(json['technicianName']),
        repairTypes: _strList(json['repairTypes']),
        repairNotes: _s(json['repairNotes']),
        damageReason: _s(json['damageReason']),
        createdAt: _dt(json['createdAt']),
        readyAt: json['readyAt'] == null ? null : _dt(json['readyAt']),
      );

  Map<String, dynamic> toJson() => {'dieAssetId': dieAssetId, 'factoryId': factoryId, 'dieName': dieName, 'codesDisplay': codesDisplay, 'removalReason': removalReason.name, 'removalNotes': removalNotes, 'priority': priority.name, 'status': status, 'technicianName': technicianName, 'repairTypes': repairTypes, 'repairNotes': repairNotes, 'damageReason': damageReason, 'createdAt': createdAt.toIso8601String(), 'readyAt': readyAt?.toIso8601String()};
}

class DieTracking {
  static DatabaseReference _templatesRef(String factoryId) => FirebaseDatabase.instance.ref('factories/$factoryId/dieTemplates');
  static DatabaseReference _assetsRef(String factoryId) => FirebaseDatabase.instance.ref('factories/$factoryId/dieAssets');
  static DatabaseReference _movementsRef(String factoryId) => FirebaseDatabase.instance.ref('factories/$factoryId/dieMovements');

  static Future<DieTemplate?> findTemplate(String factoryId, List<String> codes) async {
    final snap = await _templatesRef(factoryId).get();
    final val = snap.value;
    if (val is! Map) return null;
    final templates = <DieTemplate>[];
    val.forEach((key, value) {
      if (value is Map) {
        templates.add(DieTemplate.fromJson(key.toString(), Map<String, dynamic>.from(value)));
      }
    });
    for (final code in codes) {
      final q = code.trim();
      if (q.isEmpty) continue;
      for (final t in templates) {
        if (t.matchesExactCode(q)) return t;
      }
    }
    for (final code in codes) {
      final q = code.trim();
      if (q.isEmpty) continue;
      for (final t in templates) {
        if (t.matchesAnyCode(q)) return t;
      }
    }
    return null;
  }

  static Future<DieAssetLocation?> findLocation(String factoryId, List<String> codes) async {
    final template = await findTemplate(factoryId, codes);
    if (template == null) return null;
    final snap = await _assetsRef(factoryId).child(template.id).get();
    if (snap.value is Map) {
      return DieAssetModel.fromJson(template.id, snap.value as Map).location;
    }
    return DieAssetLocation.unknown;
  }

  static Future<DieAssetModel> _getOrCreateAsset(String factoryId, DieTemplate template) async {
    final snap = await _assetsRef(factoryId).child(template.id).get();
    if (snap.value is Map) {
      return DieAssetModel.fromJson(template.id, snap.value as Map);
    }
    return DieAssetModel.fromTemplate(template, factoryId);
  }

  static Future<void> _addMovement(String factoryId, DieAssetModel asset, String from, String to, String note) async {
    final user = FirebaseAuth.instance.currentUser;
    final ref = _movementsRef(factoryId).push();
    await ref.set(DieMovementModel(id: ref.key ?? '', dieAssetId: asset.id, factoryId: factoryId, fromLocation: from, toLocation: to, note: note, by: user?.email ?? '').toJson());
  }

  static Future<void> recordPressExit({
    required String factoryId,
    required List<String> codes,
    required String pressId,
    required String pressName,
    required String pressSize,
  }) async {
    final template = await findTemplate(factoryId, codes);
    if (template == null) return;
    final asset = await _getOrCreateAsset(factoryId, template);
    final onPress = asset.copyWith(location: DieAssetLocation.onPress, locationName: 'على $pressName ($pressSize)', pressId: pressId, pressName: pressName, pressSize: pressSize, pressCount: asset.pressCount + 1, readyAt: null);
    await _addMovement(factoryId, asset, asset.location.label, onPress.locationName, 'تسجيل كبس/خروج من المكبس');
    final inSoda = onPress.copyWith(location: DieAssetLocation.inSoda, locationName: 'الصودا - تنظيف بقايا الألمنيوم');
    await _addMovement(factoryId, onPress, onPress.locationName, inSoda.locationName, 'بعد رفع القالب ينتقل للصودا');
    await _assetsRef(factoryId).child(asset.id).set(inSoda.toJson());
  }

  static Future<void> recordDieFurnace({required String factoryId, required List<String> codes, required String furnaceName}) async {
    final template = await findTemplate(factoryId, codes);
    if (template == null) return;
    final asset = await _getOrCreateAsset(factoryId, template);
    final updated = asset.copyWith(location: DieAssetLocation.inDieFurnace, locationName: furnaceName);
    await _addMovement(factoryId, asset, asset.locationName, updated.locationName, 'إضافة القالب إلى فرن القوالب');
    await _assetsRef(factoryId).child(asset.id).set(updated.toJson());
  }

  static Future<void> updateAsset(String factoryId, DieAssetModel asset) async {
    await _assetsRef(factoryId).child(asset.id).set(asset.copyWith(updatedAt: DateTime.now()).toJson());
  }
}

// ============================================================
// 🔧 شاشة البحث في الكوريكشن
// ============================================================

class DieCorrectionScreen extends StatefulWidget {
  const DieCorrectionScreen({super.key});

  @override
  State<DieCorrectionScreen> createState() => _DieCorrectionScreenState();
}

class _DieCorrectionScreenState extends State<DieCorrectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<DieTemplate> _parseTemplates(DatabaseEvent event) {
    final list = <DieTemplate>[];
    final val = event.snapshot.value;
    if (val is Map) {
      val.forEach((key, value) {
        if (value is Map) list.add(DieTemplate.fromJson(key.toString(), Map<String, dynamic>.from(value)));
      });
    }
    return list;
  }

  Future<DieAssetModel?> _assetFuture(String factoryId, DieTemplate t) async {
    final snap = await FirebaseDatabase.instance.ref('factories/$factoryId/dieAssets/${t.id}').get();
    if (snap.value is Map) return DieAssetModel.fromJson(t.id, snap.value as Map);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final factoryId = Provider.of<ShiftProvider>(context, listen: false).currentFactoryId;
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔧 الكوريكشن وتتبع القوالب'),
        actions: [
          IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DieAssetListScreen(location: DieAssetLocation.readyStore, title: 'القوالب الجاهزة'))), icon: const Icon(Icons.check_circle)),
          IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DieAssetListScreen(location: DieAssetLocation.inCorrection, title: 'القوالب العالقة'))), icon: const Icon(Icons.warning_amber)),
          IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DieAssetListScreen(location: DieAssetLocation.damaged, title: 'القوالب التالفة'))), icon: const Icon(Icons.broken_image)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'ابحث بكود القطاع أو التصميم أو العميل',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(onPressed: () { _searchController.clear(); setState(() => _query = ''); }, icon: const Icon(Icons.clear)),
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
          Expanded(
            child: StreamBuilder<DatabaseEvent>(
              stream: FirebaseDatabase.instance.ref('factories/$factoryId/dieTemplates').onValue,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                var templates = _parseTemplates(snapshot.data!);
                if (_query.isNotEmpty) {
                  templates = templates.where((t) => t.matchesAnyCode(_query)).toList();
                }
                if (templates.isEmpty) return const Center(child: Text('لا توجد قوالب مطابقة'));
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: templates.length,
                  itemBuilder: (context, index) {
                    final t = templates[index];
                    return FutureBuilder<DieAssetModel?>(
                      future: _assetFuture(factoryId, t),
                      builder: (context, assetSnap) {
                        final asset = assetSnap.data;
                        final location = asset?.location ?? DieAssetLocation.unknown;
                        return Card(
                          child: ListTile(
                            leading: Icon(location == DieAssetLocation.inCorrection ? Icons.build : location == DieAssetLocation.readyStore ? Icons.check_circle : location == DieAssetLocation.damaged ? Icons.broken_image : Icons.location_on, color: location == DieAssetLocation.damaged ? Colors.red : location == DieAssetLocation.readyStore ? Colors.green : Colors.orange),
                            title: Text(t.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${t.codesDisplay}\nالموقع الحالي: ${asset?.locationName ?? location.label}'),
                            isThreeLine: true,
                            trailing: const Icon(Icons.chevron_left),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DieAssetDetailScreen(template: t))),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 🔧 تفاصيل القالب والأكشنات
// ============================================================

class DieAssetDetailScreen extends StatefulWidget {
  final DieTemplate template;
  const DieAssetDetailScreen({super.key, required this.template});

  @override
  State<DieAssetDetailScreen> createState() => _DieAssetDetailScreenState();
}

class _DieAssetDetailScreenState extends State<DieAssetDetailScreen> {
  late final String _factoryId;
  DieAssetModel? _asset;

  @override
  void initState() {
    super.initState();
    _factoryId = Provider.of<ShiftProvider>(context, listen: false).currentFactoryId;
    _load();
  }

  Future<void> _load() async {
    final snap = await FirebaseDatabase.instance.ref('factories/$_factoryId/dieAssets/${widget.template.id}').get();
    if (!mounted) return;
    setState(() {
      _asset = snap.value is Map ? DieAssetModel.fromJson(widget.template.id, snap.value as Map) : DieAssetModel.fromTemplate(widget.template, _factoryId);
    });
  }

  Future<void> _enterCorrection() async {
    final asset = _asset!;
    final removal = ValueNotifier<DieRemovalReason>(DieRemovalReason.defect);
    final priority = ValueNotifier<CorrectionPriority>(CorrectionPriority.normal);
    final technician = TextEditingController(text: asset.technicianName);
    final removalNotes = TextEditingController(text: asset.lastRemovalNotes);
    final repairTypes = TextEditingController(text: asset.repairTypes.join('، '));
    final repairNotes = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إدخال القالب للكوريكشن'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<DieRemovalReason>(valueListenable: removal, builder: (context, v, _) => DropdownButtonFormField<DieRemovalReason>(value: v, decoration: const InputDecoration(labelText: 'سبب رفع القالب من المكبس'), items: DieRemovalReason.values.map((e) => DropdownMenuItem(value: e, child: Text(e.label))).toList(), onChanged: (x) => removal.value = x ?? DieRemovalReason.defect)),
              ValueListenableBuilder<CorrectionPriority>(valueListenable: priority, builder: (context, v, _) => DropdownButtonFormField<CorrectionPriority>(value: v, decoration: const InputDecoration(labelText: 'الأولوية'), items: CorrectionPriority.values.map((e) => DropdownMenuItem(value: e, child: Text(e.label))).toList(), onChanged: (x) => priority.value = x ?? CorrectionPriority.normal)),
              TextField(controller: technician, decoration: const InputDecoration(labelText: 'اسم الفني')),
              TextField(controller: removalNotes, decoration: const InputDecoration(labelText: 'ملاحظات سبب الرفع')),
              TextField(controller: repairTypes, decoration: const InputDecoration(labelText: 'الإصلاح المطلوب: بولش، قطع بيرنج، لحام...')),
              TextField(controller: repairNotes, decoration: const InputDecoration(labelText: 'وصف الإصلاح')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('دخول الكوريكشن')),
        ],
      ),
    );
    if (ok == true) {
      final updated = asset.copyWith(
        location: DieAssetLocation.inCorrection,
        locationName: 'داخل الكوريكشن',
        correctionCount: asset.correctionCount + 1,
        lastRemovalReason: removal.value,
        lastRemovalNotes: removalNotes.text.trim(),
        priority: priority.value,
        technicianName: technician.text.trim(),
        repairTypes: _strList(repairTypes.text),
        repairNotes: repairNotes.text.trim(),
        readyAt: null,
      );
      await DieTracking.updateAsset(_factoryId, updated);
      final orderRef = FirebaseDatabase.instance.ref('factories/$_factoryId/dieCorrectionOrders').push();
      await orderRef.set(CorrectionOrderModel(
        id: orderRef.key ?? '',
        dieAssetId: asset.id,
        factoryId: _factoryId,
        dieName: asset.name,
        codesDisplay: asset.codesDisplay,
        removalReason: removal.value,
        removalNotes: removalNotes.text.trim(),
        priority: priority.value,
        technicianName: technician.text.trim(),
        repairTypes: _strList(repairTypes.text),
        repairNotes: repairNotes.text.trim(),
      ).toJson());
      final from = asset.location;
      await FirebaseDatabase.instance.ref('factories/$_factoryId/dieMovements').push().set(DieMovementModel(id: '', dieAssetId: asset.id, factoryId: _factoryId, fromLocation: from.label, toLocation: updated.locationName, note: 'دخول الكوريكشن', by: FirebaseAuth.instance.currentUser?.email ?? '').toJson());
      await _load();
    }
  }

  Future<void> _markReady() async {
    final asset = _asset!;
    final updated = asset.copyWith(location: DieAssetLocation.readyStore, locationName: 'جاهز في مخزن الكوريكشن', readyAt: DateTime.now(), damageReason: '');
    await DieTracking.updateAsset(_factoryId, updated);
    await FirebaseDatabase.instance.ref('factories/$_factoryId/dieMovements').push().set(DieMovementModel(id: '', dieAssetId: asset.id, factoryId: _factoryId, fromLocation: asset.location.label, toLocation: updated.locationName, note: 'تم تجهيز القالب', by: FirebaseAuth.instance.currentUser?.email ?? '').toJson());
    await FirebaseDatabase.instance.ref('factories/$_factoryId/dieCorrectionOrders').get().then((snap) {
      final val = snap.value;
      if (val is Map) {
        val.forEach((key, value) {
          if (value is Map && _s(value['dieAssetId']) == asset.id && _s(value['status']) == 'داخل الكوريكشن') {
            FirebaseDatabase.instance.ref('factories/$_factoryId/dieCorrectionOrders/$key').update({'status': 'جاهز', 'readyAt': DateTime.now().toIso8601String()});
          }
        });
      }
    });
    await _load();
  }

  Future<void> _markDamaged() async {
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل القالب كتالف'),
        content: TextField(controller: reason, decoration: const InputDecoration(labelText: 'سبب التلف: كسر، وزن زيادة، غير قابل للإصلاح...'), maxLines: 3),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('تسجيل التلف')),
        ],
      ),
    );
    if (ok == true && reason.text.trim().isNotEmpty) {
      final asset = _asset!;
      final updated = asset.copyWith(location: DieAssetLocation.damaged, locationName: 'تالف / سكراب', damageReason: reason.text.trim());
      await DieTracking.updateAsset(_factoryId, updated);
      await FirebaseDatabase.instance.ref('factories/$_factoryId/dieMovements').push().set(DieMovementModel(id: '', dieAssetId: asset.id, factoryId: _factoryId, fromLocation: asset.location.label, toLocation: updated.locationName, note: reason.text.trim(), by: FirebaseAuth.instance.currentUser?.email ?? '').toJson());
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final asset = _asset;
    if (asset == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: Text('🔧 ${asset.name}')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: ListTile(
              title: Text(asset.codesDisplay),
              subtitle: Text('المقاس: ${asset.sizeDisplay}\nالموقع الحالي: ${asset.locationName}\nعدد مرات الكبس: ${asset.pressCount} | عدد دخول الكوريكشن: ${asset.correctionCount}'),
              isThreeLine: true,
            ),
          ),
          if (asset.location == DieAssetLocation.damaged && asset.damageReason.isNotEmpty)
            Card(color: Colors.red.shade50, child: ListTile(leading: const Icon(Icons.broken_image, color: Colors.red), title: Text('سبب التلف: ${asset.damageReason}'))),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (asset.location == DieAssetLocation.inSoda || asset.location == DieAssetLocation.unknown || asset.location == DieAssetLocation.readyStore)
                ElevatedButton.icon(onPressed: _enterCorrection, icon: const Icon(Icons.build), label: const Text('إدخال للكوريكشن')),
              if (asset.location == DieAssetLocation.inCorrection)
                ElevatedButton.icon(onPressed: _markReady, icon: const Icon(Icons.check_circle), label: const Text('جاهز')),
              ElevatedButton.icon(onPressed: _markDamaged, icon: const Icon(Icons.broken_image), label: const Text('تالف')),
            ],
          ),
          const SizedBox(height: 12),
          const Text('سجل الحركة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          StreamBuilder<DatabaseEvent>(
            stream: FirebaseDatabase.instance.ref('factories/$_factoryId/dieMovements').onValue,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              final val = snapshot.data!.snapshot.value;
              final moves = <DieMovementModel>[];
              if (val is Map) {
                val.forEach((key, value) {
                  if (value is Map && _s(value['dieAssetId']) == asset.id) moves.add(DieMovementModel.fromJson(key.toString(), value));
                });
              }
              moves.sort((a, b) => b.at.compareTo(a.at));
              if (moves.isEmpty) return const Padding(padding: EdgeInsets.all(8), child: Text('لا يوجد سجل حركة بعد'));
              return Column(children: moves.map((m) => ListTile(leading: const Icon(Icons.history), title: Text('${m.fromLocation} ← ${m.toLocation}'), subtitle: Text('${m.note}\nبواسطة: ${m.by} • ${m.at}'), isThreeLine: true)).toList());
            },
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 📋 شاشة قوائم جاهز/عالق/تالف
// ============================================================

class DieAssetListScreen extends StatelessWidget {
  final DieAssetLocation location;
  final String title;
  const DieAssetListScreen({super.key, required this.location, required this.title});

  @override
  Widget build(BuildContext context) {
    final factoryId = Provider.of<ShiftProvider>(context, listen: false).currentFactoryId;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: StreamBuilder<DatabaseEvent>(
        stream: FirebaseDatabase.instance.ref('factories/$factoryId/dieAssets').onValue,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final val = snapshot.data!.snapshot.value;
          final assets = <DieAssetModel>[];
          if (val is Map) {
            val.forEach((key, value) {
              if (value is Map) {
                final a = DieAssetModel.fromJson(key.toString(), value);
                if (a.location == location) assets.add(a);
              }
            });
          }
          assets.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          if (assets.isEmpty) return const Center(child: Text('لا توجد قوالب في هذه القائمة'));
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: assets.length,
            itemBuilder: (context, index) {
              final a = assets[index];
              return Card(
                child: ListTile(
                  title: Text(a.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${a.codesDisplay}\n${a.locationName} • آخر تحديث: ${a.updatedAt}'),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
