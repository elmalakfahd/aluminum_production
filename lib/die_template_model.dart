// ============================================================
// 🔥 نموذج القالب المسجل (Die Template)
// ------------------------------------------------------------
// يحتوي على الأكواد الثلاثة للقالب مع إمكانية إضافة رقم النسخة
// وربطه برسومات PDF أو صور
// ============================================================

class DieTemplate {
  final String id;
  final String name; // اسم القالب (مثل: ES001029)
  final String clientCode; // Cust. Profile Code (كود العميل)
  final String designCode; // Design Code (كود التصميم)
  final String dieCode; // Profil code (كود القالب الأساسي)
  final String? version; // رقم النسخة (مثل: 1m, 2m, 3d)
  final String fullCode; // الكود الكامل (dieCode/version)
  final String factoryId;
  final String? pdfUrl; // رابط ملف PDF للرسم
  final String? pdfPath; // مسار الملف في Firebase Storage
  final DateTime createdAt;
  final String? type; // hollow / solid - للإضافة لاحقاً
  final double? widthMm; // للإضافة لاحقاً
  final double? heightMm; // للإضافة لاحقاً
  final double? heatingTime; // للإضافة لاحقاً
  final String? imageData; // ✅ جديد: تخزين الصورة كـ Base64

  DieTemplate({
    required this.id,
    required this.name,
    required this.clientCode,
    required this.designCode,
    required this.dieCode,
    this.version,
    required this.fullCode,
    required this.factoryId,
    this.pdfUrl,
    this.pdfPath,
    DateTime? createdAt,
    this.type,
    this.widthMm,
    this.heightMm,
    this.heatingTime,
    this.imageData, // ✅ جديد
  }) : createdAt = createdAt ?? DateTime.now();

  // ✅ التحقق من تطابق أي كود من الأكواد (بما فيها الكود الكامل)
  bool matchesAnyCode(String searchText) {
    final query = searchText.trim().toLowerCase();
    return fullCode.toLowerCase().contains(query) ||
        name.toLowerCase().contains(query) ||
        clientCode.toLowerCase().contains(query) ||
        designCode.toLowerCase().contains(query) ||
        dieCode.toLowerCase().contains(query);
  }

  // ✅ البحث بأي كود من الأكواد الثلاثة (مطابقة تامة)
  bool matchesExactCode(String searchText) {
    final query = searchText.trim().toLowerCase();
    return clientCode.toLowerCase() == query ||
        designCode.toLowerCase() == query ||
        dieCode.toLowerCase() == query ||
        fullCode.toLowerCase() == query;
  }

  // ✅ البحث عن النسخ المتطابقة (نفس الكود الأساسي)
  bool isSameBaseCode(DieTemplate other) {
    return dieCode == other.dieCode;
  }

  // ✅ الحصول على جميع الأكواد كـ List
  List<String> getAllCodes() {
    return [clientCode, designCode, dieCode, fullCode];
  }

  // ✅ تنسيق الأكواد للعرض
  String get codesDisplay =>
      'العميل: $clientCode | التصميم: $designCode | القالب: $fullCode';

  // ✅ اسم مختصر للعرض
  String get displayName {
    if (version != null && version!.isNotEmpty) {
      return '$name ($version)';
    }
    return name;
  }

  // ✅ هل يوجد رسم للقالب؟ (يدعم PDF و Base64)
  bool get hasDrawing => 
      (pdfUrl != null && pdfUrl!.isNotEmpty) || 
      (imageData != null && imageData!.isNotEmpty);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'clientCode': clientCode,
      'designCode': designCode,
      'dieCode': dieCode,
      'version': version,
      'fullCode': fullCode,
      'factoryId': factoryId,
      'pdfUrl': pdfUrl,
      'pdfPath': pdfPath,
      'createdAt': createdAt.toIso8601String(),
      'type': type,
      'widthMm': widthMm,
      'heightMm': heightMm,
      'heatingTime': heatingTime,
      'imageData': imageData, // ✅ جديد
    };
  }

  factory DieTemplate.fromJson(String id, Map<String, dynamic> json) {
    return DieTemplate(
      id: id,
      name: json['name']?.toString() ?? '',
      clientCode: json['clientCode']?.toString() ?? '',
      designCode: json['designCode']?.toString() ?? '',
      dieCode: json['dieCode']?.toString() ?? '',
      version: json['version']?.toString(),
      fullCode: json['fullCode']?.toString() ?? json['dieCode']?.toString() ?? '',
      factoryId: json['factoryId']?.toString() ?? '',
      pdfUrl: json['pdfUrl']?.toString(),
      pdfPath: json['pdfPath']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      type: json['type']?.toString(),
      widthMm: json['widthMm'] is num ? (json['widthMm'] as num).toDouble() : null,
      heightMm: json['heightMm'] is num ? (json['heightMm'] as num).toDouble() : null,
      heatingTime: json['heatingTime'] is num ? (json['heatingTime'] as num).toDouble() : null,
      imageData: json['imageData']?.toString(), // ✅ جديد
    );
  }

  DieTemplate copyWith({
    String? id,
    String? name,
    String? clientCode,
    String? designCode,
    String? dieCode,
    String? version,
    String? fullCode,
    String? factoryId,
    String? pdfUrl,
    String? pdfPath,
    DateTime? createdAt,
    String? type,
    double? widthMm,
    double? heightMm,
    double? heatingTime,
    String? imageData, // ✅ جديد
  }) {
    return DieTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      clientCode: clientCode ?? this.clientCode,
      designCode: designCode ?? this.designCode,
      dieCode: dieCode ?? this.dieCode,
      version: version ?? this.version,
      fullCode: fullCode ?? this.fullCode,
      factoryId: factoryId ?? this.factoryId,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      pdfPath: pdfPath ?? this.pdfPath,
      createdAt: createdAt ?? this.createdAt,
      type: type ?? this.type,
      widthMm: widthMm ?? this.widthMm,
      heightMm: heightMm ?? this.heightMm,
      heatingTime: heatingTime ?? this.heatingTime,
      imageData: imageData ?? this.imageData,
    );
  }
}