import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as excel;
import 'package:http/http.dart' as http;
import 'dart:io';
import 'models.dart';
import 'services.dart';
import 'app_localization.dart';
import 'die_template_model.dart';
import 'pdf_viewer_screen.dart';

// ============================================================
// 🔧 شاشة إدارة القوالب المسجلة
// ============================================================
class DieManagementScreen extends StatefulWidget {
  const DieManagementScreen({super.key});

  @override
  State<DieManagementScreen> createState() => _DieManagementScreenState();
}

class _DieManagementScreenState extends State<DieManagementScreen> {
  late ShiftProvider _provider;
  List<DieTemplate> _templates = [];
  List<DieTemplate> _filteredTemplates = [];
  bool _isLoading = true;
  bool _isImporting = false;
  bool _isUploadingPdf = false;
  double _uploadProgress = 0.0;
  String _uploadStatus = '';

  // ✅ متغيرات الإضافة اليدوية
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _clientCodeController = TextEditingController();
  final TextEditingController _designCodeController = TextEditingController();
  final TextEditingController _dieCodeController = TextEditingController();
  final TextEditingController _versionController = TextEditingController();

  // ✅ متغيرات البحث
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _provider = Provider.of<ShiftProvider>(context, listen: false);
      _loadTemplates();
    });
  }

  Future<void> _loadTemplates() async {
    setState(() => _isLoading = true);
    try {
      await _provider.loadAllData();
      _templates = await _provider.service.getDieTemplates(_provider.currentFactoryId);
      _filteredTemplates = List.from(_templates);
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      Fluttertoast.showToast(
        msg: 'خطأ في تحميل القوالب: $e',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  void _filterTemplates() {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() => _filteredTemplates = List.from(_templates));
      return;
    }
    setState(() {
      _filteredTemplates = _templates.where((die) {
        return die.name.toLowerCase().contains(query) ||
            die.clientCode.toLowerCase().contains(query) ||
            die.designCode.toLowerCase().contains(query) ||
            die.dieCode.toLowerCase().contains(query) ||
            die.fullCode.toLowerCase().contains(query);
      }).toList();
    });
  }

  // ✅ دالة محسنة لاستخراج كود القالب من اسم الملف
  String _extractDieCodeFromFileName(String fileName) {
    String code = fileName.replaceAll(RegExp(r'\.(pdf|PDF|png|jpg|jpeg|PNG|JPG|JPEG)$'), '');
    code = code.replaceAll(RegExp(r'\s*\(\d+\)\s*$'), '');
    code = code.replaceAll(' ', '');
    code = code.replaceAll('_', '');
    code = code.replaceAll('-', '');
    code = code.trim();
    return code;
  }

  // ✅ دالة للحصول على امتداد الملف
  String _getFileExtension(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    if (extension == 'pdf') return 'pdf';
    if (extension == 'png') return 'png';
    if (extension == 'jpg' || extension == 'jpeg') return 'jpg';
    return 'pdf';
  }

  // ✅ تحويل رابط Google Drive إلى رابط مباشر
  String _getGoogleDriveDirectLink(String url) {
    if (url.contains('livedbs.web.app')) {
      return url;
    }
    
    final RegExp regExp = RegExp(r'/file/d/([a-zA-Z0-9_-]+)');
    final match = regExp.firstMatch(url);
    if (match != null) {
      final fileId = match.group(1);
      return 'https://drive.google.com/thumbnail?sz=w1000&id=$fileId';
    }
    return url;
  }

  bool _isGoogleDriveUrl(String url) {
    return url.contains('drive.google.com') || url.contains('googleusercontent.com');
  }

  // ============================================================
  // 📤 رفع صورة وتخزينها كـ Base64 في قاعدة البيانات
  // ============================================================
  Future<void> _uploadImageAsBase64() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.image,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        Fluttertoast.showToast(
          msg: '⚠️ لم يتم اختيار أي صورة',
          backgroundColor: Colors.orange,
          textColor: Colors.white,
        );
        return;
      }

      setState(() => _isUploadingPdf = true);

      final file = result.files.first;
      String dieCode = _extractDieCodeFromFileName(file.name);
      
      final dieTemplate = await _provider.service.getDieTemplateByCode(
        _provider.currentFactoryId,
        dieCode,
      );

      if (dieTemplate == null) {
        setState(() => _isUploadingPdf = false);
        Fluttertoast.showToast(
          msg: '⚠️ لا يوجد قالب بهذا الكود: $dieCode',
          backgroundColor: Colors.orange,
          textColor: Colors.white,
        );
        return;
      }

      // ✅ تحويل الصورة إلى Base64
      final base64Image = base64Encode(file.bytes!);
      
      // ✅ حفظ الصورة في قاعدة البيانات
      final updatedDie = dieTemplate.copyWith(
        imageData: base64Image,
        pdfUrl: null,
        pdfPath: 'base64_${dieCode}_${DateTime.now().millisecondsSinceEpoch}',
      );
      await _provider.service.saveDieTemplate(_provider.currentFactoryId, updatedDie);

      await _loadTemplates();
      setState(() => _isUploadingPdf = false);

      Fluttertoast.showToast(
        msg: '✅ تم رفع الصورة للقالب: ${dieTemplate.fullCode}',
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
    } catch (e) {
      setState(() => _isUploadingPdf = false);
      Fluttertoast.showToast(
        msg: '❌ خطأ: $e',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  // ============================================================
  // 📤 رفع PDF وتخزينه كـ Base64 في قاعدة البيانات
  // ============================================================
  Future<void> _uploadPdfAsBase64() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        Fluttertoast.showToast(
          msg: '⚠️ لم يتم اختيار أي ملف PDF',
          backgroundColor: Colors.orange,
          textColor: Colors.white,
        );
        return;
      }

      setState(() => _isUploadingPdf = true);

      final file = result.files.first;
      String dieCode = _extractDieCodeFromFileName(file.name);
      
      final dieTemplate = await _provider.service.getDieTemplateByCode(
        _provider.currentFactoryId,
        dieCode,
      );

      if (dieTemplate == null) {
        setState(() => _isUploadingPdf = false);
        Fluttertoast.showToast(
          msg: '⚠️ لا يوجد قالب بهذا الكود: $dieCode',
          backgroundColor: Colors.orange,
          textColor: Colors.white,
        );
        return;
      }

      // ✅ تحويل PDF إلى Base64
      final base64Pdf = base64Encode(file.bytes!);
      
      // ✅ حفظ PDF في قاعدة البيانات (نستخدم imageData لتخزين Base64)
      final updatedDie = dieTemplate.copyWith(
        imageData: base64Pdf,  // ✅ نخزن PDF كـ Base64 في imageData
        pdfUrl: null,
        pdfPath: 'base64_pdf_${dieCode}_${DateTime.now().millisecondsSinceEpoch}',
      );
      await _provider.service.saveDieTemplate(_provider.currentFactoryId, updatedDie);

      await _loadTemplates();
      setState(() => _isUploadingPdf = false);

      Fluttertoast.showToast(
        msg: '✅ تم رفع PDF للقالب: ${dieTemplate.fullCode}',
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
    } catch (e) {
      setState(() => _isUploadingPdf = false);
      Fluttertoast.showToast(
        msg: '❌ خطأ: $e',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  // ============================================================
  // 🔄 تحديث رسم القالب (استبدال الرسم الحالي بآخر جديد)
  // ============================================================
  Future<void> _updateDieDrawing(DieTemplate die) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'PNG', 'JPG', 'JPEG'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        Fluttertoast.showToast(
          msg: '⚠️ لم يتم اختيار أي ملف',
          backgroundColor: Colors.orange,
          textColor: Colors.white,
        );
        return;
      }

      setState(() => _isUploadingPdf = true);

      final file = result.files.first;
      final extension = _getFileExtension(file.name);
      final isPdf = extension == 'pdf';
      
      // ✅ تحويل الملف إلى Base64
      final base64Data = base64Encode(file.bytes!);
      
      // ✅ تحديث بيانات الرسم
      final updatedDie = die.copyWith(
        imageData: base64Data,  // ✅ نخزن الصورة أو PDF كـ Base64
        pdfUrl: null,
        pdfPath: 'updated_${die.dieCode}_${DateTime.now().millisecondsSinceEpoch}.$extension',
      );
      
      await _provider.service.saveDieTemplate(_provider.currentFactoryId, updatedDie);
      await _loadTemplates();

      setState(() => _isUploadingPdf = false);

      Fluttertoast.showToast(
        msg: '✅ تم تحديث رسم القالب: ${die.fullCode}',
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
    } catch (e) {
      setState(() => _isUploadingPdf = false);
      Fluttertoast.showToast(
        msg: '❌ خطأ في تحديث الرسم: $e',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  // ============================================================
  // 🗑️ حذف الرسم المرتبط بالقالب
  // ============================================================
  Future<void> _deleteDieDrawing(DieTemplate die) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ تأكيد حذف الرسم'),
        content: Text(
          'هل أنت متأكد من حذف الرسم المرتبط بالقالب "${die.fullCode}"؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final updatedDie = die.copyWith(
        imageData: null,
        pdfUrl: null,
        pdfPath: null,
      );
      
      await _provider.service.saveDieTemplate(_provider.currentFactoryId, updatedDie);
      await _loadTemplates();

      Fluttertoast.showToast(
        msg: '✅ تم حذف الرسم من القالب: ${die.fullCode}',
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: '❌ خطأ في حذف الرسم: $e',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ============================================================
  // 📤 ربط يدوي برابط (مع دعم Google Drive)
  // ============================================================
  void _showManualUrlDialog() {
    final TextEditingController urlController = TextEditingController();
    final TextEditingController codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🔗 ربط رسم يدوياً'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: codeController,
              decoration: const InputDecoration(
                labelText: '🏷️ كود القالب',
                hintText: 'مثال: ES001029',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: '🔗 رابط الرسم (Google Drive)',
                hintText: 'https://drive.google.com/file/d/.../view',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info, color: Colors.blue, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '💡 استخدم رابط Google Drive بعد جعل الملف عاماً',
                      style: TextStyle(fontSize: 11, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              final code = codeController.text.trim();
              final url = urlController.text.trim();

              if (code.isEmpty || url.isEmpty) {
                Fluttertoast.showToast(
                  msg: '⚠️ الرجاء إدخال الكود والرابط',
                  backgroundColor: Colors.orange,
                  textColor: Colors.white,
                );
                return;
              }

              Navigator.pop(context);
              await _updateDieWithManualUrl(code, url);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
            ),
            child: const Text('💾 حفظ'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateDieWithManualUrl(String code, String url) async {
    try {
      String finalUrl = url;
      
      if (_isGoogleDriveUrl(url)) {
        finalUrl = _getGoogleDriveDirectLink(url);
        print('🔗 تحويل Google Drive إلى رابط عرض: $finalUrl');
      }
      
      print('🔗 الرابط الأصلي: $url');
      print('🔗 الرابط النهائي: $finalUrl');

      final dieTemplate = await _provider.service.getDieTemplateByCode(
        _provider.currentFactoryId,
        code,
      );

      if (dieTemplate == null) {
        Fluttertoast.showToast(
          msg: '⚠️ القالب غير موجود: $code',
          backgroundColor: Colors.orange,
          textColor: Colors.white,
        );
        return;
      }

      try {
        final response = await http.head(Uri.parse(finalUrl));
        if (response.statusCode != 200 && response.statusCode != 302) {
          Fluttertoast.showToast(
            msg: '⚠️ الرابط غير صحيح أو الملف غير متاح (الرمز: ${response.statusCode})',
            backgroundColor: Colors.orange,
            textColor: Colors.white,
          );
          return;
        }
      } catch (e) {
        print('⚠️ تحذير: لا يمكن التحقق من الرابط: $e');
      }

      final updatedDie = dieTemplate.copyWith(
        pdfUrl: finalUrl,
        pdfPath: 'google_drive_${code}_${DateTime.now().millisecondsSinceEpoch}',
        imageData: null,
      );
      await _provider.service.saveDieTemplate(_provider.currentFactoryId, updatedDie);
      await _loadTemplates();

      Fluttertoast.showToast(
        msg: '✅ تم ربط الرسم بالقالب: ${dieTemplate.fullCode}',
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: '❌ خطأ: $e',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  // ============================================================
  // ➕ إضافة قالب يدوياً
  // ============================================================
  Future<void> _addDieTemplate() async {
    if (_nameController.text.isEmpty ||
        _clientCodeController.text.isEmpty ||
        _dieCodeController.text.isEmpty) {
      Fluttertoast.showToast(
        msg: '⚠️ الرجاء إدخال الاسم وكود العميل وكود القالب',
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
      return;
    }

    final baseCode = _dieCodeController.text.trim();
    final version = _versionController.text.trim();
    final fullCode = version.isNotEmpty ? '$baseCode/$version' : baseCode;

    final existing = _templates.any((d) =>
        d.clientCode == _clientCodeController.text.trim() ||
        d.designCode == _designCodeController.text.trim() ||
        d.dieCode == baseCode ||
        d.fullCode == fullCode);

    if (existing) {
      Fluttertoast.showToast(
        msg: '⚠️ يوجد قالب بنفس الكود بالفعل',
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final newDie = DieTemplate(
        id: 'die_${DateTime.now().millisecondsSinceEpoch}',
        name: _nameController.text.trim(),
        clientCode: _clientCodeController.text.trim(),
        designCode: _designCodeController.text.trim().isNotEmpty
            ? _designCodeController.text.trim()
            : _clientCodeController.text.trim(),
        dieCode: baseCode,
        version: version.isNotEmpty ? version : null,
        fullCode: fullCode,
        factoryId: _provider.currentFactoryId,
      );

      await _provider.service.saveDieTemplate(_provider.currentFactoryId, newDie);
      await _loadTemplates();

      _nameController.clear();
      _clientCodeController.clear();
      _designCodeController.clear();
      _dieCodeController.clear();
      _versionController.clear();

      Fluttertoast.showToast(
        msg: '✅ تم إضافة القالب ${newDie.fullCode}',
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: '❌ خطأ: $e',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ============================================================
  // 📤 استيراد من Excel
  // ============================================================
  Future<void> _importFromExcel() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
      );

      if (result == null) return;

      setState(() => _isImporting = true);

      final bytes = result.files.first.bytes;
      if (bytes == null) {
        setState(() => _isImporting = false);
        Fluttertoast.showToast(
          msg: '⚠️ الملف فارغ',
          backgroundColor: Colors.orange,
          textColor: Colors.white,
        );
        return;
      }

      final excelFile = excel.Excel.decodeBytes(bytes);
      final sheet = excelFile.tables[excelFile.tables.keys.first];
      if (sheet == null) {
        setState(() => _isImporting = false);
        Fluttertoast.showToast(
          msg: '⚠️ الملف لا يحتوي على بيانات',
          backgroundColor: Colors.orange,
          textColor: Colors.white,
        );
        return;
      }

      int addedCount = 0;
      int errorCount = 0;

      for (var row in sheet.rows.skip(1)) {
        if (row.length < 3) continue;

        final dieCode = row[0]?.value?.toString().trim() ?? '';
        final clientCode = row[1]?.value?.toString().trim() ?? '';
        final designCode = row[2]?.value?.toString().trim() ?? '';

        if (dieCode.isEmpty || clientCode.isEmpty) {
          errorCount++;
          continue;
        }

        String baseCode = dieCode;
        String? version;
        if (dieCode.contains('/')) {
          final parts = dieCode.split('/');
          baseCode = parts[0].trim();
          version = parts.sublist(1).join('/').trim();
        }

        final fullCode = version != null && version.isNotEmpty
            ? '$baseCode/$version'
            : baseCode;

        final name = baseCode;

        final existing = _templates.any((d) =>
            d.clientCode == clientCode ||
            d.designCode == designCode ||
            d.dieCode == baseCode ||
            d.fullCode == fullCode);

        if (existing) {
          errorCount++;
          continue;
        }

        final newDie = DieTemplate(
          id: 'die_${DateTime.now().millisecondsSinceEpoch}_${addedCount}',
          name: name,
          clientCode: clientCode,
          designCode: designCode.isNotEmpty ? designCode : clientCode,
          dieCode: baseCode,
          version: version,
          fullCode: fullCode,
          factoryId: _provider.currentFactoryId,
        );

        await _provider.service.saveDieTemplate(_provider.currentFactoryId, newDie);
        addedCount++;
        _templates.add(newDie);
      }

      _filteredTemplates = List.from(_templates);
      setState(() => _isImporting = false);

      Fluttertoast.showToast(
        msg: '✅ تم استيراد $addedCount قالب${errorCount > 0 ? ', $errorCount خطأ' : ''}',
        backgroundColor: Colors.green,
        textColor: Colors.white,
        toastLength: Toast.LENGTH_LONG,
      );
    } catch (e) {
      setState(() => _isImporting = false);
      Fluttertoast.showToast(
        msg: '❌ خطأ في الاستيراد: $e',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  // ============================================================
  // 🗑️ حذف قالب
  // ============================================================
  Future<void> _deleteDieTemplate(DieTemplate die) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف القالب "${die.fullCode}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _provider.service.deleteDieTemplate(_provider.currentFactoryId, die.id);
                await _loadTemplates();
                Fluttertoast.showToast(
                  msg: '✅ تم حذف القالب',
                  backgroundColor: Colors.red,
                  textColor: Colors.white,
                );
              } catch (e) {
                Fluttertoast.showToast(
                  msg: '❌ خطأ: $e',
                  backgroundColor: Colors.red,
                  textColor: Colors.white,
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ✅ عرض الملف (PDF أو صورة)
  void _openFileViewer(DieTemplate die) {
    // ✅ نرسل البيانات مباشرة إلى PdfViewerScreen
    if (die.imageData != null && die.imageData!.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfViewerScreen(
            imageData: die.imageData,  // ✅ Base64 (صورة أو PDF)
            title: 'رسم القالب: ${die.name}',
          ),
        ),
      );
      return;
    }
    
    if (die.pdfUrl != null && die.pdfUrl!.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfViewerScreen(
            pdfUrl: die.pdfUrl,
            title: 'رسم القالب: ${die.name}',
          ),
        ),
      );
      return;
    }
    
    Fluttertoast.showToast(
      msg: '⚠️ لا يوجد رسم للقالب',
      backgroundColor: Colors.orange,
      textColor: Colors.white,
    );
  }

  // ============================================================
  // 📋 عرض القالب في نافذة منبثقة
  // ============================================================
  void _showDieDetails(DieTemplate die) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('📦 ${die.fullCode}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow('📦 اسم القالب', die.name),
              _detailRow('🏷️ كود العميل', die.clientCode),
              _detailRow('🏷️ كود التصميم', die.designCode),
              _detailRow('🏷️ كود القالب', die.fullCode),
              if (die.version != null) _detailRow('🔢 رقم النسخة', die.version!),
              _detailRow('📅 تاريخ التسجيل', _formatDate(die.createdAt)),
              if (die.hasDrawing) ...[
                const Divider(),
                const Text('📎 الرسم:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _openFileViewer(die),
                  child: Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: die.imageData != null
                        ? Image.memory(
                            base64Decode(die.imageData!),
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.error_outline, color: Colors.red, size: 32),
                                    SizedBox(height: 8),
                                    Text('تعذر عرض الصورة'),
                                  ],
                                ),
                              );
                            },
                          )
                        : const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.picture_as_pdf, size: 48, color: Colors.red),
                                SizedBox(height: 8),
                                Text('اضغط لعرض الرسم'),
                              ],
                            ),
                          ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
          if (die.hasDrawing)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _openFileViewer(die);
              },
              icon: const Icon(Icons.visibility),
              label: const Text('عرض الرسم'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _clientCodeController.dispose();
    _designCodeController.dispose();
    _dieCodeController.dispose();
    _versionController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ShiftProvider>(context);

    if (!provider.isDeveloper && !provider.isOwner && !provider.isManager) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('⛔ غير مصرح'),
          backgroundColor: Colors.red,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text(
                'ليس لديك صلاحية للوصول إلى هذه الصفحة',
                style: TextStyle(fontSize: 18, color: Colors.red),
              ),
              Text(
                'هذه الصفحة مخصصة للمطور والمالك ومديري المصانع',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('🔧 إدارة القوالب المسجلة'),
        backgroundColor: Colors.deepPurple,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadTemplates,
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextFormField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: '🔍 ابحث عن قالب (اسم، كود العميل، كود التصميم، كود القالب)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                                _filterTemplates();
                              },
                            )
                          : null,
                    ),
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                      _filterTemplates();
                    },
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isImporting ? null : _importFromExcel,
                          icon: _isImporting
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.upload_file),
                          label: Text(
                            _isImporting ? 'جاري الاستيراد...' : '📤 استيراد من Excel',
                            style: const TextStyle(fontSize: 12),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isUploadingPdf ? null : _uploadImageAsBase64,
                          icon: _isUploadingPdf
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.image),
                          label: Text(
                            _isUploadingPdf ? 'جاري الرفع...' : '🖼️ رفع صورة',
                            style: const TextStyle(fontSize: 12),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isUploadingPdf ? null : _uploadPdfAsBase64,
                          icon: _isUploadingPdf
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.picture_as_pdf),
                          label: Text(
                            _isUploadingPdf ? 'جاري الرفع...' : '📄 رفع PDF',
                            style: const TextStyle(fontSize: 12),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _showManualUrlDialog,
                          icon: const Icon(Icons.link),
                          label: const Text('🔗 ربط يدوي', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (_isUploadingPdf)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        LinearProgressIndicator(
                          value: _uploadProgress,
                          backgroundColor: Colors.grey.shade300,
                          color: Colors.purple,
                          minHeight: 8,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _uploadStatus,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 8),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '📋 القوالب المسجلة',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${_filteredTemplates.length} قالب',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 4),

                Expanded(
                  child: _filteredTemplates.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inventory, size: 64, color: Colors.grey.shade300),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isEmpty
                                    ? 'لا توجد قوالب مسجلة'
                                    : 'لا توجد نتائج مطابقة',
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                              ),
                              if (_searchQuery.isEmpty)
                                Text(
                                  'أضف قوالب من خلال استيراد Excel أو الإضافة اليدوية',
                                  style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                                ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: _filteredTemplates.length,
                          itemBuilder: (context, index) {
                            final die = _filteredTemplates[index];
                            return _buildDieCard(die);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  // ============================================================
  // 🃏 بطاقة القالب (مع أزرار تحديث وحذف الرسم)
  // ============================================================
  Widget _buildDieCard(DieTemplate die) {
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: () => _showDieDetails(die),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: die.version != null ? Colors.deepPurple.shade100 : Colors.blue.shade100,
                radius: 18,
                child: Text(
                  die.name.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    color: die.version != null ? Colors.deepPurple.shade700 : Colors.blue.shade700,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      die.fullCode,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '🏷️ ${die.clientCode} | ${die.designCode}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                    if (die.version != null)
                      Text(
                        '🔢 نسخة: ${die.version}',
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                      ),
                    // ✅ عرض حالة الرسم
                    if (die.hasDrawing)
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          die.imageData != null ? '🖼️ صورة' : '📄 PDF',
                          style: TextStyle(fontSize: 9, color: Colors.green.shade700),
                        ),
                      ),
                  ],
                ),
              ),
              // ✅ أيقونة الملف (إذا كان هناك رسم)
              if (die.hasDrawing)
                GestureDetector(
                  onTap: () => _openFileViewer(die),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: die.imageData != null ? Colors.green.shade100 : Colors.red.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      die.imageData != null ? Icons.image : Icons.picture_as_pdf,
                      color: die.imageData != null ? Colors.green : Colors.red,
                      size: 20,
                    ),
                  ),
                ),
              // ✅ زر تحديث الرسم
              if (die.hasDrawing)
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.orange, size: 20),
                  onPressed: () => _updateDieDrawing(die),
                  tooltip: 'تحديث الرسم',
                ),
              // ✅ زر حذف الرسم
              if (die.hasDrawing)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  onPressed: () => _deleteDieDrawing(die),
                  tooltip: 'حذف الرسم',
                ),
              // ✅ زر حذف القالب
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                onPressed: () => _deleteDieTemplate(die),
                tooltip: 'حذف القالب',
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // 📝 نافذة الإضافة اليدوية
  // ============================================================
  void _showAddDialog() {
    _nameController.clear();
    _clientCodeController.clear();
    _designCodeController.clear();
    _dieCodeController.clear();
    _versionController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('➕ إضافة قالب جديد'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '📦 اسم القالب',
                  border: OutlineInputBorder(),
                  isDense: true,
                  hintText: 'مثال: ES001029',
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _clientCodeController,
                decoration: const InputDecoration(
                  labelText: '🏷️ كود العميل (Cust. Profile Code)',
                  border: OutlineInputBorder(),
                  isDense: true,
                  hintText: 'مثال: 10212AA',
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _designCodeController,
                decoration: const InputDecoration(
                  labelText: '🏷️ كود التصميم (Design Code)',
                  border: OutlineInputBorder(),
                  isDense: true,
                  hintText: 'مثال: 213204',
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _dieCodeController,
                decoration: const InputDecoration(
                  labelText: '🏷️ كود القالب الأساسي (Profil code)',
                  border: OutlineInputBorder(),
                  isDense: true,
                  hintText: 'مثال: ES001029',
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _versionController,
                decoration: const InputDecoration(
                  labelText: '🔢 رقم النسخة (اختياري)',
                  border: OutlineInputBorder(),
                  isDense: true,
                  hintText: 'مثال: 1m, 2m, 3d',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: _addDieTemplate,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            child: const Text('💾 حفظ'),
          ),
        ],
      ),
    );
  }
}