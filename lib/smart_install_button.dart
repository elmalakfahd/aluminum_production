import 'dart:js' as js;
import 'dart:js_util' as js_util;
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'app_localization.dart';

/// زر تثبيت التطبيق (PWA).
///
/// مهم: حدث `beforeinstallprompt` يُطلقه المتصفح مبكراً جداً أثناء تحميل
/// الصفحة - غالباً قبل أن يبدأ Flutter بالعمل. لهذا السبب يجب التقاطه من
/// `web/index.html` (سكربت يعمل فور تحميل الصفحة) وتخزينه في
/// `window.deferredPrompt`، ثم هذا الويدجت فقط "يقرأ" منه لاحقاً - لا يحاول
/// التقاط الحدث بنفسه لأن ذلك يأتي متأخراً دائماً ويفوّت الحدث.
///
/// Smart PWA install button. Reads the already-captured
/// `window.deferredPrompt` (captured early in index.html) instead of trying
/// to listen for `beforeinstallprompt` itself, since that event fires before
/// Flutter finishes booting and would otherwise always be missed.
class SmartInstallButton extends StatefulWidget {
  const SmartInstallButton({super.key});

  @override
  State<SmartInstallButton> createState() => _SmartInstallButtonState();
}

class _SmartInstallButtonState extends State<SmartInstallButton> {
  bool _isInstalled = false;
  bool _isLoading = true;
  bool _canPrompt = false;
  bool _isIOS = false;

  @override
  void initState() {
    super.initState();
    _detectPlatform();
    _checkAlreadyInstalled();
    _checkDeferredPromptAvailable();
    _listenForInstallReadyEvent();
    _listenForInstalledEvent();
  }

  bool get _hasDeferredPrompt => js.context['deferredPrompt'] != null;

  void _checkDeferredPromptAvailable() {
    setState(() => _canPrompt = _hasDeferredPrompt);
  }

  void _checkAlreadyInstalled() {
    try {
      final isStandalone = js.context['navigator']?['standalone'];
      final displayModeStandalone = js.context['window']
          ?.callMethod('matchMedia', ['(display-mode: standalone)'])?['matches'];

      setState(() {
        _isInstalled = isStandalone == true || displayModeStandalone == true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isInstalled = false;
        _isLoading = false;
      });
    }
  }

  void _detectPlatform() {
    try {
      final ua = (js.context['navigator']?['userAgent'] ?? '').toString();
      final isIOSDevice = ua.contains('iPhone') || ua.contains('iPad') || ua.contains('iPod');
      final isSafari = ua.contains('Safari') && !ua.contains('CriOS') && !ua.contains('FxiOS');
      _isIOS = isIOSDevice && isSafari;
    } catch (e) {
      _isIOS = false;
    }
  }

  // ✅ index.html يُطلق 'pwa-install-ready' على document فور التقاطه للحدث.
  // نلتقط هذا لتحديث الواجهة إن أصبح التثبيت متاحاً بعد أن بُني الويدجت.
  void _listenForInstallReadyEvent() {
    try {
      js.context['document'].callMethod('addEventListener', [
        'pwa-install-ready',
        js.JsFunction.withThis((thisArg, args) {
          if (mounted) setState(() => _canPrompt = true);
        })
      ]);
    } catch (e) {
      debugPrint('pwa-install-ready listener error: $e');
    }
  }

  // ✅ index.html يُطلق 'pwa-installed' سواء بعد تثبيت فعلي أو عند اكتشاف
  // أن التطبيق يعمل أصلاً في وضع standalone.
  void _listenForInstalledEvent() {
    try {
      js.context['document'].callMethod('addEventListener', [
        'pwa-installed',
        js.JsFunction.withThis((thisArg, args) {
          if (mounted) {
            setState(() {
              _isInstalled = true;
              _canPrompt = false;
            });
          }
        })
      ]);
    } catch (e) {
      debugPrint('pwa-installed listener error: $e');
    }
  }

  Future<void> _installApp() async {
    final deferredPrompt = js.context['deferredPrompt'];

    if (deferredPrompt != null) {
      try {
        deferredPrompt.callMethod('prompt', []);
        final choice = await js_util.promiseToFuture(deferredPrompt['userChoice']);
        final outcome = choice['outcome'];

        // ✅ حدث beforeinstallprompt يُستخدم مرة واحدة فقط - نفرّغه بعد الاستخدام
        js.context['deferredPrompt'] = null;
        setState(() => _canPrompt = false);

        if (outcome == 'accepted') {
          setState(() => _isInstalled = true);
          Fluttertoast.showToast(
            msg: context.mounted ? context.tr('app_installed_success') : '✅',
            backgroundColor: Colors.green,
            textColor: Colors.white,
          );
        }
        return;
      } catch (e) {
        debugPrint('install prompt failed: $e');
      }
    }

    // مسار iOS/Safari: لا يوجد beforeinstallprompt إطلاقاً على هذا المتصفح
    if (_isIOS) {
      _showIOSInstructions();
      return;
    }

    // الحدث لم يُطلق بعد (المتصفح لم يقرر بعد أنه قابل للتثبيت) - نعرض
    // تعليمات يدوية بدل ترك المستخدم بلا أي خطوة يقوم بها
    _showManualInstructions();
  }

  void _showManualInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('install_app_button')),
        content: Text(context.tr('manual_install_instructions')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('cancel')),
          ),
        ],
      ),
    );
  }

  void _showIOSInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('install_app_button')),
        content: Text(context.tr('ios_install_instructions')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('cancel')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 40,
        width: 40,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    // ✅ يختفي الزر تماماً إذا كان التطبيق مثبتاً بالفعل
    if (_isInstalled) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.green.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.green.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 16),
            const SizedBox(width: 6),
            Text(
              context.tr('app_installed_label'),
              style: const TextStyle(color: Colors.green, fontSize: 12),
            ),
          ],
        ),
      );
    }

    // ✅ الزر يبقى ظاهراً دائماً طالما التطبيق غير مثبت - حتى لو لم يُطلق
    // المتصفح حدث beforeinstallprompt بعد، لأن الضغط عليه سيعرض تعليمات
    // مناسبة بدل تركه بلا وسيلة تثبيت إطلاقاً.

    return ElevatedButton.icon(
      onPressed: _installApp,
      icon: const Icon(Icons.download, size: 20),
      label: Text(
        context.tr('install_app_button'),
        style: const TextStyle(fontSize: 14),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}
