import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'services.dart';
import 'login_screen.dart';
import 'admin_users_screen.dart';
import 'change_password_screen.dart';
import 'manage_presses_screen.dart';
import 'manage_factories_screen.dart';
import 'register_user_screen.dart';
import 'furnace_screen.dart';
import 'furnace_dies_screen.dart';
import 'production_monitoring_screen.dart';
import 'smart_install_button.dart';
import 'app_localization.dart';
import 'all_shifts_screen.dart';
import 'die_management_screen.dart';
import 'die_template_model.dart';
import 'pdf_viewer_screen.dart';
import 'material_stock_screen.dart';
import 'solution_and_packaging_screens.dart';
import 'solution_shipments_screens.dart';
import 'die_correction_screens.dart';
import 'packaging_qc_screens.dart';
import 'permissions.dart';
import 'planning_screen.dart';

// ============================================================
// ✅ دوال مساعدة للترحيب والتاريخ
// ============================================================

String getGreeting(BuildContext context, String name) {
  final hour = DateTime.now().hour;
  String greeting;

  if (hour >= 6 && hour < 12) {
    greeting = context.tr('greeting_morning');
  } else if (hour >= 12 && hour < 18) {
    greeting = context.tr('greeting_afternoon');
  } else {
    greeting = context.tr('greeting_evening');
  }

  return '$greeting $name';
}

String getFormattedDate() {
  final now = DateTime.now();
  final dateFormat = DateFormat('EEEE d MMMM y', 'ar');
  final timeFormat = DateFormat('h:mm a', 'ar');
  return '${dateFormat.format(now)}  ⏰ ${timeFormat.format(now)}';
}

