import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'die_template_model.dart';
import 'services.dart';
import 'app_localization.dart';

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

String _fixName(String name) {
  if (name.startsWith('قطعة ')) return name.replaceFirst('قطعة ', 'قالب ');
  return name;
}

enum DieAssetLocation { unknown, onPress, inSoda, inDieFurnace, inCorrection, readyStore, damaged }
enum CorrectionPriority { normal, important, urgent }
enum DieRemovalReason { ok, defect, productionFinished, sizeChange, transferPress, other }

extension DieAssetLocationX on DieAssetLocation {
  String get label => AppStrings.trStatic(_key);
  String get _key {
    switch (this) {
      case DieAssetLocation.unknown: return 'loc_unknown';
      case DieAssetLocation.onPress: return 'loc_on_press';
      case DieAssetLocation.inSoda: return 'loc_in_soda';
      case DieAssetLocation.inDieFurnace: return 'loc_in_die_furnace';
      case DieAssetLocation.inCorrection: return 'loc_in_correction';
      case DieAssetLocation.readyStore: return 'loc_ready_store';
      case DieAssetLocation.damaged: return 'loc_damaged';
    }
  }
}

extension CorrectionPriorityX on CorrectionPriority {
  String get label => AppStrings.trStatic(_key);
  String get _key {
    switch (this) {
      case CorrectionPriority.normal: return 'priority_normal';
      case CorrectionPriority.important: return 'priority_important';
      case CorrectionPriority.urgent: return 'priority_urgent';
    }
  }
}

extension DieRemovalReasonX on DieRemovalReason {
  String get label => AppStrings.trStatic(_key);
  String get _key {
    switch (this) {
      case DieRemovalReason.ok: return 'reason_ok';
      case DieRemovalReason.defect: return 'reason_defect';
      case DieRemovalReason.productionFinished: return 'reason_prod_finished';
      case DieRemovalReason.sizeChange: return 'reason_size_change';
      case DieRemovalReason.transferPress: return 'reason_transfer_press';
      case DieRemovalReason.other: return 'reason_other';
    }
  }
}

T _enumFromName<T extends Enum>(List<T> values, dynamic name, T fallback) {
  final n = name?.toString();
  for (final v in values) { if (v.name == n) return v; }
  return fallback;
}

class DieAssetModel {
  final String id; final String name; final String profileCode; final String designCode; final String clientCode; final String fullCode; final String factoryId; final String dieType; final double widthMm; final double heightMm; final DieAssetLocation location; final String locationName; final String pressId; final String pressName; final String pressSize; final int pressCount; final int correctionCount; final DieRemovalReason lastRemovalReason; final String lastRemovalNotes; final CorrectionPriority priority; final String technicianName; final List<String> repairTypes; final String repairNotes; final String damageReason; final DateTime? readyAt; final DateTime createdAt; final DateTime updatedAt;

  DieAssetModel({required this.id, required this.name, required this.profileCode, required this.designCode, required this.clientCode, required this.fullCode, required this.factoryId, this.dieType = '', this.widthMm = 0, this.heightMm = 0, this.location = DieAssetLocation.unknown, this.locationName = '', this.pressId = '', this.pressName = '', this.pressSize = '', this.pressCount = 0, this.correctionCount = 0, this.lastRemovalReason = DieRemovalReason.other, this.lastRemovalNotes = '', this.priority = CorrectionPriority.normal, this.technicianName = '', this.repairTypes = const [], this.repairNotes = '', this.damageReason = '', this.readyAt, DateTime? createdAt, DateTime? updatedAt}) : createdAt = createdAt ?? DateTime.now(), updatedAt = updatedAt ?? DateTime.now();

  factory DieAssetModel.fromTemplate(DieTemplate t, String factoryId) => DieAssetModel(id: t.id, name: t.name, profileCode: t.dieCode, designCode: t.designCode, clientCode: t.clientCode, fullCode: t.fullCode, factoryId: factoryId, dieType: t.type ?? '', widthMm: t.widthMm ?? 0, heightMm: t.heightMm ?? 0);

