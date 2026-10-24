import 'dart:math';
import 'app_localization.dart';

const double ALUMINUM_DENSITY = 2.7;
const double CM_PER_INCH = 2.54;

// ============================================================
// 🌐 كلمات الوحدات حسب اللغة الحالية
// ============================================================
bool get _isArabicNow => LocaleProvider.currentLanguage == AppLanguage.ar;
String get _wordHour => _isArabicNow ? 'ساعة' : 'hour';
String get _wordMinute => _isArabicNow ? 'دقيقة' : 'min';
String get _wordTon => _isArabicNow ? 'طن' : 'ton';
String get _wordKg => _isArabicNow ? 'كجم' : 'kg';
String get _wordMm => _isArabicNow ? 'مم' : 'mm';
String get _wordInch => _isArabicNow ? 'بوصة' : 'in';

// ============================================================
// ✅ تحويل آمن لأي Map راجعة من Firebase
// ============================================================
Map<String, dynamic> safeMapCast(dynamic value) {
  if (value == null) return <String, dynamic>{};
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, val) => MapEntry(key.toString(), val));
  }
  return <String, dynamic>{};
}

// ============================================================
// ✅ حالة القالب
// ============================================================
enum DieStatus {
  draft,
  active,
  completed,
}

// ============================================================
// ✅ سجل العطل
// ============================================================
class WasteRecord {
  final int minutes;
  final String reason;
  final DateTime timestamp;

  WasteRecord({
    required this.minutes,
    required this.reason,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'minutes': minutes,
      'reason': reason,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory WasteRecord.fromJson(Map<String, dynamic> json) {
    return WasteRecord(
      minutes: json['minutes'] is int 
          ? json['minutes'] 
          : int.tryParse(json['minutes']?.toString() ?? '0') ?? 0,
      reason: json['reason']?.toString() ?? '',
      timestamp: json['timestamp'] != null 
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String get formatted {
    return '$reason: $minutes $_wordMinute';
  }
}

// ============================================================
// 🔥 حالة الفرن
// ============================================================
enum FurnaceStatus {
  idle,
  heating,
  holding,
  cooling,
  error,
}

// ============================================================
// 🔥 دورة الفرن
// ============================================================
class FurnaceCycle {
  final String id;
  final DateTime startTime;
  final DateTime? endTime;
  final double startTemperature;
  final double? endTemperature;
  final double targetTemperature;
  final double? maxTemperature;
  final double? minTemperature;
  final String notes;
  final String? supervisorId;
  final String? supervisorName;
  final List<String> dieIds;

  FurnaceCycle({
    required this.id,
    required this.startTime,
    this.endTime,
    required this.startTemperature,
    this.endTemperature,
    required this.targetTemperature,
    this.maxTemperature,
    this.minTemperature,
    this.notes = '',
    this.supervisorId,
    this.supervisorName,
    this.dieIds = const [],
  });

  int get durationMinutes {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime).inMinutes;
  }

  String get durationFormatted {
    final minutes = durationMinutes;
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      return '$hours $_wordHour $remainingMinutes $_wordMinute';
    }
    return '$minutes $_wordMinute';
  }

  bool get isActive => endTime == null;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'startTemperature': startTemperature,
      'endTemperature': endTemperature,
      'targetTemperature': targetTemperature,
      'maxTemperature': maxTemperature,
      'minTemperature': minTemperature,
      'notes': notes,
      'supervisorId': supervisorId,
      'supervisorName': supervisorName,
      'dieIds': dieIds,
    };
  }

  factory FurnaceCycle.fromJson(String id, Map<String, dynamic> json) {
    return FurnaceCycle(
      id: id,
      startTime: json['startTime'] != null 
          ? DateTime.tryParse(json['startTime'].toString()) ?? DateTime.now()
          : DateTime.now(),
      endTime: json['endTime'] != null 
          ? DateTime.tryParse(json['endTime'].toString())
          : null,
      startTemperature: json['startTemperature'] is num 
          ? (json['startTemperature'] as num).toDouble()
          : 0.0,
      endTemperature: json['endTemperature'] is num 
          ? (json['endTemperature'] as num).toDouble()
          : null,
      targetTemperature: json['targetTemperature'] is num 
          ? (json['targetTemperature'] as num).toDouble()
          : 0.0,
      maxTemperature: json['maxTemperature'] is num 
          ? (json['maxTemperature'] as num).toDouble()
          : null,
      minTemperature: json['minTemperature'] is num 
          ? (json['minTemperature'] as num).toDouble()
          : null,
      notes: json['notes']?.toString() ?? '',
      supervisorId: json['supervisorId']?.toString(),
      supervisorName: json['supervisorName']?.toString(),
      dieIds: json['dieIds'] is List 
          ? List<String>.from(json['dieIds']) 
          : [],
    );
  }

  FurnaceCycle copyWith({
    String? id,
    DateTime? startTime,
    DateTime? endTime,
    double? startTemperature,
    double? endTemperature,
    double? targetTemperature,
    double? maxTemperature,
    double? minTemperature,
    String? notes,
    String? supervisorId,
    String? supervisorName,
    List<String>? dieIds,
  }) {
    return FurnaceCycle(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      startTemperature: startTemperature ?? this.startTemperature,
      endTemperature: endTemperature ?? this.endTemperature,
      targetTemperature: targetTemperature ?? this.targetTemperature,
      maxTemperature: maxTemperature ?? this.maxTemperature,
      minTemperature: minTemperature ?? this.minTemperature,
      notes: notes ?? this.notes,
      supervisorId: supervisorId ?? this.supervisorId,
      supervisorName: supervisorName ?? this.supervisorName,
      dieIds: dieIds ?? this.dieIds,
    );
  }
}

// ============================================================
// 🔥 نموذج الفرن (Furnace)
// ============================================================
class FurnaceModel {
  final String id;
  final String name;
  final String factoryId;
  final double targetTemperature;
  final double currentTemperature;
  final FurnaceStatus status;
  final bool isActive;
  final List<FurnaceCycle> cycles;
  final DateTime createdAt;
  final String? supervisorId;
  final double hollowHeatingTime;
  final double solidHeatingTime;
  final String pressId;
  final String pressName;

  FurnaceModel({
    required this.id,
    required this.name,
    required this.factoryId,
    required this.targetTemperature,
    this.currentTemperature = 0.0,
    this.status = FurnaceStatus.idle,
    this.isActive = true,
    this.cycles = const [],
    required this.createdAt,
    this.supervisorId,
    this.hollowHeatingTime = 210.0,
    this.solidHeatingTime = 120.0,
    required this.pressId,
    required this.pressName,
  });

  FurnaceCycle? get currentCycle {
    try {
      return cycles.firstWhere((cycle) => cycle.isActive);
    } catch (e) {
      return null;
    }
  }

  int get totalCycles => cycles.length;
  int get completedCycles => cycles.where((c) => !c.isActive).length;

  double get averageTemperature {
    if (cycles.isEmpty) return 0.0;
    final total = cycles.fold(0.0, (sum, cycle) => sum + cycle.targetTemperature);
    return total / cycles.length;
  }

  double getHeatingTimeForType(String dieType) {
    return dieType == 'hollow' ? hollowHeatingTime : solidHeatingTime;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'factoryId': factoryId,
      'targetTemperature': targetTemperature,
      'currentTemperature': currentTemperature,
      'status': status.name,
      'isActive': isActive,
      'cycles': cycles.map((c) => c.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'supervisorId': supervisorId,
      'hollowHeatingTime': hollowHeatingTime,
      'solidHeatingTime': solidHeatingTime,
      'pressId': pressId,
      'pressName': pressName,
    };
  }