// ============================================================
// 🏠 الشاشة الرئيسية
// ============================================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late ShiftProvider _provider;
  String? _selectedPressIdForNewShift;
  final TextEditingController _newSupervisorController = TextEditingController();
  final TextEditingController _newTechnicianController = TextEditingController();
  int _newShiftNumber = 1;
  String _selectedDefaultAlloy = '6063';

  List<FurnaceModel> _activeFurnaces = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _provider = Provider.of<ShiftProvider>(context, listen: false);
      _provider.loadAllData();
      _loadShiftNumber();
      _updateActiveFurnaces();
    });
  }

  void _updateActiveFurnaces() {
    setState(() {
      _activeFurnaces = _provider.furnaces.where((f) => f.isActive).toList();
    });
  }

  Future<void> _loadShiftNumber() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final number = prefs.getInt('shift_number') ?? 1;
      setState(() {
        _newShiftNumber = number;
      });
    } catch (e) {
      print(context.trP('shift_number_load_error', {'e': '$e'}));
    }
  }

  Future<void> _saveShiftNumber(int number) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('shift_number', number);
    } catch (e) {
      print(context.trP('shift_number_save_error', {'e': '$e'}));
    }
  }

  @override
  void dispose() {
    _newSupervisorController.dispose();
    _newTechnicianController.dispose();
    super.dispose();
  }

  String get _userEmail => FirebaseAuth.instance.currentUser?.email ?? context.tr('not_available');
  String get _userName => _provider.currentUser?.name ?? context.tr('user_word');
  String get _factoryDisplayName {
    final user = _provider.currentUser;
    if (user != null && user.factoryName.isNotEmpty) {
      return user.factoryName;
    }
    final factoryId = _provider.currentFactoryId;
    return factoryId.isNotEmpty ? factoryId : context.tr('factory_word');
  }

  void _logout() async {
    try {
      await _provider.service.signOut();
      Fluttertoast.showToast(msg: context.tr('logout_success'), backgroundColor: Colors.green, textColor: Colors.white);
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
      }
    } catch (e) {
      Fluttertoast.showToast(msg: context.trP('logout_error', {'e': '$e'}), backgroundColor: Colors.red, textColor: Colors.white);
    }
  }

  void _showOwnerFactories() {
    final provider = Provider.of<ShiftProvider>(context, listen: false);

    List<FactoryModel> availableFactories = [];

    if (provider.isDeveloper) {
      availableFactories = provider.ownerFactories;
    } else if (provider.isOwner) {
      availableFactories = provider.ownerFactories;
    } else if (provider.isManager) {
      availableFactories = provider.managerFactories;
    } else {
      Fluttertoast.showToast(msg: context.tr('no_permission_switch_factory'), backgroundColor: Colors.orange, textColor: Colors.white);
      return;
    }

    if (availableFactories.isEmpty) {
      Fluttertoast.showToast(msg: context.tr('no_factories_available'), backgroundColor: Colors.orange, textColor: Colors.white);
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.tr('switch_factory_title'), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const Divider(),
            ...availableFactories.map((factory) => ListTile(
              leading: CircleAvatar(
                backgroundColor: factory.id == provider.currentFactoryId ? Colors.green : Colors.blue,
                child: Text(
                  factory.id == provider.currentFactoryId ? '✓' : '${availableFactories.indexOf(factory) + 1}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text(factory.name),
              subtitle: Text('🆔 ${factory.id}'),
              trailing: factory.id == provider.currentFactoryId
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.pop(context);
                if (factory.id != provider.currentFactoryId) {
                  provider.switchFactory(factory.id);
                }
              },
            )),
            const SizedBox(height: 8),
            TextButton(onPressed: () => Navigator.pop(context), child: Text(context.tr('cancel'))),
          ],
        ),
      ),
    );
  }

  void _openAllShiftsScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AllShiftsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    _provider = Provider.of<ShiftProvider>(context);
    final user = _provider.currentUser;
    final canShift = AppPermissions.canWrite(user, 'shift');
    final canPanel = AppPermissions.canWrite(user, 'panel');
    final canCorrection = AppPermissions.canWrite(user, 'correction');
    final canSolution = AppPermissions.canWrite(user, 'solution');
    final canPackaging = AppPermissions.canWrite(user, 'packaging');
    final canQuality = AppPermissions.canWrite(user, 'quality');
    final canStore = AppPermissions.canWrite(user, 'store');
    final canPlanning = AppPermissions.canWrite(user, 'planning');
    final isPermissionsAdmin = AppPermissions.isAdmin(user);
    final bool isOwner = user?.isOwner ?? false;
    final bool isDeveloper = user?.isDeveloper ?? false;
    final bool isManager = user?.isManager ?? false;
    final bool isSupervisor = user?.isSupervisor ?? false;
    final bool canStartShift = (isSupervisor || isDeveloper || isOwner || isManager);
    final bool canSeeFactorySwitch = (isDeveloper || isOwner || isManager);

    _activeFurnaces = _provider.furnaces.where((f) => f.isActive).toList();
    final activePresses = _provider.getActivePresses();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('app_title_bar')),
        backgroundColor: Colors.blue,
        elevation: 2,
        actions: [
          const LanguageToggleButton(compact: true),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_userEmail, style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                Text('🏭 $_factoryDisplayName', style: TextStyle(fontSize: 9, color: Colors.white.withOpacity(0.8))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (canSeeFactorySwitch)
            IconButton(
              icon: const Icon(Icons.swap_horiz, color: Colors.white),
              onPressed: _showOwnerFactories,
              tooltip: context.tr('switch_factory'),
            ),
          IconButton(icon: const Icon(Icons.password, color: Colors.white), onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const ChangePasswordScreen()));
          }, tooltip: context.tr('change_password')),
          IconButton(icon: const Icon(Icons.logout, color: Colors.white), onPressed: _logout, tooltip: context.tr('logout')),
          if (isDeveloper)
            IconButton(
              icon: const Icon(Icons.developer_mode, color: Colors.amber),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const DeveloperLockScreen()));
              },
              tooltip: context.tr('dev_panel_title'),
            ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => _provider.loadAllData(), tooltip: context.tr('refresh_plain')),
        ],
      ),
      body: _provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.person, color: Colors.blue),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  getGreeting(context, _userName),
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            getFormattedDate(),
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      const SmartInstallButton(),
                      ElevatedButton.icon(
                        onPressed: _openAllShiftsScreen,
                        icon: const Icon(Icons.history, size: 20),
                        label: Text(context.tr('all_shifts_title'), style: TextStyle(fontSize: 14)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => MaterialStockScreen()),
                          ).then((_) => _provider.loadAllData());
                        },
                        icon: const Icon(Icons.inventory, size: 20),
                        label: Text(context.tr('material_stock_title'), style: TextStyle(fontSize: 14)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const RegisterUserScreen()),
                          );
                        },
                        icon: const Icon(Icons.person_add, size: 20),
                        label: Text(context.tr('register_user_menu'), style: TextStyle(fontSize: 14)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      if (canSolution)
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const SolutionShipmentsScreen()),
                          );
                        },
                        icon: const Icon(Icons.heat_pump, size: 20),
                        label: const Text('🧪 فرن الصلادة', style: TextStyle(fontSize: 14)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepOrange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      if (canPackaging)
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const PackagingOrdersHomeScreen()),
                          );
                        },
                        icon: const Icon(Icons.inventory_2, size: 20),
                        label: const Text('📦 قسم التغليف', style: TextStyle(fontSize: 14)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      if (canCorrection)
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const DieCorrectionScreen()),
                          );
                        },
                        icon: const Icon(Icons.build, size: 20),
                        label: const Text('🔧 الكوريكشن', style: TextStyle(fontSize: 14)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.brown,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      if (canQuality)
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const QualityControlScreen()),
                          );
                        },
                        icon: const Icon(Icons.fact_check, size: 20),
                        label: const Text('🧪 الجودة', style: TextStyle(fontSize: 14)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      if (canPlanning)
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const PlanningOrdersScreen()),
                          );
                        },
                        icon: const Icon(Icons.assignment, size: 20),
                        label: const Text('🗂️ التخطيط', style: TextStyle(fontSize: 14)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      if (isPermissionsAdmin)
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const PermissionsAdminScreen()),
                          );
                        },
                        icon: const Icon(Icons.admin_panel_settings, size: 20),
                        label: const Text('🛡️ الصلاحيات', style: TextStyle(fontSize: 14)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black87,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const FurnaceScreen()),
                          );
                        },
                        icon: const Icon(Icons.fireplace, size: 20),
                        label: Text(context.tr('manage_furnaces_menu'), style: TextStyle(fontSize: 14)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const ProductionMonitoringScreen()),
                          );
                        },
                        icon: const Icon(Icons.insights, size: 20),
                        label: Text(context.tr('production_monitoring_menu'), style: TextStyle(fontSize: 14)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      if (canStartShift && _provider.getInactivePresses().isNotEmpty)
                        ElevatedButton.icon(
                          onPressed: _showStartShiftDialog,
                          icon: const Icon(Icons.add_circle, size: 20),
                          label: Text(context.tr('start_shift_menu'), style: TextStyle(fontSize: 14)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  if (_activeFurnaces.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(context.tr('active_furnaces_title'),
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            context.trP('furnace_count', {'n': '${_activeFurnaces.length}'}),
                            style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._activeFurnaces.map((furnace) => _buildFurnaceCard(furnace)),
                    const SizedBox(height: 12),
                  ],

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(context.tr('active_presses_title'),
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          context.trP('press_count', {'n': '${activePresses.length}'}),
                          style: TextStyle(color: Colors.green.shade700, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (activePresses.isEmpty)
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox, size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 8),
                          Text(
                            context.tr('no_active_presses'),
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                          ),
                          if (canStartShift && _provider.getInactivePresses().isNotEmpty)
                            Text(
                              context.tr('tap_start_shift_hint'),
                              style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                            ),
                        ],
                      ),
                    )
                  else
                    ...activePresses.map((press) {
                      final shift = _provider.getShiftForPress(press.id);
                      if (shift == null) return const SizedBox.shrink();

                      final efficiency = shift.getEfficiency(press.targetTonsPerHour);
                      final efficiencyColor = _provider.getEfficiencyColor(efficiency);
                      final efficiencyEmoji = _provider.getEfficiencyEmoji(efficiency);

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PressDetailScreen(shiftId: shift.id),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: Colors.green,
                                      radius: 18,
                                      child: Text(
                                        press.diameterInInches.toStringAsFixed(1),
                                        style: const TextStyle(color: Colors.white, fontSize: 12),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                press.name,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.green,
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(context.tr('active_status'),
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            context.trP('supervisor_label', {'name': '${shift.supervisor}'}),
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                          Text(
                                            context.trP('technician_label', {'name': '${shift.technician}'}),
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                          Text(
                                            context.trP('dies_billets_label', {'d': '${shift.totalDies}', 'b': '${shift.totalBillets}'}),
                                            style: const TextStyle(fontSize: 11),
                                          ),
                                          Row(
                                            children: [
                                              Text(context.tr('efficiency_label'), style: const TextStyle(fontSize: 11)),
                                              Text(
                                                '${efficiency.toStringAsFixed(1)}% $efficiencyEmoji',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: efficiencyColor,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.blue),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),

                  const SizedBox(height: 12),
                ],
              ),
            ),
    );
  }

  Widget _buildFurnaceCard(FurnaceModel furnace) {
    final furnaceDies = _provider.allShifts
        .expand((shift) => shift.dies)
        .where((die) => die.furnaceId == furnace.id && !die.isFurnaceReady)
        .toList();

    final readyDies = furnaceDies.where((die) => die.isReady(furnace)).length;
    final totalDies = furnaceDies.length;

    Color statusColor;
    String statusText;
    String statusIcon;

    switch (furnace.status) {
      case FurnaceStatus.idle:
        statusColor = Colors.grey;
        statusText = context.tr('idle_status');
        statusIcon = '🟤';
        break;
      case FurnaceStatus.heating:
        statusColor = Colors.orange;
        statusText = context.tr('heating_status');
        statusIcon = '🟠';
        break;
      case FurnaceStatus.holding:
        statusColor = Colors.green;
        statusText = context.tr('stabilizing_status');
        statusIcon = '🟢';
        break;
      case FurnaceStatus.cooling:
        statusColor = Colors.blue;
        statusText = context.tr('cooling_status');
        statusIcon = '🔵';
        break;
      case FurnaceStatus.error:
        statusColor = Colors.red;
        statusText = context.tr('error_word');
        statusIcon = '🔴';
        break;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FurnaceDiesScreen(
                pressId: furnace.pressId,
                pressName: furnace.pressName,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: statusColor,
                    radius: 16,
                    child: Text(
                      furnace.pressName.replaceAll(context.tr('press_word'), '').trim().substring(0, 1),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          furnace.name,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '📏 ${furnace.pressName}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      '$statusIcon $statusText',
                      style: TextStyle(fontSize: 12, color: statusColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildFurnaceStat('🎯 ${furnace.targetTemperature}°C', context.tr('target_word')),
                  _buildFurnaceStat('🌡️ ${furnace.currentTemperature}°C', context.tr('current_word')),
                  _buildFurnaceStat(context.trP('hollow_time', {'v': '${furnace.hollowHeatingTime}'}), context.tr('hollow_word')),
                  _buildFurnaceStat(context.trP('solid_time', {'v': '${furnace.solidHeatingTime}'}), context.tr('solid_word')),
                ],
              ),
              const Divider(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.inventory, size: 16, color: Colors.blue),
                      const SizedBox(width: 4),
                      Text(
                        context.trP('dies_total', {'n': '$totalDies'}),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.check_circle, size: 16, color: Colors.green),
                      const SizedBox(width: 4),
                      Text(
                        context.trP('dies_ready', {'n': '$readyDies'}),
                        style: TextStyle(fontSize: 12, color: Colors.green),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.timer, size: 16, color: Colors.orange),
                      const SizedBox(width: 4),
                      Text(
                        context.trP('dies_heating', {'n': '${totalDies - readyDies}'}),
                        style: TextStyle(fontSize: 12, color: Colors.orange),
                      ),
                    ],
                  ),
                ],
              ),
              if (furnace.currentCycle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    context.trP('cycle_duration', {'v': '${furnace.currentCycle!.durationFormatted}'}),
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFurnaceStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }

  void _showStartShiftDialog() {
    final user = _provider.currentUser;
    if (user == null) return;

    if (!user.isSupervisor && !user.isDeveloper && !user.isOwner && !user.isManager) {
      Fluttertoast.showToast(
        msg: context.tr('no_permission_start_shift'),
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
      return;
    }

    final inactivePresses = _provider.getInactivePresses();

    if (inactivePresses.isEmpty) {
      Fluttertoast.showToast(
        msg: context.tr('no_presses_available_busy'),
        backgroundColor: Colors.orange,
        textColor: Colors.white,
        toastLength: Toast.LENGTH_LONG,
      );

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.tr('no_presses_available')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox, size: 48, color: Colors.orange),
              SizedBox(height: 8),
              Text(context.tr('all_presses_busy')),
              Text(context.tr('wait_for_shift_to_end')),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.tr('cancel')),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _provider.loadAllData();
                _showStartShiftDialog();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: Text(context.tr('refresh')),
            ),
          ],
        ),
      );
      return;
    }

    List<PressModel> availablePresses;
    if (user.isDeveloper || user.isOwner || user.isManager) {
      availablePresses = inactivePresses;
    } else if (user.assignedPressId != null && user.assignedPressId!.isNotEmpty) {
      final assignedPress = _provider.getPressById(user.assignedPressId!);
      if (assignedPress != null && inactivePresses.contains(assignedPress)) {
        availablePresses = [assignedPress];
      } else {
        availablePresses = [];
      }
    } else {
      availablePresses = inactivePresses;
    }

    if (availablePresses.isEmpty) {
      Fluttertoast.showToast(
        msg: context.tr('no_presses_for_permissions'),
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
      return;
    }

    if (_selectedPressIdForNewShift == null ||
        !availablePresses.any((p) => p.id == _selectedPressIdForNewShift)) {
      _selectedPressIdForNewShift = availablePresses.first.id;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('start_new_shift_title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.tr('choose_press_enter_data')),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedPressIdForNewShift,
              decoration: InputDecoration(
                labelText: context.tr('press_label_short'),
                border: OutlineInputBorder(),
              ),
              items: availablePresses.map((press) =>
                DropdownMenuItem(
                  value: press.id,
                  child: Text(press.name),
                )
              ).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedPressIdForNewShift = value;
                  });
                }
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _newSupervisorController,
              decoration: InputDecoration(
                labelText: context.tr('supervisor_name_label'),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _newTechnicianController,
              decoration: InputDecoration(
                labelText: context.tr('technician_name_label'),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedDefaultAlloy,
              decoration: InputDecoration(
                labelText: '🔧 السبيكة الافتراضية',
                border: OutlineInputBorder(),
              ),
              items: AlloyModel.getAlloyNames().map((alloy) =>
                DropdownMenuItem(
                  value: alloy,
                  child: Text(alloy),
                )
              ).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedDefaultAlloy = value);
                }
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: '$_newShiftNumber',
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: context.tr('shift_number_label'),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                final num = int.tryParse(value);
                if (num != null) {
                  setState(() {
                    _newShiftNumber = num;
                  });
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _newSupervisorController.clear();
              _newTechnicianController.clear();
              Navigator.pop(context);
            },
            child: Text(context.tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_newSupervisorController.text.isEmpty || _newTechnicianController.text.isEmpty) {
                Fluttertoast.showToast(
                  msg: context.tr('enter_supervisor_technician'),
                  backgroundColor: Colors.orange,
                  textColor: Colors.white,
                );
                return;
              }

              if (_selectedPressIdForNewShift == null) {
                Fluttertoast.showToast(
                  msg: context.tr('please_choose_press'),
                  backgroundColor: Colors.orange,
                  textColor: Colors.white,
                );
                return;
              }

              Navigator.pop(context);
              await _provider.startNewShift(
                supervisor: _newSupervisorController.text,
                technician: _newTechnicianController.text,
                pressId: _selectedPressIdForNewShift!,
                shiftNumber: _newShiftNumber,
              );

              _newSupervisorController.clear();
              _newTechnicianController.clear();
              _newShiftNumber++;
              _saveShiftNumber(_newShiftNumber);

              final newShift = _provider.currentShift;
              if (newShift != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PressDetailScreen(shiftId: newShift.id),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text(context.tr('start_shift_button')),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 🔐 شاشة قفل المطور
// ============================================================
class DeveloperLockScreen extends StatefulWidget {
  const DeveloperLockScreen({super.key});

  static DateTime? lastSuccessfulLogin;
  static const Duration sessionDuration = Duration(minutes: 1);

  @override
  State<DeveloperLockScreen> createState() => _DeveloperLockScreenState();
}

class _DeveloperLockScreenState extends State<DeveloperLockScreen> {
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  final String _correctPassword = '1231900';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (DeveloperLockScreen.lastSuccessfulLogin != null) {
        final elapsed = DateTime.now().difference(DeveloperLockScreen.lastSuccessfulLogin!);
        if (elapsed < DeveloperLockScreen.sessionDuration) {
          final provider = Provider.of<ShiftProvider>(context, listen: false);
          await provider.loadAllData();
          final user = provider.currentUser;

          if (user != null && user.isDeveloper) {
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const DeveloperScreen()),
              );
            }
            return;
          }
        } else {
          DeveloperLockScreen.lastSuccessfulLogin = null;
        }
      }

      final provider = Provider.of<ShiftProvider>(context, listen: false);
      await provider.loadAllData();
      final user = provider.currentUser;

      if (user != null && user.isDeveloper) {
        Fluttertoast.showToast(
          msg: context.tr('dev_password_prompt'),
          backgroundColor: Colors.deepPurple,
          textColor: Colors.white,
        );
      }
    });
  }

  void _verifyPassword() async {
    if (_passwordController.text.isEmpty) {
      Fluttertoast.showToast(
        msg: context.tr('enter_password_warning'),
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final provider = Provider.of<ShiftProvider>(context, listen: false);
      await provider.loadAllData();
      final user = provider.currentUser;

      if (user == null) {
        Fluttertoast.showToast(
          msg: context.tr('please_login_first'),
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        setState(() => _isLoading = false);
        return;
      }

      if (_passwordController.text != _correctPassword) {
        Fluttertoast.showToast(
          msg: context.tr('wrong_password_dev'),
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        setState(() => _isLoading = false);
        return;
      }

      DeveloperLockScreen.lastSuccessfulLogin = DateTime.now();

      if (user.isDeveloper) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const DeveloperScreen()),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final updatedUser = UserModel(
        uid: user.uid,
        email: user.email,
        name: user.name,
        role: 'developer',
        factoryId: user.factoryId,
        factoryName: user.factoryName,
        factories: user.factories,
        managedFactories: user.managedFactories,
        canEndShift: user.canEndShift,
        assignedPressId: user.assignedPressId,
      );
      await provider.updateUser(updatedUser);
      await provider.loadAllData();

      Fluttertoast.showToast(
        msg: context.tr('upgraded_to_developer'),
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DeveloperScreen()),
        );
      }
      setState(() => _isLoading = false);

    } catch (e) {
      Fluttertoast.showToast(
        msg: context.trP('generic_error', {'e': '$e'}),
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      setState(() => _isLoading = false);
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
            colors: [Colors.deepPurple.shade700, Colors.deepPurple.shade300],
          ),
        ),
        child: Center(
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
                  const Icon(Icons.lock_outline, size: 64, color: Colors.deepPurple),
                  const SizedBox(height: 16),
                  Text(context.tr('dev_panel_title'),
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                  Text(context.tr('enter_password_to_login'), style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(context.tr('dev_name'),
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: context.tr('password_word'),
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
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _isLoading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(context.tr('login_word'), style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(onPressed: () => Navigator.pop(context), child: Text(context.tr('back_word'))),
                  const SizedBox(height: 4),
                  Text(
                    context.tr('session_duration_hint'),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// 👨‍💻 شاشة المطور
// ============================================================
class DeveloperScreen extends StatefulWidget {
  const DeveloperScreen({super.key});

  @override
  State<DeveloperScreen> createState() => _DeveloperScreenState();
}

class _DeveloperScreenState extends State<DeveloperScreen> {
  late ShiftProvider _provider;
  bool _isLoadingTargets = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _provider = Provider.of<ShiftProvider>(context, listen: false);
      _provider.loadAllData();
    });
  }

  void _logout() async {
    try {
      DeveloperLockScreen.lastSuccessfulLogin = null;
      await _provider.service.signOut();
      Fluttertoast.showToast(msg: context.tr('logout_success'), backgroundColor: Colors.green, textColor: Colors.white);
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
      }
    } catch (e) {
      Fluttertoast.showToast(msg: context.trP('logout_error', {'e': '$e'}), backgroundColor: Colors.red, textColor: Colors.white);
    }
  }

  Future<void> _updateTargetTons(String pressId, double newValue) async {
    setState(() => _isLoadingTargets = true);
    try {
      final press = _provider.presses.firstWhere((p) => p.id == pressId);
      final updatedPress = PressModel(
        id: press.id,
        name: press.name,
        size: press.size,
        diameterInInches: press.diameterInInches,
        isActive: press.isActive,
        targetTonsPerHour: newValue,
        targetWastePercentage: press.targetWastePercentage,
      );
      await _provider.service.savePress(_provider.currentFactoryId, updatedPress);
      await _provider.loadAllData();
      Fluttertoast.showToast(
        msg: context.trP('target_tons_updated', {'name': '${press.name}'}),
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: context.trP('generic_error', {'e': '$e'}),
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      setState(() => _isLoadingTargets = false);
    }
  }

  Future<void> _updateTargetWaste(String pressId, double newValue) async {
    setState(() => _isLoadingTargets = true);
    try {
      final press = _provider.presses.firstWhere((p) => p.id == pressId);
      final updatedPress = PressModel(
        id: press.id,
        name: press.name,
        size: press.size,
        diameterInInches: press.diameterInInches,
        isActive: press.isActive,
        targetTonsPerHour: press.targetTonsPerHour,
        targetWastePercentage: newValue,
      );
      await _provider.service.savePress(_provider.currentFactoryId, updatedPress);
      await _provider.loadAllData();
      Fluttertoast.showToast(
        msg: context.trP('waste_pct_updated', {'name': '${press.name}', 'val': '${newValue.toStringAsFixed(1)}'}),
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: context.trP('generic_error', {'e': '$e'}),
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      setState(() => _isLoadingTargets = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ShiftProvider>(context);
    final user = provider.currentUser;
    final isDeveloper = user?.isDeveloper ?? false;

    if (isDeveloper) {
      return Scaffold(
        appBar: AppBar(
          title: Text(context.tr('dev_panel_subtitle')),
          backgroundColor: Colors.deepPurple,
          elevation: 4,
          actions: [
            IconButton(
              icon: const Icon(Icons.admin_panel_settings),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminUsersScreen()));
              },
              tooltip: context.tr('manage_users_menu'),
            ),
            IconButton(
              icon: const Icon(Icons.business, color: Colors.white),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageFactoriesScreen()));
              },
              tooltip: context.tr('manage_factories_menu'),
            ),
            IconButton(
              icon: const Icon(Icons.precision_manufacturing, color: Colors.white),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const ManagePressesScreen()));
              },
              tooltip: context.tr('manage_presses_title'),
            ),
            IconButton(
              icon: const Icon(Icons.inventory, color: Colors.white),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => MaterialStockScreen()));
              },
              tooltip: context.tr('material_stock_title'),
            ),
            IconButton(icon: const Icon(Icons.refresh), onPressed: () => provider.loadAllData()),
            IconButton(icon: const Icon(Icons.password, color: Colors.white), onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const ChangePasswordScreen()));
            }, tooltip: context.tr('change_password')),
            IconButton(icon: const Icon(Icons.home, color: Colors.white), onPressed: () {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen()));
            }, tooltip: context.tr('home_word')),
            IconButton(icon: const Icon(Icons.logout, color: Colors.white), onPressed: _logout, tooltip: context.tr('logout')),
          ],
        ),
        body: provider.isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        color: Colors.deepPurple.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.developer_mode, color: Colors.deepPurple, size: 32),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(context.tr('welcome_dev_panel'),
                                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(8)),
                                child: Row(
                                  children: [
                                    const Icon(Icons.person, color: Colors.amber),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: SelectableText(context.tr('developer_label'),
                                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.amber.shade800)),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                                child: Row(
                                  children: [
                                    Icon(Icons.info, color: Colors.green, size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: SelectableText(context.tr('grant_end_shift_permission_hint'),
                                          style: TextStyle(fontSize: 12, color: Colors.green)),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: Colors.deepPurple.shade100, borderRadius: BorderRadius.circular(8)),
                                child: Text(context.trP('your_role', {'role': '${user?.role ?? context.tr("not_specified")}'}),
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple.shade800)),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      Card(
                        color: Colors.blue.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.speed, color: Colors.blue),
                                  const SizedBox(width: 8),
                                  Text(context.tr('edit_target_tonnage_title'),
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(context.tr('edit_target_tonnage_hint'),
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              const SizedBox(height: 12),
                              if (_isLoadingTargets)
                                const Center(child: CircularProgressIndicator())
                              else
                                ...provider.presses.map((press) {
                                  final controller = TextEditingController(
                                    text: press.targetTonsPerHour.toStringAsFixed(3),
                                  );

                                  return Card(
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    child: Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: Colors.blue,
                                            radius: 16,
                                            child: Text(
                                              press.diameterInInches.toStringAsFixed(1),
                                              style: const TextStyle(color: Colors.white, fontSize: 12),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  press.name,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                ),
                                                Text(
                                                  context.trP('press_size_label', {'size': press.sizeLabel}),
                                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          SizedBox(
                                            width: 80,
                                            child: TextFormField(
                                              controller: controller,
                                              keyboardType: TextInputType.number,
                                              decoration: InputDecoration(
                                                labelText: context.tr('tons_per_hour'),
                                                border: OutlineInputBorder(),
                                                isDense: true,
                                              ),
                                              style: const TextStyle(fontSize: 13),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.save, color: Colors.blue),
                                            onPressed: () {
                                              final value = double.tryParse(controller.text);
                                              if (value != null && value > 0) {
                                                _updateTargetTons(press.id, value);
                                              } else {
                                                Fluttertoast.showToast(
                                                  msg: context.tr('enter_valid_value'),
                                                  backgroundColor: Colors.orange,
                                                  textColor: Colors.white,
                                                );
                                              }
                                            },
                                            tooltip: context.tr('save_word'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      Card(
                        color: Colors.teal.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.timer_off, color: Colors.teal),
                                  const SizedBox(width: 8),
                                  Text(context.tr('edit_waste_pct_title'),
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(context.tr('waste_pct_hint'),
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              const SizedBox(height: 12),
                              if (_isLoadingTargets)
                                const Center(child: CircularProgressIndicator())
                              else
                                ...provider.presses.map((press) {
                                  final controller = TextEditingController(
                                    text: press.targetWastePercentage.toStringAsFixed(1),
                                  );

                                  return Card(
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    child: Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: Colors.teal,
                                            radius: 16,
                                            child: Text(
                                              press.diameterInInches.toStringAsFixed(1),
                                              style: const TextStyle(color: Colors.white, fontSize: 12),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  press.name,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                ),
                                                Text(
                                                  context.trP('press_size_label', {'size': press.sizeLabel}),
                                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          SizedBox(
                                            width: 80,
                                            child: TextFormField(
                                              controller: controller,
                                              keyboardType: TextInputType.number,
                                              decoration: InputDecoration(
                                                labelText: context.tr('percent_word'),
                                                border: OutlineInputBorder(),
                                                isDense: true,
                                              ),
                                              style: const TextStyle(fontSize: 13),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.save, color: Colors.teal),
                                            onPressed: () {
                                              final value = double.tryParse(controller.text);
                                              if (value != null && value >= 0 && value <= 100) {
                                                _updateTargetWaste(press.id, value);
                                              } else {
                                                Fluttertoast.showToast(
                                                  msg: context.tr('enter_value_0_100'),
                                                  backgroundColor: Colors.orange,
                                                  textColor: Colors.white,
                                                );
                                              }
                                            },
                                            tooltip: context.tr('save_percentage'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      Card(
                        color: Colors.blue.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.factory, color: Colors.blue),
                                  const SizedBox(width: 8),
                                  Text(context.tr('current_factory_label'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.blue.shade300),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: SelectableText(
                                        provider.currentFactoryId.isNotEmpty ? provider.currentFactoryId : context.tr('no_factory'),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blue),
                                      onPressed: () => _showSwitchFactoryDialog(context, provider),
                                    ),
                                  ],
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
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildQuickStat(context.tr('users_word'), '${provider.users.length}', Icons.people, Colors.blue),
                              _buildQuickStat(context.tr('supervisors_word'), '${provider.users.where((u) => u.role == 'supervisor').length}', Icons.person, Colors.green),
                              _buildQuickStat(context.tr('have_permission'), '${provider.users.where((u) => u.canEndShift).length}', Icons.lock_open, Colors.orange),
                              _buildQuickStat(context.tr('owners_word'), '${provider.users.where((u) => u.isOwner).length}', Icons.business, Colors.purple),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminUsersScreen()));
                          },
                          icon: const Icon(Icons.admin_panel_settings),
                          label: Text(context.tr('manage_users_permissions_title')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageFactoriesScreen()));
                          },
                          icon: const Icon(Icons.business),
                          label: Text(context.tr('manage_factories_title')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const ManagePressesScreen()));
                          },
                          icon: const Icon(Icons.precision_manufacturing),
                          label: Text(context.tr('manage_presses_title')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const DieManagementScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.inventory),
                          label: Text('🔧 إدارة القوالب المسجلة'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const FurnaceScreen()),
                            );
                          },
                          icon: const Icon(Icons.fireplace),
                          label: Text(context.tr('manage_furnaces_menu')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => MaterialStockScreen()),
                            );
                          },
                          icon: const Icon(Icons.inventory, color: Colors.white),
                          label: Text(context.tr('material_stock_title')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen()));
                          },
                          icon: const Icon(Icons.home),
                          label: Text(context.tr('back_to_home')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('not_authorized')),
        backgroundColor: Colors.red,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(context.tr('no_permission_page'), style: TextStyle(fontSize: 18, color: Colors.red)),
              Text(context.tr('dev_only_page'), style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout),
                  label: Text(context.tr('logout'), style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen()));
                },
                child: Text(context.tr('back_to_home_page')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSwitchFactoryDialog(BuildContext context, ShiftProvider provider) {
    final TextEditingController controller = TextEditingController(text: provider.currentFactoryId);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('switch_factory_title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.tr('enter_new_factory_name')),
            const SizedBox(height: 8),
            TextFormField(
              controller: controller,
              decoration: InputDecoration(border: OutlineInputBorder(), hintText: context.tr('factory_name_label')),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(context.tr('cancel'))),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                Navigator.pop(context);
                await provider.switchFactory(controller.text);
              } else {
                Fluttertoast.showToast(msg: context.tr('enter_factory_name_warning'), backgroundColor: Colors.orange, textColor: Colors.white);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
            child: Text(context.tr('switch_word')),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}

// ============================================================
// 📊 شاشة تفاصيل المكبس (مع ربط الفرن والبحث الذكي عن القوالب)
// ============================================================
class PressDetailScreen extends StatefulWidget {
  final String shiftId;

  const PressDetailScreen({super.key, required this.shiftId});

  @override
  State<PressDetailScreen> createState() => _PressDetailScreenState();
}

// ============================================================
// _PressDetailScreenState - مع إصلاح مشكلة تعديل وقت الخروج
// ============================================================
class _PressDetailScreenState extends State<PressDetailScreen> {
  late ShiftProvider _provider;
  ShiftModel? _shift;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isCheckingFurnace = false;

  final TextEditingController _dieCodeController = TextEditingController();
  final TextEditingController _clientCodeController = TextEditingController();
  final TextEditingController _designCodeController = TextEditingController();

  final TextEditingController _versionController = TextEditingController();
  String _fullDieCode = '';

  DieTemplate? _foundDie;
  List<DieTemplate> _foundVersions = [];
  bool _isSearching = false;
  Timer? _searchTimer;
  static const Duration _searchDelay = Duration(milliseconds: 400);

  final TextEditingController _holesController = TextEditingController();
  final TextEditingController _billetLengthController = TextEditingController();
  final TextEditingController _temperatureController = TextEditingController();
  final TextEditingController _ramSpeedController = TextEditingController();
  final TextEditingController _billetCountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  String _selectedAlloy = '6063';

  final TextEditingController _pieceLengthController = TextEditingController();
  final TextEditingController _tableLengthController = TextEditingController();

  DieModel? _matchedFurnaceDie;
  FurnaceModel? _matchedFurnace;

  DateTime _entryTime = DateTime.now();
  DateTime _exitTime = DateTime.now();

  Timer? _exitTimeTimer;

  final TextEditingController _wasteMinutesController = TextEditingController();
  final TextEditingController _wasteReasonController = TextEditingController();
  bool _isAddingWaste = false;

  final TextEditingController _updateBilletCountController = TextEditingController();
  final TextEditingController _updateBilletLengthController = TextEditingController();

  Timer? _debounceTimer;
  static const Duration _debounceDuration = Duration(milliseconds: 500);

  DieModel? _currentDraftDie;

  // ✅ دالة لإعادة حساب جميع القيم عند تغيير وقت الخروج
  void _recalculateDieValues() {
    final newDuration = _exitTime.difference(_entryTime).inMinutes;
    
    final length = double.tryParse(_billetLengthController.text) ?? 0;
    final count = int.tryParse(_billetCountController.text) ?? 0;
    
    if (length > 0 && count > 0 && _shift != null) {
      final weight = DieModel.calculateWeight(
        pressId: _shift!.pressId,
        billetLength: length,
        billetCount: count,
      );
      final weightInTons = weight / 1000;
      final hours = newDuration / 60;
      
      double newProductivity = 0.0;
      if (hours > 0) {
        newProductivity = weightInTons / hours;
      }
      
      final press = _provider.getPressById(_shift!.pressId);
      if (press != null && press.targetTonsPerHour > 0) {
        final newEfficiency = (newProductivity / press.targetTonsPerHour) * 100;
        print('✅✅✅ وقت الخروج الجديد: ${DateFormat('HH:mm:ss').format(_exitTime)}');
        print('✅✅✅ المدة الجديدة: $newDuration دقيقة');
        print('✅✅✅ الإنتاجية الجديدة: $newProductivity طن/ساعة');
        print('✅✅✅ كفاءة الإنتاج الجديدة: $newEfficiency%');
      }
    }
    
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _provider = Provider.of<ShiftProvider>(context, listen: false);
      _loadShift();
    });

    _exitTimeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _exitTime = DateTime.now();
        });
      }
    });

    _billetLengthController.addListener(_onFieldChanged);
    _billetCountController.addListener(_onFieldChanged);
    _holesController.addListener(_onFieldChanged);
    _temperatureController.addListener(_onFieldChanged);
    _ramSpeedController.addListener(_onFieldChanged);
    _notesController.addListener(_onFieldChanged);

    _dieCodeController.addListener(_onCodeFieldChanged);
    _clientCodeController.addListener(_onCodeFieldChanged);
    _designCodeController.addListener(_onCodeFieldChanged);

    _versionController.addListener(() {
      _updateFullDieCode();
    });

    _dieCodeController.addListener(() {
      _onCodeSearch(_dieCodeController.text);
    });
    _clientCodeController.addListener(() {
      _onCodeSearch(_clientCodeController.text);
    });
    _designCodeController.addListener(() {
      _onCodeSearch(_designCodeController.text);
    });
  }

  void _onFieldChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      _syncDraftDie();
    });
  }

  void _onCodeFieldChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      _syncDraftDie();
    });
  }

  void _updateFullDieCode() {
    final baseCode = _dieCodeController.text.trim();
    final version = _versionController.text.trim();
    if (baseCode.isNotEmpty && version.isNotEmpty) {
      _fullDieCode = '$baseCode/$version';
    } else if (baseCode.isNotEmpty) {
      _fullDieCode = baseCode;
    } else {
      _fullDieCode = '';
    }
    setState(() {});
  }

  void _onCodeSearch(String value) {
    _searchTimer?.cancel();
    if (value.trim().isEmpty) {
      _clearFoundDie();
      return;
    }
    _searchTimer = Timer(_searchDelay, () {
      _searchDie(value.trim());
    });
  }

  void _clearFoundDie() {
    setState(() {
      _foundDie = null;
      _foundVersions = [];
      _versionController.clear();
      _fullDieCode = '';
    });
  }

  Future<void> _searchDie(String query) async {
    if (query.isEmpty) {
      _clearFoundDie();
      return;
    }

    setState(() => _isSearching = true);

    try {
      final results = await _provider.service.getDieTemplatesByBaseCode(
        _provider.currentFactoryId,
        query,
      );

      if (results.isNotEmpty) {
        setState(() {
          _foundVersions = results;
          _foundDie = results.first;
          _dieCodeController.text = results.first.dieCode;
          _clientCodeController.text = results.first.clientCode;
          _designCodeController.text = results.first.designCode;
          if (results.first.version != null) {
            _versionController.text = results.first.version!;
          }
          _updateFullDieCode();
          _isSearching = false;
        });

        if (results.length > 1) {
          _showVersionsDialog(results);
        }
      } else {
        setState(() {
          _foundDie = null;
          _foundVersions = [];
          _versionController.clear();
          _fullDieCode = '';
          _isSearching = false;
        });
      }
    } catch (e) {
      setState(() => _isSearching = false);
      print('❌ خطأ في البحث: $e');
    }
  }

  void _showVersionsDialog(List<DieTemplate> versions) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📋 اختر النسخة المطلوبة'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: versions.length,
            itemBuilder: (context, index) {
              final die = versions[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                title: Text(die.fullCode),
                subtitle: Text(
                  'العميل: ${die.clientCode} | التصميم: ${die.designCode}',
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: die.version != null
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'نسخة ${die.version}',
                          style: TextStyle(fontSize: 10, color: Colors.green.shade700),
                        ),
                      )
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _foundDie = die;
                    _dieCodeController.text = die.dieCode;
                    _clientCodeController.text = die.clientCode;
                    _designCodeController.text = die.designCode;
                    if (die.version != null) {
                      _versionController.text = die.version!;
                    }
                    _updateFullDieCode();
                  });
                  Fluttertoast.showToast(
                    msg: '✅ تم اختيار: ${die.fullCode}',
                    backgroundColor: Colors.green,
                    textColor: Colors.white,
                    toastLength: Toast.LENGTH_SHORT,
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );
  }

  Future<void> _syncDraftDie() async {
    if (_shift == null || !_shift!.isActive) return;
    if (!_provider.canAddDie) return;

    final dieCode = _dieCodeController.text.trim();
    final clientCode = _clientCodeController.text.trim();
    final designCode = _designCodeController.text.trim();

    final name = dieCode.isNotEmpty ? dieCode : clientCode;

    if (name.isEmpty) return;

    try {
      final draftDie = DieModel(
        name: name,
        holes: int.tryParse(_holesController.text) ?? 0,
        entryTime: _entryTime,
        exitTime: _exitTime,
        alloy: _selectedAlloy,
        billetLength: double.tryParse(_billetLengthController.text) ?? 0,
        billetTemperature: double.tryParse(_temperatureController.text) ?? 0,
        ramSpeed: double.tryParse(_ramSpeedController.text) ?? 0,
        billetCount: int.tryParse(_billetCountController.text) ?? 0,
        notes: _notesController.text,
        pressId: _shift!.pressId,
        pressSize: _shift!.pressSize,
        isActive: true,
        status: DieStatus.draft,
        pieceLength: double.tryParse(_pieceLengthController.text),
        tableLength: double.tryParse(_tableLengthController.text),
      );

      await _provider.saveDraftDie(draftDie);

    } catch (e) {
      print(context.trP('sync_die_error', {'e': '$e'}));
    }
  }

  Widget _readOnlyField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        prefixIcon: const Icon(Icons.tag, size: 16),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      readOnly: true,
      style: const TextStyle(
        color: Colors.blue,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  // ✅ دالة buildTimePicker مع إصلاح مشكلة وقت الخروج
  Widget _buildTimePicker(String label, DateTime time, Function(DateTime) onChanged, {bool isExitTime = false}) {
    if (isExitTime) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.blue.shade300),
          borderRadius: BorderRadius.circular(8),
          color: Colors.blue.shade50,
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time, size: 16, color: Colors.blue),
            const SizedBox(width: 8),
            Text(
              '$label: ${DateFormat('HH:mm:ss').format(time)}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.edit, size: 16, color: Colors.blue),
              onPressed: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(time),
                );
                if (picked != null) {
                  final newTime = DateTime(
                    time.year,
                    time.month,
                    time.day,
                    picked.hour,
                    picked.minute,
                  );
                  
                  // ✅ تحديث الوقت
                  onChanged(newTime);
                  setState(() {
                    _exitTime = newTime;
                  });
                  
                  // ✅ حساب المدة الجديدة
                  final newDuration = _exitTime.difference(_entryTime).inMinutes;
                  
                  // ✅ حساب الوزن
                  final length = double.tryParse(_billetLengthController.text) ?? 0;
                  final count = int.tryParse(_billetCountController.text) ?? 0;
                  
                  if (length > 0 && count > 0 && _shift != null) {
                    final weight = DieModel.calculateWeight(
                      pressId: _shift!.pressId,
                      billetLength: length,
                      billetCount: count,
                    );
                    final weightInTons = weight / 1000;
                    final hours = newDuration / 60;
                    
                    // ✅ حساب الإنتاجية الجديدة
                    double newProductivity = 0.0;
                    if (hours > 0) {
                      newProductivity = weightInTons / hours;
                    }
                    
                    // ✅ حساب كفاءة الإنتاج الجديدة
                    final press = _provider.getPressById(_shift!.pressId);
                    if (press != null && press.targetTonsPerHour > 0) {
                      final newEfficiency = (newProductivity / press.targetTonsPerHour) * 100;
                      print('✅✅✅ وقت الخروج الجديد: ${DateFormat('HH:mm:ss').format(_exitTime)}');
                      print('✅✅✅ المدة الجديدة: $newDuration دقيقة');
                      print('✅✅✅ الإنتاجية الجديدة: $newProductivity طن/ساعة');
                      print('✅✅✅ كفاءة الإنتاج الجديدة: $newEfficiency%');
                    }
                  }
                  
                  // ✅ مزامنة القالب مع التغييرات
                  _syncDraftDie();
                  
                  // ✅ تحديث الواجهة
                  setState(() {});
                }
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'تعديل وقت الخروج يدوياً',
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(time),
        );
        if (picked != null) {
          final newTime = DateTime(
            time.year,
            time.month,
            time.day,
            picked.hour,
            picked.minute,
          );
          onChanged(newTime);
          _syncDraftDie();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time, size: 16),
            const SizedBox(width: 8),
            Text('$label: ${DateFormat('HH:mm').format(time)}'),
          ],
        ),
      ),
    );
  }

  Future<void> _loadShift() async {
    setState(() => _isLoading = true);
    try {
      await _provider.loadShift(widget.shiftId);
      setState(() {
        _shift = _provider.currentShift;
        _isLoading = false;
        _currentDraftDie = _provider.draftDie;

        if (_shift != null && _currentDraftDie != null) {
          _loadDraftDieToForm(_currentDraftDie!);
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
      Fluttertoast.showToast(
        msg: context.trP('load_shift_error', {'e': '$e'}),
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  void _loadDraftDieToForm(DieModel draft) {
    _dieCodeController.text = draft.name;
    _holesController.text = draft.holes.toString();
    _billetLengthController.text = draft.billetLength.toString();
    _temperatureController.text = draft.billetTemperature.toString();
    _ramSpeedController.text = draft.ramSpeed.toString();
    _billetCountController.text = draft.billetCount.toString();
    _notesController.text = draft.notes;
    _selectedAlloy = draft.alloy;
    _entryTime = draft.entryTime;
    _exitTime = draft.exitTime;
    _pieceLengthController.text = draft.pieceLength?.toString() ?? '';
    _tableLengthController.text = draft.tableLength?.toString() ?? '';
  }

  void _clearForm() {
    _dieCodeController.clear();
    _clientCodeController.clear();
    _designCodeController.clear();
    _holesController.clear();
    _billetLengthController.clear();
    _temperatureController.clear();
    _ramSpeedController.clear();
    _billetCountController.clear();
    _notesController.clear();
    _selectedAlloy = '6063';
    _entryTime = DateTime.now();
    _exitTime = DateTime.now();
    _pieceLengthController.clear();
    _tableLengthController.clear();
    _matchedFurnaceDie = null;
    _matchedFurnace = null;
    _versionController.clear();
    _fullDieCode = '';
    _foundDie = null;
    _foundVersions = [];
    _currentDraftDie = null;
  }

  @override
  void dispose() {
    _exitTimeTimer?.cancel();
    _debounceTimer?.cancel();
    _searchTimer?.cancel();
    _holesController.dispose();
    _billetLengthController.dispose();
    _temperatureController.dispose();
    _ramSpeedController.dispose();
    _billetCountController.dispose();
    _notesController.dispose();
    _pieceLengthController.dispose();
    _tableLengthController.dispose();
    _updateBilletCountController.dispose();
    _updateBilletLengthController.dispose();
    _wasteMinutesController.dispose();
    _wasteReasonController.dispose();
    _dieCodeController.dispose();
    _clientCodeController.dispose();
    _designCodeController.dispose();
    _versionController.dispose();
    super.dispose();
  }

  String _calculateDieWeight() {
    if (_shift == null) return context.tr('zero_kg');
    final length = double.tryParse(_billetLengthController.text) ?? 0;
    final count = int.tryParse(_billetCountController.text) ?? 0;
    if (length <= 0 || count <= 0) return context.tr('zero_kg');

    final weight = DieModel.calculateWeight(
      pressId: _shift!.pressId,
      billetLength: length,
      billetCount: count,
    );

    if (weight >= 1000) {
      return context.trP('weight_tons', {'v': '${(weight / 1000).toStringAsFixed(2)}'});
    }
    return context.trP('weight_kg', {'v': '${weight.toStringAsFixed(2)}'});
  }

  String _calculateDieProductivity() {
    if (_shift == null) return context.tr('zero_tons_hour');
    final length = double.tryParse(_billetLengthController.text) ?? 0;
    final count = int.tryParse(_billetCountController.text) ?? 0;
    if (length <= 0 || count <= 0) return context.tr('zero_tons_hour');

    final weight = DieModel.calculateWeight(
      pressId: _shift!.pressId,
      billetLength: length,
      billetCount: count,
    );

    final weightInTons = weight / 1000;
    final hours = _exitTime.difference(_entryTime).inMinutes / 60;
    if (hours == 0) return context.tr('zero_tons_hour');
    return context.trP('weight_tons_hour', {'v': '${(weightInTons / hours).toStringAsFixed(2)}'});
  }

  Future<void> _autoRegisterFurnaceExit(String dieName) async {
    if (dieName.isEmpty) return;
    if (_shift == null) return;
    if (_matchedFurnaceDie != null && _matchedFurnaceDie!.name == dieName) return;

    setState(() => _isCheckingFurnace = true);
    try {
      DieModel? foundDieInFurnace;
      FurnaceModel? foundFurnace;
      String? foundShiftId;

      for (var shift in _provider.allShifts) {
        for (var die in shift.dies) {
          if (die.name == dieName &&
              die.furnaceId != null &&
              die.furnaceId!.isNotEmpty &&
              !die.isFurnaceReady &&
              die.furnacePressId == _shift!.pressId) {
            foundDieInFurnace = die;
            foundFurnace = _provider.getFurnaceById(die.furnaceId!);
            foundShiftId = shift.id;
            break;
          }
        }
        if (foundDieInFurnace != null) break;
      }

      if (foundDieInFurnace == null || foundFurnace == null || foundShiftId == null) {
        _matchedFurnaceDie = null;
        _matchedFurnace = null;
        return;
      }

      final isReady = foundDieInFurnace.isReady(foundFurnace);
      final remaining = foundDieInFurnace.getRemainingTimeFormatted(foundFurnace);

      if (!isReady) {
        Fluttertoast.showToast(
          msg: context.trP('die_still_heating', {'name': '${foundDieInFurnace.name}', 'remaining': '$remaining'}),
          backgroundColor: Colors.orange,
          textColor: Colors.white,
          toastLength: Toast.LENGTH_LONG,
        );
        _matchedFurnaceDie = null;
        _matchedFurnace = null;
        return;
      }

      final exitedDie = foundDieInFurnace.copyWith(
        furnaceExitTime: DateTime.now(),
        isFurnaceReady: true,
      );
      await _provider.updateDieInShift(foundShiftId, exitedDie);

      _matchedFurnaceDie = exitedDie;
      _matchedFurnace = foundFurnace;

      Fluttertoast.showToast(
        msg: context.trP('die_exited_furnace', {'name': '${exitedDie.name}'}),
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: context.trP('furnace_check_error', {'e': '$e'}),
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      if (mounted) setState(() => _isCheckingFurnace = false);
    }
  }

  void _showFurnaceDieReadyDialog(DieModel die, FurnaceModel furnace) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text(context.tr('die_ready_for_pressing')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.trP('die_found_in_furnace_ready', {'name': '${die.name}'})),
            const SizedBox(height: 8),
            Text(context.trP('furnace_label', {'name': '${furnace.name}'})),
            Text(context.trP('entry_time_label', {'date': '${DateFormat('yyyy-MM-dd HH:mm').format(die.furnaceEntryTime!)}'})),
            Text(context.trP('required_heating_time', {'min': '${die.getRequiredHeatingTime(furnace)}'})),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.green),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.tr('auto_exit_hint'),
                      style: TextStyle(color: Colors.green),
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
            child: Text(context.tr('cancel')),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await _addDieFromFurnace(die, furnace);
            },
            icon: const Icon(Icons.add),
            label: Text(context.tr('add_to_shift')),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showFurnaceDieNotReadyDialog(DieModel die, FurnaceModel furnace, String remaining) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.timer, color: Colors.orange),
            SizedBox(width: 8),
            Text(context.tr('die_heating_in_progress')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.trP('die_found_not_ready', {'name': '${die.name}'})),
            const SizedBox(height: 8),
            Text(context.trP('furnace_label', {'name': '${furnace.name}'})),
            Text(context.trP('entry_time_label', {'date': '${DateFormat('yyyy-MM-dd HH:mm').format(die.furnaceEntryTime!)}'})),
            Text(context.trP('required_heating_time', {'min': '${die.getRequiredHeatingTime(furnace)}'})),
            Text(context.trP('remaining_time_label', {'v': '$remaining'})),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.tr('cannot_press_until_heated'),
                      style: TextStyle(color: Colors.orange),
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
            child: Text(context.tr('ok_word')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _addDieDirectly();
            },
            child: Text(context.tr('add_as_new_die')),
          ),
        ],
      ),
    );
  }

  Future<void> _addDieFromFurnace(DieModel die, FurnaceModel furnace) async {
    setState(() => _isSaving = true);

    try {
      final updatedDie = die.copyWith(
        furnaceExitTime: DateTime.now(),
        isFurnaceReady: true,
        holes: int.tryParse(_holesController.text) ?? 0,
        entryTime: _entryTime,
        exitTime: _exitTime,
        alloy: _selectedAlloy,
        billetLength: double.tryParse(_billetLengthController.text) ?? 0,
        billetTemperature: double.tryParse(_temperatureController.text) ?? 0,
        ramSpeed: double.tryParse(_ramSpeedController.text) ?? 0,
        billetCount: int.tryParse(_billetCountController.text) ?? 0,
        notes: _notesController.text,
        status: DieStatus.active,
        pieceLength: double.tryParse(_pieceLengthController.text),
        tableLength: double.tryParse(_tableLengthController.text),
      );

      await _provider.updateDie(updatedDie);

      final newDie = updatedDie.copyWith(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        supervisorId: _provider.currentUserUid,
      );

      final updatedShift = _shift!.addDie(newDie);
      await _provider.service.updateShift(updatedShift);

      await DieTracking.recordPressExit(
        factoryId: _provider.currentFactoryId,
        codes: [updatedDie.name, _dieCodeController.text, _clientCodeController.text, _designCodeController.text],
        pressId: _shift!.pressId,
        pressName: _shift!.pressName,
        pressSize: _shift!.pressSize,
      );

      _clearForm();
      await _loadShift();

      Fluttertoast.showToast(
        msg: context.trP('die_added_from_furnace', {'name': '${die.name}'}),
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );

    } catch (e) {
      Fluttertoast.showToast(
        msg: context.trP('generic_error', {'e': '$e'}),
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _addDieDirectly() async {
    if (_shift == null) {
      Fluttertoast.showToast(msg: context.tr('no_active_shift'), backgroundColor: Colors.orange, textColor: Colors.white);
      return;
    }

    if (!_provider.canAddDie) {
      Fluttertoast.showToast(msg: context.tr('no_permission_add_die'), backgroundColor: Colors.red, textColor: Colors.white);
      return;
    }

    final dieCode = _dieCodeController.text.trim();
    final clientCode = _clientCodeController.text.trim();
    final name = dieCode.isNotEmpty ? dieCode : clientCode;

    if (name.isEmpty) {
      Fluttertoast.showToast(msg: context.tr('enter_die_name_warning'), backgroundColor: Colors.orange, textColor: Colors.white);
      return;
    }

    final billetLength = double.tryParse(_billetLengthController.text);
    if (billetLength == null || billetLength <= 0) {
      Fluttertoast.showToast(msg: context.tr('enter_valid_billet_length'), backgroundColor: Colors.orange, textColor: Colors.white);
      return;
    }

    final temperature = double.tryParse(_temperatureController.text);
    if (temperature == null || temperature <= 0) {
      Fluttertoast.showToast(msg: context.tr('enter_valid_temperature'), backgroundColor: Colors.orange, textColor: Colors.white);
      return;
    }

    final ramSpeed = double.tryParse(_ramSpeedController.text);
    if (ramSpeed == null || ramSpeed <= 0) {
      Fluttertoast.showToast(msg: context.tr('enter_valid_ram_speed'), backgroundColor: Colors.orange, textColor: Colors.white);
      return;
    }

    final billetCount = int.tryParse(_billetCountController.text);
    if (billetCount == null || billetCount <= 0) {
      Fluttertoast.showToast(msg: context.tr('enter_valid_billet_count'), backgroundColor: Colors.orange, textColor: Colors.white);
      return;
    }

    final holes = int.tryParse(_holesController.text);
    if (holes == null || holes <= 0) {
      Fluttertoast.showToast(msg: context.tr('enter_valid_holes_count'), backgroundColor: Colors.orange, textColor: Colors.white);
      return;
    }

    final trackedLocation = await DieTracking.findLocation(
      _provider.currentFactoryId,
      [name, _dieCodeController.text, _clientCodeController.text, _designCodeController.text],
    );
    if (trackedLocation == DieAssetLocation.inCorrection || trackedLocation == DieAssetLocation.damaged) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('⚠️ لا يمكن كبس القالب'),
          content: Text(trackedLocation == DieAssetLocation.damaged
              ? 'القالب مسجل كتالف/سكراب، لا يمكن استخدامه في الوردية.'
              : 'القالب داخل الكوريكشن حاليًا، لا يمكن كبس قالب غير جاهز.'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('حسنًا'))],
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final draft = _provider.draftDie;
      if (draft == null) {
        Fluttertoast.showToast(
          msg: context.tr('no_die_in_progress'),
          backgroundColor: Colors.orange,
          textColor: Colors.white,
        );
        setState(() => _isSaving = false);
        return;
      }

      final updatedDraft = draft.copyWith(
        exitTime: _exitTime,
        pieceLength: double.tryParse(_pieceLengthController.text),
        tableLength: double.tryParse(_tableLengthController.text),
      );

      await _provider.saveDraftDie(updatedDraft);
      await _provider.addDieDirect(updatedDraft);

      await DieTracking.recordPressExit(
        factoryId: _provider.currentFactoryId,
        codes: [updatedDraft.name, _dieCodeController.text, _clientCodeController.text, _designCodeController.text],
        pressId: _shift!.pressId,
        pressName: _shift!.pressName,
        pressSize: _shift!.pressSize,
      );

      _clearForm();
      await _loadShift();

      Fluttertoast.showToast(
        msg: context.tr('die_added_success'),
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );

    } catch (e) {
      Fluttertoast.showToast(
        msg: context.trP('generic_error', {'e': '$e'}),
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _addDie() async {
    if (_shift == null) {
      Fluttertoast.showToast(msg: context.tr('no_active_shift'), backgroundColor: Colors.orange, textColor: Colors.white);
      return;
    }

    if (!_provider.canAddDie) {
      Fluttertoast.showToast(msg: context.tr('no_permission_add_die'), backgroundColor: Colors.red, textColor: Colors.white);
      return;
    }

    final dieCode = _dieCodeController.text.trim();
    final clientCode = _clientCodeController.text.trim();
    final name = dieCode.isNotEmpty ? dieCode : clientCode;

    if (name.isEmpty) {
      Fluttertoast.showToast(msg: context.tr('enter_die_name_warning'), backgroundColor: Colors.orange, textColor: Colors.white);
      return;
    }

    final billetLength = double.tryParse(_billetLengthController.text);
    if (billetLength == null || billetLength <= 0) {
      Fluttertoast.showToast(msg: context.tr('enter_valid_billet_length'), backgroundColor: Colors.orange, textColor: Colors.white);
      return;
    }

    final temperature = double.tryParse(_temperatureController.text);
    if (temperature == null || temperature <= 0) {
      Fluttertoast.showToast(msg: context.tr('enter_valid_temperature'), backgroundColor: Colors.orange, textColor: Colors.white);
      return;
    }

    final ramSpeed = double.tryParse(_ramSpeedController.text);
    if (ramSpeed == null || ramSpeed <= 0) {
      Fluttertoast.showToast(msg: context.tr('enter_valid_ram_speed'), backgroundColor: Colors.orange, textColor: Colors.white);
      return;
    }

    final billetCount = int.tryParse(_billetCountController.text);
    if (billetCount == null || billetCount <= 0) {
      Fluttertoast.showToast(msg: context.tr('enter_valid_billet_count'), backgroundColor: Colors.orange, textColor: Colors.white);
      return;
    }

    final holes = int.tryParse(_holesController.text);
    if (holes == null || holes <= 0) {
      Fluttertoast.showToast(msg: context.tr('enter_valid_holes_count'), backgroundColor: Colors.orange, textColor: Colors.white);
      return;
    }

    if (_matchedFurnaceDie != null && _matchedFurnace != null) {
      setState(() => _isSaving = true);
      try {
        final dieFromFurnace = _matchedFurnaceDie!.copyWith(
          furnaceExitTime: DateTime.now(),
          isFurnaceReady: true,
          holes: holes,
          entryTime: _entryTime,
          exitTime: _exitTime,
          alloy: _selectedAlloy,
          billetLength: billetLength,
          billetTemperature: temperature,
          ramSpeed: ramSpeed,
          billetCount: billetCount,
          notes: _notesController.text,
          pressId: _shift!.pressId,
          pressSize: _shift!.pressSize,
          pieceLength: double.tryParse(_pieceLengthController.text),
          tableLength: double.tryParse(_tableLengthController.text),
        );
        await _provider.addDieDirect(dieFromFurnace);
        _clearForm();
        await _loadShift();
        Fluttertoast.showToast(
          msg: context.trP('die_added_from_furnace2', {'name': '${dieFromFurnace.name}'}),
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
      } catch (e) {
        Fluttertoast.showToast(msg: context.trP('generic_error', {'e': '$e'}), backgroundColor: Colors.red, textColor: Colors.white);
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
      return;
    }

    await _addDieDirectly();
  }

  Future<void> _cancelDraft() async {
    try {
      await _provider.deleteDraftDie();
      _clearForm();
      await _loadShift();
      Fluttertoast.showToast(
        msg: context.tr('in_progress_die_cancelled'),
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: context.trP('generic_error', {'e': '$e'}),
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  Future<void> _addWastedTime() async {
    if (_shift == null || !_shift!.isActive) {
      Fluttertoast.showToast(msg: context.tr('no_active_shift'), backgroundColor: Colors.orange, textColor: Colors.white);
      return;
    }

    final minutes = int.tryParse(_wasteMinutesController.text);
    if (minutes == null || minutes <= 0) {
      Fluttertoast.showToast(msg: context.tr('enter_valid_minutes'), backgroundColor: Colors.orange, textColor: Colors.white);
      return;
    }

    final reason = _wasteReasonController.text.trim();
    if (reason.isEmpty) {
      Fluttertoast.showToast(msg: context.tr('enter_downtime_reason'), backgroundColor: Colors.orange, textColor: Colors.white);
      return;
    }

    setState(() => _isAddingWaste = true);

    try {
      await _provider.addWastedTime(minutes, reason);

      _wasteMinutesController.clear();
      _wasteReasonController.clear();
      await _loadShift();

      Fluttertoast.showToast(
        msg: context.trP('downtime_recorded', {'min': '$minutes'}),
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: context.trP('generic_error', {'e': '$e'}),
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      setState(() => _isAddingWaste = false);
    }
  }

  Future<void> _updateBilletCount(DieModel die) async {
    if (_updateBilletCountController.text.isEmpty) {
      Fluttertoast.showToast(msg: context.tr('enter_billet_count'), backgroundColor: Colors.orange, textColor: Colors.white);
      return;
    }
    try {
      final newCount = int.tryParse(_updateBilletCountController.text) ?? 0;
      if (newCount <= 0) {
        Fluttertoast.showToast(msg: context.tr('enter_valid_number_gt0'), backgroundColor: Colors.orange, textColor: Colors.white);
        return;
      }

      final updatedDie = die.copyWith(
        billetCount: newCount,
      );

      await _provider.updateDie(updatedDie);
      _updateBilletCountController.clear();
      await _loadShift();

      final press = _shift != null ? _provider.getPressById(_shift!.pressId) : null;
      if (press != null) {
        final newEfficiency = updatedDie.getEfficiency(press.targetTonsPerHour);
        final newWeight = updatedDie.totalWeight;
        final newWeightInTons = newWeight / 1000;
        Fluttertoast.showToast(
          msg: context.trP('counter_updated_full', {'n': '$newCount', 'w': '${newWeightInTons.toStringAsFixed(3)}', 'eff': '${newEfficiency.toStringAsFixed(1)}'}),
          backgroundColor: Colors.green,
          textColor: Colors.white,
          toastLength: Toast.LENGTH_LONG,
        );
      } else {
        Fluttertoast.showToast(
          msg: context.trP('counter_updated', {'n': '$newCount'}),
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(msg: context.trP('generic_error', {'e': '$e'}), backgroundColor: Colors.red, textColor: Colors.white);
    }
  }

  Future<void> _updateBilletLength(DieModel die) async {
    if (_updateBilletLengthController.text.isEmpty) {
      Fluttertoast.showToast(msg: context.tr('enter_billet_length'), backgroundColor: Colors.orange, textColor: Colors.white);
      return;
    }
    try {
      final updatedDie = die.copyWith(
        billetLength: double.tryParse(_updateBilletLengthController.text) ?? 0,
      );
      await _provider.updateDie(updatedDie);
      _updateBilletLengthController.clear();
      await _loadShift();
      Fluttertoast.showToast(msg: context.tr('billet_length_updated'), backgroundColor: Colors.purple, textColor: Colors.white);
    } catch (e) {
      Fluttertoast.showToast(msg: context.trP('generic_error', {'e': '$e'}), backgroundColor: Colors.red, textColor: Colors.white);
    }
  }

  Future<void> _endShift() async {
    if (_shift == null) return;
    try {
      await _provider.endShift();
      Fluttertoast.showToast(msg: context.tr('shift_ended_success'), backgroundColor: Colors.green, textColor: Colors.white);
      Navigator.pop(context);
    } catch (e) {
      Fluttertoast.showToast(msg: context.trP('generic_error', {'e': '$e'}), backgroundColor: Colors.red, textColor: Colors.white);
    }
  }

  void _confirmEndShift() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('confirm_end_shift_title')),
        content: Text(context.tr('confirm_end_shift_body')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(context.tr('cancel'))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _endShift();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(context.tr('confirm_end'), style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildDieDrawingPreview() {
    if (_foundDie == null || !_foundDie!.hasDrawing) {
      return const SizedBox.shrink();
    }

    final die = _foundDie!;
    final isPdf = die.pdfUrl != null && 
                   (die.pdfUrl!.toLowerCase().endsWith('.pdf') ||
                    die.pdfUrl!.contains('drive.google.com'));

    if (die.imageData != null && die.imageData!.isNotEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.memory(
                base64Decode(die.imageData!),
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 60,
                    height: 60,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.broken_image, size: 30, color: Colors.grey),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🖼️ رسم القالب: ${die.fullCode}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'اضغط للتكبير',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.open_in_full, size: 18, color: Colors.blue),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PdfViewerScreen(
                      imageData: die.imageData,
                      title: 'رسم القالب: ${die.name}',
                    ),
                  ),
                );
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      );
    }

    if (die.pdfUrl != null && die.pdfUrl!.isNotEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isPdf ? Colors.red.shade50 : Colors.green.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isPdf ? Colors.red.shade300 : Colors.green.shade300,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isPdf ? Colors.red.shade100 : Colors.green.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isPdf ? Icons.picture_as_pdf : Icons.image,
                color: isPdf ? Colors.red : Colors.green,
                size: 24,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPdf ? '📄 PDF: ${die.fullCode}' : '🖼️ رسم: ${die.fullCode}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'اضغط للعرض',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.visibility, size: 18, color: Colors.blue),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PdfViewerScreen(
                      pdfUrl: die.pdfUrl,
                      title: 'رسم القالب: ${die.name}',
                    ),
                  ),
                );
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ShiftProvider>(context);
    final shift = provider.currentShift;
    final isActive = shift?.isActive ?? false;
    final draftDie = provider.draftDie;

    final press = shift != null ? provider.getPressById(shift.pressId) : null;
    final efficiency = (shift != null && press != null) ? shift.getEfficiency(press.targetTonsPerHour) : 0.0;
    final efficiencyColor = provider.getEfficiencyColor(efficiency);
    final efficiencyEmoji = provider.getEfficiencyEmoji(efficiency);

    final monthlyProduction = shift != null ? provider.getMonthlyProductionFormattedForPress(shift.pressId) : context.tr('zero_kg');

    final diameter = press?.diameterInInches ?? 0;
    final stock = provider.getMaterialStockForDiameter(diameter);

    if (provider.isLoading || _isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (shift == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(context.tr('shift_not_found')),
          backgroundColor: Colors.red,
        ),
        body: Center(
          child: Text(context.tr('shift_not_found_body')),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.trP('press_shift_header', {'press': '${press?.name ?? shift.pressSize}', 'num': '${shift.shiftNumber}'})),
        backgroundColor: isActive ? Colors.green : Colors.blue,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadShift,
            tooltip: context.tr('refresh_plain'),
          ),
          if (isActive && provider.canAddDie && draftDie != null)
            IconButton(
              icon: _isSaving || _isCheckingFurnace
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save, color: Colors.white),
              onPressed: (_isSaving || _isCheckingFurnace) ? null : _addDie,
              tooltip: context.tr('save_die_check_furnace'),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Card(
              color: stock < 50 ? Colors.red.shade50 : Colors.green.shade50,
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                child: Row(
                  children: [
                    const Icon(Icons.inventory, size: 24, color: Colors.amber),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.trP('material_stock_by_diameter', {
                          'diameter': diameter.toStringAsFixed(1),
                          'stock': stock.toStringAsFixed(2),
                        }),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: stock < 50 ? Colors.red : Colors.green,
                        ),
                      ),
                    ),
                    if (stock < 50)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '⚠️ منخفض',
                          style: TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            Card(
              color: isActive ? Colors.green.shade50 : Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('📅 ${shift.date}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isActive ? Colors.green : Colors.grey,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isActive ? context.tr('active_status') : context.tr('finished_status'),
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _infoChip(context.tr('supervisor_word'), shift.supervisor)),
                        Expanded(child: _infoChip(context.tr('technician_word'), shift.technician)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(child: _infoChip(context.tr('press_label_short'), press?.name ?? shift.pressSize)),
                        Expanded(child: _infoChip(context.tr('duration_word'), shift.duration)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(child: _infoChip(context.tr('dies_word'), '${shift.totalDies}')),
                        Expanded(child: _infoChip(context.tr('billets_word'), '${shift.totalBillets}')),
                        Expanded(child: _infoChip(context.tr('weight_word'), shift.totalWeightFormatted)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(child: _infoChip(context.tr('productivity_word'), shift.averageProductivityFormatted)),
                        Expanded(
                          child: Row(
                            children: [
                              Text(context.tr('efficiency_label'), style: TextStyle(fontSize: 11)),
                              Text(
                                '${efficiency.toStringAsFixed(1)}% $efficiencyEmoji',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: efficiencyColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _infoChip(context.tr('monthly_production'), monthlyProduction),
                        ),
                      ],
                    ),
                    if (shift.dies.isNotEmpty) ...[
                      const Divider(),
                      Row(
                        children: [
                          Expanded(
                            child: _infoChip(context.tr('shift_duration'), shift.actualDurationFormatted),
                          ),
                          Expanded(
                            child: _infoChip(context.tr('work_time'), shift.totalWorkFormatted),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _infoChip(context.tr('downtime_between_dies'), shift.gapFormatted),
                          ),
                          Expanded(
                            child: _infoChip(context.tr('waste_percentage'), '${shift.gapPercentage.toStringAsFixed(1)}%'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            if (isActive && provider.canAddDie) ...[
              Card(
                color: draftDie != null ? Colors.orange.shade50 : Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            draftDie != null ? Icons.edit : Icons.add_box,
                            color: draftDie != null ? Colors.orange : Colors.green,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            draftDie != null ? context.tr('edit_in_progress_die') : context.tr('add_new_die'),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: draftDie != null ? Colors.orange : Colors.green,
                            ),
                          ),
                          if (draftDie != null) ...[
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(context.tr('in_progress_status'),
                                style: TextStyle(color: Colors.white, fontSize: 10),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _dieCodeController,
                              decoration: InputDecoration(
                                labelText: '🏷️ كود القالب',
                                hintText: 'مثال: ES001029',
                                border: OutlineInputBorder(),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: TextFormField(
                              controller: _clientCodeController,
                              decoration: InputDecoration(
                                labelText: '🏷️ كود العميل',
                                hintText: 'مثال: 10212AA',
                                border: OutlineInputBorder(),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: TextFormField(
                              controller: _designCodeController,
                              decoration: InputDecoration(
                                labelText: '🏷️ كود التصميم',
                                hintText: 'مثال: 213204',
                                border: OutlineInputBorder(),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      _buildDieDrawingPreview(),

                      if (_foundDie != null) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.check_circle, color: Colors.green, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    '✅ ${_foundDie!.fullCode}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 13),
                                  ),
                                  const Spacer(),
                                  if (_foundVersions.length > 1)
                                    TextButton(
                                      onPressed: () => _showVersionsDialog(_foundVersions),
                                      child: Text(
                                        '${_foundVersions.length} نسخ',
                                        style: TextStyle(fontSize: 10, color: Colors.blue),
                                      ),
                                    ),
                                  if (_foundDie!.hasDrawing)
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => PdfViewerScreen(
                                              pdfUrl: _foundDie!.pdfUrl!,
                                              title: 'رسم القالب: ${_foundDie!.name}',
                                            ),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade100,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Icon(
                                          Icons.picture_as_pdf,
                                          color: Colors.red,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      controller: _versionController,
                                      decoration: InputDecoration(
                                        labelText: '🔢 رقم النسخة',
                                        hintText: 'مثال: 1m, 2m, 3d',
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                        prefixIcon: const Icon(Icons.copy, size: 16),
                                      ),
                                      onChanged: (_) => _updateFullDieCode(),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 3,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.blue.shade300),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '📋 الكود الكامل',
                                            style: TextStyle(fontSize: 9, color: Colors.blue.shade700),
                                          ),
                                          Text(
                                            _fullDieCode.isEmpty ? 'انتظر إدخال رقم النسخة' : _fullDieCode,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: _fullDieCode.isEmpty ? Colors.grey : Colors.blue,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],

                      const SizedBox(height: 8),

                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _holesController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: context.tr('holes_word'),
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              enabled: !_isSaving && !_isCheckingFurnace,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTimePicker(context.tr('entry_time_word'), _entryTime, (time) {
                              setState(() => _entryTime = time);
                              _syncDraftDie();
                            }),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildTimePicker(
                              context.tr('exit_time_word'), 
                              _exitTime, 
                              (time) {
                                setState(() => _exitTime = time);
                                _syncDraftDie();
                              },
                              isExitTime: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedAlloy,
                              decoration: InputDecoration(
                                labelText: context.tr('alloy_word'),
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: AlloyModel.getAlloyNames().map((a) =>
                                DropdownMenuItem(value: a, child: Text(a))
                              ).toList(),
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => _selectedAlloy = v);
                                  _syncDraftDie();
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _billetLengthController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: context.tr('length_mm_label'),
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              enabled: !_isSaving && !_isCheckingFurnace,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _temperatureController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: context.tr('temperature_c_label'),
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              enabled: !_isSaving && !_isCheckingFurnace,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _ramSpeedController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: context.tr('speed_word'),
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              enabled: !_isSaving && !_isCheckingFurnace,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _billetCountController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: context.tr('billet_counter'),
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              enabled: !_isSaving && !_isCheckingFurnace,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.green),
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.green.shade50,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(context.tr('expected_weight'),
                                    style: TextStyle(fontSize: 11, color: Colors.green),
                                  ),
                                  Text(
                                    _calculateDieWeight(),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    context.trP('die_productivity', {'v': '${_calculateDieProductivity()}'}),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.purple,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _pieceLengthController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: '📏 طول القطعة (متر)',
                                hintText: '(اختياري)',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              enabled: !_isSaving && !_isCheckingFurnace,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _tableLengthController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: '📏 طول الفرش للقطاع (متر)',
                                hintText: '(اختياري)',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              enabled: !_isSaving && !_isCheckingFurnace,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _notesController,
                        decoration: InputDecoration(
                          labelText: context.tr('notes_word'),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        maxLines: 2,
                        enabled: !_isSaving && !_isCheckingFurnace,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: (_isSaving || _isCheckingFurnace || draftDie == null) ? null : _addDie,
                              icon: _isSaving || _isCheckingFurnace
                                  ? const SizedBox(
                                      height: 16,
                                      width: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.save),
                              label: Text(
                                _isSaving ? context.tr('saving_word') :
                                _isCheckingFurnace ? context.tr('checking_word') : context.tr('add_die_button'),
                                style: const TextStyle(fontSize: 14),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (draftDie != null)
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: (_isSaving || _isCheckingFurnace) ? null : _cancelDraft,
                                icon: const Icon(Icons.delete),
                                label: Text(context.tr('cancel_word_trash'), style: TextStyle(fontSize: 14)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                              ),
                            ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info, color: Colors.blue, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                context.tr('furnace_check_hint'),
                                style: TextStyle(fontSize: 11, color: Colors.blue.shade700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            if (isActive) ...[
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning, color: Colors.red),
                          const SizedBox(width: 8),
                          Text(context.tr('record_downtime_title'),
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: TextFormField(
                              controller: _wasteMinutesController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: context.tr('minutes_count_label'),
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              enabled: !_isAddingWaste,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _wasteReasonController,
                              decoration: InputDecoration(
                                labelText: context.tr('downtime_reason_label'),
                                border: OutlineInputBorder(),
                                isDense: true,
                                hintText: context.tr('downtime_reason_hint'),
                              ),
                              enabled: !_isAddingWaste,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isAddingWaste ? null : _addWastedTime,
                          icon: _isAddingWaste
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.add),
                          label: Text(
                            _isAddingWaste ? context.tr('recording_word') : context.tr('record_downtime_button'),
                            style: const TextStyle(fontSize: 14),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            if (shift.dies.isNotEmpty) ...[
              Row(
                children: [
                  Text(context.tr('dies_title'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (shift.dies.where((d) => d.status == DieStatus.draft).isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '🟡 ${shift.dies.where((d) => d.status == DieStatus.draft).length}',
                            style: const TextStyle(color: Colors.white, fontSize: 10),
                          ),
                        ),
                      if (shift.dies.where((d) => d.status == DieStatus.active).isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '🟢 ${shift.dies.where((d) => d.status == DieStatus.active).length}',
                            style: const TextStyle(color: Colors.white, fontSize: 10),
                          ),
                        ),
                      if (shift.dies.where((d) => d.status == DieStatus.completed).isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '✅ ${shift.dies.where((d) => d.status == DieStatus.completed).length}',
                            style: const TextStyle(color: Colors.white, fontSize: 10),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...shift.dies.map((die) => _buildDieCard(die, shift.dies.indexOf(die), isActive: isActive)),
            ] else ...[
              const SizedBox(height: 30),
              Center(
                child: Column(
                  children: [
                    Icon(Icons.inbox, size: 48, color: Colors.grey.shade300),
                    const SizedBox(height: 8),
                    Text(context.tr('no_dies'), style: TextStyle(color: Colors.grey.shade500)),
                    if (isActive)
                      Text(context.tr('add_die_to_start'), style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                  ],
                ),
              ),
            ],

            if (shift.wasteRecords.isNotEmpty) ...[
              const Divider(),
              Text(context.tr('downtime_details'),
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 4),
              ...shift.wasteRecords.map((record) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red, size: 14),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            record.reason,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                          Text(
                            context.trP('downtime_minutes', {'n': '${record.minutes}'}),
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      DateFormat('HH:mm').format(record.timestamp),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              )),
              const Divider(),
              Row(
                children: [
                  Text(context.tr('total_downtime_label'), style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    shift.totalWastedFormatted,
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: _infoChip(context.tr('actual_production_time'), shift.productiveFormatted),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 12),

            if (isActive) ...[
              Card(
                color: Colors.amber.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(context.tr('total_weight_label'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          Text(
                            shift.totalWeightFormatted,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(context.tr('avg_productivity_label2'), style: TextStyle(fontSize: 14)),
                          Text(
                            shift.averageProductivityFormatted,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.purple),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(context.tr('shift_efficiency_label'), style: TextStyle(fontSize: 14)),
                          Text(
                            '${efficiency.toStringAsFixed(1)}% $efficiencyEmoji',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: efficiencyColor,
                            ),
                          ),
                        ],
                      ),
                      if (shift.wasteRecords.isNotEmpty) ...[
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(context.tr('total_downtime_label2'), style: TextStyle(fontSize: 14)),
                            Text(
                              shift.totalWastedFormatted,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red),
                            ),
                          ],
                        ),
                      ],
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(context.tr('monthly_production_press'), style: TextStyle(fontSize: 14)),
                          Text(
                            monthlyProduction,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (_provider.canEndCurrentShift)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _confirmEndShift,
                    icon: const Icon(Icons.stop),
                    label: Text(context.tr('end_shift_title'), style: TextStyle(fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lock, color: Colors.orange),
                      const SizedBox(width: 8),
                      Text(
                        context.trP('only_supervisor_can_end', {'name': '${shift.supervisor}'}),
                        style: TextStyle(color: Colors.orange.shade800),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$label: $value', style: const TextStyle(fontSize: 11)),
    );
  }

  Widget _buildDieCard(DieModel die, int index, {required bool isActive}) {
    Color cardColor = Colors.blue;
    String statusText = context.tr('active_status');
    Color statusColor = Colors.green;

    if (die.status == DieStatus.draft) {
      cardColor = Colors.orange;
      statusText = context.tr('in_progress_status');
      statusColor = Colors.orange;
    } else if (die.status == DieStatus.completed) {
      cardColor = Colors.grey;
      statusText = context.tr('completed_status');
      statusColor = Colors.grey;
    }

    final press = _shift != null ? _provider.getPressById(_shift!.pressId) : null;
    final targetTonsPerHour = press?.targetTonsPerHour ?? 0.0;
    final dieEfficiency = _shift != null ? die.getEfficiency(targetTonsPerHour) : 0.0;
    final efficiencyColor = _provider.getEfficiencyColor(dieEfficiency);
    final efficiencyEmoji = _provider.getEfficiencyEmoji(dieEfficiency);

    final wastedTimeFormatted = die.wastedTimeFormatted;
    final wastedTimePercentage = die.wastedTimePercentage;
    final productionEfficiency = die.productionEfficiency;

    final isInFurnace = die.furnaceId != null && die.furnaceId!.isNotEmpty;
    final furnace = isInFurnace ? _provider.getFurnaceById(die.furnaceId!) : null;
    final isFurnaceReady = isInFurnace && furnace != null ? die.isReady(furnace) : false;
    final furnaceRemaining = isInFurnace && furnace != null ? die.getRemainingTimeFormatted(furnace) : '';

    bool hasDieDrawing = false;
    String? dieDrawingUrl;
    if (_foundDie != null && _foundDie!.dieCode == die.name) {
      hasDieDrawing = _foundDie!.hasDrawing;
      dieDrawingUrl = _foundDie!.pdfUrl;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: statusColor,
                      radius: 14,
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      die.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: die.status == DieStatus.draft ? Colors.orange : null,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (hasDieDrawing && dieDrawingUrl != null)
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PdfViewerScreen(
                                pdfUrl: dieDrawingUrl!,
                                title: 'رسم القالب: ${die.name}',
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.picture_as_pdf,
                            color: Colors.red,
                            size: 16,
                          ),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        statusText,
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 2,
              children: [
                _dieChip(context.tr('holes_word'), '${die.holes}'),
                _dieChip(context.tr('entry_word'), DateFormat('HH:mm').format(die.entryTime)),
                _dieChip(context.tr('exit_word'), DateFormat('HH:mm:ss').format(die.exitTime)),
                _dieChip(context.tr('alloy_word'), die.alloy),
                _dieChip(context.tr('length_word'), context.trP('billet_length_mm', {'v': '${die.billetLength.toStringAsFixed(0)}'})),
                _dieChip(context.tr('temperature_word'), '${die.billetTemperature.toStringAsFixed(0)}°C'),
                _dieChip(context.tr('speed_word'), die.ramSpeed.toStringAsFixed(1)),
                _dieChip(context.tr('billets_word2'), '${die.billetCount}'),
                _dieChip(context.tr('weight_word2'), die.totalWeightFormatted, color: Colors.green),
                _dieChip(context.tr('duration_word'), die.durationFormatted),
                _dieChip(context.tr('productivity_word'), die.productivityFormatted, color: Colors.purple),
                if (die.pieceLength != null)
                  _dieChip('📏 طول القطعة', '${die.pieceLength!.toStringAsFixed(1)} م', color: Colors.deepOrange),
                if (die.tableLength != null)
                  _dieChip('📏 طول الفرش', '${die.tableLength!.toStringAsFixed(1)} م', color: Colors.deepOrange),
                if (die.calculatedExpectedBars != null)
                  _dieChip('📊 المتوقع', '${die.calculatedExpectedBars}', color: Colors.indigo),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: efficiencyColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: efficiencyColor),
                  ),
                  child: Text(
                    context.trP('target_efficiency', {'v': '${dieEfficiency.toStringAsFixed(1)}', 'emoji': '$efficiencyEmoji'}),
                    style: TextStyle(fontSize: 10, color: efficiencyColor, fontWeight: FontWeight.bold),
                  ),
                ),
                if (isInFurnace)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: isFurnaceReady ? Colors.green.shade100 : Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isFurnaceReady ? Colors.green : Colors.orange,
                      ),
                    ),
                    child: Text(
                      isFurnaceReady
                          ? context.tr('ready_for_pressing')
                          : context.trP('in_furnace_remaining', {'v': '$furnaceRemaining'}),
                      style: TextStyle(
                        fontSize: 10,
                        color: isFurnaceReady ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),

            if (die.durationMinutes > 0 && die.ramSpeed > 0) ...[
              const Divider(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 2,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: wastedTimePercentage > 20 ? Colors.red.shade100 : Colors.green.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: wastedTimePercentage > 20 ? Colors.red : Colors.green,
                      ),
                    ),
                    child: Text(
                      context.trP('wasted_time_pct', {'formatted': '$wastedTimeFormatted', 'pct': '${wastedTimePercentage.toStringAsFixed(1)}'}),
                      style: TextStyle(
                        fontSize: 10,
                        color: wastedTimePercentage > 20 ? Colors.red : Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: productionEfficiency >= 80 ? Colors.green.shade100 : Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: productionEfficiency >= 80 ? Colors.green : Colors.orange,
                      ),
                    ),
                    child: Text(
                      context.trP('production_efficiency', {'v': '${productionEfficiency.toStringAsFixed(1)}'}),
                      style: TextStyle(
                        fontSize: 10,
                        color: productionEfficiency >= 80 ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            if (die.notes.isNotEmpty) ...[
              const Divider(height: 4),
              Text('📝 ${die.notes}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
            if (die.status == DieStatus.active && isActive) ...[
              const Divider(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _updateBilletCountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: context.tr('update_counter'),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _updateBilletCount(die),
                      icon: const Icon(Icons.update, size: 16),
                      label: Text(context.tr('refresh_plain'), style: TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        minimumSize: const Size(0, 32),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _updateBilletLengthController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: context.tr('update_length_mm'),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _updateBilletLength(die),
                      icon: const Icon(Icons.update, size: 16),
                      label: Text(context.tr('update_length'), style: TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        minimumSize: const Size(0, 32),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _dieChip(String label, String value, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(fontSize: 10, color: color ?? Colors.black87),
      ),
    );
  }
}