  factory DieAssetModel.fromJson(String id, Map<dynamic, dynamic> json) => DieAssetModel(id: id, name: _s(json['name'], id), profileCode: _s(json['profileCode']), designCode: _s(json['designCode']), clientCode: _s(json['clientCode']), fullCode: _s(json['fullCode']), factoryId: _s(json['factoryId']), dieType: _s(json['dieType']), widthMm: _d(json['widthMm']), heightMm: _d(json['heightMm']), location: _enumFromName(DieAssetLocation.values, json['location'], DieAssetLocation.unknown), locationName: _s(json['locationName']), pressId: _s(json['pressId']), pressName: _s(json['pressName']), pressSize: _s(json['pressSize']), pressCount: _i(json['pressCount']), correctionCount: _i(json['correctionCount']), lastRemovalReason: _enumFromName(DieRemovalReason.values, json['lastRemovalReason'], DieRemovalReason.other), lastRemovalNotes: _s(json['lastRemovalNotes']), priority: _enumFromName(CorrectionPriority.values, json['priority'], CorrectionPriority.normal), technicianName: _s(json['technicianName']), repairTypes: _strList(json['repairTypes']), repairNotes: _s(json['repairNotes']), damageReason: _s(json['damageReason']), readyAt: json['readyAt'] == null ? null : _dt(json['readyAt']), createdAt: _dt(json['createdAt']), updatedAt: _dt(json['updatedAt']));

  Map<String, dynamic> toJson() => {'name': name, 'profileCode': profileCode, 'designCode': designCode, 'clientCode': clientCode, 'fullCode': fullCode, 'factoryId': factoryId, 'dieType': dieType, 'widthMm': widthMm, 'heightMm': heightMm, 'location': location.name, 'locationName': locationName, 'pressId': pressId, 'pressName': pressName, 'pressSize': pressSize, 'pressCount': pressCount, 'correctionCount': correctionCount, 'lastRemovalReason': lastRemovalReason.name, 'lastRemovalNotes': lastRemovalNotes, 'priority': priority.name, 'technicianName': technicianName, 'repairTypes': repairTypes, 'repairNotes': repairNotes, 'damageReason': damageReason, 'readyAt': readyAt?.toIso8601String(), 'createdAt': createdAt.toIso8601String(), 'updatedAt': updatedAt.toIso8601String()};

  String get codesDisplay => 'القطاع: $profileCode | التصميم: $designCode | العميل: $clientCode';
  String get sizeDisplay {
    final type = dieType.isEmpty ? '' : '$dieType - ';
    if (widthMm > 0 && heightMm > 0) return '$type${widthMm.toStringAsFixed(0)}×${heightMm.toStringAsFixed(0)} مم';
    return type.trim();
  }

  DieAssetModel copyWith({String? dieType, double? widthMm, double? heightMm, DieAssetLocation? location, String? locationName, String? pressId, String? pressName, String? pressSize, int? pressCount, int? correctionCount, DieRemovalReason? lastRemovalReason, String? lastRemovalNotes, CorrectionPriority? priority, String? technicianName, List<String>? repairTypes, String? repairNotes, String? damageReason, DateTime? readyAt, DateTime? updatedAt}) => DieAssetModel(id: id, name: name, profileCode: profileCode, designCode: designCode, clientCode: clientCode, fullCode: fullCode, factoryId: factoryId, dieType: dieType ?? this.dieType, widthMm: widthMm ?? this.widthMm, heightMm: heightMm ?? this.heightMm, location: location ?? this.location, locationName: locationName ?? this.locationName, pressId: pressId ?? this.pressId, pressName: pressName ?? this.pressName, pressSize: pressSize ?? this.pressSize, pressCount: pressCount ?? this.pressCount, correctionCount: correctionCount ?? this.correctionCount, lastRemovalReason: lastRemovalReason ?? this.lastRemovalReason, lastRemovalNotes: lastRemovalNotes ?? this.lastRemovalNotes, priority: priority ?? this.priority, technicianName: technicianName ?? this.technicianName, repairTypes: repairTypes ?? this.repairTypes, repairNotes: repairNotes ?? this.repairNotes, damageReason: damageReason ?? this.damageReason, readyAt: readyAt ?? this.readyAt, createdAt: createdAt, updatedAt: updatedAt ?? DateTime.now());
}