  factory FurnaceModel.fromJson(String id, Map<String, dynamic> json) {
    List<FurnaceCycle> cycles = [];
    if (json['cycles'] != null) {
      final cyclesList = json['cycles'] as List;
      cycles = cyclesList.map((cycle) {
        final cycleJson = safeMapCast(cycle);
        final cycleId = cycleJson['id']?.toString() ?? 'cycle_${DateTime.now().millisecondsSinceEpoch}';
        return FurnaceCycle.fromJson(cycleId, cycleJson);
      }).toList();
    }

    return FurnaceModel(
      id: id,
      name: json['name']?.toString() ?? '',
      factoryId: json['factoryId']?.toString() ?? '',
      targetTemperature: json['targetTemperature'] is num 
          ? (json['targetTemperature'] as num).toDouble()
          : 0.0,
      currentTemperature: json['currentTemperature'] is num 
          ? (json['currentTemperature'] as num).toDouble()
          : 0.0,
      status: json['status'] != null 
          ? FurnaceStatus.values.firstWhere(
              (e) => e.name == json['status'].toString(),
              orElse: () => FurnaceStatus.idle,
            )
          : FurnaceStatus.idle,
      isActive: json['isActive'] ?? true,
      cycles: cycles,
      createdAt: json['createdAt'] != null 
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      supervisorId: json['supervisorId']?.toString(),
      hollowHeatingTime: json['hollowHeatingTime'] is num 
          ? (json['hollowHeatingTime'] as num).toDouble()
          : 210.0,
      solidHeatingTime: json['solidHeatingTime'] is num 
          ? (json['solidHeatingTime'] as num).toDouble()
          : 120.0,
      pressId: json['pressId']?.toString() ?? '',
      pressName: json['pressName']?.toString() ?? '',
    );
  }

  FurnaceModel copyWith({
    String? id,
    String? name,
    String? factoryId,
    double? targetTemperature,
    double? currentTemperature,
    FurnaceStatus? status,
    bool? isActive,
    List<FurnaceCycle>? cycles,
    DateTime? createdAt,
    String? supervisorId,
    double? hollowHeatingTime,
    double? solidHeatingTime,
    String? pressId,
    String? pressName,
  }) {
    return FurnaceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      factoryId: factoryId ?? this.factoryId,
      targetTemperature: targetTemperature ?? this.targetTemperature,
      currentTemperature: currentTemperature ?? this.currentTemperature,
      status: status ?? this.status,
      isActive: isActive ?? this.isActive,
      cycles: cycles ?? this.cycles,
      createdAt: createdAt ?? this.createdAt,
      supervisorId: supervisorId ?? this.supervisorId,
      hollowHeatingTime: hollowHeatingTime ?? this.hollowHeatingTime,
      solidHeatingTime: solidHeatingTime ?? this.solidHeatingTime,
      pressId: pressId ?? this.pressId,
      pressName: pressName ?? this.pressName,
    );
  }

  FurnaceModel startCycle({
    required double startTemperature,
    required String? supervisorId,
    String? supervisorName,
    String? notes,
    List<String>? dieIds,
  }) {
    final newCycle = FurnaceCycle(
      id: 'cycle_${DateTime.now().millisecondsSinceEpoch}',
      startTime: DateTime.now(),
      startTemperature: startTemperature,
      targetTemperature: targetTemperature,
      notes: notes ?? '',
      supervisorId: supervisorId,
      supervisorName: supervisorName,
      dieIds: dieIds ?? [],
    );
    final updatedCycles = List<FurnaceCycle>.from(cycles)..add(newCycle);
    return copyWith(
      cycles: updatedCycles,
      status: FurnaceStatus.heating,
      currentTemperature: startTemperature,
    );
  }

  FurnaceModel endCycle({
    required double endTemperature,
    double? maxTemperature,
    double? minTemperature,
    String? notes,
  }) {
    final current = currentCycle;
    if (current == null) return this;
    
    final updatedCycle = current.copyWith(
      endTime: DateTime.now(),
      endTemperature: endTemperature,
      maxTemperature: maxTemperature,
      minTemperature: minTemperature,
      notes: notes ?? current.notes,
    );
    
    final updatedCycles = cycles.map((c) {
      return c.id == updatedCycle.id ? updatedCycle : c;
    }).toList();
    
    return copyWith(
      cycles: updatedCycles,
      status: FurnaceStatus.idle,
      currentTemperature: endTemperature,
    );
  }

  FurnaceModel updateTemperature(double temperature) {
    return copyWith(
      currentTemperature: temperature,
      status: temperature >= targetTemperature ? FurnaceStatus.holding : FurnaceStatus.heating,
    );
  }
}

// ============================================================
// 🔥 نموذج المكبس (Press)
// ============================================================
class PressModel {
  final String id;
  final String name;
  final String size;
  final double diameterInInches;
  final bool isActive;
  final double targetTonsPerHour;
  final double targetWastePercentage;

  PressModel({
    required this.id,
    required this.name,
    required this.size,
    required this.diameterInInches,
    this.isActive = true,
    this.targetTonsPerHour = 1.100,
    this.targetWastePercentage = 20.0,
  });

  String get sizeLabel => '${diameterInInches.toStringAsFixed(1)} $_wordInch';

  static String displaySizeFromRaw(String rawSize) {
    final numeric = rawSize.replaceAll(RegExp(r'[^0-9.]'), '');
    return '$numeric $_wordInch';
  }

  double getWeightPerCm() {
    final radiusInCm = (diameterInInches / 2) * CM_PER_INCH;
    final area = pi * radiusInCm * radiusInCm;
    return (area * ALUMINUM_DENSITY) / 1000;
  }

  double calculateBilletWeight(double lengthInMm) {
    return getWeightPerCm() * (lengthInMm / 10);
  }

  static double getDefaultTargetTonsPerHour(String size) {
    switch (size) {
      case '5 بوصة': return 0.550;
      case '6 بوصة': return 0.800;
      case '7 بوصة': return 1.100;
      case '8 بوصة': return 1.500;
      case '9 بوصة': return 2.000;
      case '10 بوصة': return 2.500;
      case '11 بوصة': return 3.000;
      default: return 1.100;
    }
  }

  static double calculateTargetTonsPerHourFromDiameter(double diameterInInches) {
    if (diameterInInches <= 5.5) return 0.550;
    if (diameterInInches <= 6.5) return 0.800;
    if (diameterInInches <= 7.5) return 1.100;
    if (diameterInInches <= 8.5) return 1.500;
    if (diameterInInches <= 9.5) return 2.000;
    if (diameterInInches <= 10.5) return 2.500;
    return 3.000;
  }

