import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================
// 🌐 نظام تبديل اللغة (عربي / إنجليزي)
// ============================================================

enum AppLanguage { ar, en }

class LocaleProvider extends ChangeNotifier {
  static const String _prefsKey = 'app_language';

  static AppLanguage currentLanguage = AppLanguage.ar;

  AppLanguage _language = AppLanguage.ar;
  AppLanguage get language => _language;

  bool get isArabic => _language == AppLanguage.ar;

  Locale get locale =>
      isArabic ? const Locale('ar', 'SA') : const Locale('en', 'US');

  TextDirection get textDirection =>
      isArabic ? TextDirection.rtl : TextDirection.ltr;

  LocaleProvider() {
    _loadSavedLanguage();
  }

  Future<void> _loadSavedLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      if (saved == 'en') {
        _language = AppLanguage.en;
        currentLanguage = AppLanguage.en;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> toggleLanguage() async {
    _language = isArabic ? AppLanguage.en : AppLanguage.ar;
    currentLanguage = _language;
    notifyListeners();
    await _persist();
  }

  Future<void> setLanguage(AppLanguage lang) async {
    if (_language == lang) return;
    _language = lang;
    currentLanguage = _language;
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, isArabic ? 'ar' : 'en');
    } catch (_) {}
  }
}

// ============================================================
// 📚 قاموس النصوص
// ============================================================

class AppStrings {
  AppStrings._();

