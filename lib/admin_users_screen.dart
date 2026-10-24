import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'models.dart';
import 'services.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _factoryController = TextEditingController();
  final TextEditingController _factoryNameController = TextEditingController();
  String _selectedRole = 'operator';
  bool _canEndShift = false;
  String? _selectedAssignedPressId;
  bool _isLoading = false;
  List<UserModel> _users = [];
  List<FactoryModel> _factories = [];
  List<PressModel> _presses = [];

  String? _selectedUserForFactoryChange;
  final TextEditingController _changeFactoryIdController = TextEditingController();
  final TextEditingController _changeFactoryNameController = TextEditingController();

  late ShiftProvider _provider;
  late UserModel _currentUser;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _provider = Provider.of<ShiftProvider>(context, listen: false);
      _currentUser = _provider.currentUser!;
      _loadData();
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await _provider.loadAllData();
      
      final allUsers = _provider.users;
      final allPresses = _provider.presses;
      
      List<UserModel> filteredUsers;
      
      if (_currentUser.isDeveloper) {
        filteredUsers = List.from(allUsers);
      } else if (_currentUser.isOwner) {
        final ownerFactoryIds = _currentUser.factories;
        filteredUsers = allUsers.where((u) => ownerFactoryIds.contains(u.factoryId)).toList();
      } else if (_currentUser.isManager) {
        final managerFactoryIds = _currentUser.managedFactories;
        filteredUsers = allUsers.where((u) => managerFactoryIds.contains(u.factoryId)).toList();
      } else {
        filteredUsers = allUsers.where((u) => u.factoryId == _provider.currentFactoryId).toList();
      }
      
      setState(() {
        _users = filteredUsers;
        _factories = List.from(_provider.ownerFactories);
        _presses = List.from(allPresses);
        _isLoading = false;
      });
      
      print('✅ تم تحميل ${_users.length} مستخدم');
      
    } catch (e) {
      setState(() => _isLoading = false);
      print('❌ خطأ في تحميل البيانات: $e');
      Fluttertoast.showToast(
        msg: 'خطأ في تحميل البيانات: $e',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _factoryController.dispose();
    _factoryNameController.dispose();
    _changeFactoryIdController.dispose();
    _changeFactoryNameController.dispose();
    super.dispose();
  }

  bool _canManageUsersInFactory(String factoryId) {
    if (_currentUser.isDeveloper) return true;
    if (_currentUser.isOwner) return _currentUser.factories.contains(factoryId);
    if (_currentUser.isManager) return _currentUser.managedFactories.contains(factoryId);
    return false;
  }

  bool get _canAddUsers {
    return _currentUser.isDeveloper || _currentUser.isOwner || _currentUser.isManager;
  }

  bool _canToggleEndShift(String factoryId) {
    if (_currentUser.isDeveloper) return true;
    if (_currentUser.isOwner) return _currentUser.factories.contains(factoryId);
    if (_currentUser.isManager) return _currentUser.managedFactories.contains(factoryId);
    return false;
  }

  bool get _canSeeDeveloperRole {
    return _currentUser.isDeveloper;
  }

  Future<void> _addUser() async {
    if (_nameController.text.isEmpty || _emailController.text.isEmpty) {
      Fluttertoast.showToast(
        msg: '⚠️ الرجاء إدخال الاسم والبريد الإلكتروني',
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
      return;
    }

    if (!_canAddUsers) {
      Fluttertoast.showToast(
        msg: '⚠️ ليس لديك صلاحية لإضافة مستخدمين',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    setState(() => _isLoading = true);

    // ✅ لو البريد ده مسجل بالفعل لمستخدم موجود، منحاولش ننشئ حساب جديد بيه
    // (هيفشل من فايربيز على أي حال) - بدل كده نوضح الطريقة الصح لربط نفس
    // المالك/المدير بمصنع إضافي، من غير ما ننشئله حساب مكرر
    final emailToAdd = _emailController.text.trim().toLowerCase();
    final existingUserWithEmail = _users.where(
      (u) => u.email.trim().toLowerCase() == emailToAdd,
    ).toList();
    if (existingUserWithEmail.isNotEmpty) {
      setState(() => _isLoading = false);
      Fluttertoast.showToast(
        msg: '⚠️ البريد ده مسجل بالفعل للمستخدم "${existingUserWithEmail.first.name}". '
            'لو عايز تضيفه كمالك/مدير لمصنع إضافي، استخدم شاشة "إدارة المصانع" '
            '(اختاره من قائمة "المالك" أو زرار "إضافة مدير")، مش إنشاء حساب جديد بنفس البريد.',
        backgroundColor: Colors.orange,
        textColor: Colors.white,
        toastLength: Toast.LENGTH_LONG,
      );
      return;
    }

    try {
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

      if (!_canManageUsersInFactory(factoryId)) {
        Fluttertoast.showToast(
          msg: '⚠️ ليس لديك صلاحية لإضافة مستخدم في هذا المصنع',
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        setState(() => _isLoading = false);
        return;
      }

      String factoryName = _factoryNameController.text.trim();
      if (factoryName.isEmpty) {
        factoryName = factoryId;
      }

      if (_selectedRole == 'developer' && !_currentUser.isDeveloper) {
        Fluttertoast.showToast(
          msg: '⚠️ فقط المطور يمكنه إضافة مستخدمين بدور مطور',
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        setState(() => _isLoading = false);
        return;
      }

      final newUser = UserModel(
        uid: userCredential.user!.uid,
        email: _emailController.text.trim(),
        name: _nameController.text.trim(),
        role: _selectedRole,
        factoryId: factoryId,
        factoryName: factoryName,
        factories: _selectedRole == 'owner' ? [factoryId] : [],
        managedFactories: _selectedRole == 'manager' ? [factoryId] : [],
        canEndShift: _canEndShift,
        assignedPressId: _selectedRole == 'supervisor' ? _selectedAssignedPressId : null,
      );

      await _provider.addUser(newUser);
      await _loadData();
      
      final userName = _nameController.text.trim();
      final userEmail = _emailController.text.trim();
      _nameController.clear();
      _emailController.clear();
      _factoryController.clear();
      _factoryNameController.clear();
      _selectedRole = 'operator';
      _canEndShift = false;
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
      setState(() => _isLoading = false);
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
            Text('✅ تم إضافة المستخدم'),
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

  Future<void> _toggleEndShiftPermission(UserModel user) async {
    if (!_canToggleEndShift(user.factoryId)) {
      Fluttertoast.showToast(
        msg: '⚠️ ليس لديك صلاحية لتغيير صلاحية هذا المستخدم',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    if (user.isDeveloper) {
      Fluttertoast.showToast(
        msg: '⚠️ لا يمكن تغيير صلاحية المطور',
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final updatedUser = UserModel(
        uid: user.uid,
        email: user.email,
        name: user.name,
        role: user.role,
        factoryId: user.factoryId,
        factoryName: user.factoryName,
        factories: user.factories,
        managedFactories: user.managedFactories,
        canEndShift: !user.canEndShift,
        assignedPressId: user.assignedPressId,
      );
      await _provider.updateUser(updatedUser);
      await _loadData();
      
      Fluttertoast.showToast(
        msg: '✅ تم ${user.canEndShift ? 'إلغاء' : 'تفعيل'} صلاحية إنهاء الوردية لـ ${user.name}',
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

  Future<void> _showChangeFactoryDialog(UserModel user) async {
    _changeFactoryIdController.text = user.factoryId;
    _changeFactoryNameController.text = user.factoryName;
    _selectedUserForFactoryChange = user.uid;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('🏭 تغيير مصنع المستخدم: ${user.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('أدخل معرف المصنع الجديد:'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _changeFactoryIdController,
              decoration: const InputDecoration(
                labelText: '🏭 معرف المصنع',
                border: OutlineInputBorder(),
                hintText: 'مثال: default_factory',
              ),
            ),
            const SizedBox(height: 12),
            const Text('أدخل اسم المصنع الجديد:'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _changeFactoryNameController,
              decoration: const InputDecoration(
                labelText: '🏷️ اسم المصنع',
                border: OutlineInputBorder(),
                hintText: 'اسم المصنع الظاهر للمستخدم',
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info, color: Colors.amber, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '💡 سيتم نقل المستخدم إلى المصنع الجديد مع جميع بياناته',
                      style: TextStyle(fontSize: 12, color: Colors.amber),
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
          ElevatedButton.icon(
            onPressed: () async {
              final newFactoryId = _changeFactoryIdController.text.trim();
              final newFactoryName = _changeFactoryNameController.text.trim();

              if (newFactoryId.isEmpty) {
                Fluttertoast.showToast(
                  msg: '⚠️ الرجاء إدخال معرف المصنع',
                  backgroundColor: Colors.orange,
                  textColor: Colors.white,
                );
                return;
              }

              Navigator.pop(context);
              await _changeUserFactory(user.uid, newFactoryId, newFactoryName);
            },
            icon: const Icon(Icons.save),
            label: const Text('تغيير المصنع'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ جديد: تعديل دور مستخدم موجود بالفعل (مثلاً ترقية مدير ليصبح مالكاً)
  // بدل ما يحتاج المستخدم لحساب جديد بنفس البريد الإلكتروني، وهو أمر
  // ممنوع أصلاً. ده اللي كان ناقص وبيمنع ربط نفس الشخص كمالك لأكتر من
  // مصنع من قائمة "المالك" في شاشة "إدارة المصانع".
  Future<void> _showEditRoleDialog(UserModel user) async {
    String newRole = user.role;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text('🎯 تعديل دور المستخدم: ${user.name}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('الدور الحالي: ${_roleDisplayName(user.role)}'),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: newRole,
                  decoration: const InputDecoration(
                    labelText: '🎯 الدور الجديد',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    if (_canSeeDeveloperRole)
                      const DropdownMenuItem(value: 'developer', child: Text('👑 مطور')),
                    const DropdownMenuItem(value: 'owner', child: Text('🏢 مالك')),
                    const DropdownMenuItem(value: 'manager', child: Text('🏗️ مدير مصنع')),
                    const DropdownMenuItem(value: 'supervisor', child: Text('👔 مشرف')),
                    const DropdownMenuItem(value: 'operator', child: Text('🔧 مشغل')),
                  ],
                  onChanged: (value) {
                    setStateDialog(() => newRole = value!);
                  },
                ),
                const SizedBox(height: 12),
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
                          '💡 نفس الحساب هيفضل بإيميله الحالي، وهيقدر بعد كده يظهر '
                          'في قائمة "المالك"/"المدير" عند إضافة مصانع تانية له.',
                          style: TextStyle(fontSize: 12, color: Colors.blue),
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
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  await _applyRoleChange(user, newRole);
                },
                icon: const Icon(Icons.save),
                label: const Text('حفظ الدور'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _roleDisplayName(String role) {
    switch (role) {
      case 'developer':
        return '👑 مطور';
      case 'owner':
        return '🏢 مالك';
      case 'manager':
        return '🏗️ مدير مصنع';
      case 'supervisor':
        return '👔 مشرف';
      default:
        return '🔧 مشغل';
    }
  }

  Future<void> _applyRoleChange(UserModel user, String newRole) async {
    if (newRole == user.role) return;

    setState(() => _isLoading = true);
    try {
      // ✅ لما يتحول لـ"مالك" أو "مدير"، لازم يبقى شايف على الأقل مصنعه
      // الحالي في قائمة factories/managedFactories الخاصة به، وإلا مش
      // هيقدر يشوف حتى المصنع اللي هو فيه أصلاً.
      List<String> updatedFactories = user.factories;
      List<String> updatedManagedFactories = user.managedFactories;

      if (newRole == 'owner' && !updatedFactories.contains(user.factoryId)) {
        updatedFactories = [...updatedFactories, user.factoryId];
      }
      if (newRole == 'manager' && !updatedManagedFactories.contains(user.factoryId)) {
        updatedManagedFactories = [...updatedManagedFactories, user.factoryId];
      }

      final updatedUser = UserModel(
        uid: user.uid,
        email: user.email,
        name: user.name,
        role: newRole,
        factoryId: user.factoryId,
        factoryName: user.factoryName,
        factories: updatedFactories,
        managedFactories: updatedManagedFactories,
        canEndShift: user.canEndShift,
        assignedPressId: newRole == 'supervisor' ? user.assignedPressId : null,
      );

      await _provider.updateUser(updatedUser);
      await _loadData();

      Fluttertoast.showToast(
        msg: '✅ تم تحديث دور ${user.name} إلى ${_roleDisplayName(newRole)}',
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: '❌ خطأ في تعديل الدور: $e',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _changeUserFactory(String uid, String newFactoryId, String newFactoryName) async {
    setState(() => _isLoading = true);
    try {
      await _provider.updateUserFactory(uid, newFactoryId, newFactoryName);
      await _loadData();
      Fluttertoast.showToast(
        msg: '✅ تم تغيير مصنع المستخدم بنجاح',
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: '❌ خطأ في تغيير المصنع: $e',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteUser(UserModel user) async {
    if (!_canManageUsersInFactory(user.factoryId)) {
      Fluttertoast.showToast(
        msg: '⚠️ ليس لديك صلاحية لحذف هذا المستخدم',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    if (user.isDeveloper) {
      Fluttertoast.showToast(
        msg: '⚠️ لا يمكن حذف المطور',
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف المستخدم ${user.name}؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              try {
                await _provider.deleteUser(user.uid);
                await _loadData();
                Fluttertoast.showToast(
                  msg: '✅ تم حذف المستخدم',
                  backgroundColor: Colors.red,
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
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ShiftProvider>(context);
    
    if (!_canAddUsers) {
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
    
    String pageTitle;
    if (_currentUser.isDeveloper) {
      pageTitle = '👑 إدارة المستخدمين - المطور';
    } else if (_currentUser.isOwner) {
      pageTitle = '🏢 إدارة المستخدمين - المالك';
    } else if (_currentUser.isManager) {
      pageTitle = '🏗️ إدارة المستخدمين - مدير المصنع';
    } else {
      pageTitle = '👤 إدارة المستخدمين';
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text(pageTitle),
        backgroundColor: _currentUser.isDeveloper 
            ? Colors.deepPurple 
            : _currentUser.isOwner 
                ? Colors.blue 
                : Colors.teal,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: _isLoading || provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                return Column(
                  children: [
                    if (_canAddUsers)
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: constraints.maxHeight * 0.65,
                        ),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(12),
                          child: Card(
                            color: _currentUser.isDeveloper 
                                ? Colors.deepPurple.shade50 
                                : _currentUser.isOwner 
                                    ? Colors.blue.shade50 
                                    : Colors.teal.shade50,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.person_add, 
                                        color: _currentUser.isDeveloper 
                                            ? Colors.deepPurple 
                                            : _currentUser.isOwner 
                                                ? Colors.blue 
                                                : Colors.teal,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '➕ إضافة مستخدم جديد',
                                        style: TextStyle(
                                          fontSize: 16, 
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _nameController,
                                    decoration: const InputDecoration(
                                      labelText: '👤 الاسم الكامل',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.person),
                                      isDense: true,
                                    ),
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  const SizedBox(height: 6),
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
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  const SizedBox(height: 6),
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
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: TextFormField(
                                          controller: _factoryNameController,
                                          decoration: const InputDecoration(
                                            labelText: '🏷️ اسم المصنع',
                                            border: OutlineInputBorder(),
                                            prefixIcon: Icon(Icons.business),
                                            isDense: true,
                                          ),
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<String>(
                                    value: _selectedRole,
                                    decoration: const InputDecoration(
                                      labelText: '🎯 الدور',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.admin_panel_settings),
                                      isDense: true,
                                    ),
                                    items: [
                                      if (_canSeeDeveloperRole)
                                        const DropdownMenuItem(
                                          value: 'developer', 
                                          child: Text('👑 مطور'),
                                        ),
                                      const DropdownMenuItem(
                                        value: 'owner', 
                                        child: Text('🏢 مالك'),
                                      ),
                                      const DropdownMenuItem(
                                        value: 'manager', 
                                        child: Text('🏗️ مدير مصنع'),
                                      ),
                                      const DropdownMenuItem(
                                        value: 'supervisor', 
                                        child: Text('👔 مشرف'),
                                      ),
                                      const DropdownMenuItem(
                                        value: 'operator', 
                                        child: Text('🔧 مشغل'),
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
                                    const SizedBox(height: 6),
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
                                  const SizedBox(height: 4),
                                  SwitchListTile(
                                    title: const Text('🔓 صلاحية إنهاء الوردية', style: TextStyle(fontSize: 13)),
                                    subtitle: Text(
                                      _canEndShift 
                                          ? 'يمكنه إنهاء أي وردية' 
                                          : 'لا يمكنه إنهاء الورديات',
                                      style: TextStyle(
                                        color: _canEndShift ? Colors.green : Colors.grey,
                                        fontSize: 11,
                                      ),
                                    ),
                                    value: _canEndShift,
                                    onChanged: (value) => setState(() => _canEndShift = value),
                                    activeColor: Colors.green,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  const SizedBox(height: 4),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: _isLoading ? null : _addUser,
                                      icon: const Icon(Icons.add, size: 18),
                                      label: const Text('إضافة مستخدم', style: TextStyle(fontSize: 13)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _currentUser.isDeveloper 
                                            ? Colors.deepPurple 
                                            : _currentUser.isOwner 
                                                ? Colors.blue 
                                                : Colors.teal,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        minimumSize: const Size(0, 40),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  '📋 قائمة المستخدمين',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '${_users.length} مستخدم',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Expanded(
                              child: _users.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.people_outline, size: 48, color: Colors.grey.shade300),
                                          const SizedBox(height: 12),
                                          Text(
                                            'لا يوجد مستخدمين',
                                            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                                          ),
                                          Text(
                                            'أضف مستخدمين جدد من الأعلى',
                                            style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                                          ),
                                          const SizedBox(height: 12),
                                          ElevatedButton.icon(
                                            onPressed: _loadData,
                                            icon: const Icon(Icons.refresh, size: 16),
                                            label: const Text('تحديث', style: TextStyle(fontSize: 12)),
                                            style: ElevatedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                              minimumSize: const Size(0, 32),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : ListView.builder(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      shrinkWrap: false,
                                      physics: const BouncingScrollPhysics(),
                                      itemCount: _users.length,
                                      itemBuilder: (context, index) {
                                        final user = _users[index];
                                        final isCurrentUser = user.uid == provider.currentUserUid;
                                        final displayName = user.name.isNotEmpty ? user.name : user.email.split('@').first;
                                        
                                        String roleName;
                                        Color roleColor;
                                        if (user.isDeveloper) {
                                          roleName = '👑 مطور';
                                          roleColor = Colors.deepPurple;
                                        } else if (user.isOwner) {
                                          roleName = '🏢 مالك';
                                          roleColor = Colors.blue;
                                        } else if (user.isManager) {
                                          roleName = '🏗️ مدير مصنع';
                                          roleColor = Colors.teal;
                                        } else if (user.isSupervisor) {
                                          roleName = '👔 مشرف';
                                          roleColor = Colors.green;
                                        } else {
                                          roleName = '🔧 مشغل';
                                          roleColor = Colors.grey;
                                        }
                                        
                                        String assignedPressName = '';
                                        if (user.assignedPressId != null) {
                                          final press = PressModel.getPressById(user.assignedPressId!);
                                          if (press != null) {
                                            assignedPressName = press.name;
                                          }
                                        }
                                        
                                        final canManage = _canManageUsersInFactory(user.factoryId);
                                        
                                        return Card(
                                          margin: const EdgeInsets.symmetric(vertical: 3),
                                          child: Column(
                                            children: [
                                              ListTile(
                                                dense: true,
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                                leading: CircleAvatar(
                                                  radius: 16,
                                                  backgroundColor: roleColor,
                                                  child: Text(
                                                    displayName.substring(0, 1).toUpperCase(),
                                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                                  ),
                                                ),
                                                title: Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        displayName,
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.bold, 
                                                          fontSize: 13,
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    if (user.isDeveloper)
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                        decoration: BoxDecoration(
                                                          color: Colors.deepPurple,
                                                          borderRadius: BorderRadius.circular(8),
                                                        ),
                                                        child: const Text(
                                                          'مطور',
                                                          style: TextStyle(color: Colors.white, fontSize: 8),
                                                        ),
                                                      ),
                                                    if (isCurrentUser)
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                        decoration: BoxDecoration(
                                                          color: Colors.green,
                                                          borderRadius: BorderRadius.circular(8),
                                                        ),
                                                        child: const Text(
                                                          'أنت',
                                                          style: TextStyle(color: Colors.white, fontSize: 8),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                subtitle: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text('📧 ${user.email}', style: const TextStyle(fontSize: 10)),
                                                    Text('🎯 $roleName', style: const TextStyle(fontSize: 10)),
                                                    Text('🏭 ${user.factoryName}', style: const TextStyle(fontSize: 10)),
                                                    if (assignedPressName.isNotEmpty)
                                                      Text('📏 مخصص: $assignedPressName', style: const TextStyle(fontSize: 9, color: Colors.blue)),
                                                    if (user.canEndShift)
                                                      const Text(
                                                        '🔑 صلاحية إنهاء',
                                                        style: TextStyle(color: Colors.green, fontSize: 9),
                                                      ),
                                                  ],
                                                ),
                                                trailing: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    if (canManage && !user.isDeveloper && !isCurrentUser)
                                                      Switch(
                                                        value: user.canEndShift,
                                                        onChanged: (_) => _toggleEndShiftPermission(user),
                                                        activeColor: Colors.green,
                                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                      ),
                                                    if (canManage && !isCurrentUser && !user.isDeveloper)
                                                      IconButton(
                                                        icon: const Icon(Icons.edit, color: Colors.deepPurple, size: 16),
                                                        onPressed: () => _showEditRoleDialog(user),
                                                        padding: EdgeInsets.zero,
                                                        constraints: const BoxConstraints(),
                                                        tooltip: 'تعديل الدور',
                                                      ),
                                                    if (canManage && !isCurrentUser && !user.isDeveloper)
                                                      IconButton(
                                                        icon: const Icon(Icons.delete, color: Colors.red, size: 16),
                                                        onPressed: () => _deleteUser(user),
                                                        padding: EdgeInsets.zero,
                                                        constraints: const BoxConstraints(),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                              if (canManage && !isCurrentUser && !user.isDeveloper)
                                                Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                  child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.end,
                                                    children: [
                                                      ElevatedButton.icon(
                                                        onPressed: () => _showChangeFactoryDialog(user),
                                                        icon: const Icon(Icons.factory, size: 12),
                                                        label: const Text('🏭 تغيير', style: TextStyle(fontSize: 10)),
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: Colors.orange,
                                                          foregroundColor: Colors.white,
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                          textStyle: const TextStyle(fontSize: 10),
                                                          minimumSize: const Size(0, 24),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      ElevatedButton.icon(
                                                        onPressed: () {
                                                          _changeUserFactory(
                                                            user.uid,
                                                            'default_factory',
                                                            'المصنع الافتراضي'
                                                          );
                                                        },
                                                        icon: const Icon(Icons.home, size: 12),
                                                        label: const Text('🏠 افتراضي', style: TextStyle(fontSize: 10)),
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: Colors.green,
                                                          foregroundColor: Colors.white,
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                          textStyle: const TextStyle(fontSize: 10),
                                                          minimumSize: const Size(0, 24),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}