class DieMovementModel {
  final String id; final String dieAssetId; final String factoryId; final String fromLocation; final String toLocation; final String note; final String by; final DateTime at;
  DieMovementModel({required this.id, required this.dieAssetId, required this.factoryId, this.fromLocation = '', this.toLocation = '', this.note = '', this.by = '', DateTime? at}) : at = at ?? DateTime.now();
  factory DieMovementModel.fromJson(String id, Map<dynamic, dynamic> json) => DieMovementModel(id: id, dieAssetId: _s(json['dieAssetId']), factoryId: _s(json['factoryId']), fromLocation: _s(json['fromLocation']), toLocation: _s(json['toLocation']), note: _s(json['note']), by: _s(json['by']), at: _dt(json['at']));
  Map<String, dynamic> toJson() => {'dieAssetId': dieAssetId, 'factoryId': factoryId, 'fromLocation': fromLocation, 'toLocation': toLocation, 'note': note, 'by': by, 'at': at.toIso8601String()};
}

class CorrectionOrderModel {
  final String id; final String dieAssetId; final String factoryId; final String dieName; final String codesDisplay; final DieRemovalReason removalReason; final String removalNotes; final CorrectionPriority priority; final String status; final String technicianName; final List<String> repairTypes; final String repairNotes; final String damageReason; final DateTime createdAt; final DateTime? readyAt;
  CorrectionOrderModel({required this.id, required this.dieAssetId, required this.factoryId, required this.dieName, this.codesDisplay = '', this.removalReason = DieRemovalReason.defect, this.removalNotes = '', this.priority = CorrectionPriority.normal, this.status = 'داخل الكوريكشن', this.technicianName = '', this.repairTypes = const [], this.repairNotes = '', this.damageReason = '', DateTime? createdAt, this.readyAt}) : createdAt = createdAt ?? DateTime.now();
  factory CorrectionOrderModel.fromJson(String id, Map<dynamic, dynamic> json) => CorrectionOrderModel(id: id, dieAssetId: _s(json['dieAssetId']), factoryId: _s(json['factoryId']), dieName: _s(json['dieName']), codesDisplay: _s(json['codesDisplay']), removalReason: _enumFromName(DieRemovalReason.values, json['removalReason'], DieRemovalReason.defect), removalNotes: _s(json['removalNotes']), priority: _enumFromName(CorrectionPriority.values, json['priority'], CorrectionPriority.normal), status: _s(json['status'], 'داخل الكوريكشن'), technicianName: _s(json['technicianName']), repairTypes: _strList(json['repairTypes']), repairNotes: _s(json['repairNotes']), damageReason: _s(json['damageReason']), createdAt: _dt(json['createdAt']), readyAt: json['readyAt'] == null ? null : _dt(json['readyAt']));
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
    val.forEach((key, value) { if (value is Map) templates.add(DieTemplate.fromJson(key.toString(), Map<String, dynamic>.from(value))); });
    for (final code in codes) { final q = code.trim(); if (q.isEmpty) continue; for (final t in templates) { if (t.matchesExactCode(q)) return t; } }
    for (final code in codes) { final q = code.trim(); if (q.isEmpty) continue; for (final t in templates) { if (t.matchesAnyCode(q)) return t; } }
    return null;
  }

  static Future<DieAssetLocation?> findLocation(String factoryId, List<String> codes) async {
    final template = await findTemplate(factoryId, codes);
    if (template == null) return null;
    final snap = await _assetsRef(factoryId).child(template.id).get();
    if (snap.value is Map) return DieAssetModel.fromJson(template.id, snap.value as Map).location;
    return DieAssetLocation.unknown;
  }

  static Future<DieAssetModel> _getOrCreateAsset(String factoryId, DieTemplate template) async {
    final snap = await _assetsRef(factoryId).child(template.id).get();
    if (snap.value is Map) return DieAssetModel.fromJson(template.id, snap.value as Map);
    return DieAssetModel.fromTemplate(template, factoryId);
  }

  static Future<void> _addMovement(String factoryId, DieAssetModel asset, String from, String to, String note) async {
    final user = FirebaseAuth.instance.currentUser;
    final ref = _movementsRef(factoryId).push();
    await ref.set(DieMovementModel(id: ref.key ?? '', dieAssetId: asset.id, factoryId: factoryId, fromLocation: from, toLocation: to, note: note, by: user?.email ?? '').toJson());
  }

  static Future<void> recordPressExit({required String factoryId, required List<String> codes, required String pressId, required String pressName, required String pressSize}) async {
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
  void dispose() { _searchController.dispose(); super.dispose(); }

  List<DieTemplate> _parseTemplates(DatabaseEvent event) {
    final list = <DieTemplate>[];
    final val = event.snapshot.value;
    if (val is Map) {
      val.forEach((key, value) { if (value is Map) list.add(DieTemplate.fromJson(key.toString(), Map<String, dynamic>.from(value))); });
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
    return SelectionArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.tr('die_correction_title')),
          actions: [
            IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DieAssetListScreen(location: DieAssetLocation.readyStore, title: context.tr('ready_dies')))), icon: const Icon(Icons.check_circle)),
            IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DieAssetListScreen(location: DieAssetLocation.inCorrection, title: context.tr('stuck_dies')))), icon: const Icon(Icons.warning_amber)),
            IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DieAssetListScreen(location: DieAssetLocation.damaged, title: context.tr('damaged_dies')))), icon: const Icon(Icons.broken_image)),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            final newTemplate = await showDialog<DieTemplate>(
              context: context,
              builder: (context) => const SmartDieSearchDialog(),
            );
            if (newTemplate != null) {
              if (context.mounted) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => DieAssetDetailScreen(template: newTemplate)));
              }
            }
          },
          icon: const Icon(Icons.add),
          label: Text(context.tr('add_die_correction')),
          backgroundColor: Colors.blue,
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: context.tr('search_list_hint'),
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
                  if (_query.isNotEmpty) templates = templates.where((t) => t.matchesAnyCode(_query)).toList();
                  if (templates.isEmpty) return Center(child: Text(context.tr('no_matching_dies')));
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
                          final displayName = _fixName(t.displayName);
                          
                          return Card(
                            child: ListTile(
                              leading: Icon(location == DieAssetLocation.inCorrection ? Icons.build : location == DieAssetLocation.readyStore ? Icons.check_circle : location == DieAssetLocation.damaged ? Icons.broken_image : Icons.location_on, color: location == DieAssetLocation.damaged ? Colors.red : location == DieAssetLocation.readyStore ? Colors.green : Colors.orange),
                              title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
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
      ),
    );
  }
}