  static final Map<String, Map<AppLanguage, String>> _values = {
    // ---- عام / General ----
    'app_title': {
      AppLanguage.ar: '🏆 DELMAR PRO',
      AppLanguage.en: '🏆 DELMAR PRO',
    },
    'loading_app': {
      AppLanguage.ar: 'جاري تحميل التطبيق...',
      AppLanguage.en: 'Loading application...',
    },
    'cancel': {AppLanguage.ar: 'إلغاء', AppLanguage.en: 'Cancel'},
    'send': {AppLanguage.ar: 'إرسال', AppLanguage.en: 'Send'},
    'error_generic': {AppLanguage.ar: '❌ خطأ', AppLanguage.en: '❌ Error'},
    'unexpected_error': {
      AppLanguage.ar: '❌ خطأ غير متوقع:',
      AppLanguage.en: '❌ Unexpected error:',
    },
    'delete_word': {AppLanguage.ar: 'حذف', AppLanguage.en: 'Delete'},
    'diameter_label': {AppLanguage.ar: 'القطر', AppLanguage.en: 'Diameter'},
    'inch_suffix': {AppLanguage.ar: ' بوصة', AppLanguage.en: ' in'},
    'save_word': {AppLanguage.ar: 'حفظ', AppLanguage.en: 'Save'},
    'refresh_plain': {AppLanguage.ar: 'تحديث', AppLanguage.en: 'Refresh'},
    'not_authorized': {AppLanguage.ar: '⛔ غير مصرح', AppLanguage.en: '⛔ Not Authorized'},
    'no_permission_page': {
      AppLanguage.ar: 'ليس لديك صلاحية للوصول إلى هذه الصفحة',
      AppLanguage.en: 'You don\'t have permission to access this page',
    },
    'dev_only_page': {
      AppLanguage.ar: 'هذه الصفحة مخصصة للمطور فقط',
      AppLanguage.en: 'This page is for the developer only',
    },

    // ---- تسجيل الدخول / Login ----
    'login': {AppLanguage.ar: 'تسجيل الدخول', AppLanguage.en: 'Login'},
    'login_enter_email_password': {
      AppLanguage.ar: '⚠️ الرجاء إدخال البريد الإلكتروني وكلمة المرور',
      AppLanguage.en: '⚠️ Please enter your email and password',
    },
    'welcome_developer': {
      AppLanguage.ar: '👑 مرحباً بك مطور التطبيق',
      AppLanguage.en: '👑 Welcome, App Developer',
    },
    'login_success': {
      AppLanguage.ar: '✅ تم تسجيل الدخول بنجاح',
      AppLanguage.en: '✅ Signed in successfully',
    },
    'login_error': {
      AppLanguage.ar: '❌ خطأ في تسجيل الدخول',
      AppLanguage.en: '❌ Login error',
    },
    'user_not_found': {
      AppLanguage.ar: '❌ المستخدم غير موجود',
      AppLanguage.en: '❌ User not found',
    },
    'wrong_password': {
      AppLanguage.ar: '❌ كلمة المرور غير صحيحة',
      AppLanguage.en: '❌ Incorrect password',
    },
    'invalid_email': {
      AppLanguage.ar: '❌ البريد الإلكتروني غير صحيح',
      AppLanguage.en: '❌ Invalid email address',
    },
    'too_many_attempts': {
      AppLanguage.ar: '❌ محاولات كثيرة، يرجى المحاولة لاحقاً',
      AppLanguage.en: '❌ Too many attempts, please try again later',
    },
    'no_internet': {
      AppLanguage.ar: '❌ لا يوجد اتصال بالإنترنت',
      AppLanguage.en: '❌ No internet connection',
    },
    'account_not_activated': {
      AppLanguage.ar: '⛔ حسابك غير مفعل. يرجى التواصل مع المطور لتفعيل حسابك',
      AppLanguage.en:
          '⛔ Your account is not activated. Please contact the developer.',
    },
    'no_permission_login': {
      AppLanguage.ar: '⛔ ليس لديك صلاحية للدخول. يرجى التواصل مع المطور',
      AppLanguage.en:
          '⛔ You don\'t have permission to log in. Please contact the developer.',
    },
    'user_not_found_system': {
      AppLanguage.ar: '❌ المستخدم غير موجود في النظام',
      AppLanguage.en: '❌ User not found in the system',
    },
    'email_label': {
      AppLanguage.ar: '📧 البريد الإلكتروني',
      AppLanguage.en: '📧 Email',
    },
    'password_label': {
      AppLanguage.ar: '🔑 كلمة المرور',
      AppLanguage.en: '🔑 Password',
    },
    'factory_name_new_users': {
      AppLanguage.ar: '🏭 اسم المصنع (للمستخدمين الجدد)',
      AppLanguage.en: '🏭 Factory Name (for new users)',
    },
    'enter_factory_name': {
      AppLanguage.ar: 'أدخل اسم المصنع الخاص بك',
      AppLanguage.en: 'Enter your factory name',
    },
    'forgot_password': {
      AppLanguage.ar: '🔑 نسيت كلمة المرور؟',
      AppLanguage.en: '🔑 Forgot password?',
    },
    'copyright': {
      AppLanguage.ar: '© 2026 🏆 DELMAR PRO',
      AppLanguage.en: '© 2026 🏆 DELMAR PRO',
    },
    'reset_password': {
      AppLanguage.ar: '🔑 إعادة تعيين كلمة المرور',
      AppLanguage.en: '🔑 Reset Password',
    },
    'enter_email_reset_link': {
      AppLanguage.ar: 'أدخل بريدك الإلكتروني لإرسال رابط إعادة التعيين',
      AppLanguage.en: 'Enter your email to receive a reset link',
    },
    'please_enter_email': {
      AppLanguage.ar: '⚠️ الرجاء إدخال البريد الإلكتروني',
      AppLanguage.en: '⚠️ Please enter your email',
    },
    'reset_link_sent': {
      AppLanguage.ar: '✅ تم إرسال رابط إعادة التعيين إلى بريدك الإلكتروني',
      AppLanguage.en: '✅ Reset link sent to your email',
    },

    // ---- تغيير كلمة المرور ----
    'change_password_title': {
      AppLanguage.ar: '🔑 تغيير كلمة المرور',
      AppLanguage.en: '🔑 Change Password',
    },
    'change_password': {
      AppLanguage.ar: 'تغيير كلمة المرور',
      AppLanguage.en: 'Change Password',
    },
    'enter_current_new_password': {
      AppLanguage.ar: 'أدخل كلمة المرور الحالية والجديدة',
      AppLanguage.en: 'Enter your current and new password',
    },
    'fill_all_fields': {
      AppLanguage.ar: '⚠️ الرجاء ملء جميع الحقول',
      AppLanguage.en: '⚠️ Please fill in all fields',
    },
    'passwords_dont_match': {
      AppLanguage.ar: '⚠️ كلمة المرور الجديدة غير متطابقة',
      AppLanguage.en: '⚠️ New passwords do not match',
    },
    'password_min_length': {
      AppLanguage.ar: '⚠️ كلمة المرور يجب أن تكون 6 أحرف على الأقل',
      AppLanguage.en: '⚠️ Password must be at least 6 characters',
    },
    'min_6_chars_helper': {
      AppLanguage.ar: 'يجب أن تكون 6 أحرف على الأقل',
      AppLanguage.en: 'Must be at least 6 characters',
    },
    'not_signed_in': {
      AppLanguage.ar: '❌ لم يتم تسجيل الدخول',
      AppLanguage.en: '❌ Not signed in',
    },
    'password_changed_success': {
      AppLanguage.ar: '✅ تم تغيير كلمة المرور بنجاح',
      AppLanguage.en: '✅ Password changed successfully',
    },
    'password_change_error': {
      AppLanguage.ar: '❌ خطأ في تغيير كلمة المرور',
      AppLanguage.en: '❌ Error changing password',
    },
    'current_password_incorrect': {
      AppLanguage.ar: '❌ كلمة المرور الحالية غير صحيحة',
      AppLanguage.en: '❌ Current password is incorrect',
    },
    'new_password_weak': {
      AppLanguage.ar: '❌ كلمة المرور الجديدة ضعيفة',
      AppLanguage.en: '❌ New password is too weak',
    },
    'reauth_required': {
      AppLanguage.ar: '❌ يرجى تسجيل الدخول مرة أخرى ثم المحاولة',
      AppLanguage.en: '❌ Please sign in again and retry',
    },
    'current_password_label': {
      AppLanguage.ar: '🔑 كلمة المرور الحالية',
      AppLanguage.en: '🔑 Current Password',
    },
    'new_password_label': {
      AppLanguage.ar: '🔑 كلمة المرور الجديدة',
      AppLanguage.en: '🔑 New Password',
    },
    'confirm_new_password_label': {
      AppLanguage.ar: '🔑 تأكيد كلمة المرور الجديدة',
      AppLanguage.en: '🔑 Confirm New Password',
    },

    // ---- زر التثبيت ----
    'app_installed_success': {
      AppLanguage.ar: '✅ تم تثبيت التطبيق بنجاح',
      AppLanguage.en: '✅ App installed successfully',
    },
    'installing_app': {
      AppLanguage.ar: '📱 جاري تثبيت التطبيق...',
      AppLanguage.en: '📱 Installing app...',
    },
    'tap_install_icon': {
      AppLanguage.ar: 'اضغط على زر التثبيت في شريط العنوان',
      AppLanguage.en: 'Tap the install icon in the address bar',
    },
    'app_installed_label': {
      AppLanguage.ar: '✅ التطبيق مثبت',
      AppLanguage.en: '✅ App Installed',
    },
    'install_app_button': {
      AppLanguage.ar: '📱 تثبيت التطبيق',
      AppLanguage.en: '📱 Install App',
    },
    'ios_install_instructions': {
      AppLanguage.ar:
          'لتثبيت التطبيق: اضغط على زر المشاركة ثم "إضافة إلى الشاشة الرئيسية"',
      AppLanguage.en:
          'To install: tap the Share button, then "Add to Home Screen"',
    },
    'manual_install_instructions': {
      AppLanguage.ar:
          'افتح قائمة المتصفح (⋮ أو ⋯) واختر "تثبيت التطبيق" أو "إضافة إلى الشاشة الرئيسية". إذا لم يظهر هذا الخيار، تأكد من فتح الموقع عبر الرابط الرسمي المنشور (وليس أثناء التطوير)، ثم أعد تحميل الصفحة.',
      AppLanguage.en:
          'Open the browser menu (⋮ or ⋯) and choose "Install app" or "Add to Home Screen". If you don\'t see that option, make sure you\'re on the published site (not a development build), then reload the page.',
    },

    // ---- الشاشة الرئيسية ----
    'greeting_morning': {
      AppLanguage.ar: '☀️ صباح الخير يا',
      AppLanguage.en: '☀️ Good morning,',
    },
    'greeting_afternoon': {
      AppLanguage.ar: '🌤️ مساء الخير يا',
      AppLanguage.en: '🌤️ Good afternoon,',
    },
    'greeting_evening': {
      AppLanguage.ar: '🌙 مساء الخير يا',
      AppLanguage.en: '🌙 Good evening,',
    },
    'shift_number_load_error': {
      AppLanguage.ar: 'خطأ في تحميل رقم الوردية: {e}',
      AppLanguage.en: 'Error loading shift number: {e}',
    },
    'shift_number_save_error': {
      AppLanguage.ar: 'خطأ في حفظ رقم الوردية: {e}',
      AppLanguage.en: 'Error saving shift number: {e}',
    },
    'not_available': {
      AppLanguage.ar: 'غير متاح',
      AppLanguage.en: 'Not available',
    },
    'user_word': {
      AppLanguage.ar: 'مستخدم',
      AppLanguage.en: 'User',
    },
    'factory_word': {
      AppLanguage.ar: 'مصنع',
      AppLanguage.en: 'Factory',
    },
    'logout_success': {
      AppLanguage.ar: '✅ تم تسجيل الخروج بنجاح',
      AppLanguage.en: '✅ Signed out successfully',
    },
    'logout_error': {
      AppLanguage.ar: '❌ خطأ في تسجيل الخروج: {e}',
      AppLanguage.en: '❌ Error signing out: {e}',
    },
    'no_permission_switch_factory': {
      AppLanguage.ar: '⚠️ ليس لديك صلاحية للتبديل بين المصانع',
      AppLanguage.en: '⚠️ You don\'t have permission to switch factories',
    },
    'no_factories_available': {
      AppLanguage.ar: 'لا توجد مصانع متاحة',
      AppLanguage.en: 'No factories available',
    },
    'switch_factory_title': {
      AppLanguage.ar: '🏭 تبديل المصنع',
      AppLanguage.en: '🏭 Switch Factory',
    },
    'all_shifts_title': {
      AppLanguage.ar: '📋 جميع الورديات',
      AppLanguage.en: '📋 All Shifts',
    },
    'no_shifts': {
      AppLanguage.ar: 'لا توجد ورديات',
      AppLanguage.en: 'No shifts',
    },
    'shift_header': {
      AppLanguage.ar: 'الوردية #{num} - {press}',
      AppLanguage.en: 'Shift #{num} - {press}',
    },
    'supervisor_label': {
      AppLanguage.ar: '👤 المشرف: {name}',
      AppLanguage.en: '👤 Supervisor: {name}',
    },
    'technician_label': {
      AppLanguage.ar: '🔧 الفني: {name}',
      AppLanguage.en: '🔧 Technician: {name}',
    },
    'press_label': {
      AppLanguage.ar: '📏 المكبس: {name}',
      AppLanguage.en: '📏 Press: {name}',
    },
    'dies_count_label': {
      AppLanguage.ar: '📊 القوالب: {n}',
      AppLanguage.en: '📊 Dies: {n}',
    },
    'billets_count_label': {
      AppLanguage.ar: '🔢 البليت: {n}',
      AppLanguage.en: '🔢 Billets: {n}',
    },
    'weight_label': {
      AppLanguage.ar: '⚖️ الوزن: {w}',
      AppLanguage.en: '⚖️ Weight: {w}',
    },
    'avg_productivity_label': {
      AppLanguage.ar: '📈 متوسط الإنتاجية: {v}',
      AppLanguage.en: '📈 Avg Productivity: {v}',
    },
    'productive_time_label': {
      AppLanguage.ar: '⏱️ وقت الإنتاج: {v}',
      AppLanguage.en: '⏱️ Production Time: {v}',
    },
    'wasted_time_label': {
      AppLanguage.ar: '⏳ وقت العطل: {v}',
      AppLanguage.en: '⏳ Downtime: {v}',
    },
    'efficiency_label': {
      AppLanguage.ar: '📊 الكفاءة: ',
      AppLanguage.en: '📊 Efficiency: ',
    },
    'duration_label': {
      AppLanguage.ar: '⏱️ المدة: {v}',
      AppLanguage.en: '⏱️ Duration: {v}',
    },
    'no_permission_start_shift': {
      AppLanguage.ar: '⚠️ فقط المشرفين والمديرين يمكنهم بدء وردية جديدة',
      AppLanguage.en: '⚠️ Only supervisors and managers can start a new shift',
    },
    'no_presses_available_busy': {
      AppLanguage.ar: '⚠️ لا توجد مكابس متاحة حالياً. جميع المكابس مشغولة.',
      AppLanguage.en: '⚠️ No presses available right now. All presses are busy.',
    },
    'no_presses_available': {
      AppLanguage.ar: '⚠️ لا توجد مكابس متاحة',
      AppLanguage.en: '⚠️ No presses available',
    },
    'all_presses_busy': {
      AppLanguage.ar: 'جميع المكابس مشغولة حالياً.',
      AppLanguage.en: 'All presses are currently busy.',
    },
    'wait_for_shift_to_end': {
      AppLanguage.ar: 'انتظر حتى تنتهي وردية حالية ثم حاول مرة أخرى.',
      AppLanguage.en: 'Wait for the current shift to finish, then try again.',
    },
    'refresh': {
      AppLanguage.ar: '🔄 تحديث',
      AppLanguage.en: '🔄 Refresh',
    },
    'no_presses_for_permissions': {
      AppLanguage.ar: '⚠️ لا توجد مكابس متاحة لك حسب صلاحياتك',
      AppLanguage.en: '⚠️ No presses available to you based on your permissions',
    },
    'start_new_shift_title': {
      AppLanguage.ar: '▶️ بدء وردية جديدة',
      AppLanguage.en: '▶️ Start New Shift',
    },
    'choose_press_enter_data': {
      AppLanguage.ar: 'اختر المكبس وأدخل بيانات المشرف والفني',
      AppLanguage.en: 'Choose a press and enter supervisor and technician details',
    },
    'press_label_short': {
      AppLanguage.ar: '📏 المكبس',
      AppLanguage.en: '📏 Press',
    },
    'supervisor_name_label': {
      AppLanguage.ar: '👤 اسم المشرف',
      AppLanguage.en: '👤 Supervisor Name',
    },
    'technician_name_label': {
      AppLanguage.ar: '🔧 اسم الفني',
      AppLanguage.en: '🔧 Technician Name',
    },
    'shift_number_label': {
      AppLanguage.ar: '🔢 رقم الوردية',
      AppLanguage.en: '🔢 Shift Number',
    },
    'refresh_presses': {
      AppLanguage.ar: '🔄 تحديث المكابس',
      AppLanguage.en: '🔄 Refresh Presses',
    },
    'enter_supervisor_technician': {
      AppLanguage.ar: '⚠️ الرجاء إدخال اسم المشرف والفني',
      AppLanguage.en: '⚠️ Please enter the supervisor and technician names',
    },
    'please_choose_press': {
      AppLanguage.ar: '⚠️ الرجاء اختيار المكبس',
      AppLanguage.en: '⚠️ Please choose a press',
    },
    'start_shift_button': {
      AppLanguage.ar: 'بدء الوردية',
      AppLanguage.en: 'Start Shift',
    },
    'idle_status': {
      AppLanguage.ar: 'خامل',
      AppLanguage.en: 'Idle',
    },
    'heating_status': {
      AppLanguage.ar: 'تسخين',
      AppLanguage.en: 'Heating',
    },
    'stabilizing_status': {
      AppLanguage.ar: 'تثبيت',
      AppLanguage.en: 'Stabilizing',
    },
    'cooling_status': {
      AppLanguage.ar: 'تبريد',
      AppLanguage.en: 'Cooling',
    },
    'error_word': {
      AppLanguage.ar: 'خطأ',
      AppLanguage.en: 'Error',
    },
    'press_word': {
      AppLanguage.ar: 'مكبس',
      AppLanguage.en: 'Press',
    },
    'target_word': {
      AppLanguage.ar: 'المستهدفة',
      AppLanguage.en: 'Target',
    },
    'current_word': {
      AppLanguage.ar: 'الحالية',
      AppLanguage.en: 'Current',
    },
    'hollow_time': {
      AppLanguage.ar: '⏱️ {v}د',
      AppLanguage.en: '⏱️ {v}m',
    },
    'hollow_word': {
      AppLanguage.ar: 'هولو',
      AppLanguage.en: 'Hollow',
    },
    'solid_time': {
      AppLanguage.ar: '⏱️ {v}د',
      AppLanguage.en: '⏱️ {v}m',
    },
    'solid_word': {
      AppLanguage.ar: 'صوليد',
      AppLanguage.en: 'Solid',
    },
    'dies_total': {
      AppLanguage.ar: '{n} قوالب',
      AppLanguage.en: '{n} dies',
    },
    'dies_ready': {
      AppLanguage.ar: '{n} جاهز',
      AppLanguage.en: '{n} ready',
    },
    'dies_heating': {
      AppLanguage.ar: '{n} قيد التسخين',
      AppLanguage.en: '{n} heating',
    },
    'cycle_duration': {
      AppLanguage.ar: '⏱️ مدة الدورة: {v}',
      AppLanguage.en: '⏱️ Cycle duration: {v}',
    },
    'app_title_bar': {
      AppLanguage.ar: '🏆 DELMAR PRO',
      AppLanguage.en: '🏆 DELMAR PRO',
    },
    'switch_factory': {
      AppLanguage.ar: 'تبديل المصنع',
      AppLanguage.en: 'Switch Factory',
    },
    'logout': {
      AppLanguage.ar: 'تسجيل الخروج',
      AppLanguage.en: 'Sign Out',
    },
    'dev_panel_title': {
      AppLanguage.ar: '🔐 لوحة المطور',
      AppLanguage.en: '🔐 Developer Panel',
    },
    'register_user_menu': {
      AppLanguage.ar: '📝 تسجيل مستخدم',
      AppLanguage.en: '📝 Register User',
    },
    'manage_furnaces_menu': {
      AppLanguage.ar: '🔥 إدارة الأفران',
      AppLanguage.en: '🔥 Manage Furnaces',
    },
    'start_shift_menu': {
      AppLanguage.ar: '▶️ بدء وردية',
      AppLanguage.en: '▶️ Start Shift',
    },
    'active_furnaces_title': {
      AppLanguage.ar: '🔥 الأفران النشطة',
      AppLanguage.en: '🔥 Active Furnaces',
    },
    'furnace_count': {
      AppLanguage.ar: '{n} فرن',
      AppLanguage.en: '{n} furnaces',
    },
    'active_presses_title': {
      AppLanguage.ar: '🔄 المكابس النشطة',
      AppLanguage.en: '🔄 Active Presses',
    },
    'press_count': {
      AppLanguage.ar: '{n} مكبس',
      AppLanguage.en: '{n} presses',
    },
    'no_active_presses': {
      AppLanguage.ar: 'لا توجد مكابس نشطة حالياً',
      AppLanguage.en: 'No active presses right now',
    },
    'tap_start_shift_hint': {
      AppLanguage.ar: 'اضغط على "بدء وردية" لتشغيل مكبس',
      AppLanguage.en: 'Tap "Start Shift" to run a press',
    },
    'active_status': {
      AppLanguage.ar: '🟢 نشط',
      AppLanguage.en: '🟢 Active',
    },
    'dies_billets_label': {
      AppLanguage.ar: '📊 القوالب: {d} | 🔢 البليت: {b}',
      AppLanguage.en: '📊 Dies: {d} | 🔢 Billets: {b}',
    },
    'dev_password_prompt': {
      AppLanguage.ar: '🔐 الرجاء إدخال كلمة المرور للدخول إلى لوحة المطور',
      AppLanguage.en: '🔐 Please enter the password to access the Developer Panel',
    },
    'enter_password_warning': {
      AppLanguage.ar: '⚠️ الرجاء إدخال كلمة المرور',
      AppLanguage.en: '⚠️ Please enter the password',
    },
    'please_login_first': {
      AppLanguage.ar: '❌ يرجى تسجيل الدخول أولاً',
      AppLanguage.en: '❌ Please sign in first',
    },
    'wrong_password_dev': {
      AppLanguage.ar: '❌ كلمة المرور غير صحيحة',
      AppLanguage.en: '❌ Incorrect password',
    },
    'upgraded_to_developer': {
      AppLanguage.ar: '✅ تم ترقية حسابك إلى مطور',
      AppLanguage.en: '✅ Your account has been upgraded to Developer',
    },
    'generic_error': {
      AppLanguage.ar: '❌ خطأ: {e}',
      AppLanguage.en: '❌ Error: {e}',
    },
    'enter_password_to_login': {
      AppLanguage.ar: 'أدخل كلمة المرور للدخول',
      AppLanguage.en: 'Enter the password to continue',
    },
    'dev_name': {
      AppLanguage.ar: '👨‍💻 فهد عبدالعزيز',
      AppLanguage.en: '👨‍💻 Fahd Abdulaziz',
    },
    'password_word': {
      AppLanguage.ar: '🔑 كلمة المرور',
      AppLanguage.en: '🔑 Password',
    },
    'login_word': {
      AppLanguage.ar: 'دخول',
      AppLanguage.en: 'Login',
    },
    'back_word': {
      AppLanguage.ar: 'رجوع',
      AppLanguage.en: 'Back',
    },
    'session_duration_hint': {
      AppLanguage.ar: '⏱️ مدة الجلسة: دقيقة واحدة',
      AppLanguage.en: '⏱️ Session duration: one minute',
    },
    'target_tons_updated': {
      AppLanguage.ar: '✅ تم تحديث الطن المستهدف للمكبس {name}',
      AppLanguage.en: '✅ Target tonnage updated for press {name}',
    },
    'waste_pct_updated': {
      AppLanguage.ar: '✅ تم تحديث نسبة الضياع للمكبس {name} إلى {val}%',
      AppLanguage.en: '✅ Waste percentage for press {name} updated to {val}%',
    },
    'dev_panel_subtitle': {
      AppLanguage.ar: '👨‍💻 لوحة المطور - فهد عبدالعزيز',
      AppLanguage.en: '👨‍💻 Developer Panel - Fahd Abdulaziz',
    },
    'manage_users_menu': {
      AppLanguage.ar: 'إدارة المستخدمين',
      AppLanguage.en: 'Manage Users',
    },
    'manage_factories_menu': {
      AppLanguage.ar: 'إدارة المصانع',
      AppLanguage.en: 'Manage Factories',
    },
    'home_word': {
      AppLanguage.ar: 'الرئيسية',
      AppLanguage.en: 'Home',
    },
    'welcome_dev_panel': {
      AppLanguage.ar: '👨‍💻 مرحباً بك في لوحة المطور',
      AppLanguage.en: '👨‍💻 Welcome to the Developer Panel',
    },
    'developer_label': {
      AppLanguage.ar: '👨‍💻 المطور: فهد عبدالعزيز',
      AppLanguage.en: '👨‍💻 Developer: Fahd Abdulaziz',
    },
    'grant_end_shift_permission_hint': {
      AppLanguage.ar: '🔑 يمكنك منح أو إلغاء صلاحية "إنهاء الوردية" لأي مستخدم',
      AppLanguage.en: '🔑 You can grant or revoke "End Shift" permission for any user',
    },
    'your_role': {
      AppLanguage.ar: '🎯 دورك: {role}',
      AppLanguage.en: '🎯 Your role: {role}',
    },
    'edit_target_tonnage_title': {
      AppLanguage.ar: '🎯 تعديل الطن المستهدف للمكابس',
      AppLanguage.en: '🎯 Edit Target Tonnage for Presses',
    },
    'edit_target_tonnage_hint': {
      AppLanguage.ar: 'يمكنك تعديل القيمة المستهدفة لكل مكبس (طن/ساعة)',
      AppLanguage.en: 'You can edit the target value for each press (tons/hour)',
    },
    'press_size_label': {
      AppLanguage.ar: 'الحجم: {size}',
      AppLanguage.en: 'Size: {size}',
    },
    'tons_per_hour': {
      AppLanguage.ar: 'طن/س',
      AppLanguage.en: 'tons/hr',
    },
    'enter_valid_value': {
      AppLanguage.ar: '⚠️ الرجاء إدخال قيمة صحيحة',
      AppLanguage.en: '⚠️ Please enter a valid value',
    },
    'edit_waste_pct_title': {
      AppLanguage.ar: '🎯 تعديل نسبة الوقت الضائع المستهدفة للمكابس',
      AppLanguage.en: '🎯 Edit Target Waste Percentage for Presses',
    },
    'waste_pct_hint': {
      AppLanguage.ar: 'النسبة = الوقت الضائع المسموح به كنسبة من الوقت الفعلي (تستخدم للمقارنة فقط)',
      AppLanguage.en: 'The percentage of allowed wasted time relative to actual time (used for comparison only)',
    },
    'percent_word': {
      AppLanguage.ar: 'نسبة %',
      AppLanguage.en: 'Percentage %',
    },
    'enter_value_0_100': {
      AppLanguage.ar: '⚠️ الرجاء إدخال قيمة بين 0 و 100',
      AppLanguage.en: '⚠️ Please enter a value between 0 and 100',
    },
    'save_percentage': {
      AppLanguage.ar: 'حفظ النسبة',
      AppLanguage.en: 'Save Percentage',
    },
    'current_factory_label': {
      AppLanguage.ar: '🏭 المصنع الحالي',
      AppLanguage.en: '🏭 Current Factory',
    },
    'no_factory': {
      AppLanguage.ar: 'لا يوجد مصنع',
      AppLanguage.en: 'No factory',
    },
    'users_word': {
      AppLanguage.ar: 'المستخدمين',
      AppLanguage.en: 'Users',
    },
    'supervisors_word': {
      AppLanguage.ar: 'المشرفين',
      AppLanguage.en: 'Supervisors',
    },
    'have_permission': {
      AppLanguage.ar: 'لديهم صلاحية',
      AppLanguage.en: 'Have permission',
    },
    'owners_word': {
      AppLanguage.ar: 'المالكين',
      AppLanguage.en: 'Owners',
    },
    'manage_users_permissions_title': {
      AppLanguage.ar: '👑 إدارة المستخدمين والصلاحيات',
      AppLanguage.en: '👑 Manage Users & Permissions',
    },
    'manage_factories_title': {
      AppLanguage.ar: '🏭 إدارة المصانع',
      AppLanguage.en: '🏭 Manage Factories',
    },
    'back_to_home': {
      AppLanguage.ar: '🏠 العودة إلى الشاشة الرئيسية',
      AppLanguage.en: '🏠 Back to Home',
    },
    'back_to_home_page': {
      AppLanguage.ar: 'العودة إلى الصفحة الرئيسية',
      AppLanguage.en: 'Back to Home',
    },
    'enter_new_factory_name': {
      AppLanguage.ar: 'أدخل اسم المصنع الجديد:',
      AppLanguage.en: 'Enter the new factory name:',
    },
    'factory_name_label': {
      AppLanguage.ar: 'اسم المصنع',
      AppLanguage.en: 'Factory Name',
    },
    'enter_factory_name_warning': {
      AppLanguage.ar: '⚠️ الرجاء إدخال اسم المصنع',
      AppLanguage.en: '⚠️ Please enter the factory name',
    },
    'switch_word': {
      AppLanguage.ar: 'تبديل',
      AppLanguage.en: 'Switch',
    },
    'done_word': {
      AppLanguage.ar: 'تم',
      AppLanguage.en: 'Done',
    },
    'new_die': {
      AppLanguage.ar: 'قالب جديد',
      AppLanguage.en: 'New Die',
    },
    'sync_die_error': {
      AppLanguage.ar: 'خطأ في مزامنة القالب قيد الإدخال: {e}',
      AppLanguage.en: 'Error syncing the in-progress die: {e}',
    },
    'load_shift_error': {
      AppLanguage.ar: 'خطأ في تحميل الوردية: {e}',
      AppLanguage.en: 'Error loading shift: {e}',
    },
    'zero_kg': {
      AppLanguage.ar: '0.00 كجم',
      AppLanguage.en: '0.00 kg',
    },
    'weight_tons': {
      AppLanguage.ar: '{v} طن',
      AppLanguage.en: '{v} tons',
    },
    'weight_kg': {
      AppLanguage.ar: '{v} كجم',
      AppLanguage.en: '{v} kg',
    },
    'zero_tons_hour': {
      AppLanguage.ar: '0.00 طن/ساعة',
      AppLanguage.en: '0.00 tons/hr',
    },
    'weight_tons_hour': {
      AppLanguage.ar: '{v} طن/ساعة',
      AppLanguage.en: '{v} tons/hr',
    },
    'add_word': {
      AppLanguage.ar: 'إضافة',
      AppLanguage.en: 'Add',
    },
    'die_still_heating': {
      AppLanguage.ar: '⏳ "{name}" لسه بيتسخن (متبقي: {remaining})',
      AppLanguage.en: '⏳ "{name}" is still heating (remaining: {remaining})',
    },
    'die_exited_furnace': {
      AppLanguage.ar: '✅ تم تسجيل خروج "{name}" من الفرن الآن',
      AppLanguage.en: '✅ "{name}" exit from the furnace recorded',
    },
    'furnace_check_error': {
      AppLanguage.ar: '❌ خطأ في التحقق من الفرن: {e}',
      AppLanguage.en: '❌ Error checking the furnace: {e}',
    },
    'die_ready_for_pressing': {
      AppLanguage.ar: '✅ القالب جاهز للكبس',
      AppLanguage.en: '✅ Die ready for pressing',
    },
    'die_found_in_furnace_ready': {
      AppLanguage.ar: 'القالب "{name}" موجود في الفرن وهو جاهز للكبس.',
      AppLanguage.en: 'Die "{name}" is in the furnace and ready for pressing.',
    },
    'furnace_label': {
      AppLanguage.ar: '🔥 الفرن: {name}',
      AppLanguage.en: '🔥 Furnace: {name}',
    },
    'entry_time_label': {
      AppLanguage.ar: '📥 وقت الدخول: {date}',
      AppLanguage.en: '📥 Entry time: {date}',
    },
    'required_heating_time': {
      AppLanguage.ar: '⏱️ وقت التسخين المطلوب: {min} دقيقة',
      AppLanguage.en: '⏱️ Required heating time: {min} minutes',
    },
    'auto_exit_hint': {
      AppLanguage.ar: 'سيتم تسجيل خروج القالب من الفرن تلقائياً عند إضافته للوردية',
      AppLanguage.en: 'The die will be automatically marked as exited from the furnace once added to the shift',
    },
    'add_to_shift': {
      AppLanguage.ar: 'إضافة للوردية',
      AppLanguage.en: 'Add to Shift',
    },
    'die_heating_in_progress': {
      AppLanguage.ar: '⏳ القالب قيد التسخين',
      AppLanguage.en: '⏳ Die is heating',
    },
    'die_found_not_ready': {
      AppLanguage.ar: 'القالب "{name}" موجود في الفرن لكنه لم يكمل التسخين بعد.',
      AppLanguage.en: 'Die "{name}" is in the furnace but hasn\'t finished heating yet.',
    },
    'remaining_time_label': {
      AppLanguage.ar: '⏳ الوقت المتبقي: {v}',
      AppLanguage.en: '⏳ Remaining time: {v}',
    },
    'cannot_press_until_heated': {
      AppLanguage.ar: 'لا يمكن كبس القالب حتى يكمل التسخين',
      AppLanguage.en: 'The die cannot be pressed until heating is complete',
    },
    'ok_word': {
      AppLanguage.ar: 'حسناً',
      AppLanguage.en: 'OK',
    },
    'add_as_new_die': {
      AppLanguage.ar: 'إضافة كقالب جديد',
      AppLanguage.en: 'Add as New Die',
    },
    'die_added_from_furnace': {
      AppLanguage.ar: '✅ تم إضافة القالب {name} من الفرن (تم تسجيل الخروج)',
      AppLanguage.en: '✅ Die {name} added from the furnace (exit recorded)',
    },
    'no_active_shift': {
      AppLanguage.ar: '⚠️ لا توجد وردية نشطة',
      AppLanguage.en: '⚠️ No active shift',
    },
    'no_permission_add_die': {
      AppLanguage.ar: '⚠️ ليس لديك صلاحية لإضافة قالب',
      AppLanguage.en: '⚠️ You don\'t have permission to add a die',
    },
    'enter_die_name_warning': {
      AppLanguage.ar: '⚠️ الرجاء إدخال اسم القالب',
      AppLanguage.en: '⚠️ Please enter the die name',
    },
    'enter_valid_billet_length': {
      AppLanguage.ar: '⚠️ الرجاء إدخال طول بليت صحيح',
      AppLanguage.en: '⚠️ Please enter a valid billet length',
    },
    'enter_valid_temperature': {
      AppLanguage.ar: '⚠️ الرجاء إدخال حرارة صحيحة',
      AppLanguage.en: '⚠️ Please enter a valid temperature',
    },
    'enter_valid_ram_speed': {
      AppLanguage.ar: '⚠️ الرجاء إدخال سرعة رام صحيحة',
      AppLanguage.en: '⚠️ Please enter a valid ram speed',
    },
    'enter_valid_billet_count': {
      AppLanguage.ar: '⚠️ الرجاء إدخال عدد بليت صحيح',
      AppLanguage.en: '⚠️ Please enter a valid billet count',
    },
    'enter_valid_holes_count': {
      AppLanguage.ar: '⚠️ الرجاء إدخال عدد فتحات صحيح',
      AppLanguage.en: '⚠️ Please enter a valid number of holes',
    },
    'no_die_in_progress': {
      AppLanguage.ar: '⚠️ لا يوجد قالب قيد الإدخال',
      AppLanguage.en: '⚠️ No die in progress',
    },
    'die_added_success': {
      AppLanguage.ar: '✅ تم إضافة القالب بنجاح',
      AppLanguage.en: '✅ Die added successfully',
    },
    'die_added_from_furnace2': {
      AppLanguage.ar: '✅ تم إضافة "{name}" (تم تسجيل خروجه من الفرن)',
      AppLanguage.en: '✅ "{name}" added (exit from furnace recorded)',
    },
    'in_progress_die_cancelled': {
      AppLanguage.ar: '🗑️ تم إلغاء القالب قيد الإدخال',
      AppLanguage.en: '🗑️ In-progress die cancelled',
    },
    'enter_valid_minutes': {
      AppLanguage.ar: '⚠️ الرجاء إدخال عدد دقائق صحيح',
      AppLanguage.en: '⚠️ Please enter a valid number of minutes',
    },
    'enter_downtime_reason': {
      AppLanguage.ar: '⚠️ الرجاء إدخال سبب العطل',
      AppLanguage.en: '⚠️ Please enter the downtime reason',
    },
    'downtime_recorded': {
      AppLanguage.ar: '✅ تم تسجيل وقت العطل: {min} دقيقة',
      AppLanguage.en: '✅ Downtime recorded: {min} minutes',
    },
    'enter_billet_count': {
      AppLanguage.ar: '⚠️ الرجاء إدخال عدد البليت',
      AppLanguage.en: '⚠️ Please enter the billet count',
    },
    'enter_valid_number_gt0': {
      AppLanguage.ar: '⚠️ الرجاء إدخال عدد صحيح أكبر من 0',
      AppLanguage.en: '⚠️ Please enter a whole number greater than 0',
    },
    'counter_updated_full': {
      AppLanguage.ar: '✅ تم تحديث العداد: {n} بليت (الوزن: {w} طن، الكفاءة: {eff}%)',
      AppLanguage.en: '✅ Counter updated: {n} billets (Weight: {w} tons, Efficiency: {eff}%)',
    },
    'counter_updated': {
      AppLanguage.ar: '✅ تم تحديث العداد: {n} بليت',
      AppLanguage.en: '✅ Counter updated: {n} billets',
    },
    'enter_billet_length': {
      AppLanguage.ar: '⚠️ الرجاء إدخال طول البليت',
      AppLanguage.en: '⚠️ Please enter the billet length',
    },
    'billet_length_updated': {
      AppLanguage.ar: '✅ تم تحديث طول البليت',
      AppLanguage.en: '✅ Billet length updated',
    },
    'shift_ended_success': {
      AppLanguage.ar: '✅ تم إنهاء الوردية بنجاح. المكبس أصبح متاحاً لوردية جديدة.',
      AppLanguage.en: '✅ Shift ended successfully. The press is now available for a new shift.',
    },
    'confirm_end_shift_title': {
      AppLanguage.ar: '⚠️ تأكيد إنهاء الوردية',
      AppLanguage.en: '⚠️ Confirm End Shift',
    },
    'confirm_end_shift_body': {
      AppLanguage.ar: 'هل أنت متأكد من إنهاء الوردية الحالية؟\\nلا يمكن التراجع عن هذا الإجراء.',
      AppLanguage.en: 'Are you sure you want to end the current shift?\\nThis action cannot be undone.',
    },
    'confirm_end': {
      AppLanguage.ar: 'تأكيد الإنتهاء',
      AppLanguage.en: 'Confirm End',
    },
    'shift_not_found': {
      AppLanguage.ar: 'الوردية غير موجودة',
      AppLanguage.en: 'Shift not found',
    },
    'shift_not_found_body': {
      AppLanguage.ar: 'لم يتم العثور على الوردية المطلوبة',
      AppLanguage.en: 'The requested shift could not be found',
    },
    'press_shift_header': {
      AppLanguage.ar: '📏 {press} - الوردية #{num}',
      AppLanguage.en: '📏 {press} - Shift #{num}',
    },
    'save_die_check_furnace': {
      AppLanguage.ar: 'حفظ القالب والتحقق من الفرن',
      AppLanguage.en: 'Save Die & Check Furnace',
    },
    'finished_status': {
      AppLanguage.ar: '✅ منتهية',
      AppLanguage.en: '✅ Finished',
    },
    'supervisor_word': {
      AppLanguage.ar: '👤 المشرف',
      AppLanguage.en: '👤 Supervisor',
    },
    'technician_word': {
      AppLanguage.ar: '🔧 الفني',
      AppLanguage.en: '🔧 Technician',
    },
    'duration_word': {
      AppLanguage.ar: '⏱️ المدة',
      AppLanguage.en: '⏱️ Duration',
    },
    'dies_word': {
      AppLanguage.ar: '📊 القوالب',
      AppLanguage.en: '📊 Dies',
    },
    'billets_word': {
      AppLanguage.ar: '🔢 البليت',
      AppLanguage.en: '🔢 Billets',
    },
    'weight_word': {
      AppLanguage.ar: '⚖️ الوزن',
      AppLanguage.en: '⚖️ Weight',
    },
    'productivity_word': {
      AppLanguage.ar: '📈 الإنتاجية',
      AppLanguage.en: '📈 Productivity',
    },
    'monthly_production': {
      AppLanguage.ar: '📅 إنتاج الشهر',
      AppLanguage.en: '📅 Monthly Production',
    },
    'shift_duration': {
      AppLanguage.ar: '⏱️ مدة الوردية',
      AppLanguage.en: '⏱️ Shift Duration',
    },
    'work_time': {
      AppLanguage.ar: '⚙️ وقت العمل',
      AppLanguage.en: '⚙️ Work Time',
    },
    'downtime_between_dies': {
      AppLanguage.ar: '⏳ وقت ضائع بين القوالب',
      AppLanguage.en: '⏳ Downtime Between Dies',
    },
    'waste_percentage': {
      AppLanguage.ar: '📊 نسبة الضياع',
      AppLanguage.en: '📊 Waste Percentage',
    },
    'edit_in_progress_die': {
      AppLanguage.ar: '✏️ تعديل القالب قيد الإدخال',
      AppLanguage.en: '✏️ Edit In-Progress Die',
    },
    'add_new_die': {
      AppLanguage.ar: '➕ إضافة قالب جديد',
      AppLanguage.en: '➕ Add New Die',
    },
    'in_progress_status': {
      AppLanguage.ar: '🟡 قيد الإدخال',
      AppLanguage.en: '🟡 In Progress',
    },
    'die_name_label': {
      AppLanguage.ar: 'اسم القالب',
      AppLanguage.en: 'Die Name',
    },
    'enter_die_name': {
      AppLanguage.ar: 'أدخل اسم القالب',
      AppLanguage.en: 'Enter the die name',
    },
    'holes_word': {
      AppLanguage.ar: 'الفتحات',
      AppLanguage.en: 'Holes',
    },
    'entry_time_word': {
      AppLanguage.ar: '⏰ وقت الدخول',
      AppLanguage.en: '⏰ Entry Time',
    },
    'exit_time_word': {
      AppLanguage.ar: '⏰ وقت الخروج',
      AppLanguage.en: '⏰ Exit Time',
    },
    'alloy_word': {
      AppLanguage.ar: 'السبيكة',
      AppLanguage.en: 'Alloy',
    },
    'length_mm_label': {
      AppLanguage.ar: 'الطول (مم)',
      AppLanguage.en: 'Length (mm)',
    },
    'temperature_c_label': {
      AppLanguage.ar: 'الحرارة (°C)',
      AppLanguage.en: 'Temperature (°C)',
    },
    'speed_word': {
      AppLanguage.ar: 'السرعة',
      AppLanguage.en: 'Speed',
    },
    'billet_counter': {
      AppLanguage.ar: 'عداد البليت',
      AppLanguage.en: 'Billet Counter',
    },
    'expected_weight': {
      AppLanguage.ar: '⚖️ الوزن المتوقع',
      AppLanguage.en: '⚖️ Expected Weight',
    },
    'die_productivity': {
      AppLanguage.ar: '📈 الإنتاجية: {v}',
      AppLanguage.en: '📈 Productivity: {v}',
    },
    'notes_word': {
      AppLanguage.ar: '📝 ملاحظات',
      AppLanguage.en: '📝 Notes',
    },
    'saving_word': {
      AppLanguage.ar: 'جاري الحفظ...',
      AppLanguage.en: 'Saving...',
    },
    'checking_word': {
      AppLanguage.ar: 'جاري التحقق...',
      AppLanguage.en: 'Checking...',
    },
    'add_die_button': {
      AppLanguage.ar: '💾 إضافة القالب',
      AppLanguage.en: '💾 Add Die',
    },
    'cancel_word_trash': {
      AppLanguage.ar: '🗑️ إلغاء',
      AppLanguage.en: '🗑️ Cancel',
    },
    'furnace_check_hint': {
      AppLanguage.ar: '💡 سيتم التحقق من وجود القالب في الفرن. إذا كان جاهزاً، سيتم تسجيل خروجه تلقائياً.',
      AppLanguage.en: '💡 The furnace will be checked for this die. If ready, its exit will be recorded automatically.',
    },
    'record_downtime_title': {
      AppLanguage.ar: '⏳ تسجيل وقت العطل',
      AppLanguage.en: '⏳ Record Downtime',
    },
    'minutes_count_label': {
      AppLanguage.ar: '⏳ عدد الدقائق',
      AppLanguage.en: '⏳ Number of Minutes',
    },
    'downtime_reason_label': {
      AppLanguage.ar: '📝 سبب العطل',
      AppLanguage.en: '📝 Downtime Reason',
    },
    'downtime_reason_hint': {
      AppLanguage.ar: 'مثال: عطل ميكانيكي',
      AppLanguage.en: 'Example: mechanical failure',
    },
    'recording_word': {
      AppLanguage.ar: 'جاري التسجيل...',
      AppLanguage.en: 'Recording...',
    },
    'record_downtime_button': {
      AppLanguage.ar: '✅ تسجيل وقت العطل',
      AppLanguage.en: '✅ Record Downtime',
    },
    'dies_title': {
      AppLanguage.ar: '📋 القوالب',
      AppLanguage.en: '📋 Dies',
    },
    'no_dies': {
      AppLanguage.ar: 'لا توجد قوالب',
      AppLanguage.en: 'No dies',
    },
    'add_die_to_start': {
      AppLanguage.ar: 'أضف قالباً جديداً للبدء',
      AppLanguage.en: 'Add a new die to get started',
    },
    'downtime_details': {
      AppLanguage.ar: '⏳ تفاصيل الأعطال:',
      AppLanguage.en: '⏳ Downtime Details:',
    },
    'downtime_minutes': {
      AppLanguage.ar: '⏱️ {n} دقيقة',
      AppLanguage.en: '⏱️ {n} minutes',
    },
    'total_downtime_label': {
      AppLanguage.ar: '📊 إجمالي وقت العطل: ',
      AppLanguage.en: '📊 Total Downtime: ',
    },
    'actual_production_time': {
      AppLanguage.ar: '⏱️ وقت الإنتاج الفعلي',
      AppLanguage.en: '⏱️ Actual Production Time',
    },
    'total_weight_label': {
      AppLanguage.ar: '⚖️ إجمالي الوزن:',
      AppLanguage.en: '⚖️ Total Weight:',
    },
    'avg_productivity_label2': {
      AppLanguage.ar: '📈 متوسط الإنتاجية:',
      AppLanguage.en: '📈 Average Productivity:',
    },
    'shift_efficiency_label': {
      AppLanguage.ar: '📊 كفاءة الوردية:',
      AppLanguage.en: '📊 Shift Efficiency:',
    },
    'total_downtime_label2': {
      AppLanguage.ar: '⏳ إجمالي وقت العطل:',
      AppLanguage.en: '⏳ Total Downtime:',
    },
    'monthly_production_press': {
      AppLanguage.ar: '📅 إنتاج الشهر لهذا المكبس:',
      AppLanguage.en: '📅 Monthly Production for This Press:',
    },
    'end_shift_title': {
      AppLanguage.ar: '🛑 إنهاء الوردية',
      AppLanguage.en: '🛑 End Shift',
    },
    'only_supervisor_can_end': {
      AppLanguage.ar: '🔒 فقط المشرف ({name}) أو المدير يمكنه إنهاء هذه الوردية',
      AppLanguage.en: '🔒 Only the supervisor ({name}) or a manager can end this shift',
    },
    'completed_status': {
      AppLanguage.ar: '✅ مكتمل',
      AppLanguage.en: '✅ Completed',
    },
    'entry_word': {
      AppLanguage.ar: 'الدخول',
      AppLanguage.en: 'Entry',
    },
    'exit_word': {
      AppLanguage.ar: 'الخروج',
      AppLanguage.en: 'Exit',
    },
    'length_word': {
      AppLanguage.ar: 'الطول',
      AppLanguage.en: 'Length',
    },
    'billet_length_mm': {
      AppLanguage.ar: '{v} مم',
      AppLanguage.en: '{v} mm',
    },
    'temperature_word': {
      AppLanguage.ar: 'الحرارة',
      AppLanguage.en: 'Temperature',
    },
    'billets_word2': {
      AppLanguage.ar: 'البليت',
      AppLanguage.en: 'Billets',
    },
    'weight_word2': {
      AppLanguage.ar: 'الوزن',
      AppLanguage.en: 'Weight',
    },
    'target_efficiency': {
      AppLanguage.ar: '📊 كفاءة الهدف: {v}% {emoji}',
      AppLanguage.en: '📊 Target Efficiency: {v}% {emoji}',
    },
    'ready_for_pressing': {
      AppLanguage.ar: '🔥 جاهز للكبس',
      AppLanguage.en: '🔥 Ready for Pressing',
    },
    'in_furnace_remaining': {
      AppLanguage.ar: '🔥 في الفرن (متبقي {v})',
      AppLanguage.en: '🔥 In furnace (remaining {v})',
    },
    'wasted_time_pct': {
      AppLanguage.ar: '⏳ وقت ضائع: {formatted} ({pct}%)',
      AppLanguage.en: '⏳ Wasted time: {formatted} ({pct}%)',
    },
    'production_efficiency': {
      AppLanguage.ar: '📈 كفاءة الإنتاج: {v}%',
      AppLanguage.en: '📈 Production Efficiency: {v}%',
    },
    'update_counter': {
      AppLanguage.ar: 'تحديث العداد',
      AppLanguage.en: 'Update Counter',
    },
    'update_length_mm': {
      AppLanguage.ar: 'تحديث الطول (مم)',
      AppLanguage.en: 'Update Length (mm)',
    },
    'update_length': {
      AppLanguage.ar: 'تحديث الطول',
      AppLanguage.en: 'Update Length',
    },
    'not_specified': {
      AppLanguage.ar: 'غير محدد',
      AppLanguage.en: 'Not specified',
    },

    // ---- إدارة المكابس ----
    'manage_presses_title': {
      AppLanguage.ar: '⚙️ إدارة المكابس',
      AppLanguage.en: '⚙️ Manage Presses',
    },
    'add_new_press': {
      AppLanguage.ar: '➕ إضافة مكبس جديد',
      AppLanguage.en: '➕ Add New Press',
    },
    'press_name_label': {
      AppLanguage.ar: 'اسم المكبس',
      AppLanguage.en: 'Press Name',
    },
    'press_name_hint': {
      AppLanguage.ar: 'مثال: مكبس 7 بوصة - خط 2',
      AppLanguage.en: 'Example: 7 inch Press - Line 2',
    },
    'custom_diameter_label': {
      AppLanguage.ar: 'القطر المخصص (بوصة)',
      AppLanguage.en: 'Custom Diameter (inches)',
    },
    'press_target_auto_hint': {
      AppLanguage.ar: '📌 سيتم تعيين قيمة الطن المستهدف تلقائياً حسب القطر (يمكن تعديلها من لوحة المطور)',
      AppLanguage.en: '📌 Target tonnage will be auto-calculated based on diameter (can be edited in Developer Panel)',
    },
    'same_diameter_multi_press_hint': {
      AppLanguage.ar: '💡 يمكنك إضافة أكثر من مكبس بنفس القطر (مثال: مكبس 7 بوصة - خط 1، مكبس 7 بوصة - خط 2)، فقط تأكد أن اسم كل مكبس مختلف عن الباقي',
      AppLanguage.en: '💡 You can add more than one press with the same diameter (e.g. Press 7in - Line 1, Press 7in - Line 2) — just make sure each press has a different name',
    },
    'add_press_button': {
      AppLanguage.ar: 'إضافة مكبس',
      AppLanguage.en: 'Add Press',
    },
    'presses_list_title': {
      AppLanguage.ar: '📋 قائمة المكابس',
      AppLanguage.en: '📋 Presses List',
    },
    'press_count_suffix': {
      AppLanguage.ar: 'مكبس',
      AppLanguage.en: 'presses',
    },
    'no_presses_message': {
      AppLanguage.ar: 'لا توجد مكابس',
      AppLanguage.en: 'No presses',
    },
    'add_press_hint': {
      AppLanguage.ar: 'أضف مكبساً جديداً من الأعلى',
      AppLanguage.en: 'Add a new press from above',
    },
    'enter_press_name_warning': {
      AppLanguage.ar: '⚠️ الرجاء إدخال اسم المكبس',
      AppLanguage.en: '⚠️ Please enter the press name',
    },
    'press_name_exists_warning': {
      AppLanguage.ar: '⚠️ يوجد مكبس بنفس الاسم بالفعل',
      AppLanguage.en: '⚠️ A press with this name already exists',
    },
    'enter_valid_diameter_warning': {
      AppLanguage.ar: '⚠️ الرجاء إدخال قطر صحيح (أكبر من 0)',
      AppLanguage.en: '⚠️ Please enter a valid diameter (greater than 0)',
    },
    'cannot_delete_active_press_warning': {
      AppLanguage.ar: '⚠️ لا يمكن حذف المكبس لأن هناك وردية نشطة عليه',
      AppLanguage.en: '⚠️ Cannot delete press because there is an active shift',
    },
    'confirm_delete_title': {
      AppLanguage.ar: '⚠️ تأكيد الحذف',
      AppLanguage.en: '⚠️ Confirm Delete',
    },
    'confirm_delete_press_body': {
      AppLanguage.ar: 'هل أنت متأكد من حذف المكبس',
      AppLanguage.en: 'Are you sure you want to delete the press',
    },
    'press_deleted_success': {
      AppLanguage.ar: 'تم حذف المكبس',
      AppLanguage.en: 'Press deleted',
    },
    'edit_press_title': {
      AppLanguage.ar: '✏️ تعديل المكبس',
      AppLanguage.en: '✏️ Edit Press',
    },
    'enter_new_press_name': {
      AppLanguage.ar: 'أدخل الاسم الجديد للمكبس:',
      AppLanguage.en: 'Enter the new press name:',
    },
    'press_updated_success': {
      AppLanguage.ar: 'تم تحديث المكبس',
      AppLanguage.en: 'Press updated',
    },
    'press_added_success': {
      AppLanguage.ar: 'تم إضافة المكبس',
      AppLanguage.en: 'Press added',
    },
    'active_shift_label': {
      AppLanguage.ar: 'وردية نشطة',
      AppLanguage.en: 'Active Shift',
    },
    'no_active_shift_label': {
      AppLanguage.ar: 'لا توجد وردية نشطة',
      AppLanguage.en: 'No active shift',
    },
    'edit_press_tooltip': {
      AppLanguage.ar: 'تعديل الاسم',
      AppLanguage.en: 'Edit name',
    },
    'delete_press_tooltip': {
      AppLanguage.ar: 'حذف',
      AppLanguage.en: 'Delete',
    },
    'manage_presses_permission_hint': {
      AppLanguage.ar: 'هذه الصفحة مخصصة للمطور والمالك ومديري المصانع',
      AppLanguage.en: 'This page is for developers, owners, and factory managers',
    },
    'supervisor_label_short': {
      AppLanguage.ar: 'المشرف',
      AppLanguage.en: 'Supervisor',
    },

    // ---- مراقبة الإنتاج والخردة ----
    'production_monitoring_menu': {
      AppLanguage.ar: 'مراقبة الإنتاج',
      AppLanguage.en: 'Production Monitoring',
    },
    'production_monitoring_title': {
      AppLanguage.ar: 'مراقبة الإنتاج والخردة',
      AppLanguage.en: 'Production & Scrap Monitoring',
    },
    'production_monitoring_empty': {
      AppLanguage.ar: 'لا توجد ورديات نشطة حالياً',
      AppLanguage.en: 'No active shifts right now',
    },
    'overall_summary_title': {
      AppLanguage.ar: 'ملخص عام لكل الورديات',
      AppLanguage.en: 'Overall Summary — All Shifts',
    },
    'total_pressed_weight': {
      AppLanguage.ar: 'إجمالي الكمية المكبوسة',
      AppLanguage.en: 'Total Pressed Weight',
    },
    'total_good_weight': {
      AppLanguage.ar: 'إجمالي الوزن الجيد',
      AppLanguage.en: 'Total Good Weight',
    },
    'total_scrap_weight': {
      AppLanguage.ar: 'إجمالي وزن الخردة',
      AppLanguage.en: 'Total Scrap Weight',
    },
    'overall_scrap_percentage': {
      AppLanguage.ar: 'نسبة الخردة العامة',
      AppLanguage.en: 'Overall Scrap %',
    },
    'dies_with_data_count': {
      AppLanguage.ar: 'عدد القوالب المسجّلة',
      AppLanguage.en: 'Dies with Data',
    },
    'pressed_quantity_label': {
      AppLanguage.ar: 'الكمية المكبوسة',
      AppLanguage.en: 'Pressed Quantity',
    },
    'record_production_data_btn': {
      AppLanguage.ar: 'تسجيل بيانات الإنتاج',
      AppLanguage.en: 'Record Production Data',
    },
    'edit_production_data_btn': {
      AppLanguage.ar: 'تعديل بيانات الإنتاج',
      AppLanguage.en: 'Edit Production Data',
    },
    'production_data_dialog_title': {
      AppLanguage.ar: 'بيانات إنتاج القالب',
      AppLanguage.en: 'Die Production Data',
    },
    'bar_weight_label': {
      AppLanguage.ar: 'وزن العود بالقطعة (كجم)',
      AppLanguage.en: 'Bar Weight per Piece (kg)',
    },
    'expected_bar_count_label': {
      AppLanguage.ar: 'عدد الأعواد المتوقع',
      AppLanguage.en: 'Expected Bar Count',
    },
    'expected_bar_count_hint': {
      AppLanguage.ar: 'حسب عدد فتحات القالب وطول الفرش',
      AppLanguage.en: 'Based on die cavities and table length',
    },
    'good_bar_count_label': {
      AppLanguage.ar: 'عدد الأعواد المنتجة (الجيدة)',
      AppLanguage.en: 'Good Bars Produced',
    },
    'scrap_bar_count_label': {
      AppLanguage.ar: 'عدد أعواد الخردة',
      AppLanguage.en: 'Scrap Bar Count',
    },
    'related_bar_count_label': {
      AppLanguage.ar: 'عدد الأعواد المتعلقات',
      AppLanguage.en: 'Related Bars Count',
    },
    'live_preview_label': {
      AppLanguage.ar: 'معاينة فورية للنتيجة',
      AppLanguage.en: 'Live Result Preview',
    },
    'good_weight_label': {
      AppLanguage.ar: 'الوزن الجيد',
      AppLanguage.en: 'Good Weight',
    },
    'scrap_bars_weight_label': {
      AppLanguage.ar: 'وزن خردة الأعواد',
      AppLanguage.en: 'Scrap Bars Weight',
    },
    'related_bars_weight_label': {
      AppLanguage.ar: 'وزن الأعواد المتعلقات',
      AppLanguage.en: 'Related Bars Weight',
    },
    'unaccounted_scrap_label': {
      AppLanguage.ar: 'خردة أطراف/كعب غير معدودة',
      AppLanguage.en: 'Unaccounted Butt/End Scrap',
    },
    'total_scrap_label': {
      AppLanguage.ar: 'إجمالي وزن الخردة',
      AppLanguage.en: 'Total Scrap Weight',
    },
    'scrap_percentage_label': {
      AppLanguage.ar: 'نسبة الخردة',
      AppLanguage.en: 'Scrap Percentage',
    },
    'no_production_data_yet': {
      AppLanguage.ar: 'لم يتم تسجيل بيانات الإنتاج لهذا القالب بعد',
      AppLanguage.en: 'No production data recorded for this die yet',
    },
    'save_production_data': {
      AppLanguage.ar: 'حفظ بيانات الإنتاج',
      AppLanguage.en: 'Save Production Data',
    },
    'production_data_saved': {
      AppLanguage.ar: '✅ تم حفظ بيانات الإنتاج',
      AppLanguage.en: '✅ Production data saved',
    },
    'production_data_error': {
      AppLanguage.ar: '❌ خطأ في حفظ بيانات الإنتاج',
      AppLanguage.en: '❌ Error saving production data',
    },
    'bar_weight_required_error': {
      AppLanguage.ar: '⚠️ الرجاء إدخال وزن العود بشكل صحيح',
      AppLanguage.en: '⚠️ Please enter a valid bar weight',
    },
    'discrepancy_note': {
      AppLanguage.ar: 'ملاحظة: مجموع الأعداد المدخلة يختلف عن العدد المتوقع، والفرق يُحتسب تلقائياً ضمن الخردة غير المعدودة',
      AppLanguage.en: 'Note: entered totals differ from the expected count; the difference is automatically counted as unaccounted scrap',
    },
    'expected_word': {
      AppLanguage.ar: 'المتوقع',
      AppLanguage.en: 'Expected',
    },
    'entered_word': {
      AppLanguage.ar: 'المُدخل',
      AppLanguage.en: 'Entered',
    },

    // ---- شاشة جميع الورديات ----
    'shift_word': {AppLanguage.ar: 'وردية', AppLanguage.en: 'Shift'},
    'clear_filters': {AppLanguage.ar: 'مسح الفلاتر', AppLanguage.en: 'Clear Filters'},
    'from_date': {AppLanguage.ar: 'من تاريخ', AppLanguage.en: 'From Date'},
    'to_date': {AppLanguage.ar: 'إلى تاريخ', AppLanguage.en: 'To Date'},
    'all_presses': {AppLanguage.ar: 'جميع المكابس', AppLanguage.en: 'All Presses'},
    'try_adjusting_filters': {AppLanguage.ar: 'حاول تعديل الفلاتر', AppLanguage.en: 'Try adjusting filters'},
    'view_shift_details': {AppLanguage.ar: 'عرض تفاصيل الوردية', AppLanguage.en: 'View Shift Details'},
    'and_more_dies': {AppLanguage.ar: 'و {n} قوالب أخرى', AppLanguage.en: 'and {n} more dies'},
    'shift_scrap_summary': {AppLanguage.ar: '🗑️ ملخص خردة الوردية', AppLanguage.en: '🗑️ Shift Scrap Summary'},
    'ton_word': {AppLanguage.ar: 'طن', AppLanguage.en: 'ton'},
    'kg_word': {AppLanguage.ar: 'كجم', AppLanguage.en: 'kg'},

    // ---- شاشة مراقبة الإنتاج ----
    'search_by_die_name': {AppLanguage.ar: '🔍 ابحث عن قالب...', AppLanguage.en: '🔍 Search for a die...'},
    'search_results': {AppLanguage.ar: 'نتائج البحث', AppLanguage.en: 'Search Results'},
    'clear_search': {AppLanguage.ar: 'مسح البحث', AppLanguage.en: 'Clear Search'},
    'shift_status': {AppLanguage.ar: 'حالة الوردية', AppLanguage.en: 'Shift Status'},

    // ---- شاشة تفاصيل الوردية ----
    'shift_details': {AppLanguage.ar: '📊 تفاصيل الوردية', AppLanguage.en: '📊 Shift Details'},
    'expected_weight_label': {AppLanguage.ar: 'الوزن المتوقع', AppLanguage.en: 'Expected Weight'},
    'total_scrap_label': {AppLanguage.ar: 'وزن الخردة الكلي', AppLanguage.en: 'Total Scrap Weight'},
    'scrap_percentage_label': {AppLanguage.ar: 'نسبة الخردة', AppLanguage.en: 'Scrap Percentage'},
    'good_bars_label': {AppLanguage.ar: 'عدد الأعواد المنتجة', AppLanguage.en: 'Good Bars Produced'},
    'scrap_bars_label': {AppLanguage.ar: 'عدد أعواد الخردة', AppLanguage.en: 'Scrap Bars'},
    'related_bars_label': {AppLanguage.ar: 'عدد الأعواد المتعلقات', AppLanguage.en: 'Related Bars'},
    'save_die_data': {AppLanguage.ar: '💾 حفظ بيانات القالب', AppLanguage.en: '💾 Save Die Data'},
    'update_die_data': {AppLanguage.ar: 'تحديث بيانات القالب', AppLanguage.en: 'Update Die Data'},
    'save_all': {AppLanguage.ar: '💾 حفظ الكل', AppLanguage.en: '💾 Save All'},
    'shift_summary': {AppLanguage.ar: '📊 ملخص الوردية', AppLanguage.en: '📊 Shift Summary'},
    'view_details': {AppLanguage.ar: '📋 عرض التفاصيل', AppLanguage.en: '📋 View Details'},
    'no_dies_in_shift': {AppLanguage.ar: 'لا توجد قوالب في هذه الوردية', AppLanguage.en: 'No dies in this shift'},

    // ---- إدارة القوالب المسجلة ----
    'die_management_title': {
      AppLanguage.ar: '🔧 إدارة القوالب المسجلة',
      AppLanguage.en: '🔧 Manage Die Templates'
    },
    'import_from_excel': {
      AppLanguage.ar: '📤 استيراد من Excel',
      AppLanguage.en: '📤 Import from Excel'
    },
    'add_manually': {
      AppLanguage.ar: '➕ إضافة يدوي',
      AppLanguage.en: '➕ Add Manually'
    },
    'no_templates': {
      AppLanguage.ar: 'لا توجد قوالب مسجلة',
      AppLanguage.en: 'No die templates'
    },
    'add_template_hint': {
      AppLanguage.ar: 'أضف قوالب من خلال استيراد Excel أو الإضافة اليدوية',
      AppLanguage.en: 'Add templates via Excel import or manually'
    },
    'client_code': {
      AppLanguage.ar: '🏷️ كود العميل',
      AppLanguage.en: '🏷️ Client Code'
    },
    'design_code': {
      AppLanguage.ar: '🏷️ كود التصميم',
      AppLanguage.en: '🏷️ Design Code'
    },
    'die_code': {
      AppLanguage.ar: '🏷️ كود القالب',
      AppLanguage.en: '🏷️ Die Code'
    },
    'has_drawing': {
      AppLanguage.ar: '📎 يوجد رسم',
      AppLanguage.en: '📎 Has drawing'
    },
    'importing': {
      AppLanguage.ar: 'جاري الاستيراد...',
      AppLanguage.en: 'Importing...'
    },
    'import_success': {
      AppLanguage.ar: '✅ تم استيراد {count} قالب',
      AppLanguage.en: '✅ Imported {count} dies'
    },
    'search_die_hint': {
      AppLanguage.ar: '🔍 ابحث عن قالب (اسم، كود العميل، كود التصميم، كود القالب)',
      AppLanguage.en: '🔍 Search for die (name, client code, design code, die code)'
    },

    // ---- البحث الذكي في الوردية ----
    'search_die': {AppLanguage.ar: '🔍 ابحث عن القالب', AppLanguage.en: '🔍 Search for die'},
    'search_hint': {AppLanguage.ar: 'أدخل أي كود من الأكواد الثلاثة (كود القالب، كود العميل، كود التصميم)', AppLanguage.en: 'Enter any of the three codes (die code, client code, design code)'},
    'search_button': {AppLanguage.ar: '🔍 بحث', AppLanguage.en: '🔍 Search'},
    'client_code_label': {AppLanguage.ar: 'كود العميل', AppLanguage.en: 'Client Code'},
    'design_code_label': {AppLanguage.ar: 'كود التصميم', AppLanguage.en: 'Design Code'},
    'die_code_label': {AppLanguage.ar: 'كود القالب', AppLanguage.en: 'Die Code'},
    'die_found': {AppLanguage.ar: '✅ تم العثور على القالب', AppLanguage.en: '✅ Die found'},
    'die_not_found': {AppLanguage.ar: '⚠️ هذا القالب غير مسجل في النظام', AppLanguage.en: '⚠️ This die is not registered in the system'},
    'versions_found': {AppLanguage.ar: 'نسخ', AppLanguage.en: 'versions'},
    'select_version': {AppLanguage.ar: '📋 اختر النسخة المطلوبة', AppLanguage.en: '📋 Select the required version'},
    'version_label': {AppLanguage.ar: '🔢 رقم النسخة', AppLanguage.en: '🔢 Version Number'},
    'full_code_label': {AppLanguage.ar: '📋 الكود الكامل', AppLanguage.en: '📋 Full Code'},
    'enter_version_hint': {AppLanguage.ar: 'مثال: 1m, 2m, 3d', AppLanguage.en: 'Example: 1m, 2m, 3d'},

    // ---- إدارة رصيد الخامة ----
    'material_stock_title': {
      AppLanguage.ar: '📦 رصيد الخامة',
      AppLanguage.en: '📦 Material Stock',
    },
    'add_material_stock': {
      AppLanguage.ar: '➕ إضافة رصيد خامة',
      AppLanguage.en: '➕ Add Material Stock',
    },
    'alloy_label': {
      AppLanguage.ar: '🔧 السبيكة',
      AppLanguage.en: '🔧 Alloy',
    },
    'origin_label': {
      AppLanguage.ar: '🌍 بلد المنشأ',
      AppLanguage.en: '🌍 Origin',
    },
    'imported': {
      AppLanguage.ar: '🌍 مستوردة',
      AppLanguage.en: '🌍 Imported',
    },
    'local': {
      AppLanguage.ar: '🇪🇬 محلي', // ✅ تغيير العلم من 🇸🇦 إلى 🇪🇬
      AppLanguage.en: '🇪🇬 Local',
    },
    'local_foundry': {
      AppLanguage.ar: '🏭 محلي - مسبك',
      AppLanguage.en: '🏭 Local Foundry',
    },
    'notes_label': {
      AppLanguage.ar: '📝 ملاحظات',
      AppLanguage.en: '📝 Notes',
    },
    'low_stock_warning': {
      AppLanguage.ar: '⚠️ منخفض',
      AppLanguage.en: '⚠️ Low Stock',
    },
    'stock_item_count': {
      AppLanguage.ar: '{n} صنف',
      AppLanguage.en: '{n} items',
    },
    'no_stock': {
      AppLanguage.ar: 'لا يوجد رصيد خامات',
      AppLanguage.en: 'No material stock',
    },
    'add_stock_hint': {
      AppLanguage.ar: 'أضف رصيداً جديداً من الأعلى',
      AppLanguage.en: 'Add new stock from above',
    },
    'consumption_summary': {
      AppLanguage.ar: 'الاستهلاك حسب السبيكة',
      AppLanguage.en: 'Consumption by Alloy',
    },
    'material_stock_by_diameter': {
      AppLanguage.ar: '📦 رصيد الخامة (قطر {diameter} بوصة): {stock} طن',
      AppLanguage.en: '📦 Material Stock (Diameter {diameter} in): {stock} tons',
    },
    'add_stock_to_diameter': {
      AppLanguage.ar: 'إضافة رصيد للقطر',
      AppLanguage.en: 'Add Stock to Diameter',
    },
    'select_diameter': {
      AppLanguage.ar: '📏 اختيار القطر (بوصة)',
      AppLanguage.en: '📏 Select Diameter (in)',
    },
    'stock_added_to_diameter': {
      AppLanguage.ar: '✅ تم إضافة {amount} طن من الخامة للقطر {diameter} بوصة',
      AppLanguage.en: '✅ {amount} tons of material added to diameter {diameter} in',
    },
    'stock_added': {
      AppLanguage.ar: 'تم إضافة الرصيد',
      AppLanguage.en: 'Stock added',
    },
    'remaining_stock': {
      AppLanguage.ar: 'الرصيد المتبقي',
      AppLanguage.en: 'Remaining Stock',
    },

    // ---- رصيد الخامة ----
    'manage_material_stock': {
      AppLanguage.ar: 'إدارة رصيد الخامة',
      AppLanguage.en: 'Manage Material Stock',
    },
    'stock_amount': {
      AppLanguage.ar: 'كمية الخامة (طن)',
      AppLanguage.en: 'Material Amount (tons)',
    },
    'enter_valid_amount': {
      AppLanguage.ar: '⚠️ الرجاء إدخال كمية صحيحة (أكبر من 0)',
      AppLanguage.en: '⚠️ Please enter a valid amount (greater than 0)',
    },
    'no_permission_add_stock': {
      AppLanguage.ar: '⚠️ ليس لديك صلاحية لإضافة رصيد',
      AppLanguage.en: '⚠️ You don\'t have permission to add stock',
    },
    'production_monitor_role': {
      AppLanguage.ar: '📊 مراقب إنتاج',
      AppLanguage.en: '📊 Production Monitor',
    },
    'only_read_only': {
      AppLanguage.ar: '🔒 للقراءة فقط',
      AppLanguage.en: '🔒 Read Only',
    },
    'select_press': {
      AppLanguage.ar: '📏 اختيار المكبس',
      AppLanguage.en: '📏 Select Press',
    },
    'auto_calculation': {
      AppLanguage.ar: 'تحديث تلقائي',
      AppLanguage.en: 'Auto Update',
    },
    'calculated_results': {
      AppLanguage.ar: '📊 النتائج المحسوبة:',
      AppLanguage.en: '📊 Calculated Results:',
    },
    'piece_length_label': {
      AppLanguage.ar: '📏 طول القطعة (متر)',
      AppLanguage.en: '📏 Piece Length (m)',
    },
    'table_length_label': {
      AppLanguage.ar: '📏 طول الفرش للقطاع (متر)',
      AppLanguage.en: '📏 Table Length (m)',
    },
    'expected_bars_label': {
      AppLanguage.ar: '📊 الأعواد المتوقعة',
      AppLanguage.en: '📊 Expected Bars',
    },
    'related_bars_label': {
      AppLanguage.ar: '🔗 الأعواد المتعلقات',
      AppLanguage.en: '🔗 Related Bars',
    },
    'end_shift_btn': {
      AppLanguage.ar: '🛑 إنهاء الوردية',
      AppLanguage.en: '🛑 End Shift',
    },
    'total_shift_scrap': {
      AppLanguage.ar: '🗑️ إجمالي خردة الوردية',
      AppLanguage.en: '🗑️ Total Shift Scrap',
    },
    'optional_field': {
      AppLanguage.ar: '(اختياري)',
      AppLanguage.en: '(Optional)',
    },
  };

