
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models.dart';
import 'services.dart';

class AppPermissions {
  static const Map<String, String> moduleLabels = {
    'shift': 'الوردية ومراقبة الإنتاج',
    'panel': 'شاشة اللوحة',
    'correction': 'الكوريكشن',
    'solution': 'فرن الصلادة',
    'packaging': 'التغليف',
    'quality': 'الجودة',
    'store': 'المخزون',
    'planning': 'التخطيط',
  };

  static bool isAdmin(UserModel? user) => user != null && (user.isDeveloper || user.isOwner || user.isManager);

  static List<String> defaultModules(String? role, [String department = '']) {
    if (department.isNotEmpty) return [department];
    switch (role) {
      case 'supervisor':
        return const ['shift', 'panel'];
      case 'production_monitor':
        return const ['shift', 'panel', 'store'];
      case 'operator':
        return const ['shift', 'panel'];
      default:
        return const [];
    }
  }

  static bool canWrite(UserModel? user, String module) {
    if (user == null) return false;
    if (isAdmin(user)) return true;
    final mods = user.modules.isNotEmpty ? user.modules : defaultModules(user.role, user.department);
    return mods.contains(module);
  }
}

class PermissionsAdminScreen extends StatefulWidget {
  const PermissionsAdminScreen({super.key});
  @override
  State<PermissionsAdminScreen> createState() => _PermissionsAdminScreenState();
}

class _PermissionsAdminScreenState extends State<PermissionsAdminScreen> {
  final Map<String, List<String>> _selected = {};

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ShiftProvider>(context);
    final user = provider.currentUser;
    if (!AppPermissions.isAdmin(user)) {
      return const Scaffold(body: Center(child: Text('غير مصرح لك بإدارة الصلاحيات')));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('🛡️ صلاحيات المستخدمين')),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: provider.users.length,
        itemBuilder: (context, index) {
          final u = provider.users[index];
          final current = _selected.putIfAbsent(u.uid, () => u.modules.isNotEmpty ? List<String>.from(u.modules) : AppPermissions.defaultModules(u.role, u.department));
          return Card(
            child: ExpansionTile(
              leading: const Icon(Icons.person),
              title: Text('${u.name} - ${u.email}'),
              subtitle: Text('الدور: ${u.role} • القسم: ${u.department.isEmpty ? 'غير محدد' : u.department}'),
              children: [
                ...AppPermissions.moduleLabels.entries.map((e) => CheckboxListTile(
                      title: Text(e.value),
                      value: current.contains(e.key),
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          if (!current.contains(e.key)) current.add(e.key);
                        } else {
                          current.remove(e.key);
                        }
                      }),
                    )),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: FilledButton.icon(
                    onPressed: () async {
                      final updated = UserModel(
                        uid: u.uid,
                        email: u.email,
                        name: u.name,
                        role: u.role,
                        factoryId: u.factoryId,
                        factoryName: u.factoryName,
                        factories: u.factories,
                        managedFactories: u.managedFactories,
                        canEndShift: u.canEndShift,
                        assignedPressId: u.assignedPressId,
                        department: current.isEmpty ? u.department : current.first,
                        modules: List<String>.from(current),
                      );
                      await provider.service.updateUser(updated);
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الصلاحيات')));
                    },
                    icon: const Icon(Icons.save),
                    label: const Text('حفظ الصلاحيات'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
