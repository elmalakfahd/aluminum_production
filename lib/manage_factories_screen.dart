import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; // ✅ إضافة هذا السطر
import 'models.dart';
import 'services.dart';

class ManageFactoriesScreen extends StatefulWidget {
  const ManageFactoriesScreen({super.key});

  @override
  State<ManageFactoriesScreen> createState() => _ManageFactoriesScreenState();
}

class _ManageFactoriesScreenState extends State<ManageFactoriesScreen> {
  late ShiftProvider _provider;
  List<FactoryModel> _factories = [];
  bool _isLoading = true;
  List<UserModel> _allUsers = [];

  final TextEditingController _newFactoryIdController = TextEditingController();
  final TextEditingController _newFactoryNameController = TextEditingController();
  String? _selectedOwnerId;

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
      
      // ✅ جلب جميع المستخدمين
      _allUsers = _provider.users;
      
      // ✅ جلب جميع المصانع من خلال المطور
      final allFactories = await _getAllFactories();
      setState(() {
        _factories = allFactories;
        _isLoading = false;
      });
      
      print('✅ تم تحميل ${_factories.length} مصنع');
      
    } catch (e) {
      setState(() => _isLoading = false);
      Fluttertoast.showToast(
        msg: 'خطأ في تحميل البيانات: $e',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  Future<List<FactoryModel>> _getAllFactories() async {
    try {
      // ✅ الإصلاح: كنا بنجيب المصانع اللي "المطور" نفسه مالكها (وده دايماً صفر
      // لأن المطور مش مسجل كـ"مالك" لأي مصنع) بدل ما نجيب كل المصانع فعلياً.
      final factories = await _provider.service.getAllFactories();
      return factories;
    } catch (e) {
      print('خطأ في جلب المصانع: $e');
      return [];
    }
  }

  Future<void> _addFactory() async {
    final factoryId = _newFactoryIdController.text.trim();
    final factoryName = _newFactoryNameController.text.trim();

    if (factoryId.isEmpty) {
      Fluttertoast.showToast(
        msg: '⚠️ الرجاء إدخال معرف المصنع',
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
      return;
    }

    if (factoryName.isEmpty) {
      Fluttertoast.showToast(
        msg: '⚠️ الرجاء إدخال اسم المصنع',
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
      return;
    }

    if (_selectedOwnerId == null) {
      Fluttertoast.showToast(
        msg: '⚠️ الرجاء اختيار المالك',
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
      return;
    }

    UserModel? owner;
    try {
      owner = _allUsers.firstWhere((u) => u.uid == _selectedOwnerId);
    } catch (e) {
      owner = null;
    }
    if (owner == null) {
      Fluttertoast.showToast(
        msg: '⚠️ المالك غير موجود',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    final exists = await _provider.service.validateFactoryId(factoryId);
    if (exists) {
      Fluttertoast.showToast(
        msg: '⚠️ يوجد مصنع بنفس المعرف بالفعل',
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
      return;
    }

    try {
      final newFactory = FactoryModel(
        id: factoryId,
        name: factoryName,
        ownerId: owner.uid,
        ownerEmail: owner.email,
        ownerName: owner.name,
        managers: [],
        createdAt: DateTime.now(),
      );

      await _provider.service.createFactory(newFactory);
      
      final updatedOwner = UserModel(
        uid: owner.uid,
        email: owner.email,
        name: owner.name,
        role: owner.role,
        factoryId: owner.factoryId,
        factoryName: owner.factoryName,
        factories: [...owner.factories, factoryId],
        managedFactories: owner.managedFactories,
        canEndShift: owner.canEndShift,
        assignedPressId: owner.assignedPressId,
      );
      await _provider.service.updateUser(updatedOwner);

      _newFactoryIdController.clear();
      _newFactoryNameController.clear();
      _selectedOwnerId = null;
      
      await _loadData();
      Fluttertoast.showToast(
        msg: '✅ تم إضافة المصنع: $factoryName',
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

  Future<void> _addManagerToFactory(FactoryModel factory) async {
    final availableUsers = _allUsers.where((u) => 
      !factory.managers.contains(u.uid) && 
      u.uid != factory.ownerId
    ).toList();

    if (availableUsers.isEmpty) {
      Fluttertoast.showToast(
        msg: '⚠️ لا يوجد مستخدمين متاحين للإضافة كمديرين',
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
      return;
    }

    String? selectedUserId;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('🏗️ إضافة مدير لمصنع ${factory.name}'),
        content: StatefulBuilder(
          builder: (context, setStateDialog) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('اختر المستخدم لإضافته كمدير للمصنع:'),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedUserId,
                  decoration: const InputDecoration(
                    labelText: '👤 المستخدم',
                    border: OutlineInputBorder(),
                  ),
                  items: availableUsers.map((user) => 
                    DropdownMenuItem(
                      value: user.uid,
                      child: Text('${user.name} (${user.email})'),
                    )
                  ).toList(),
                  onChanged: (value) {
                    setStateDialog(() {
                      selectedUserId = value;
                    });
                  },
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (selectedUserId == null) {
                Fluttertoast.showToast(
                  msg: '⚠️ الرجاء اختيار مستخدم',
                  backgroundColor: Colors.orange,
                  textColor: Colors.white,
                );
                return;
              }

              Navigator.pop(context);
              
              final user = _allUsers.firstWhere((u) => u.uid == selectedUserId);
              final updatedManagers = List<String>.from(factory.managers)..add(selectedUserId!);
              
              final updatedFactory = FactoryModel(
                id: factory.id,
                name: factory.name,
                ownerId: factory.ownerId,
                ownerEmail: factory.ownerEmail,
                ownerName: factory.ownerName,
                managers: updatedManagers,
                createdAt: factory.createdAt,
              );

              try {
                await _provider.service.updateFactory(updatedFactory);
                
                final updatedUser = UserModel(
                  uid: user.uid,
                  email: user.email,
                  name: user.name,
                  role: user.role,
                  factoryId: user.factoryId,
                  factoryName: user.factoryName,
                  factories: user.factories,
                  managedFactories: [...user.managedFactories, factory.id],
                  canEndShift: user.canEndShift,
                  assignedPressId: user.assignedPressId,
                );
                await _provider.service.updateUser(updatedUser);
                
                await _loadData();
                Fluttertoast.showToast(
                  msg: '✅ تم إضافة ${user.name} كمدير للمصنع',
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
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeManager(FactoryModel factory, String managerId) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ تأكيد الإزالة'),
        content: Text('هل أنت متأكد من إزالة هذا المدير من المصنع؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              final updatedManagers = List<String>.from(factory.managers)..remove(managerId);
              
              final updatedFactory = FactoryModel(
                id: factory.id,
                name: factory.name,
                ownerId: factory.ownerId,
                ownerEmail: factory.ownerEmail,
                ownerName: factory.ownerName,
                managers: updatedManagers,
                createdAt: factory.createdAt,
              );

              try {
                await _provider.service.updateFactory(updatedFactory);
                
                final user = _allUsers.firstWhere((u) => u.uid == managerId);
                final updatedUser = UserModel(
                  uid: user.uid,
                  email: user.email,
                  name: user.name,
                  role: user.role,
                  factoryId: user.factoryId,
                  factoryName: user.factoryName,
                  factories: user.factories,
                  managedFactories: user.managedFactories.where((id) => id != factory.id).toList(),
                  canEndShift: user.canEndShift,
                  assignedPressId: user.assignedPressId,
                );
                await _provider.service.updateUser(updatedUser);
                
                await _loadData();
                Fluttertoast.showToast(
                  msg: '✅ تم إزالة المدير من المصنع',
                  backgroundColor: Colors.orange,
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
            child: const Text('إزالة', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteFactory(FactoryModel factory) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف المصنع "${factory.name}"؟\nسيتم حذف جميع البيانات المرتبطة به.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _provider.service.deleteFactory(factory.id);
                await _loadData();
                Fluttertoast.showToast(
                  msg: '✅ تم حذف المصنع: ${factory.name}',
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

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ShiftProvider>(context);
    
    if (!provider.isDeveloper) {
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
                'هذه الصفحة مخصصة للمطور فقط',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('🏭 إدارة المصانع - المطور'),
        backgroundColor: Colors.deepPurple,
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
          : Column(
              children: [
                Card(
                  color: Colors.deepPurple.shade50,
                  margin: const EdgeInsets.all(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.add_business, color: Colors.deepPurple),
                            SizedBox(width: 8),
                            Text(
                              '➕ إضافة مصنع جديد',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _newFactoryIdController,
                                decoration: const InputDecoration(
                                  labelText: '🆔 معرف المصنع',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  hintText: 'مثال: factory_riyadh',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _newFactoryNameController,
                                decoration: const InputDecoration(
                                  labelText: '🏷️ اسم المصنع',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  hintText: 'مثال: مصنع الرياض',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _selectedOwnerId,
                          decoration: const InputDecoration(
                            labelText: '👤 المالك',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: _allUsers.where((u) => u.isOwner).map((user) => 
                            DropdownMenuItem(
                              value: user.uid,
                              child: Text('${user.name} (${user.email})'),
                            )
                          ).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedOwnerId = value;
                            });
                          },
                        ),
                        // ✅ لو مفيش أي مستخدم بدور "مالك" لسه، نوضح ده صراحة بدل ما
                        // القائمة تفضل فاضية وتبان معطلة من غير أي تفسير
                        if (_allUsers.where((u) => u.isOwner).isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '⚠️ لا يوجد أي مستخدم بدور "مالك" حتى الآن. أضف مستخدماً بدور مالك أولاً من شاشة "إدارة المستخدمين"، أو لو المالك موجود بالفعل لمصنع تاني، متعملش له حساب جديد بنفس البريد — استخدمه هنا مباشرة.',
                              style: TextStyle(color: Colors.orange.shade800, fontSize: 12),
                            ),
                          ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _addFactory,
                            icon: const Icon(Icons.add),
                            label: const Text('إضافة مصنع', style: TextStyle(fontSize: 14)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
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
                              '📋 قائمة المصانع',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${_factories.length} مصنع',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: _factories.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.business, size: 64, color: Colors.grey.shade300),
                                      const SizedBox(height: 16),
                                      Text(
                                        'لا توجد مصانع',
                                        style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                                      ),
                                      Text(
                                        'أضف مصنعاً جديداً من الأعلى',
                                        style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _factories.length,
                                  itemBuilder: (context, index) {
                                    final factory = _factories[index];
                                    UserModel? owner;
                                    try {
                                      owner = _allUsers.firstWhere((u) => u.uid == factory.ownerId);
                                    } catch (e) {
                                      owner = null;
                                    }
                                    
                                    return Card(
                                      margin: const EdgeInsets.symmetric(vertical: 4),
                                      child: ExpansionTile(
                                        leading: CircleAvatar(
                                          backgroundColor: Colors.deepPurple,
                                          child: Text(
                                            '${index + 1}',
                                            style: const TextStyle(color: Colors.white, fontSize: 12),
                                          ),
                                        ),
                                        title: Text(
                                          factory.name,
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        subtitle: Text('🆔 ${factory.id}'),
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                _infoRow('👤 المالك', owner?.name ?? 'غير معروف'),
                                                _infoRow('📧 بريد المالك', owner?.email ?? 'غير معروف'),
                                                _infoRow('📅 تاريخ الإنشاء', DateFormat('yyyy-MM-dd').format(factory.createdAt)),
                                                const Divider(),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Text(
                                                      '🏗️ المديرين (${factory.managers.length})',
                                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                                    ),
                                                    ElevatedButton.icon(
                                                      onPressed: () => _addManagerToFactory(factory),
                                                      icon: const Icon(Icons.add, size: 14),
                                                      label: const Text('إضافة مدير', style: TextStyle(fontSize: 11)),
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: Colors.teal,
                                                        foregroundColor: Colors.white,
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                        minimumSize: const Size(0, 28),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                if (factory.managers.isEmpty)
                                                  const Text(
                                                    'لا يوجد مديرين',
                                                    style: TextStyle(color: Colors.grey, fontSize: 12),
                                                  )
                                                else
                                                  ...factory.managers.map((managerId) {
                                                    UserModel? manager;
                                                    try {
                                                      manager = _allUsers.firstWhere((u) => u.uid == managerId);
                                                    } catch (e) {
                                                      manager = null;
                                                    }
                                                    return ListTile(
                                                      dense: true,
                                                      contentPadding: EdgeInsets.zero,
                                                      leading: const Icon(Icons.person, size: 16),
                                                      title: Text(
                                                        manager?.name ?? 'غير معروف',
                                                        style: const TextStyle(fontSize: 13),
                                                      ),
                                                      subtitle: Text(
                                                        manager?.email ?? '',
                                                        style: const TextStyle(fontSize: 11),
                                                      ),
                                                      trailing: IconButton(
                                                        icon: const Icon(Icons.remove_circle, color: Colors.red, size: 18),
                                                        onPressed: () => _removeManager(factory, managerId),
                                                        padding: EdgeInsets.zero,
                                                        constraints: const BoxConstraints(),
                                                      ),
                                                    );
                                                  }),
                                                const SizedBox(height: 8),
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: ElevatedButton.icon(
                                                        onPressed: () => _deleteFactory(factory),
                                                        icon: const Icon(Icons.delete, size: 14),
                                                        label: const Text('حذف المصنع', style: TextStyle(fontSize: 12)),
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: Colors.red,
                                                          foregroundColor: Colors.white,
                                                          padding: const EdgeInsets.symmetric(vertical: 6),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
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
            ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}