  static List<PressModel> getDefaultPresses() {
    return [
      PressModel(id: 'press_5_1', name: 'مكبس 5 بوصة - خط 1', size: '5 بوصة', diameterInInches: 5.0, targetTonsPerHour: 0.550, targetWastePercentage: 20.0),
      PressModel(id: 'press_6_1', name: 'مكبس 6 بوصة - خط 1', size: '6 بوصة', diameterInInches: 6.0, targetTonsPerHour: 0.800, targetWastePercentage: 20.0),
      PressModel(id: 'press_7_1', name: 'مكبس 7 بوصة - خط 1', size: '7 بوصة', diameterInInches: 7.0, targetTonsPerHour: 1.100, targetWastePercentage: 20.0),
      PressModel(id: 'press_8_1', name: 'مكبس 8 بوصة - خط 1', size: '8 بوصة', diameterInInches: 8.0, targetTonsPerHour: 1.500, targetWastePercentage: 20.0),
      PressModel(id: 'press_9_1', name: 'مكبس 9 بوصة - خط 1', size: '9 بوصة', diameterInInches: 9.0, targetTonsPerHour: 2.000, targetWastePercentage: 20.0),
      PressModel(id: 'press_10_1', name: 'مكبس 10 بوصة - خط 1', size: '10 بوصة', diameterInInches: 10.0, targetTonsPerHour: 2.500, targetWastePercentage: 20.0),
      PressModel(id: 'press_11_1', name: 'مكبس 11 بوصة - خط 1', size: '11 بوصة', diameterInInches: 11.0, targetTonsPerHour: 3.000, targetWastePercentage: 20.0),
    ];
  }

  static List<PressModel> _liveRegistry = [];

  static void registerPresses(List<PressModel> presses) {
    _liveRegistry = presses;
  }

  static PressModel? getPressById(String id) {
    try {
      return _liveRegistry.firstWhere((press) => press.id == id);
    } catch (e) {
      try {
        return getDefaultPresses().firstWhere((press) => press.id == id);
      } catch (e2) {
        return null;
      }
    }
  }

  static PressModel? getPressByName(String name) {
    try {
      return getDefaultPresses().firstWhere((press) => press.name == name);
    } catch (e) {
      return null;
    }
  }

  static List<String> getPressSizes() {
    return ['5 بوصة', '6 بوصة', '7 بوصة', '8 بوصة', '9 بوصة', '10 بوصة', '11 بوصة'];
  }

  String get weightPerCmFormatted => getWeightPerCm().toStringAsFixed(3);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'size': size,
      'diameterInInches': diameterInInches,
      'isActive': isActive,
      'targetTonsPerHour': targetTonsPerHour,
      'targetWastePercentage': targetWastePercentage,
    };
  }

  factory PressModel.fromJson(Map<String, dynamic> json) {
    return PressModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      size: json['size']?.toString() ?? '',
      diameterInInches: json['diameterInInches'] is num 
          ? (json['diameterInInches'] as num).toDouble() 
          : double.tryParse(json['diameterInInches']?.toString() ?? '0') ?? 0.0,
      isActive: json['isActive'] ?? true,
      targetTonsPerHour: json['targetTonsPerHour'] is num 
          ? (json['targetTonsPerHour'] as num).toDouble() 
          : getDefaultTargetTonsPerHour(json['size']?.toString() ?? '7 بوصة'),
      targetWastePercentage: json['targetWastePercentage'] is num 
          ? (json['targetWastePercentage'] as num).toDouble() 
          : 20.0,
    );
  }

  PressModel copyWith({
    String? id,
    String? name,
    String? size,
    double? diameterInInches,
    bool? isActive,
    double? targetTonsPerHour,
    double? targetWastePercentage,
  }) {
    return PressModel(
      id: id ?? this.id,
      name: name ?? this.name,
      size: size ?? this.size,
      diameterInInches: diameterInInches ?? this.diameterInInches,
      isActive: isActive ?? this.isActive,
      targetTonsPerHour: targetTonsPerHour ?? this.targetTonsPerHour,
      targetWastePercentage: targetWastePercentage ?? this.targetWastePercentage,
    );
  }
}

// ============================================================
// 🔥 نموذج رصيد الخامة حسب القطر (Material Stock)
// ============================================================
class MaterialStockModel {
  final String id;
  final double diameter;
  final double stock;
  final String factoryId;
  final DateTime updatedAt;
  final String alloy;
  final String origin;
  final String? notes;

  MaterialStockModel({
    required this.id,
    required this.diameter,
    required this.stock,
    required this.factoryId,
    DateTime? updatedAt,
    required this.alloy,
    required this.origin,
    this.notes,
  }) : updatedAt = updatedAt ?? DateTime.now();

  MaterialStockModel addStock(double amount) {
    return copyWith(stock: stock + amount, updatedAt: DateTime.now());
  }

  MaterialStockModel consumeStock(double amount) {
    final newStock = (stock - amount).clamp(0, double.infinity);
    return copyWith(stock: newStock.toDouble(), updatedAt: DateTime.now());
  }

  String get stockFormatted => '${stock.toStringAsFixed(2)} $_wordTon';

  String get originLabel {
    switch (origin) {
      case 'imported': return 'مستوردة';
      case 'local': return '🇪🇬 محلي';
      case 'local_foundry': return '🏭 محلي - مسبك';
      default: return origin;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'diameter': diameter,
      'stock': stock,
      'factoryId': factoryId,
      'updatedAt': updatedAt.toIso8601String(),
      'alloy': alloy,
      'origin': origin,
      'notes': notes,
    };
  }

  factory MaterialStockModel.fromJson(String id, Map<String, dynamic> json) {
    return MaterialStockModel(
      id: id,
      diameter: json['diameter'] is num 
          ? (json['diameter'] as num).toDouble() 
          : double.tryParse(json['diameter']?.toString() ?? '0') ?? 0.0,
      stock: json['stock'] is num 
          ? (json['stock'] as num).toDouble() 
          : double.tryParse(json['stock']?.toString() ?? '0') ?? 0.0,
      factoryId: json['factoryId']?.toString() ?? '',
      updatedAt: json['updatedAt'] != null 
          ? DateTime.tryParse(json['updatedAt'].toString()) 
          : null,
      alloy: json['alloy']?.toString() ?? '6063',
      origin: json['origin']?.toString() ?? 'imported',
      notes: json['notes']?.toString(),
    );
  }

  MaterialStockModel copyWith({
    String? id,
    double? diameter,
    double? stock,
    String? factoryId,
    DateTime? updatedAt,
    String? alloy,
    String? origin,
    String? notes,
  }) {
    return MaterialStockModel(
      id: id ?? this.id,
      diameter: diameter ?? this.diameter,
      stock: stock ?? this.stock,
      factoryId: factoryId ?? this.factoryId,
      updatedAt: updatedAt ?? this.updatedAt,
      alloy: alloy ?? this.alloy,
      origin: origin ?? this.origin,
      notes: notes ?? this.notes,
    );
  }
}

// ============================================================
// 🔥 نموذج السبيكة (Alloy)
// ============================================================
class AlloyModel {
  final String id;
  final String name;

  const AlloyModel({
    required this.id,
    required this.name,
  });

  static List<AlloyModel> getAlloys() {
    return [
      const AlloyModel(id: '1', name: '1050'),
      const AlloyModel(id: '2', name: '6005'),
      const AlloyModel(id: '3', name: '6060'), // ✅ إضافة سبيكة 6060
      const AlloyModel(id: '4', name: '6061'),
      const AlloyModel(id: '5', name: '6063'),
      const AlloyModel(id: '6', name: '6082'),
      const AlloyModel(id: '7', name: '6101'),
    ];
  }

  static List<String> getAlloyNames() {
    return ['1050', '6005', '6060', '6061', '6063', '6082', '6101']; // ✅ إضافة 6060
  }

  static AlloyModel? getAlloyByName(String name) {
    try {
      return getAlloys().firstWhere((alloy) => alloy.name == name);
    } catch (e) {
      return null;
    }
  }
}

