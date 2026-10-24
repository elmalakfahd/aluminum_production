import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'models.dart';
import 'services.dart';

// ============================================================
// 📝 شاشة تسجيل المستخدمين (بكلمة مرور 2026)
// ============================================================
class RegisterUserScreen extends StatefulWidget {
  const RegisterUserScreen({super.key});

  @override
  State<RegisterUserScreen> createState() => _RegisterUserScreenState();
}

class _RegisterUserScreenState extends State<RegisterUserScreen> {
  // ✅ كلمة المرور الخاصة بالزر
  static const String _registerPassword = '2026';

  // ✅ متغيرات التحكم
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVerified = false;
  bool _isLoading = false;
  bool _obscurePassword = true;

  // ✅ متغيرات تسجيل المستخدم
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _factoryController = TextEditingController();
  final TextEditingController _factoryNameController = TextEditingController();
  String _selectedRole = 'operator';
  String? _selectedAssignedPressId;
  bool _isRegistering = false;
  List<UserModel> _registeredUsers = [];
  List<PressModel> _presses = [];

  late ShiftProvider _provider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _provider = Provider.of<ShiftProvider>(context, listen: false);
      _loadData();
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await _provider.loadAllData();
      
      final allUsers = _provider.users;
      final currentFactoryId = _provider.currentFactoryId;
      
      setState(() {
        _registeredUsers = allUsers.where((u) => u.factoryId == currentFactoryId).toList();
        _presses = List.from(_provider.presses);
        _isLoading = false;
        
        if (_factoryController.text.isEmpty) {
          _factoryController.text = currentFactoryId;
        }
        if (_factoryNameController.text.isEmpty) {
          _factoryNameController.text = _provider.currentUser?.factoryName ?? currentFactoryId;
        }
      });
      
