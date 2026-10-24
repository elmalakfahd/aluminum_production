import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'models.dart';
import 'services.dart';
import 'furnace_dies_screen.dart';
import 'app_localization.dart';

class FurnaceScreen extends StatefulWidget {
  const FurnaceScreen({super.key});

  @override
  State<FurnaceScreen> createState() => _FurnaceScreenState();
}

class _FurnaceScreenState extends State<FurnaceScreen> {
  late ShiftProvider _provider;
  List<FurnaceModel> _furnaces = [];
  List<DieModel> _diesInFurnace = [];
  List<PressModel> _presses = [];
  bool _isLoading = true;
  String? _lastMessage;
  bool _isMessageSuccess = true;

  final TextEditingController _furnaceNameController = TextEditingController();
  final TextEditingController _targetTempController = TextEditingController();
  final TextEditingController _hollowTimeController = TextEditingController();
  final TextEditingController _solidTimeController = TextEditingController();
  String? _selectedPressId;

  final TextEditingController _startTempController = TextEditingController();
  final TextEditingController _endTempController = TextEditingController();
  final TextEditingController _maxTempController = TextEditingController();
  final TextEditingController _minTempController = TextEditingController();
  final TextEditingController _cycleNotesController = TextEditingController();
  String? _selectedFurnaceId;

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
      _furnaces = List.from(_provider.furnaces);
      _presses = List.from(_provider.presses);
      
