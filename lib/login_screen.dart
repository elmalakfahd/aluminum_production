import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'services.dart';
import 'models.dart';
import 'app_localization.dart';

// ============================================================
// 🔐 شاشة تسجيل الدخول - مع شعار الشركة
// ============================================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _imageLoaded = false;

  @override
  void initState() {
    super.initState();
    // ✅ التحقق من تحميل الصورة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkImage();
    });
  }

  void _checkImage() {
    try {
      // ✅ محاولة تحميل الصورة للتأكد من وجودها
      final image = AssetImage('assets/images/logo_delmar.png');
      image.resolve(ImageConfiguration()).addListener(
        ImageStreamListener(
          (info, sync) {
            if (mounted) setState(() => _imageLoaded = true);
          },
          onError: (error, stackTrace) {
            print('❌ خطأ في تحميل الصورة: $error');
            if (mounted) setState(() => _imageLoaded = false);
          },
        ),
      );
    } catch (e) {
      print('❌ خطأ: $e');
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      Fluttertoast.showToast(
        msg: context.tr('login_enter_email_password'),
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final service = Provider.of<AbstractFirebaseService>(context, listen: false);
      await service.signIn(_emailController.text, _passwordController.text);

      final userData = await service.getCurrentUserData();

      if (userData != null && userData.isDeveloper) {
        Fluttertoast.showToast(
          msg: context.tr('welcome_developer'),
          backgroundColor: Colors.deepPurple,
          textColor: Colors.white,
        );
      }

      Fluttertoast.showToast(
        msg: context.tr('login_success'),
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
    } on FirebaseAuthException catch (e) {
      String message = context.tr('login_error');
      if (e.code == 'user-not-found') {
        message = context.tr('user_not_found');
      } else if (e.code == 'wrong-password') {
        message = context.tr('wrong_password');
      } else if (e.code == 'invalid-email') {
        message = context.tr('invalid_email');
      } else if (e.code == 'too-many-requests') {
        message = context.tr('too_many_attempts');
      } else if (e.code == 'network-request-failed') {
        message = context.tr('no_internet');
      }
      Fluttertoast.showToast(
        msg: message,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        toastLength: Toast.LENGTH_LONG,
      );
    } catch (e) {
      String message = e.toString();
      if (message.contains('غير مفعل')) {
        message = context.tr('account_not_activated');
      } else if (message.contains('permission-denied')) {
        message = context.tr('no_permission_login');
      } else if (message.contains('network')) {
        message = context.tr('no_internet');
      } else if (message.contains('User not found')) {
        message = context.tr('user_not_found_system');
      } else {
        message = '${context.tr('unexpected_error')} $message';
      }
      Fluttertoast.showToast(
        msg: message,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        toastLength: Toast.LENGTH_LONG,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0A1628),
              Color(0xFF1A2A4A),
              Color(0xFF2A4A7A),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ✅ شعار الشركة
                      Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: _imageLoaded
                              ? Image.asset(
                                  'assets/images/logo_delmar.png',
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    print('❌ خطأ في عرض الصورة: $error');
                                    return _buildFallbackLogo();
                                  },
                                )
                              : _buildFallbackLogo(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ✅ اسم الشركة
                      Text(
                        'مجموعة دلمار الصناعية',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 10,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'DELEMAR INDUSTRIAL GROUP',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.8),
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 60,
                        height: 2,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.amber.shade400,
                              Colors.amber.shade700,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ✅ العنوان
                      Text(
                        context.tr('app_title'),
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.tr('login'),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ✅ حقل البريد الإلكتروني
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        child: TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: context.tr('email_label'),
                            labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                            prefixIcon: Icon(Icons.email, color: Colors.white.withOpacity(0.6)),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          enabled: !_isLoading,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ✅ حقل كلمة المرور
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        child: TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: context.tr('password_label'),
                            labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                            prefixIcon: Icon(Icons.lock, color: Colors.white.withOpacity(0.6)),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                color: Colors.white.withOpacity(0.6),
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          enabled: !_isLoading,
                          onFieldSubmitted: (_) => _login(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ✅ زر تسجيل الدخول
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  context.tr('login'),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ✅ زر "نسيت كلمة المرور"
                      TextButton(
                        onPressed: () {
                          _showForgotPasswordDialog();
                        },
                        child: Text(
                          context.tr('forgot_password'),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ✅ حقوق النشر
                      Text(
                        context.tr('copyright'),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ✅ زر تبديل اللغة أعلى الشاشة
              Positioned(
                top: 8,
                right: 8,
                child: LanguageToggleButton(
                  compact: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ شعار احتياطي في حال عدم وجود الصورة
  Widget _buildFallbackLogo() {
    return Container(
      color: Color(0xFF1A2A4A),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.business,
              size: 50,
              color: Colors.amber.shade400,
            ),
            const SizedBox(height: 4),
            Text(
              'DELMAR',
              style: TextStyle(
                color: Colors.amber.shade400,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ دالة نسيت كلمة المرور
  void _showForgotPasswordDialog() {
    final TextEditingController emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.tr('reset_password')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(dialogContext.tr('enter_email_reset_link')),
            const SizedBox(height: 16),
            TextFormField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: dialogContext.tr('email_label'),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(dialogContext.tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              if (emailController.text.isEmpty) {
                Fluttertoast.showToast(
                  msg: dialogContext.tr('please_enter_email'),
                  backgroundColor: Colors.orange,
                  textColor: Colors.white,
                );
                return;
              }

              Navigator.pop(dialogContext);
              setState(() => _isLoading = true);

              try {
                await FirebaseAuth.instance.sendPasswordResetEmail(
                  email: emailController.text.trim(),
                );
                Fluttertoast.showToast(
                  msg: context.tr('reset_link_sent'),
                  backgroundColor: Colors.green,
                  textColor: Colors.white,
                  toastLength: Toast.LENGTH_LONG,
                );
              } on FirebaseAuthException catch (e) {
                String message = context.tr('error_generic');
                if (e.code == 'user-not-found') {
                  message = context.tr('user_not_found');
                } else if (e.code == 'invalid-email') {
                  message = context.tr('invalid_email');
                }
                Fluttertoast.showToast(
                  msg: message,
                  backgroundColor: Colors.red,
                  textColor: Colors.white,
                );
              } catch (e) {
                Fluttertoast.showToast(
                  msg: '${context.tr('error_generic')}: $e',
                  backgroundColor: Colors.red,
                  textColor: Colors.white,
                );
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade700,
              foregroundColor: Colors.white,
            ),
            child: Text(dialogContext.tr('send')),
          ),
        ],
      ),
    );
  }
}