      print('✅ تم تحميل ${_registeredUsers.length} مستخدم في المصنع');
      
    } catch (e) {
      setState(() => _isLoading = false);
      Fluttertoast.showToast(
        msg: 'خطأ في تحميل البيانات: $e',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  Future<bool> _isEmailRegisteredInAnyFactory(String email) async {
    try {
      return await _provider.service.isEmailRegisteredInAnyFactory(email);
    } catch (e) {
      print('خطأ في التحقق من البريد: $e');
      return false;
    }
  }

  Future<void> _registerUser() async {
    if (_nameController.text.isEmpty || _emailController.text.isEmpty) {
      Fluttertoast.showToast(
        msg: '⚠️ الرجاء إدخال الاسم والبريد الإلكتروني',
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
      return;
    }

    setState(() => _isRegistering = true);

    try {
      final emailExists = await _isEmailRegisteredInAnyFactory(_emailController.text.trim());
      if (emailExists) {
        Fluttertoast.showToast(
          msg: '⚠️ هذا البريد الإلكتروني مسجل بالفعل في مصنع آخر',
          backgroundColor: Colors.orange,
          textColor: Colors.white,
          toastLength: Toast.LENGTH_LONG,
        );
        setState(() => _isRegistering = false);
        return;
      }

      final auth = FirebaseAuth.instance;
      final tempPassword = 'Temp@${DateTime.now().millisecondsSinceEpoch}';
      
      final userCredential = await auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: tempPassword,
      );

      String factoryId = _factoryController.text.trim();
      if (factoryId.isEmpty) {
        factoryId = _provider.currentFactoryId;
      }

      String factoryName = _factoryNameController.text.trim();
      if (factoryName.isEmpty) {
        factoryName = factoryId;
      }

      final newUser = UserModel(
        uid: userCredential.user!.uid,
        email: _emailController.text.trim(),
        name: _nameController.text.trim(),
        role: _selectedRole,
        factoryId: factoryId,
        factoryName: factoryName,
        factories: [],
        managedFactories: [],
        canEndShift: false,
        assignedPressId: _selectedRole == 'supervisor' ? _selectedAssignedPressId : null,
      );

      await _provider.addUser(newUser);
      await _loadData();
      
      final userName = _nameController.text.trim();
      final userEmail = _emailController.text.trim();
      _nameController.clear();
      _emailController.clear();
      _selectedRole = 'operator';
      _selectedAssignedPressId = null;
      
      _showSuccessDialog(userName, userEmail, tempPassword);
      
    } on FirebaseAuthException catch (e) {
      String message = '❌ خطأ في إنشاء المستخدم';
      if (e.code == 'email-already-in-use') {
        message = '❌ البريد الإلكتروني مستخدم بالفعل';
      } else if (e.code == 'invalid-email') {
        message = '❌ البريد الإلكتروني غير صحيح';
      } else if (e.code == 'weak-password') {
        message = '❌ كلمة المرور ضعيفة';
      } else if (e.code == 'operation-not-allowed') {
        message = '❌ تسجيل المستخدمين غير مفعل في Firebase Console';
      }
      Fluttertoast.showToast(
        msg: message,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        toastLength: Toast.LENGTH_LONG,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: '❌ خطأ غير متوقع: $e',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      setState(() => _isRegistering = false);
    }
  }

  void _showSuccessDialog(String name, String email, String password) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('✅ تم تسجيل المستخدم'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(),
              _infoRow('👤 الاسم', name),
              _infoRow('📧 البريد', email),
              _infoRow('🔑 كلمة المرور المؤقتة', password),
              _infoRow('🎯 الدور', _selectedRole == 'production_monitor' ? '📊 مراقب إنتاج' : _selectedRole == 'supervisor' ? '👔 مشرف' : '🔧 مشغل'),
              if (_selectedRole == 'supervisor' && _selectedAssignedPressId != null)
                _infoRow('📏 المكبس المخصص', _selectedAssignedPressId!),
              const Divider(),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.amber, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '⚠️ يرجى تسجيل الدخول باستخدام هذه البيانات',
                        style: TextStyle(fontSize: 12, color: Colors.amber),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '📌 يمكن للمستخدم تغيير كلمة المرور بعد تسجيل الدخول',
                        style: TextStyle(fontSize: 12, color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('حسناً'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Clipboard.setData(ClipboardData(text: password));
              Fluttertoast.showToast(
                msg: '📋 تم نسخ كلمة المرور',
                backgroundColor: Colors.green,
                textColor: Colors.white,
              );
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('نسخ كلمة المرور'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_outline,
                  size: 64,
                  color: Colors.teal,
                ),
                const SizedBox(height: 16),
                const Text(
                  '🔐 تسجيل مستخدم جديد',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
                const Text(
                  'أدخل كلمة المرور للدخول إلى شاشة التسجيل',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: '🔑 كلمة المرور',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  onFieldSubmitted: (_) => _verifyPassword(),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _verifyPassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
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
                        : const Text('دخول', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('رجوع'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _verifyPassword() async {
    if (_passwordController.text.isEmpty) {
      Fluttertoast.showToast(
        msg: '⚠️ الرجاء إدخال كلمة المرور',
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
      return;
    }

    if (_passwordController.text == _registerPassword) {
      setState(() {
        _isPasswordVerified = true;
        _isLoading = false;
      });
      Fluttertoast.showToast(
        msg: '✅ تم التحقق من كلمة المرور',
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
      await _loadData();
    } else {
      Fluttertoast.showToast(
        msg: '❌ كلمة المرور غير صحيحة',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  Widget _buildRegisterScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📝 تسجيل مستخدم جديد'),
        backgroundColor: Colors.teal,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'تحديث',
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _isPasswordVerified = false;
                _passwordController.clear();
              });
            },
            child: const Text(
              '🔒 خروج',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Card(
                    color: Colors.teal.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.person_add, color: Colors.teal),
                              SizedBox(width: 8),
                              Text(
                                '➕ تسجيل مستخدم جديد',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: '👤 الاسم الكامل',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _emailController,
                            decoration: const InputDecoration(
                              labelText: '📧 البريد الإلكتروني',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.email),
                              helperText: 'سيتم إنشاء حساب تلقائياً',
                              isDense: true,
                            ),
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _factoryController,
                                  decoration: const InputDecoration(
                                    labelText: '🏭 معرف المصنع',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.code),
                                    isDense: true,
                                  ),
                                  enabled: false,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  controller: _factoryNameController,
                                  decoration: const InputDecoration(
                                    labelText: '🏷️ اسم المصنع',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.business),
                                    isDense: true,
                                  ),
                                  enabled: false,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _selectedRole,
                            decoration: const InputDecoration(
                              labelText: '🎯 الدور',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.admin_panel_settings),
                              isDense: true,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'production_monitor',
                                child: Text('📊 مراقب إنتاج (Production Monitor)'),
                              ),
                              DropdownMenuItem(
                                value: 'supervisor',
                                child: Text('👔 مشرف (Supervisor)'),
                              ),
                              DropdownMenuItem(
                                value: 'operator',
                                child: Text('🔧 مشغل (Operator)'),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedRole = value!;
                                if (_selectedRole != 'supervisor') {
                                  _selectedAssignedPressId = null;
                                }
                              });
                            },
                          ),
                          if (_selectedRole == 'supervisor' && _presses.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: _selectedAssignedPressId,
                              decoration: const InputDecoration(
                                labelText: '📏 المكبس المخصص',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.settings),
                                isDense: true,
                                helperText: 'اختر المكبس الذي سيشرف عليه هذا المشرف',
                              ),
                              items: [
                                const DropdownMenuItem(
                                  value: null,
                                  child: Text('جميع المكابس'),
                                ),
                                ..._presses.map((press) =>
                                  DropdownMenuItem(
                                    value: press.id,
                                    child: Text(press.name),
                                  )
                                ),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedAssignedPressId = value;
                                });
                              },
                            ),
                          ],
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isRegistering ? null : _registerUser,
                              icon: _isRegistering
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.add),
                              label: Text(
                                _isRegistering ? 'جاري التسجيل...' : '✅ تسجيل المستخدم',
                                style: const TextStyle(fontSize: 14),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                '📋 المستخدمين المسجلين',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${_registeredUsers.length} مستخدم',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_registeredUsers.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Text(
                                  'لا يوجد مستخدمين مسجلين',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _registeredUsers.length,
                              itemBuilder: (context, index) {
                                final user = _registeredUsers[index];
                                final displayName = user.name.isNotEmpty
                                    ? user.name
                                    : user.email.split('@').first;
                                
                                String roleName;
                                Color roleColor;
                                if (user.isProductionMonitor) {
                                  roleName = '📊 مراقب إنتاج';
                                  roleColor = Colors.purple;
                                } else if (user.isSupervisor) {
                                  roleName = '👔 مشرف';
                                  roleColor = Colors.green;
                                } else {
                                  roleName = '🔧 مشغل';
                                  roleColor = Colors.grey;
                                }
                                
                                return ListTile(
                                  dense: true,
                                  leading: CircleAvatar(
                                    radius: 14,
                                    backgroundColor: roleColor,
                                    child: Text(
                                      displayName.substring(0, 1).toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    displayName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '📧 ${user.email}  🎯 $roleName',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  trailing: user.canEndShift
                                      ? const Icon(
                                          Icons.lock_open,
                                          color: Colors.green,
                                          size: 16,
                                        )
                                      : null,
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isPasswordVerified) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.teal.shade700, Colors.teal.shade300],
            ),
          ),
          child: _buildPasswordScreen(),
        ),
      );
    }

    return _buildRegisterScreen();
  }
}