      _diesInFurnace = [];
      for (var shift in _provider.allShifts) {
        for (var die in shift.dies) {
          if (die.furnaceId != null && die.furnaceId!.isNotEmpty && !die.isFurnaceReady) {
            _diesInFurnace.add(die);
          }
        }
      }
      
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      Fluttertoast.showToast(
        msg: AppStrings.trStaticP('load_data_error', {'e': e.toString()}),
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  bool _canManagePress(String pressId) {
    final user = _provider.currentUser;
    if (user == null) return false;
    if (user.isDeveloper) return true;
    if (user.isOwner) return true;
    if (user.isManager) return true;
    if (user.isSupervisor) {
      return user.assignedPressId == pressId;
    }
    return false;
  }

  Future<void> _reloadAfterFurnaceAction({FurnaceModel? optimistic}) async {
    if (optimistic != null) {
      setState(() {
        final idx = _furnaces.indexWhere((f) => f.id == optimistic.id);
        if (idx >= 0) {
          _furnaces[idx] = optimistic;
        } else {
          _furnaces.add(optimistic);
        }
      });
    }
    await _loadData();
    try {
      final freshFurnaces = await _provider.service.getFurnaces(_provider.currentFactoryId);
      if (mounted) {
        setState(() {
          if (optimistic != null && !freshFurnaces.any((f) => f.id == optimistic.id)) {
            _furnaces = [...freshFurnaces, optimistic];
          } else {
            _furnaces = freshFurnaces;
          }
        });
      }
    } catch (e) {
      print(AppStrings.trStaticP('live_update_error', {'e': e.toString()}));
    }
  }

  Future<void> _addFurnace() async {
    final name = _furnaceNameController.text.trim();
    final targetTemp = double.tryParse(_targetTempController.text);
    final hollowTime = double.tryParse(_hollowTimeController.text) ?? 210.0;
    final solidTime = double.tryParse(_solidTimeController.text) ?? 120.0;

    if (name.isEmpty) {
      setState(() {
        _lastMessage = AppStrings.trStatic('furnace_name_required');
        _isMessageSuccess = false;
      });
      return;
    }

    if (targetTemp == null || targetTemp <= 0) {
      setState(() {
        _lastMessage = AppStrings.trStatic('target_temp_required');
        _isMessageSuccess = false;
      });
      return;
    }

    if (_selectedPressId == null || _selectedPressId!.isEmpty) {
      setState(() {
        _lastMessage = AppStrings.trStatic('press_required');
        _isMessageSuccess = false;
      });
      return;
    }

    if (!_canManagePress(_selectedPressId!)) {
      setState(() {
        _lastMessage = AppStrings.trStatic('no_permission_furnace');
        _isMessageSuccess = false;
      });
      return;
    }

    PressModel? press;
    try {
      press = _presses.firstWhere((p) => p.id == _selectedPressId);
    } catch (e) {
      press = null;
    }

    if (press == null) {
      setState(() {
        _lastMessage = AppStrings.trStatic('press_not_found');
        _isMessageSuccess = false;
      });
      return;
    }

    FurnaceModel? existingFurnace;
    try {
      existingFurnace = _furnaces.firstWhere((f) => f.pressId == _selectedPressId);
    } catch (e) {
      existingFurnace = null;
    }

    if (existingFurnace != null) {
      setState(() {
        _lastMessage = AppStrings.trStaticP('furnace_exists', {'press': press!.name, 'name': existingFurnace!.name});
        _isMessageSuccess = false;
      });
      return;
    }

    try {
      final newFurnace = FurnaceModel(
        id: 'furnace_${press!.id}',
        name: name,
        factoryId: _provider.currentFactoryId,
        targetTemperature: targetTemp,
        createdAt: DateTime.now(),
        supervisorId: _provider.currentUserUid,
        hollowHeatingTime: hollowTime,
        solidHeatingTime: solidTime,
        pressId: press!.id,
        pressName: press!.name,
        isActive: true,
      );

      await _provider.service.saveFurnace(_provider.currentFactoryId, newFurnace);
      
      _furnaceNameController.clear();
      _targetTempController.clear();
      _hollowTimeController.clear();
      _solidTimeController.clear();
      _selectedPressId = null;
      
      await _reloadAfterFurnaceAction(optimistic: newFurnace);

      setState(() {
        _lastMessage = AppStrings.trStaticP('furnace_added', {'name': name, 'press': press!.name});
        _isMessageSuccess = true;
      });

      Fluttertoast.showToast(
        msg: AppStrings.trStaticP('furnace_added', {'name': name, 'press': press!.name}),
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
    } catch (e) {
      setState(() {
        _lastMessage = AppStrings.trStaticP('error_prefix', {'e': e.toString()});
        _isMessageSuccess = false;
      });
      Fluttertoast.showToast(
        msg: AppStrings.trStaticP('error_prefix', {'e': e.toString()}),
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  Future<void> _startFurnace(FurnaceModel furnace) async {
    final startTemp = double.tryParse(_startTempController.text);
    if (startTemp == null || startTemp <= 0) {
      setState(() {
        _lastMessage = AppStrings.trStatic('start_temp_required');
        _isMessageSuccess = false;
      });
      return;
    }

    try {
      final updatedFurnace = furnace.startCycle(
        startTemperature: startTemp,
        supervisorId: _provider.currentUserUid,
        supervisorName: _provider.currentUser?.name,
        notes: _cycleNotesController.text,
      );
      
      await _provider.service.saveFurnace(_provider.currentFactoryId, updatedFurnace);
      _startTempController.clear();
      _cycleNotesController.clear();
      await _reloadAfterFurnaceAction(optimistic: updatedFurnace);

      setState(() {
        _lastMessage = AppStrings.trStaticP('furnace_started', {'name': furnace.name});
        _isMessageSuccess = true;
      });

      Fluttertoast.showToast(
        msg: AppStrings.trStaticP('furnace_started', {'name': furnace.name}),
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
    } catch (e) {
      setState(() {
        _lastMessage = AppStrings.trStaticP('error_prefix', {'e': e.toString()});
        _isMessageSuccess = false;
      });
      Fluttertoast.showToast(
        msg: AppStrings.trStaticP('error_prefix', {'e': e.toString()}),
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  Future<void> _stopFurnace(FurnaceModel furnace) async {
    final endTemp = double.tryParse(_endTempController.text);
    if (endTemp == null || endTemp <= 0) {
      setState(() {
        _lastMessage = AppStrings.trStatic('end_temp_required');
        _isMessageSuccess = false;
      });
      return;
    }

    final maxTemp = double.tryParse(_maxTempController.text);
    final minTemp = double.tryParse(_minTempController.text);

    try {
      final updatedFurnace = furnace.endCycle(
        endTemperature: endTemp,
        maxTemperature: maxTemp,
        minTemperature: minTemp,
        notes: _cycleNotesController.text,
      );
      
      await _provider.service.saveFurnace(_provider.currentFactoryId, updatedFurnace);
      _endTempController.clear();
      _maxTempController.clear();
      _minTempController.clear();
      _cycleNotesController.clear();
      await _reloadAfterFurnaceAction(optimistic: updatedFurnace);

      setState(() {
        _lastMessage = AppStrings.trStaticP('furnace_stopped', {'name': furnace.name});
        _isMessageSuccess = true;
      });

      Fluttertoast.showToast(
        msg: AppStrings.trStaticP('furnace_stopped', {'name': furnace.name}),
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
    } catch (e) {
      setState(() {
        _lastMessage = AppStrings.trStaticP('error_prefix', {'e': e.toString()});
        _isMessageSuccess = false;
      });
      Fluttertoast.showToast(
        msg: AppStrings.trStaticP('error_prefix', {'e': e.toString()}),
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  Future<void> _deleteFurnace(FurnaceModel furnace) async {
    if (!_canManagePress(furnace.pressId)) {
      Fluttertoast.showToast(
        msg: AppStrings.trStatic('no_permission_delete_furnace'),
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('confirm_delete_title')),
        content: Text(context.trP('delete_furnace_confirm', {'name': furnace.name})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _provider.service.deleteFurnace(_provider.currentFactoryId, furnace.id);
                await _reloadAfterFurnaceAction();
                setState(() {
                  _lastMessage = AppStrings.trStaticP('furnace_deleted', {'name': furnace.name});
                  _isMessageSuccess = true;
                });
                Fluttertoast.showToast(
                  msg: AppStrings.trStaticP('furnace_deleted', {'name': furnace.name}),
                  backgroundColor: Colors.red,
                  textColor: Colors.white,
                );
              } catch (e) {
                setState(() {
                  _lastMessage = AppStrings.trStaticP('error_prefix', {'e': e.toString()});
                  _isMessageSuccess = false;
                });
                Fluttertoast.showToast(
                  msg: AppStrings.trStaticP('error_prefix', {'e': e.toString()}),
                  backgroundColor: Colors.red,
                  textColor: Colors.white,
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(context.tr('delete_word'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showStartFurnaceDialog(FurnaceModel furnace) {
    _selectedFurnaceId = furnace.id;
    _startTempController.clear();
    _cycleNotesController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.trP('start_furnace_dialog', {'name': furnace.name})),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.tr('enter_start_temp')),
            const SizedBox(height: 8),
            TextFormField(
              controller: _startTempController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: context.tr('start_temp_label'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _cycleNotesController,
              decoration: InputDecoration(
                labelText: context.tr('notes_optional_label'),
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
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
              _startFurnace(furnace);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text(context.tr('start_furnace_btn')),
          ),
        ],
      ),
    );
  }

  void _showStopFurnaceDialog(FurnaceModel furnace) {
    _selectedFurnaceId = furnace.id;
    _endTempController.clear();
    _maxTempController.clear();
    _minTempController.clear();
    _cycleNotesController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.trP('stop_furnace_dialog', {'name': furnace.name})),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.tr('cycle_end_data')),
            const SizedBox(height: 8),
            TextFormField(
              controller: _endTempController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: context.tr('end_temp_label'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _maxTempController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: context.tr('max_temp_label'),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _minTempController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: context.tr('min_temp_label'),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _cycleNotesController,
              decoration: InputDecoration(
                labelText: context.tr('notes_optional_label'),
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
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
              _stopFurnace(furnace);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(context.tr('stop_furnace_btn')),
          ),
        ],
      ),
    );
  }

  final TextEditingController _updateTempController = TextEditingController();

  void _showUpdateTemperatureDialog(FurnaceModel furnace) {
    _updateTempController.text = furnace.currentTemperature > 0
        ? furnace.currentTemperature.toStringAsFixed(0)
        : '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.trP('update_temp_dialog', {'name': furnace.name})),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.trP('target_temp_now', {'v': '${furnace.targetTemperature}'})),
            const SizedBox(height: 8),
            TextFormField(
              controller: _updateTempController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: context.tr('current_temp_now'),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              final temp = double.tryParse(_updateTempController.text);
              if (temp == null || temp < 0) {
                Fluttertoast.showToast(
                  msg: AppStrings.trStatic('invalid_temp_warning'),
                  backgroundColor: Colors.orange,
                  textColor: Colors.white,
                );
                return;
              }
              Navigator.pop(context);
              try {
                final updatedFurnace = furnace.updateTemperature(temp);
                await _provider.service.saveFurnace(_provider.currentFactoryId, updatedFurnace);
                Fluttertoast.showToast(
                  msg: AppStrings.trStaticP('temp_updated', {'v': '$temp'}),
                  backgroundColor: Colors.green,
                  textColor: Colors.white,
                );
                await _reloadAfterFurnaceAction(optimistic: updatedFurnace);
              } catch (e) {
                Fluttertoast.showToast(
                  msg: AppStrings.trStaticP('temp_update_failed', {'e': e.toString()}),
                  backgroundColor: Colors.red,
                  textColor: Colors.white,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: Text(context.tr('update_temp_btn')),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(FurnaceStatus status) {
    switch (status) {
      case FurnaceStatus.idle: return Colors.grey;
      case FurnaceStatus.heating: return Colors.orange;
      case FurnaceStatus.holding: return Colors.green;
      case FurnaceStatus.cooling: return Colors.blue;
      case FurnaceStatus.error: return Colors.red;
    }
  }

  String _getStatusText(FurnaceStatus status) {
    switch (status) {
      case FurnaceStatus.idle: return AppStrings.trStatic('idle_status');
      case FurnaceStatus.heating: return AppStrings.trStatic('heating_status');
      case FurnaceStatus.holding: return AppStrings.trStatic('stabilizing_status');
      case FurnaceStatus.cooling: return AppStrings.trStatic('cooling_status');
      case FurnaceStatus.error: return AppStrings.trStatic('error_word');
    }
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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

  Widget _statItem(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _furnaceNameController.dispose();
    _targetTempController.dispose();
    _hollowTimeController.dispose();
    _solidTimeController.dispose();
    _startTempController.dispose();
    _endTempController.dispose();
    _maxTempController.dispose();
    _minTempController.dispose();
    _cycleNotesController.dispose();
    _updateTempController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final readyCount = _diesInFurnace.where((die) {
      final furnace = _provider.getFurnaceById(die.furnaceId ?? '');
      return furnace != null ? die.isReady(furnace) : false;
    }).length;
    
    final notReadyCount = _diesInFurnace.length - readyCount;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('manage_furnaces_menu')),
        backgroundColor: Colors.orange,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: context.tr('refresh_plain'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.grey.shade100,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _statItem(context.tr('ready_stat'), '$readyCount', Colors.green),
                        _statItem(context.tr('not_ready_stat'), '$notReadyCount', Colors.red),
                        _statItem(context.tr('furnaces_stat'), '${_furnaces.length}', Colors.orange),
                      ],
                    ),
                  ),
                  
                  TabBar(
                    tabs: [
                      Tab(text: context.tr('furnaces_tab'), icon: const Icon(Icons.fireplace)),
                      Tab(text: context.tr('dies_in_furnace_tab'), icon: const Icon(Icons.inventory)),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildFurnacesTab(),
                        _buildDiesInFurnaceTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildFurnacesTab() {
    return Column(
      children: [
        Card(
          color: Colors.orange.shade50,
          margin: const EdgeInsets.all(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.add, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text(
                      context.tr('add_new_furnace'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _furnaceNameController,
                        decoration: InputDecoration(
                          labelText: context.tr('furnace_name_label'),
                          border: const OutlineInputBorder(),
                          isDense: true,
                          hintText: context.tr('furnace_name_hint'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _targetTempController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: context.tr('target_temp_c_label'),
                          border: const OutlineInputBorder(),
                          isDense: true,
                          hintText: '480',
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
                        controller: _hollowTimeController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: context.tr('hollow_time_label'),
                          border: const OutlineInputBorder(),
                          isDense: true,
                          hintText: '210',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _solidTimeController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: context.tr('solid_time_label'),
                          border: const OutlineInputBorder(),
                          isDense: true,
                          hintText: '120',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedPressId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: context.tr('related_press_label'),
                    border: const OutlineInputBorder(),
                    isDense: true,
                    helperText: context.tr('related_press_helper'),
                  ),
                  items: _presses.map((press) => 
                    DropdownMenuItem(
                      value: press.id,
                      child: Text(press.name),
                    )
                  ).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedPressId = value;
                    });
                  },
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _addFurnace,
                    icon: const Icon(Icons.add),
                    label: Text(context.tr('add_furnace_btn')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                if (_lastMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _isMessageSuccess ? Colors.green.shade50 : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _isMessageSuccess ? Colors.green.shade300 : Colors.red.shade300,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isMessageSuccess ? Icons.check_circle : Icons.error,
                            color: _isMessageSuccess ? Colors.green : Colors.red,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _lastMessage!,
                              style: TextStyle(
                                color: _isMessageSuccess ? Colors.green.shade800 : Colors.red.shade800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () {
                              setState(() {
                                _lastMessage = null;
                              });
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
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
            child: _furnaces.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.fireplace, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          context.tr('no_furnaces_msg'),
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                        ),
                        Text(
                          context.tr('no_furnaces_hint'),
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _furnaces.length,
                    itemBuilder: (context, index) {
                      final furnace = _furnaces[index];
                      
                      final furnaceDies = _diesInFurnace
                          .where((die) => die.furnaceId == furnace.id)
                          .toList();
                      
                      final readyDies = furnaceDies.where((die) => die.isReady(furnace)).length;
                      final totalDies = furnaceDies.length;
                      
                      final currentCycle = furnace.currentCycle;
                      final statusColor = _getStatusColor(furnace.status);
                      final statusText = _getStatusText(furnace.status);
                      
                      final canManage = _canManagePress(furnace.pressId);
                      final isActive = furnace.isActive;

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: statusColor,
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(
                                furnace.name,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isActive ? Colors.green.shade100 : Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  isActive ? AppStrings.trStatic('active_status') : AppStrings.trStatic('inactive_status'),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isActive ? Colors.green : Colors.red,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '📏 ${furnace.pressName}',
                                  style: TextStyle(fontSize: 10, color: Colors.blue.shade700),
                                ),
                              ),
                              if (!canManage)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    '🔒',
                                    style: TextStyle(fontSize: 10),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('$statusText'),
                              Text(context.trP('furnace_temps_line', {'t': '${furnace.targetTemperature}', 'c': '${furnace.currentTemperature}'})),
                              Text(context.trP('furnace_times_line', {'h': '${furnace.hollowHeatingTime}', 's': '${furnace.solidHeatingTime}'})),
                              Text(context.trP('furnace_dies_line', {'d': '$totalDies', 'r': '$readyDies'})),
                              if (currentCycle != null)
                                Text(
                                  '⏱️ ${currentCycle.durationFormatted}',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.inventory, color: Colors.blue),
                                onPressed: () {
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
                                tooltip: context.tr('view_dies_in_furnace_tip'),
                              ),
                              if (canManage) ...[
                                if (furnace.status == FurnaceStatus.idle)
                                  IconButton(
                                    icon: const Icon(Icons.play_circle, color: Colors.green),
                                    onPressed: () => _showStartFurnaceDialog(furnace),
                                    tooltip: context.tr('start_furnace_tip'),
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.thermostat, color: Colors.orange),
                                  onPressed: () => _showUpdateTemperatureDialog(furnace),
                                  tooltip: context.tr('update_current_temp_tip'),
                                ),
                                if (furnace.status == FurnaceStatus.heating || furnace.status == FurnaceStatus.holding)
                                  IconButton(
                                    icon: const Icon(Icons.stop_circle, color: Colors.red),
                                    onPressed: () => _showStopFurnaceDialog(furnace),
                                    tooltip: context.trP('stop_furnace_dialog', {'name': furnace.name}),
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteFurnace(furnace),
                                  tooltip: context.tr('delete_word'),
                                ),
                              ],
                            ],
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _infoRow(context.tr('details_press'), furnace.pressName),
                                  _infoRow(context.tr('details_target'), '${furnace.targetTemperature}°C'),
                                  _infoRow(context.tr('details_current'), '${furnace.currentTemperature}°C'),
                                  _infoRow(context.tr('details_hollow'), '${furnace.hollowHeatingTime} ${context.tr('minute_unit')}'),
                                  _infoRow(context.tr('details_solid'), '${furnace.solidHeatingTime} ${context.tr('minute_unit')}'),
                                  _infoRow(context.tr('details_dies_count'), AppStrings.trStaticP('cage_count_badge', {'n': '$totalDies'})),
                                  _infoRow(context.tr('details_ready_count'), AppStrings.trStaticP('cage_count_badge', {'n': '$readyDies'})),
                                  _infoRow(context.tr('details_created'), DateFormat('yyyy-MM-dd HH:mm').format(furnace.createdAt)),
                                  _infoRow(context.tr('details_status'), _getStatusText(furnace.status)),
                                  _infoRow(context.tr('details_active'), isActive ? AppStrings.trStatic('active_status') : AppStrings.trStatic('inactive_status')),
                                  
                                  if (totalDies > 0) ...[
                                    const Divider(),
                                    Text(
                                      context.tr('dies_in_this_furnace'),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    const SizedBox(height: 4),
                                    ...furnaceDies.map((die) {
                                      final isReady = die.isReady(furnace);
                                      return ListTile(
                                        dense: true,
                                        leading: Icon(
                                          isReady ? Icons.check_circle : Icons.timer,
                                          color: isReady ? Colors.green : Colors.orange,
                                          size: 16,
                                        ),
                                        title: Text(
                                          die.name,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isReady ? Colors.green : Colors.orange,
                                          ),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              isReady 
                                                  ? context.tr('ready_for_pressing_short') 
                                                  : '⏳ ${die.getRemainingTimeFormatted(furnace)}',
                                              style: const TextStyle(fontSize: 10),
                                            ),
                                            if (die.furnaceEntryTime != null)
                                              Text(
                                                context.trP('entry_at', {'v': DateFormat('yyyy-MM-dd HH:mm').format(die.furnaceEntryTime!)}),
                                                style: const TextStyle(fontSize: 9, color: Colors.blue),
                                              ),
                                            if (die.furnaceExitTime != null)
                                              Text(
                                                context.trP('exit_at', {'v': DateFormat('yyyy-MM-dd HH:mm').format(die.furnaceExitTime!)}),
                                                style: const TextStyle(fontSize: 9, color: Colors.green),
                                              ),
                                            Text(
                                              context.trP('required_heating_at', {'v': '${die.getRequiredHeatingTime(furnace)}'}),
                                              style: const TextStyle(fontSize: 9, color: Colors.grey),
                                            ),
                                            Text(
                                              context.trP('dims_at', {'v': die.dimensionsFormatted}),
                                              style: const TextStyle(fontSize: 9, color: Colors.purple),
                                            ),
                                          ],
                                        ),
                                        trailing: Text(
                                          '${die.dieType == "hollow" ? AppStrings.trStatic('hollow_word') : AppStrings.trStatic('solid_word')}',
                                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                                        ),
                                      );
                                    }),
                                  ],
                                  
                                  if (furnace.cycles.isNotEmpty) ...[
                                    const Divider(),
                                    Text(
                                      context.tr('previous_cycles'),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    const SizedBox(height: 4),
                                    ...furnace.cycles.reversed.map((cycle) {
                                      return Card(
                                        margin: const EdgeInsets.symmetric(vertical: 2),
                                        child: ListTile(
                                          dense: true,
                                          leading: Icon(
                                            cycle.isActive ? Icons.play_circle : Icons.check_circle,
                                            color: cycle.isActive ? Colors.green : Colors.grey,
                                            size: 16,
                                          ),
                                          title: Text(
                                            '${cycle.startTemperature}°C → ${cycle.endTemperature?.toStringAsFixed(1) ?? '...'}°C',
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                          subtitle: Text(
                                            context.trP('cycle_summary_ext', {'t': '${cycle.targetTemperature}', 'd': cycle.durationFormatted, 'n': '${cycle.dieIds.length}'}),
                                            style: const TextStyle(fontSize: 10),
                                          ),
                                        ),
                                      );
                                    }),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildDiesInFurnaceTab() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.tr('all_dies_in_furnaces'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        AppStrings.trStaticP('cage_count_badge', {'n': '${_diesInFurnace.length}'}),
                        style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _diesInFurnace.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inventory, size: 64, color: Colors.grey.shade300),
                              const SizedBox(height: 16),
                              Text(
                                context.tr('no_dies_in_furnace'),
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                context.tr('add_die_from_furnace_hint'),
                                style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _diesInFurnace.length,
                          itemBuilder: (context, index) {
                            final die = _diesInFurnace[index];
                            final furnace = _provider.getFurnaceById(die.furnaceId ?? '');
                            final isReady = furnace != null ? die.isReady(furnace) : false;
                            final remaining = furnace != null ? die.getRemainingTimeFormatted(furnace) : AppStrings.trStatic('unknown_word');
                            final press = _provider.getPressById(die.pressId);
                            final elapsedMinutes = die.furnaceEntryTime != null
                                ? DateTime.now().difference(die.furnaceEntryTime!).inMinutes
                                : 0;
                            final elapsedHours = (elapsedMinutes / 60).toStringAsFixed(1);

                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border(
                                    left: BorderSide(
                                      color: isReady ? Colors.green : Colors.red,
                                      width: 4,
                                    ),
                                  ),
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: isReady ? Colors.green : Colors.red,
                                    child: Icon(
                                      isReady ? Icons.check : Icons.timer,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                  title: Text(
                                    die.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isReady ? Colors.green : Colors.red,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('📏 ${press?.name ?? die.pressId}'),
                                      Text('🔥 ${furnace?.name ?? die.furnaceId}'),
                                      Text('🔧 ${die.dieType == "hollow" ? AppStrings.trStatic('hollow_word') : AppStrings.trStatic('solid_word')}'),
                                      Text(context.trP('dims_at', {'v': die.dimensionsFormatted})),
                                      Text(context.trP('heating_time_line', {'v': furnace != null ? '${die.getRequiredHeatingTime(furnace)}' : AppStrings.trStatic('unknown_word')})),
                                      Text(context.trP('elapsed_hours_at', {'v': '$elapsedHours'})),
                                      
                                      if (die.furnaceEntryTime != null)
                                        Text(
                                          context.trP('entry_at', {'v': DateFormat('yyyy-MM-dd HH:mm').format(die.furnaceEntryTime!)}),
                                          style: const TextStyle(fontSize: 10, color: Colors.blue),
                                        ),
                                      
                                      if (die.furnaceExitTime != null)
                                        Text(
                                          context.trP('exit_at', {'v': DateFormat('yyyy-MM-dd HH:mm').format(die.furnaceExitTime!)}),
                                          style: const TextStyle(fontSize: 10, color: Colors.green),
                                        ),
                                      
                                      Text(
                                        isReady 
                                            ? context.tr('ready_for_pressing_short') 
                                            : context.trP('remaining_label', {'v': remaining}),
                                        style: TextStyle(
                                          color: isReady ? Colors.green : Colors.orange,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => FurnaceDiesScreen(
                                            pressId: die.furnacePressId,
                                            pressName: press?.name,
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.visibility, size: 14),
                                    label: Text(context.tr('view_btn'), style: const TextStyle(fontSize: 10)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      minimumSize: const Size(0, 28),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}