// ============================================================
// 🔥 نموذج المستخدم (User)
// ============================================================
class UserModel {
  final String uid;
  final String email;
  final String name;
  final String role;
  final String factoryId;
  final String factoryName;
  final List<String> factories;
  final List<String> managedFactories;
  final bool canEndShift;
  final String? assignedPressId;
  final String department;
  final List<String> modules;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    required this.factoryId,
    required this.factoryName,
    this.factories = const [],
    this.managedFactories = const [],
    this.canEndShift = false,
    this.assignedPressId,
    this.department = '',
    this.modules = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'role': role,
      'factoryId': factoryId,
      'factoryName': factoryName,
      'factories': factories,
      'managedFactories': managedFactories,
      'canEndShift': canEndShift,
      'assignedPressId': assignedPressId,
      'department': department,
      'modules': modules,
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      role: json['role']?.toString() ?? 'operator',
      factoryId: json['factoryId']?.toString() ?? '',
      factoryName: json['factoryName']?.toString() ?? json['factoryId']?.toString() ?? 'مصنع',
      factories: json['factories'] is List 
          ? List<String>.from(json['factories']) 
          : [],
      managedFactories: json['managedFactories'] is List 
          ? List<String>.from(json['managedFactories']) 
          : [],
      canEndShift: json['canEndShift'] ?? false,
      assignedPressId: json['assignedPressId']?.toString(),
      department: json['department']?.toString() ?? '',
      modules: json['modules'] is List ? List<String>.from(json['modules']) : const [],
    );
  }

  bool get isDeveloper => role == 'developer';
  bool get isOwner => role == 'owner';
  bool get isManager => role == 'manager';
  bool get isSupervisor => role == 'supervisor';
  bool get isOperator => role == 'operator';
  bool get isProductionMonitor => role == 'production_monitor';
  
  bool get canManageMaterialStock => 
      isDeveloper || isOwner || isManager || isProductionMonitor;
  
  bool get canEditProductionData => 
      isDeveloper || isOwner || isManager || isProductionMonitor;
  
  bool get canAddMaterialStock => 
      isDeveloper || isOwner || isManager || isProductionMonitor;
  
  bool get canSeeMultipleFactories => isDeveloper || isOwner || isManager;
  bool get canManageUsers => isDeveloper || isOwner || isManager;
  bool get canManageFactories => isDeveloper;
  
  bool canStartShiftForPress(String pressId) {
    if (isDeveloper) return true;
    if (isOwner) return true;
    if (isManager) return true;
    if (!isSupervisor) return false;
    if (assignedPressId != null && assignedPressId!.isNotEmpty) {
      return assignedPressId == pressId;
    }
    return true;
  }

  bool get canEndShiftAutomatically {
    if (isDeveloper) return true;
    return canEndShift;
  }

  bool canSeeFactory(String factoryId) {
    if (isDeveloper) return true;
    if (isOwner) return factories.contains(factoryId);
    if (isManager) return managedFactories.contains(factoryId);
    return this.factoryId == factoryId;
  }

  bool canManageUsersInFactory(String factoryId) {
    if (isDeveloper) return true;
    if (isOwner) return factories.contains(factoryId);
    if (isManager) return managedFactories.contains(factoryId);
    return false;
  }
}

// ============================================================
// 🔥 نموذج المصنع (Factory)
// ============================================================
class FactoryModel {
  final String id;
  final String name;
  final String ownerId;
  final String ownerEmail;
  final String ownerName;
  final List<String> managers;
  final DateTime createdAt;

