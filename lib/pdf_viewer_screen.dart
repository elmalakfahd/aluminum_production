import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:http/http.dart' as http;

// ============================================================
// 📄 شاشة عرض الملفات (PDF والصور)
// ============================================================
class PdfViewerScreen extends StatefulWidget {
  final String? pdfUrl;
  final String? imageData; // ✅ Base64 data (صورة أو PDF)
  final String? title;

  const PdfViewerScreen({
    super.key,
    this.pdfUrl,
    this.imageData,
    this.title,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  bool _isImage = false;
  Uint8List? _imageBytes;
  String? _errorMessage;
  Uint8List? _pdfBytes; // ✅ تخزين بيانات PDF

  // ✅ التحقق من أن البيانات هي PDF
  bool _isPdfData(Uint8List bytes) {
    if (bytes.length < 4) return false;
    // توقيع PDF: %PDF
    return bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 && bytes[3] == 0x46;
  }

  // ✅ التحقق من أن البيانات هي صورة
  bool _isImageData(Uint8List bytes) {
    if (bytes.length < 4) return false;
    // PNG: 89 50 4E 47
    if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) return true;
    // JPEG: FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return true;
    return false;
  }

  @override
  void initState() {
    super.initState();
    _prepareFile();
  }

  Future<void> _prepareFile() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
      _imageBytes = null;
      _pdfBytes = null;
      _isImage = false;
    });

    try {
      // ✅ 1. إذا كان هناك بيانات Base64 (صورة أو PDF)
      if (widget.imageData != null && widget.imageData!.isNotEmpty) {
        try {
          final bytes = base64Decode(widget.imageData!);
          
          if (bytes.isEmpty) {
            throw Exception('البيانات فارغة');
          }
          
          // ✅ التحقق من نوع الملف
          if (_isPdfData(bytes)) {
            // ✅ عرض PDF مباشرة من الذاكرة
            setState(() {
              _pdfBytes = bytes;
              _isImage = false;
              _isLoading = false;
            });
            print('✅ تم تحميل PDF بنجاح (${bytes.length} بايت)');
            return;
          } else if (_isImageData(bytes)) {
            // ✅ عرض صورة
            setState(() {
              _imageBytes = bytes;
              _isImage = true;
              _isLoading = false;
            });
            return;
          } else {
            // ✅ نوع غير معروف، نحاول عرضه كصورة
            setState(() {
              _imageBytes = bytes;
              _isImage = true;
              _isLoading = false;
            });
            return;
          }
        } catch (e) {
          setState(() {
            _isLoading = false;
            _hasError = true;
            _errorMessage = 'فشل فك تشفير Base64: $e';
          });
          return;
        }
      }

      // ✅ 2. إذا كان هناك رابط URL
      if (widget.pdfUrl != null && widget.pdfUrl!.isNotEmpty) {
        try {
          final response = await http.get(Uri.parse(widget.pdfUrl!));
          if (response.statusCode == 200) {
            final bytes = response.bodyBytes;
            
            if (bytes.isEmpty) {
              throw Exception('الملف فارغ');
            }
            
            if (_isPdfData(bytes)) {
              setState(() {
                _pdfBytes = bytes;
                _isImage = false;
                _isLoading = false;
              });
              return;
            } else {
              setState(() {
                _imageBytes = bytes;
                _isImage = true;
                _isLoading = false;
              });
              return;
            }
          } else {
            throw Exception('فشل التحميل: ${response.statusCode}');
          }
        } catch (e) {
          setState(() {
            _isLoading = false;
            _hasError = true;
            _errorMessage = 'فشل تحميل الملف: $e';
          });
          return;
        }
      }

      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'لا يوجد بيانات لعرضها';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'خطأ غير متوقع: $e';
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ عرض الصورة من Base64
    if (_isImage && _imageBytes != null && !_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            widget.title ?? '🖼️ عرض الصورة',
            style: const TextStyle(fontSize: 16),
          ),
          backgroundColor: Colors.green,
          elevation: 2,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _prepareFile,
            ),
          ],
        ),
        body: Center(
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Image.memory(
              _imageBytes!,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, color: Colors.red, size: 48),
                      SizedBox(height: 12),
                      Text('⚠️ تعذر عرض الصورة'),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
    }

    // ✅ عرض PDF باستخدام syncfusion_flutter_pdfviewer
    if (_pdfBytes != null && !_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            widget.title ?? '📄 عرض PDF',
            style: const TextStyle(fontSize: 16),
          ),
          backgroundColor: Colors.red,
          elevation: 2,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _prepareFile,
            ),
          ],
        ),
        body: SfPdfViewer.memory(
          _pdfBytes!,
          enableTextSelection: true,
          scrollDirection: PdfScrollDirection.vertical,
          pageLayoutMode: PdfPageLayoutMode.single,
          onDocumentLoaded: (details) {
            // ✅ تم تحميل PDF بنجاح
            print('✅ PDF تم تحميله بنجاح');
          },
          onDocumentLoadFailed: (details) {
            setState(() {
              _isLoading = false;
              _hasError = true;
              _errorMessage = 'فشل تحميل PDF: ${details.error}';
            });
          },
        ),
      );
    }

    // ✅ مؤشر التحميل
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.title ?? 'جاري التحميل...'),
          backgroundColor: Colors.blue,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('جاري تحميل الملف...'),
            ],
          ),
        ),
      );
    }

    // ✅ رسالة الخطأ
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? '⚠️ خطأ'),
        backgroundColor: Colors.red,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 12),
            const Text(
              '⚠️ تعذر تحميل الملف',
              style: TextStyle(fontSize: 18, color: Colors.red),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _prepareFile,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}