  static String of(BuildContext context, String key) {
    final lang = context.read<LocaleProvider>().language;
    final entry = _values[key];
    if (entry == null) return key;
    return entry[lang] ?? entry[AppLanguage.ar] ?? key;
  }

  static String format(
    BuildContext context,
    String key,
    Map<String, String> params,
  ) {
    var result = of(context, key);
    params.forEach((k, v) {
      result = result.replaceAll('{$k}', v);
    });
    return result;
  }
}

extension AppStringsExtension on BuildContext {
  String tr(String key) => AppStrings.of(this, key);
  String trP(String key, Map<String, String> params) =>
      AppStrings.format(this, key, params);
}

class LanguageToggleButton extends StatelessWidget {
  const LanguageToggleButton({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final localeProvider = context.watch<LocaleProvider>();
    final isArabic = localeProvider.isArabic;
    final label = isArabic ? 'EN' : 'ع';

    if (compact) {
      return IconButton(
        icon: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        tooltip: isArabic ? 'Switch to English' : 'التبديل إلى العربية',
        onPressed: () => localeProvider.toggleLanguage(),
      );
    }

    return TextButton.icon(
      onPressed: () => localeProvider.toggleLanguage(),
      icon: const Icon(Icons.language, color: Colors.white),
      label: Text(
        label,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      style: TextButton.styleFrom(
        backgroundColor: Colors.white.withOpacity(0.15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
    );
  }
}