  FactoryModel({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.ownerEmail,
    required this.ownerName,
    this.managers = const [],
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'ownerId': ownerId,
      'ownerEmail': ownerEmail,
      'ownerName': ownerName,
      'managers': managers,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory FactoryModel.fromJson(String id, Map<String, dynamic> json) {
    return FactoryModel(
      id: id,
      name: json['name']?.toString() ?? id,
      ownerId: json['ownerId']?.toString() ?? '',
      ownerEmail: json['ownerEmail']?.toString() ?? '',
      ownerName: json['ownerName']?.toString() ?? '',
      managers: json['managers'] is List 
          ? List<String>.from(json['managers']) 
          : [],
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

// ============================================================
// 🔥 نموذج القالب (Die)
// ============================================================
class DieModel {
  String id;
  String name;
  int holes;
  DateTime entryTime;
  DateTime exitTime;
  String alloy;
  double billetLength;
  double billetTemperature;
  double ramSpeed;
  int billetCount;
  String notes;
  String pressId;
  String pressSize;
  bool isActive;
  String? supervisorId;
  DieStatus status;
  
  final String? furnaceId;
  final DateTime? furnaceEntryTime;
  final DateTime? furnaceExitTime;
  final bool isFurnaceReady;
  final String dieType;
  final String? furnacePressId;
  final double? widthMm;
  final double? heightMm;

  final double? barWeightKg;
  final int? expectedBarCount;
  final int? goodBarCount;
  final int? scrapBarCount;
  final int? relatedBarCount;
  
  final String? productionRecordedBy;
  final DateTime? productionRecordedAt;

  final double? pieceLength;
  final double? tableLength;

  DieModel({
    this.id = '',
    required this.name,
    required this.holes,
    required this.entryTime,
    required this.exitTime,
    required this.alloy,
    required this.billetLength,
    required this.billetTemperature,
    required this.ramSpeed,
    required this.billetCount,
    this.notes = '',
    required this.pressId,
    required this.pressSize,
    this.isActive = true,
    this.supervisorId,
    this.status = DieStatus.active,
    this.furnaceId,
    this.furnaceEntryTime,
    this.furnaceExitTime,
    this.isFurnaceReady = false,
    this.dieType = 'solid',
    this.furnacePressId,
    this.widthMm,
    this.heightMm,
    this.barWeightKg,
    this.expectedBarCount,
    this.goodBarCount,
    this.scrapBarCount,
    this.relatedBarCount,
    this.productionRecordedBy,
    this.productionRecordedAt,
    this.pieceLength,
    this.tableLength,
  });

  double get totalWeight {
    if (pressId.isEmpty) {
      return 0.0;
    }
    
    final press = PressModel.getPressById(pressId);
    if (press == null) {
      return 0.0;
    }
    
    final weightPerCm = press.getWeightPerCm();
    final lengthInCm = billetLength / 10;
    return billetCount * lengthInCm * weightPerCm;
  }

  String get totalWeightFormatted {
    final weight = totalWeight;
    if (weight >= 1000) {
      return '${(weight / 1000).toStringAsFixed(2)} $_wordTon';
    }
    return '${weight.toStringAsFixed(2)} $_wordKg';
  }

  int get durationMinutes {
    final diff = exitTime.difference(entryTime).inMinutes;
    return diff.abs();
  }

  String get durationFormatted {
    final minutes = durationMinutes;
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      return '$hours $_wordHour $remainingMinutes $_wordMinute';
    }
    return '$minutes $_wordMinute';
  }

  double get productivity {
    final hours = durationMinutes / 60;
    if (hours == 0) return 0.0;
    return (totalWeight / 1000) / hours;
  }

  String get productivityFormatted {
    return '${productivity.toStringAsFixed(2)} $_wordTon/$_wordHour';
  }

  double getEfficiency(double targetTonsPerHour) {
    final actualWeight = totalWeight / 1000;
    final hours = durationMinutes / 60;
    if (hours == 0) return 0.0;
    final expectedWeight = targetTonsPerHour * hours;
    if (expectedWeight == 0) return 0.0;
    final efficiency = (actualWeight / expectedWeight) * 100;
    return efficiency.clamp(0, 150);
  }

  String getEfficiencyFormatted(double targetTonsPerHour) {
    return '${getEfficiency(targetTonsPerHour).toStringAsFixed(1)}%';
  }

  double getRequiredHeatingTime(FurnaceModel furnace) {
    return dieType == 'hollow' ? furnace.hollowHeatingTime : furnace.solidHeatingTime;
  }

  bool isReady(FurnaceModel furnace) {
    if (isFurnaceReady) return true;
    if (furnaceEntryTime == null) return false;
    final elapsed = DateTime.now().difference(furnaceEntryTime!).inMinutes;
    final required = getRequiredHeatingTime(furnace);
    return elapsed >= required;
  }

  double getRemainingTime(FurnaceModel furnace) {
    if (isFurnaceReady) return 0;
    if (furnaceEntryTime == null) return getRequiredHeatingTime(furnace);
    final elapsed = DateTime.now().difference(furnaceEntryTime!).inMinutes;
    final required = getRequiredHeatingTime(furnace);
    return (required - elapsed).clamp(0, required);
  }

  String getRemainingTimeFormatted(FurnaceModel furnace) {
    final minutes = getRemainingTime(furnace);
    if (minutes <= 0) return 'جاهز ✅';
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (hours > 0) {
      return '$hours $_wordHour $remainingMinutes $_wordMinute';
    }
    return '${minutes.toStringAsFixed(0)} $_wordMinute';
  }

  String get dimensionsFormatted {
    if (widthMm != null && heightMm != null) {
      return '${widthMm!.toStringAsFixed(0)}×${heightMm!.toStringAsFixed(0)} مم';
    }
    return 'غير محدد';
  }

  bool get hasProductionData => barWeightKg != null && barWeightKg! > 0;

  double get goodBarsWeightKg => (goodBarCount ?? 0) * (barWeightKg ?? 0);
  double get scrapBarsWeightKg => (scrapBarCount ?? 0) * (barWeightKg ?? 0);
  double get relatedBarsWeightKg => (relatedBarCount ?? 0) * (barWeightKg ?? 0);

  double get totalScrapWeightKg {
    if (!hasProductionData) return 0.0;
    final scrap = totalWeight - goodBarsWeightKg - relatedBarsWeightKg;
    return scrap < 0 ? 0.0 : scrap;
  }

  double get scrapPercentage {
    if (!hasProductionData || totalWeight <= 0) return 0.0;
    return (totalScrapWeightKg / totalWeight) * 100;
  }

  String get scrapPercentageFormatted => '${scrapPercentage.toStringAsFixed(1)}%';

  String get goodBarsWeightFormatted => _formatKgOrTon(goodBarsWeightKg);
  String get scrapBarsWeightFormatted => _formatKgOrTon(scrapBarsWeightKg);
  String get relatedBarsWeightFormatted => _formatKgOrTon(relatedBarsWeightKg);
  String get totalScrapWeightFormatted => _formatKgOrTon(totalScrapWeightKg);

  int get countedBarsTotal => (goodBarCount ?? 0) + (scrapBarCount ?? 0) + (relatedBarCount ?? 0);

  int get barCountDiscrepancy {
    if (expectedBarCount == null) return 0;
    return expectedBarCount! - countedBarsTotal;
  }

  int? get calculatedExpectedBars {
    if (pieceLength == null || tableLength == null || pieceLength! <= 0 || tableLength! <= 0) {
      return null;
    }
    if (holes <= 0) return null;
    final result = (tableLength! / pieceLength!) * holes;
    return result.floor();
  }

  String get expectedBarsDisplay {
    final calculated = calculatedExpectedBars;
    if (calculated == null) return '---';
    return '$calculated';
  }

  String _formatKgOrTon(double weight) {
    if (weight >= 1000) {
      return '${(weight / 1000).toStringAsFixed(2)} $_wordTon';
    }
    return '${weight.toStringAsFixed(2)} $_wordKg';
  }

  double get _theoreticalBilletTimeSeconds {
    if (ramSpeed <= 0) return 0;
    return billetLength / ramSpeed;
  }

  double get _theoreticalBilletCount {
    final cycleTime = _theoreticalBilletTimeSeconds;
    if (cycleTime <= 0) return 0;
    final totalSeconds = durationMinutes * 60;
    return totalSeconds / cycleTime;
  }

  double get wastedTimeMinutes {
    if (durationMinutes == 0) return 0.0;
    if (_theoreticalBilletTimeSeconds <= 0) return 0.0;
    
    final theoretical = _theoreticalBilletCount;
    final actual = billetCount.toDouble();
    if (theoretical <= actual) return 0.0;
    
    final wastedBillets = theoretical - actual;
    return wastedBillets * (_theoreticalBilletTimeSeconds / 60);
  }

  String get wastedTimeFormatted {
    final minutes = wastedTimeMinutes;
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      return '$hours $_wordHour $remainingMinutes $_wordMinute';
    }
    return '${minutes.toStringAsFixed(1)} $_wordMinute';
  }

  double get wastedTimePercentage {
    if (durationMinutes == 0) return 0.0;
    return (wastedTimeMinutes / durationMinutes) * 100;
  }

  double get productionEfficiency {
    return 100 - wastedTimePercentage;
  }

  int get theoreticalBilletCountRounded {
    return _theoreticalBilletCount.round();
  }

  static double calculateWeight({
    required String pressId,
    required double billetLength,
    required int billetCount,
  }) {
    final press = PressModel.getPressById(pressId);
    if (press == null) return 0.0;
    final weightPerCm = press.getWeightPerCm();
    final lengthInCm = billetLength / 10;
    return billetCount * lengthInCm * weightPerCm;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'holes': holes,
      'entryTime': entryTime.toIso8601String(),
      'exitTime': exitTime.toIso8601String(),
      'alloy': alloy,
      'billetLength': billetLength,
      'billetTemperature': billetTemperature,
      'ramSpeed': ramSpeed,
      'billetCount': billetCount,
      'notes': notes,
      'pressId': pressId,
      'pressSize': pressSize,
      'isActive': isActive,
      'totalWeight': totalWeight,
      'supervisorId': supervisorId,
      'status': status.name,
      'furnaceId': furnaceId,
      'furnaceEntryTime': furnaceEntryTime?.toIso8601String(),
      'furnaceExitTime': furnaceExitTime?.toIso8601String(),
      'isFurnaceReady': isFurnaceReady,
      'dieType': dieType,
      'furnacePressId': furnacePressId,
      'widthMm': widthMm,
      'heightMm': heightMm,
      'barWeightKg': barWeightKg,
      'expectedBarCount': expectedBarCount,
      'goodBarCount': goodBarCount,
      'scrapBarCount': scrapBarCount,
      'relatedBarCount': relatedBarCount,
      'productionRecordedBy': productionRecordedBy,
      'productionRecordedAt': productionRecordedAt?.toIso8601String(),
      'pieceLength': pieceLength,
      'tableLength': tableLength,
    };
  }

  factory DieModel.fromJson(String id, Map<String, dynamic> json) {
    return DieModel(
      id: id.isNotEmpty ? id : (json['id']?.toString() ?? ''),
      name: json['name']?.toString() ?? '',
      holes: json['holes'] is int ? json['holes'] : (int.tryParse(json['holes']?.toString() ?? '0') ?? 0),
      entryTime: json['entryTime'] != null 
          ? DateTime.tryParse(json['entryTime'].toString()) ?? DateTime.now()
          : DateTime.now(),
      exitTime: json['exitTime'] != null 
          ? DateTime.tryParse(json['exitTime'].toString()) ?? DateTime.now()
          : DateTime.now(),
      alloy: json['alloy']?.toString() ?? '6063',
      billetLength: json['billetLength'] is num 
          ? (json['billetLength'] as num).toDouble() 
          : double.tryParse(json['billetLength']?.toString() ?? '0') ?? 0.0,
      billetTemperature: json['billetTemperature'] is num 
          ? (json['billetTemperature'] as num).toDouble() 
          : double.tryParse(json['billetTemperature']?.toString() ?? '0') ?? 0.0,
      ramSpeed: json['ramSpeed'] is num 
          ? (json['ramSpeed'] as num).toDouble() 
          : double.tryParse(json['ramSpeed']?.toString() ?? '0') ?? 0.0,
      billetCount: json['billetCount'] is int 
          ? json['billetCount'] 
          : int.tryParse(json['billetCount']?.toString() ?? '0') ?? 0,
      notes: json['notes']?.toString() ?? '',
      pressId: json['pressId']?.toString() ?? '',
      pressSize: json['pressSize']?.toString() ?? '7 بوصة',
      isActive: json['isActive'] is bool 
          ? json['isActive'] 
          : (json['isActive']?.toString()?.toLowerCase() == 'true'),
      supervisorId: json['supervisorId']?.toString(),
      status: json['status'] != null 
          ? DieStatus.values.firstWhere(
              (e) => e.name == json['status'].toString(),
              orElse: () => DieStatus.active,
            )
          : DieStatus.active,
      furnaceId: json['furnaceId']?.toString(),
      furnaceEntryTime: json['furnaceEntryTime'] != null 
          ? DateTime.tryParse(json['furnaceEntryTime'].toString())
          : null,
      furnaceExitTime: json['furnaceExitTime'] != null 
          ? DateTime.tryParse(json['furnaceExitTime'].toString())
          : null,
      isFurnaceReady: json['isFurnaceReady'] ?? false,
      dieType: json['dieType']?.toString() ?? 'solid',
      furnacePressId: json['furnacePressId']?.toString(),
      widthMm: json['widthMm'] is num ? (json['widthMm'] as num).toDouble() : null,
      heightMm: json['heightMm'] is num ? (json['heightMm'] as num).toDouble() : null,
      barWeightKg: json['barWeightKg'] is num ? (json['barWeightKg'] as num).toDouble() : null,
      expectedBarCount: json['expectedBarCount'] is int
          ? json['expectedBarCount']
          : int.tryParse(json['expectedBarCount']?.toString() ?? ''),
      goodBarCount: json['goodBarCount'] is int
          ? json['goodBarCount']
          : int.tryParse(json['goodBarCount']?.toString() ?? ''),
      scrapBarCount: json['scrapBarCount'] is int
          ? json['scrapBarCount']
          : int.tryParse(json['scrapBarCount']?.toString() ?? ''),
      relatedBarCount: json['relatedBarCount'] is int
          ? json['relatedBarCount']
          : int.tryParse(json['relatedBarCount']?.toString() ?? ''),
      productionRecordedBy: json['productionRecordedBy']?.toString(),
      productionRecordedAt: json['productionRecordedAt'] != null
          ? DateTime.tryParse(json['productionRecordedAt'].toString())
          : null,
      pieceLength: json['pieceLength'] is num ? (json['pieceLength'] as num).toDouble() : null,
      tableLength: json['tableLength'] is num ? (json['tableLength'] as num).toDouble() : null,
    );
  }

  DieModel copyWith({
    String? id,
    String? name,
    int? holes,
    DateTime? entryTime,
    DateTime? exitTime,
    String? alloy,
    double? billetLength,
    double? billetTemperature,
    double? ramSpeed,
    int? billetCount,
    String? notes,
    String? pressId,
    String? pressSize,
    bool? isActive,
    String? supervisorId,
    DieStatus? status,
    String? furnaceId,
    DateTime? furnaceEntryTime,
    DateTime? furnaceExitTime,
    bool? isFurnaceReady,
    String? dieType,
    String? furnacePressId,
    double? widthMm,
    double? heightMm,
    double? barWeightKg,
    int? expectedBarCount,
    int? goodBarCount,
    int? scrapBarCount,
    int? relatedBarCount,
    String? productionRecordedBy,
    DateTime? productionRecordedAt,
    double? pieceLength,
    double? tableLength,
  }) {
    return DieModel(
      id: id ?? this.id,
      name: name ?? this.name,
      holes: holes ?? this.holes,
      entryTime: entryTime ?? this.entryTime,
      exitTime: exitTime ?? this.exitTime,
      alloy: alloy ?? this.alloy,
      billetLength: billetLength ?? this.billetLength,
      billetTemperature: billetTemperature ?? this.billetTemperature,
      ramSpeed: ramSpeed ?? this.ramSpeed,
      billetCount: billetCount ?? this.billetCount,
      notes: notes ?? this.notes,
      pressId: pressId ?? this.pressId,
      pressSize: pressSize ?? this.pressSize,
      isActive: isActive ?? this.isActive,
      supervisorId: supervisorId ?? this.supervisorId,
      status: status ?? this.status,
      furnaceId: furnaceId ?? this.furnaceId,
      furnaceEntryTime: furnaceEntryTime ?? this.furnaceEntryTime,
      furnaceExitTime: furnaceExitTime ?? this.furnaceExitTime,
      isFurnaceReady: isFurnaceReady ?? this.isFurnaceReady,
      dieType: dieType ?? this.dieType,
      furnacePressId: furnacePressId ?? this.furnacePressId,
      widthMm: widthMm ?? this.widthMm,
      heightMm: heightMm ?? this.heightMm,
      barWeightKg: barWeightKg ?? this.barWeightKg,
      expectedBarCount: expectedBarCount ?? this.expectedBarCount,
      goodBarCount: goodBarCount ?? this.goodBarCount,
      scrapBarCount: scrapBarCount ?? this.scrapBarCount,
      relatedBarCount: relatedBarCount ?? this.relatedBarCount,
      productionRecordedBy: productionRecordedBy ?? this.productionRecordedBy,
      productionRecordedAt: productionRecordedAt ?? this.productionRecordedAt,
      pieceLength: pieceLength ?? this.pieceLength,
      tableLength: tableLength ?? this.tableLength,
    );
  }
}

// ============================================================
// 🔥 نموذج الوردية (Shift)
// ============================================================
class ShiftModel {
  final String id;
  final String factoryId;
  final String date;
  final int shiftNumber;
  final String supervisor;
  final String technician;
  final String pressId;
  final String pressName;
  final String pressSize;
  final String supervisorUid;
  final String? pressSupervisorUid;
  final List<DieModel> dies;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? endedAt;
  final List<WasteRecord> wasteRecords;

  ShiftModel({
    this.id = '',
    required this.factoryId,
    required this.date,
    required this.shiftNumber,
    required this.supervisor,
    required this.technician,
    required this.pressId,
    required this.pressName,
    required this.pressSize,
    required this.supervisorUid,
    this.pressSupervisorUid,
    this.dies = const [],
    this.isActive = true,
    DateTime? createdAt,
    this.endedAt,
    this.wasteRecords = const [],
  }) : createdAt = createdAt ?? DateTime.now();

  double get totalWeight {
    return dies.fold(0.0, (sum, die) => sum + die.totalWeight);
  }

  String get totalWeightFormatted {
    final weight = totalWeight;
    if (weight >= 1000) {
      return '${(weight / 1000).toStringAsFixed(2)} $_wordTon';
    }
    return '${weight.toStringAsFixed(2)} $_wordKg';
  }

  double get totalScrapWeight {
    double totalScrap = 0.0;
    for (var die in dies) {
      if (die.hasProductionData) {
        totalScrap += die.totalScrapWeightKg;
      }
    }
    return totalScrap;
  }

  String get totalScrapWeightFormatted {
    final weight = totalScrapWeight;
    if (weight >= 1000) {
      return '${(weight / 1000).toStringAsFixed(2)} $_wordTon';
    }
    return '${weight.toStringAsFixed(2)} $_wordKg';
  }

  double get totalScrapPercentage {
    double totalWeightAll = 0.0;
    double totalScrapAll = 0.0;
    for (var die in dies) {
      if (die.hasProductionData) {
        totalWeightAll += die.totalWeight;
        totalScrapAll += die.totalScrapWeightKg;
      }
    }
    if (totalWeightAll <= 0) return 0.0;
    return (totalScrapAll / totalWeightAll) * 100;
  }

  String get totalScrapPercentageFormatted {
    return '${totalScrapPercentage.toStringAsFixed(1)}%';
  }

  double get totalGoodWeight {
    double totalGood = 0.0;
    for (var die in dies) {
      if (die.hasProductionData) {
        totalGood += die.goodBarsWeightKg;
      }
    }
    return totalGood;
  }

  String get totalGoodWeightFormatted {
    final weight = totalGoodWeight;
    if (weight >= 1000) {
      return '${(weight / 1000).toStringAsFixed(2)} $_wordTon';
    }
    return '${weight.toStringAsFixed(2)} $_wordKg';
  }

  int get totalRelatedBars {
    int total = 0;
    for (var die in dies) {
      if (die.hasProductionData) {
        total += die.relatedBarCount ?? 0;
      }
    }
    return total;
  }

  int get totalExpectedBars {
    int total = 0;
    for (var die in dies) {
      final expected = die.calculatedExpectedBars;
      if (expected != null) {
        total += expected;
      }
    }
    return total;
  }

  Map<String, double> getConsumedWeightByAlloy() {
    final Map<String, double> result = {};
    for (var die in dies) {
      if (die.status == DieStatus.draft) continue;
      final alloy = die.alloy;
      final weight = die.totalWeight / 1000;
      result[alloy] = (result[alloy] ?? 0) + weight;
    }
    return result;
  }

  List<String> getUsedAlloys() {
    final Set<String> alloys = {};
    for (var die in dies) {
      if (die.status == DieStatus.draft) continue;
      alloys.add(die.alloy);
    }
    return alloys.toList();
  }

  int get diesWithProductionData {
    return dies.where((d) => d.hasProductionData).length;
  }

  int get totalBillets {
    return dies.fold(0, (sum, die) => sum + die.billetCount);
  }

  int get totalDies {
    return dies.length;
  }

  int get activePressCount {
    final activeDies = dies.where((die) => die.isActive).toList();
    return activeDies.length;
  }

  int get actualDurationMinutes {
    if (dies.isEmpty) return 0;
    
    final sortedDies = List<DieModel>.from(dies)
      ..sort((a, b) => a.entryTime.compareTo(b.entryTime));
    
    final firstEntry = sortedDies.first.entryTime;
    final lastExit = sortedDies.last.exitTime;
    
    int diffInMinutes = lastExit.difference(firstEntry).inMinutes;
    if (diffInMinutes < 0) diffInMinutes = 0;
    
    return diffInMinutes;
  }

  String get actualDurationFormatted {
    final minutes = actualDurationMinutes;
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      return '$hours $_wordHour $remainingMinutes $_wordMinute';
    }
    return '$minutes $_wordMinute';
  }

  int get totalWorkMinutes {
    int total = 0;
    for (var die in dies) {
      total += die.durationMinutes;
    }
    return total;
  }

  String get totalWorkFormatted {
    final minutes = totalWorkMinutes;
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      return '$hours $_wordHour $remainingMinutes $_wordMinute';
    }
    return '$minutes $_wordMinute';
  }