// ============================================================
// ✅ نافذة البحث الذكي الشامل
// ============================================================

class SmartDieSearchDialog extends StatefulWidget {
  const SmartDieSearchDialog({super.key});
  @override
  State<SmartDieSearchDialog> createState() => _SmartDieSearchDialogState();
}

class _SmartDieSearchDialogState extends State<SmartDieSearchDialog> {
  final _code = TextEditingController();
  List<DieTemplate> _results = [];
  bool _isSearching = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _code.addListener(_onSearch);
  }

  @override
  void dispose() {
    _code.removeListener(_onSearch);
    _debounce?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _onSearch() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () async {
      final query = _code.text.trim();
      if (query.length < 3) {
        setState(() => _results = []);
        return;
      }
      setState(() => _isSearching = true);
      try {
        final factoryId = Provider.of<ShiftProvider>(context, listen: false).currentFactoryId;
        final all = await Provider.of<ShiftProvider>(context, listen: false).service.getDieTemplates(factoryId);
        
        final matches = all.where((t) => 
          t.dieCode.toLowerCase().contains(query.toLowerCase()) || 
          t.designCode.toLowerCase().contains(query.toLowerCase()) || 
          t.clientCode.toLowerCase().contains(query.toLowerCase()) ||
          t.fullCode.toLowerCase().contains(query.toLowerCase())
        ).toList();
        
        setState(() => _results = matches);
      } finally {
        if (mounted) setState(() => _isSearching = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr('smart_search_title')),
      content: SizedBox(
        width: 500, height: 400,
        child: Column(
          children: [
            TextField(
              controller: _code,
              decoration: InputDecoration(
                labelText: context.tr('enter_any_code_hint'),
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            if (_isSearching) const LinearProgressIndicator(),
            Expanded(
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, i) {
                  final t = _results[i];
                  return Card(
                    child: ListTile(
                      title: Text(t.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${context.tr('profile_code_word')}: ${t.dieCode} | ${context.tr('design_code_word')}: ${t.designCode} | ${context.tr('client_code_word')}: ${t.clientCode}\n${context.tr('version_word')}: ${t.version ?? context.tr('no_version')} | ${context.tr('size_label')}: ${t.widthMm ?? "?"}×${t.heightMm ?? "?"} مم'),
                      isThreeLine: true,
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () => Navigator.pop(context, t),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          icon: const Icon(Icons.add, color: Colors.blue),
          label: Text(context.tr('die_not_in_list_add')),
          onPressed: () async {
            final factoryId = Provider.of<ShiftProvider>(context, listen: false).currentFactoryId;
            final t = await showDialog<DieTemplate>(
              context: context,
              builder: (_) => DieTemplateFormDialog(factoryId: factoryId),
            );
            if (t != null && context.mounted) Navigator.pop(context, t);
          },
        ),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(context.tr('cancel'))),
      ],
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
        title: Text(context.tr('enter_correction_title')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<DieRemovalReason>(valueListenable: removal, builder: (context, v, _) => DropdownButtonFormField<DieRemovalReason>(value: v, decoration: InputDecoration(labelText: context.tr('removal_reason_label')), items: DieRemovalReason.values.map((e) => DropdownMenuItem(value: e, child: Text(e.label))).toList(), onChanged: (x) => removal.value = x ?? DieRemovalReason.defect)),
              ValueListenableBuilder<CorrectionPriority>(valueListenable: priority, builder: (context, v, _) => DropdownButtonFormField<CorrectionPriority>(value: v, decoration: InputDecoration(labelText: context.tr('priority_label')), items: CorrectionPriority.values.map((e) => DropdownMenuItem(value: e, child: Text(e.label))).toList(), onChanged: (x) => priority.value = x ?? CorrectionPriority.normal)),
              TextField(controller: technician, decoration: InputDecoration(labelText: context.tr('technician_name_label'))),
              TextField(controller: removalNotes, decoration: InputDecoration(labelText: context.tr('removal_notes_label'))),
              TextField(controller: repairTypes, decoration: InputDecoration(labelText: context.tr('repair_types_label'))),
              TextField(controller: repairNotes, decoration: InputDecoration(labelText: context.tr('repair_notes_label'))),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.tr('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(context.tr('enter_correction_btn'))),
        ],
      ),
    );
    if (ok == true) {
      final updated = asset.copyWith(location: DieAssetLocation.inCorrection, locationName: 'داخل الكوريكشن', correctionCount: asset.correctionCount + 1, lastRemovalReason: removal.value, lastRemovalNotes: removalNotes.text.trim(), priority: priority.value, technicianName: technician.text.trim(), repairTypes: _strList(repairTypes.text), repairNotes: repairNotes.text.trim(), readyAt: null);
      await DieTracking.updateAsset(_factoryId, updated);
      final orderRef = FirebaseDatabase.instance.ref('factories/$_factoryId/dieCorrectionOrders').push();
      await orderRef.set(CorrectionOrderModel(id: orderRef.key ?? '', dieAssetId: asset.id, factoryId: _factoryId, dieName: _fixName(asset.name), codesDisplay: asset.codesDisplay, removalReason: removal.value, removalNotes: removalNotes.text.trim(), priority: priority.value, technicianName: technician.text.trim(), repairTypes: _strList(repairTypes.text), repairNotes: repairNotes.text.trim()).toJson());
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
        title: Text(context.tr('register_damage_title')),
        content: TextField(controller: reason, decoration: InputDecoration(labelText: context.tr('damage_reason_hint')), maxLines: 3),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.tr('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(context.tr('register_damage_btn'))),
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
    return SelectionArea(
      child: Scaffold(
        appBar: AppBar(title: Text('🔧 ${_fixName(asset.name)}')),
        body: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Card(
              child: ListTile(
                title: Text(asset.codesDisplay),
                subtitle: Text('${context.tr('size_label')}: ${asset.sizeDisplay}\n${context.tr('current_location_label')}: ${asset.locationName}\n${context.tr('press_count_label')}: ${asset.pressCount} | ${context.tr('correction_count_label')}: ${asset.correctionCount}'),
                isThreeLine: true,
              ),
            ),
            if (asset.location == DieAssetLocation.damaged && asset.damageReason.isNotEmpty)
              Card(color: Colors.red.shade50, child: ListTile(leading: const Icon(Icons.broken_image, color: Colors.red), title: Text('${context.tr('damage_reason_label')}: ${asset.damageReason}'))),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (asset.location == DieAssetLocation.inSoda || asset.location == DieAssetLocation.unknown || asset.location == DieAssetLocation.readyStore)
                  ElevatedButton.icon(onPressed: _enterCorrection, icon: const Icon(Icons.build), label: Text(context.tr('enter_correction_btn'))),
                if (asset.location == DieAssetLocation.inCorrection)
                  ElevatedButton.icon(onPressed: _markReady, icon: const Icon(Icons.check_circle), label: Text(context.tr('mark_ready_btn'))),
                ElevatedButton.icon(onPressed: _markDamaged, icon: const Icon(Icons.broken_image), label: Text(context.tr('mark_damaged_btn'))),
              ],
            ),
            const SizedBox(height: 12),
            Text(context.tr('movement_log_title'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            StreamBuilder<DatabaseEvent>(
              stream: FirebaseDatabase.instance.ref('factories/$_factoryId/dieMovements').onValue,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                final val = snapshot.data!.snapshot.value;
                final moves = <DieMovementModel>[];
                if (val is Map) {
                  val.forEach((key, value) { if (value is Map && _s(value['dieAssetId']) == asset.id) moves.add(DieMovementModel.fromJson(key.toString(), value)); });
                }
                moves.sort((a, b) => b.at.compareTo(a.at));
                if (moves.isEmpty) return Padding(padding: const EdgeInsets.all(8), child: Text(context.tr('no_movement_yet')));
                return Column(children: moves.map((m) => ListTile(leading: const Icon(Icons.history), title: Text('${m.fromLocation} ← ${m.toLocation}'), subtitle: Text('${m.note}\nبواسطة: ${m.by} • ${m.at}'), isThreeLine: true)).toList());
              },
            ),
          ],
        ),
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
    return SelectionArea(
      child: Scaffold(
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
            if (assets.isEmpty) return Center(child: Text(context.tr('no_dies_in_list')));
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: assets.length,
              itemBuilder: (context, index) {
                final a = assets[index];
                return Card(
                  child: ListTile(
                    title: Text(_fixName(a.name), style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${a.codesDisplay}\n${a.locationName} • آخر تحديث: ${a.updatedAt}'),
                    isThreeLine: true,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ============================================================
// ➕ نافذة إضافة قالب جديد (الأكواد الثلاثة + النسخة + المقاس)
// ============================================================
class DieTemplateFormDialog extends StatefulWidget {
  final String factoryId;
  const DieTemplateFormDialog({super.key, required this.factoryId});
  @override
  State<DieTemplateFormDialog> createState() => _DieTemplateFormDialogState();
}

class _DieTemplateFormDialogState extends State<DieTemplateFormDialog> {
  final _name = TextEditingController();
  final _dieCode = TextEditingController();
  final _clientCode = TextEditingController();
  final _designCode = TextEditingController();
  final _version = TextEditingController();
  final _width = TextEditingController();
  final _height = TextEditingController();
  String _type = 'hollow';
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose(); _dieCode.dispose(); _clientCode.dispose();
    _designCode.dispose(); _version.dispose(); _width.dispose(); _height.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_dieCode.text.trim().isEmpty || _clientCode.text.trim().isEmpty ||
        _designCode.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('codes_required'))));
      return;
    }
    setState(() => _saving = true);
    try {
      final ver = _version.text.trim();
      final fullCode = ver.isEmpty ? _dieCode.text.trim()
                                   : '${_dieCode.text.trim()}/$ver';
      final ref = FirebaseDatabase.instance
          .ref('factories/${widget.factoryId}/dieTemplates').push();
      final template = DieTemplate(
        id: ref.key ?? '',
        name: _name.text.trim().isEmpty ? fullCode : _name.text.trim(),
        clientCode: _clientCode.text.trim(),
        designCode: _designCode.text.trim(),
        dieCode: _dieCode.text.trim(),
        version: ver.isEmpty ? null : ver,
        fullCode: fullCode,
        factoryId: widget.factoryId,
        type: _type,
        widthMm: double.tryParse(_width.text) ?? 0,
        heightMm: double.tryParse(_height.text) ?? 0,
      );
      await ref.set(template.toJson());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.tr('die_saved_success'))));
        Navigator.pop(context, template);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(context.trP('die_save_failed', {'e': e.toString()}))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration dec(String label) => InputDecoration(
        labelText: label, border: const OutlineInputBorder(), isDense: true);
    return AlertDialog(
      title: Text(context.tr('new_die_title')),
      content: SizedBox(
        width: 550,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Expanded(child: TextField(controller: _dieCode, decoration: dec(context.tr('die_profile_code_label')))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _clientCode, decoration: dec(context.tr('die_client_code_label')))),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: _designCode, decoration: dec(context.tr('die_design_code_label')))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _version, decoration: dec(context.tr('die_version_label')))),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: _name, decoration: dec(context.tr('die_name_optional')))),
              const SizedBox(width: 8),
              Expanded(child: DropdownButtonFormField<String>(
                value: _type, isDense: true,
                decoration: dec(context.tr('die_type_label')),
                items: [
                  DropdownMenuItem(value: 'hollow', child: Text(context.tr('hollow_type'))),
                  DropdownMenuItem(value: 'solid', child: Text(context.tr('solid_type'))),
                ],
                onChanged: (v) => setState(() => _type = v ?? 'hollow'),
              )),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: _width, keyboardType: TextInputType.number, decoration: dec(context.tr('die_width_label')))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _height, keyboardType: TextInputType.number, decoration: dec(context.tr('die_height_label')))),
            ]),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context),
            child: Text(context.tr('cancel'))),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.save),
          label: Text(context.tr('save_die_btn')),
        ),
      ],
    );
  }
}