  int get gapMinutes {
    return actualDurationMinutes - totalWorkMinutes;
  }

  String get gapFormatted {
    final minutes = gapMinutes;
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      return '$hours $_wordHour $remainingMinutes $_wordMinute';
    }
    return '$minutes $_wordMinute';
  }

  double get gapPercentage {
    if (actualDurationMinutes == 0) return 0.0;
    return (gapMinutes / actualDurationMinutes) * 100;
  }

  int get totalWastedMinutes {
    return wasteRecords.fold(0, (sum, record) => sum + record.minutes);
  }

  String get totalWastedFormatted {
    final minutes = totalWastedMinutes;
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      return '$hours $_wordHour $remainingMinutes $_wordMinute';
    }
    return '$minutes $_wordMinute';
  }

  String get wasteDetails {
    if (wasteRecords.isEmpty) return 'لا يوجد أعطال';
    return wasteRecords.map((r) => r.formatted).join(' | ');
  }

  List<WasteRecord> get wasteRecordsList => wasteRecords;

  int get productiveMinutes {
    return actualDurationMinutes - totalWastedMinutes;
  }

  String get productiveFormatted {
    final minutes = productiveMinutes;
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      return '$hours $_wordHour $remainingMinutes $_wordMinute';
    }
    return '$minutes $_wordMinute';
  }

  double get averageProductivity {
    final hours = productiveMinutes / 60;
    if (hours == 0) return 0.0;
    if (totalWeight == 0) return 0.0;
    return (totalWeight / 1000) / hours;
  }

  String get averageProductivityFormatted {
    return '${averageProductivity.toStringAsFixed(2)} $_wordTon/$_wordHour';
  }

  double getEfficiency(double targetTonsPerHour) {
    if (dies.isEmpty) return 0.0;
    
    final productiveHours = productiveMinutes / 60;
    if (productiveHours == 0) return 0.0;
    
    final totalWeightInTons = totalWeight / 1000;
    final expectedWeight = targetTonsPerHour * productiveHours;
    if (expectedWeight == 0) return 0.0;
    
    final efficiency = (totalWeightInTons / expectedWeight) * 100;
    return efficiency.clamp(0, 150);
  }

  String get duration {
    final end = endedAt ?? DateTime.now();
    final difference = end.difference(createdAt);
    final hours = difference.inHours;
    final minutes = difference.inMinutes.remainder(60);
    if (hours > 0) {
      return '$hours $_wordHour $minutes $_wordMinute';
    }
    return '$minutes $_wordMinute';
  }

  DieModel? get draftDie {
    try {
      return dies.firstWhere((die) => die.status == DieStatus.draft);
    } catch (e) {
      return null;
    }
  }

  List<DieModel> get activeDies {
    return dies.where((die) => die.status == DieStatus.active).toList();
  }

  List<DieModel> get completedDies {
    return dies.where((die) => die.status == DieStatus.completed).toList();
  }

  bool canEndShift(String userUid, List<UserModel> users) {
    UserModel? user;
    try {
      user = users.firstWhere((u) => u.uid == userUid);
    } catch (e) {
      user = null;
    }
    if (user == null) return false;
    if (user.isDeveloper) return true;
    if (user.isOwner) return user.canEndShift;
    if (user.isManager) return user.canEndShift;
    if (supervisorUid == userUid) return true;
    if (pressSupervisorUid == userUid) return true;
    return user.canEndShift;
  }

  Map<String, dynamic> toJson() {
    return {
      'factoryId': factoryId,
      'date': date,
      'shiftNumber': shiftNumber,
      'supervisor': supervisor,
      'technician': technician,
      'pressId': pressId,
      'pressName': pressName,
      'pressSize': pressSize,
      'supervisorUid': supervisorUid,
      'pressSupervisorUid': pressSupervisorUid,
      'dies': dies.map((die) => die.toJson()).toList(),
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
      'totalWeight': totalWeight,
      'totalBillets': totalBillets,
      'totalDies': totalDies,
      'activePressCount': activePressCount,
      'wasteRecords': wasteRecords.map((w) => w.toJson()).toList(),
    };
  }

  factory ShiftModel.fromJson(String id, Map<String, dynamic> json) {
    List<DieModel> dies = [];
    if (json['dies'] != null) {
      final diesList = json['dies'] as List;
      dies = diesList.asMap().entries.map((entry) {
        final dieJson = safeMapCast(entry.value);
        final dieId = dieJson['id']?.toString() ?? 'die_${entry.key}';
        return DieModel.fromJson(dieId, dieJson);
      }).toList();
    }

    List<WasteRecord> wasteRecords = [];
    if (json['wasteRecords'] != null) {
      final recordsList = json['wasteRecords'] as List;
      wasteRecords = recordsList.map((record) {
        return WasteRecord.fromJson(safeMapCast(record));
      }).toList();
    }

    return ShiftModel(
      id: id,
      factoryId: json['factoryId']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      shiftNumber: json['shiftNumber'] is int 
          ? json['shiftNumber'] 
          : int.tryParse(json['shiftNumber']?.toString() ?? '1') ?? 1,
      supervisor: json['supervisor']?.toString() ?? '',
      technician: json['technician']?.toString() ?? '',
      pressId: json['pressId']?.toString() ?? '',
      pressName: json['pressName']?.toString() ?? json['pressSize']?.toString() ?? 'مكبس',
      pressSize: json['pressSize']?.toString() ?? '7 بوصة',
      supervisorUid: json['supervisorUid']?.toString() ?? '',
      pressSupervisorUid: json['pressSupervisorUid']?.toString(),
      dies: dies,
      isActive: json['isActive'] is bool 
          ? json['isActive'] 
          : (json['isActive']?.toString()?.toLowerCase() == 'true'),
      createdAt: json['createdAt'] != null 
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      endedAt: json['endedAt'] != null 
          ? DateTime.tryParse(json['endedAt'].toString())
          : null,
      wasteRecords: wasteRecords,
    );
  }

  ShiftModel addDie(DieModel newDie) {
    final newDieWithId = newDie.copyWith(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      supervisorId: supervisorUid,
    );
    final updatedDies = List<DieModel>.from(dies)..add(newDieWithId);
    return ShiftModel(
      id: id,
      factoryId: factoryId,
      date: date,
      shiftNumber: shiftNumber,
      supervisor: supervisor,
      technician: technician,
      pressId: pressId,
      pressName: pressName,
      pressSize: pressSize,
      supervisorUid: supervisorUid,
      pressSupervisorUid: pressSupervisorUid,
      dies: updatedDies,
      isActive: isActive,
      createdAt: createdAt,
      endedAt: endedAt,
      wasteRecords: List<WasteRecord>.from(wasteRecords),
    );
  }

  ShiftModel updateDie(DieModel updatedDie) {
    final updatedDies = dies.map((die) {
      return die.id == updatedDie.id ? updatedDie : die;
    }).toList();
    return ShiftModel(
      id: id,
      factoryId: factoryId,
      date: date,
      shiftNumber: shiftNumber,
      supervisor: supervisor,
      technician: technician,
      pressId: pressId,
      pressName: pressName,
      pressSize: pressSize,
      supervisorUid: supervisorUid,
      pressSupervisorUid: pressSupervisorUid,
      dies: updatedDies,
      isActive: isActive,
      createdAt: createdAt,
      endedAt: endedAt,
      wasteRecords: List<WasteRecord>.from(wasteRecords),
    );
  }

  ShiftModel removeDie(String dieId) {
    final updatedDies = dies.where((die) => die.id != dieId).toList();
    return ShiftModel(
      id: id,
      factoryId: factoryId,
      date: date,
      shiftNumber: shiftNumber,
      supervisor: supervisor,
      technician: technician,
      pressId: pressId,
      pressName: pressName,
      pressSize: pressSize,
      supervisorUid: supervisorUid,
      pressSupervisorUid: pressSupervisorUid,
      dies: updatedDies,
      isActive: isActive,
      createdAt: createdAt,
      endedAt: endedAt,
      wasteRecords: List<WasteRecord>.from(wasteRecords),
    );
  }

  ShiftModel endShift() {
    return ShiftModel(
      id: id,
      factoryId: factoryId,
      date: date,
      shiftNumber: shiftNumber,
      supervisor: supervisor,
      technician: technician,
      pressId: pressId,
      pressName: pressName,
      pressSize: pressSize,
      supervisorUid: supervisorUid,
      pressSupervisorUid: pressSupervisorUid,
      dies: List<DieModel>.from(dies),
      isActive: false,
      createdAt: createdAt,
      endedAt: DateTime.now(),
      wasteRecords: List<WasteRecord>.from(wasteRecords),
    );
  }

  ShiftModel saveDraftDie() {
    final draft = draftDie;
    if (draft == null) return this;
    final savedDie = draft.copyWith(
      status: DieStatus.active,
      exitTime: DateTime.now(),
    );
    return updateDie(savedDie);
  }

  ShiftModel cancelDraftDie() {
    final draft = draftDie;
    if (draft == null) return this;
    return removeDie(draft.id);
  }

  ShiftModel setDraftDie(DieModel draftDie) {
    var updatedShift = this;
    final existingDraft = draftDie;
    if (existingDraft != null) {
      updatedShift = updatedShift.removeDie(existingDraft.id);
    }
    final newDraft = draftDie.copyWith(
      status: DieStatus.draft,
      id: 'draft_${DateTime.now().millisecondsSinceEpoch}',
    );
    return updatedShift.addDie(newDraft);
  }

  ShiftModel addWastedTime(int minutes, String reason) {
    final newRecord = WasteRecord(minutes: minutes, reason: reason);
    final updatedRecords = List<WasteRecord>.from(wasteRecords)..add(newRecord);
    return ShiftModel(
      id: id,
      factoryId: factoryId,
      date: date,
      shiftNumber: shiftNumber,
      supervisor: supervisor,
      technician: technician,
      pressId: pressId,
      pressName: pressName,
      pressSize: pressSize,
      supervisorUid: supervisorUid,
      pressSupervisorUid: pressSupervisorUid,
      dies: List<DieModel>.from(dies),
      isActive: isActive,
      createdAt: createdAt,
      endedAt: endedAt,
      wasteRecords: updatedRecords,
    );
  }

  List<Map<String, dynamic>> getGapDetails() {
    if (dies.length < 2) return [];
    
    final sortedDies = List<DieModel>.from(dies)
      ..sort((a, b) => a.entryTime.compareTo(b.entryTime));
    
    List<Map<String, dynamic>> details = [];
    
    for (int i = 0; i < sortedDies.length; i++) {
      final die = sortedDies[i];
      final duration = die.durationMinutes;
      
      int waitTime = 0;
      DateTime? nextEntryTime;
      
      if (i < sortedDies.length - 1) {
        final nextDie = sortedDies[i + 1];
        waitTime = nextDie.entryTime.difference(die.exitTime).inMinutes;
        nextEntryTime = nextDie.entryTime;
      }
      
      details.add({
        'die': die,
        'duration': duration,
        'waitTime': waitTime,
        'nextEntryTime': nextEntryTime,
      });
    }
    
    return details;
  }
}