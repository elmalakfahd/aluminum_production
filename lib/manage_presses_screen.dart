import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'models.dart';
import 'services.dart';
import 'app_localization.dart';

class ManagePressesScreen extends StatefulWidget {
  const ManagePressesScreen({super.key});

  @override
  State<ManagePressesScreen> createState() => _ManagePressesScreenState();
}

class _ManagePressesScreenState extends State<ManagePressesScreen> {
  late ShiftProvider _provider;
  List<PressModel> _presses = [];
  bool _isLoading = true;

  final TextEditingController _newPressNameController = TextEditingController();
  String _selectedSize = '7 بوصة';

  // ✅ إضافة حقل للقطر المخصص (بوصة)
  final TextEditingController _customDiameterController = TextEditingController();
  bool _useCustomDiameter = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _provider = Provider.of<ShiftProvider>(context, listen: false);
      _loadPresses();
    });
  }

  Future<void> _loadPresses() async {
    setState(() => _isLoading = true);
    try {
      await _provider.loadAllData();
      setState(() {
        _presses = List.from(_provider.presses);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      Fluttertoast.showToast(
        msg: 'خطأ في تحميل المكابس: $e',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  Future<void> _addPress() async {
    final name = _newPressNameController.text.trim();
    if (name.isEmpty) {
      Fluttertoast.showToast(
        msg: context.tr('enter_press_name_warning'),
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
      return;
    }

    if (_presses.any((p) => p.name == name)) {
      Fluttertoast.showToast(
        msg: context.tr('press_name_exists_warning'),
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
      return;
    }

    double diameter;
    if (_useCustomDiameter) {
      diameter = double.tryParse(_customDiameterController.text) ?? 0;
      if (diameter <= 0) {
        Fluttertoast.showToast(
          msg: context.tr('enter_valid_diameter_warning'),
          backgroundColor: Colors.orange,
          textColor: Colors.white,
        );
        return;
      }
    } else {
      switch (_selectedSize) {
        case '5 بوصة': diameter = 5.0; break;
        case '6 بوصة': diameter = 6.0; break;
        case '7 بوصة': diameter = 7.0; break;
        case '8 بوصة': diameter = 8.0; break;
        case '9 بوصة': diameter = 9.0; break;
        case '10 بوصة': diameter = 10.0; break;
        case '11 بوصة': diameter = 11.0; break;
        default: diameter = 7.0;
      }
    }

    final defaultTarget = PressModel.calculateTargetTonsPerHourFromDiameter(diameter);

    final newPress = PressModel(
      id: 'press_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      size: '${diameter.toStringAsFixed(1)} بوصة',
      diameterInInches: diameter,
      isActive: true,
      targetTonsPerHour: defaultTarget,
    );

    try {
      await _provider.service.savePress(_provider.currentFactoryId, newPress);
      _newPressNameController.clear();
      _customDiameterController.clear();
      _useCustomDiameter = false;
      await _loadPresses();
      Fluttertoast.showToast(
        msg: '✅ ${context.tr('press_added_success')}: $name',
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: '❌ ${context.tr('error_generic')}: $e',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  Future<void> _deletePress(PressModel press) async {
    if (_provider.hasActiveShiftForPress(press.id)) {
      Fluttertoast.showToast(
        msg: context.tr('cannot_delete_active_press_warning'),
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('confirm_delete_title')),
        content: Text('${context.tr('confirm_delete_press_body')} "${press.name}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _provider.service.deletePress(_provider.currentFactoryId, press.id);
                await _loadPresses();
                Fluttertoast.showToast(
                  msg: '✅ ${context.tr('press_deleted_success')}: ${press.name}',
                  backgroundColor: Colors.red,
                  textColor: Colors.white,
                );
              } catch (e) {
                Fluttertoast.showToast(
                  msg: '❌ ${context.tr('error_generic')}: $e',
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

  Future<void> _editPressName(PressModel press) async {
    final controller = TextEditingController(text: press.name);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${context.tr('edit_press_title')}: ${press.size}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.tr('enter_new_press_name')),
            const SizedBox(height: 8),
            TextFormField(
              controller: controller,
              decoration: InputDecoration(
                labelText: context.tr('press_name_label'),
                border: OutlineInputBorder(),
                hintText: context.tr('press_name_hint'),
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
              final newName = controller.text.trim();
              if (newName.isEmpty) {
                Fluttertoast.showToast(
                  msg: context.tr('enter_press_name_warning'),
                  backgroundColor: Colors.orange,
                  textColor: Colors.white,
                );
                return;
              }

              if (_presses.any((p) => p.id != press.id && p.name == newName)) {
                Fluttertoast.showToast(
                  msg: context.tr('press_name_exists_warning'),
                  backgroundColor: Colors.orange,
                  textColor: Colors.white,
                );
                return;
              }

              Navigator.pop(context);
              
              final updatedPress = PressModel(
                id: press.id,
                name: newName,
                size: press.size,
                diameterInInches: press.diameterInInches,
                isActive: press.isActive,
                targetTonsPerHour: press.targetTonsPerHour,
              );

              try {
                await _provider.service.savePress(_provider.currentFactoryId, updatedPress);
                await _loadPresses();
                Fluttertoast.showToast(
                  msg: '✅ ${context.tr('press_updated_success')}',
                  backgroundColor: Colors.green,
                  textColor: Colors.white,
                );
              } catch (e) {
                Fluttertoast.showToast(
                  msg: '❌ ${context.tr('error_generic')}: $e',
                  backgroundColor: Colors.red,
                  textColor: Colors.white,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: Text(context.tr('save_word')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ShiftProvider>(context);
    
    if (!provider.isDeveloper && !provider.isOwner && !provider.isManager) {
      return Scaffold(
        appBar: AppBar(
          title: Text(context.tr('not_authorized')),
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

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('manage_presses_title')),
        backgroundColor: Colors.blue,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPresses,
            tooltip: context.tr('refresh_plain'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ✅ نموذج إضافة مكبس جديد مع حقل القطر المخصص
                Card(
                  color: Colors.blue.shade50,
                  margin: const EdgeInsets.all(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.add_circle, color: Colors.blue),
                            const SizedBox(width: 8),
                            Text(
                              context.tr('add_new_press'),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _newPressNameController,
                          decoration: InputDecoration(
                            labelText: context.tr('press_name_label'),
                            border: const OutlineInputBorder(),
                            isDense: true,
                            hintText: context.tr('press_name_hint'),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          context.tr('same_diameter_multi_press_hint'),
                          style: TextStyle(fontSize: 11, color: Colors.blue.shade700),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedSize,
                                decoration: InputDecoration(
                                  labelText: context.tr('diameter_label'),
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                ),
                                items: PressModel.getPressSizes().map((size) =>
                                  DropdownMenuItem(
                                    value: size,
                                    child: Text(PressModel.displaySizeFromRaw(size)),
                                  )
                                ).toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _selectedSize = value;
                                      _useCustomDiameter = false;
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: _useCustomDiameter,
                                    onChanged: (value) {
                                      setState(() {
                                        _useCustomDiameter = value ?? false;
                                      });
                                    },
                                  ),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _customDiameterController,
                                      keyboardType: TextInputType.number,
                                      enabled: _useCustomDiameter,
                                      decoration: InputDecoration(
                                        labelText: context.tr('custom_diameter_label'),
                                        border: const OutlineInputBorder(),
                                        isDense: true,
                                        hintText: '7.5',
                                        suffixText: context.tr('inch_suffix').trim(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info, color: Colors.grey),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  context.tr('press_target_auto_hint'),
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _addPress,
                            icon: const Icon(Icons.add),
                            label: Text(context.tr('add_press_button'), style: const TextStyle(fontSize: 14)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // ✅ قائمة المكابس
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              context.tr('presses_list_title'),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${_presses.length} ${context.tr('press_count_suffix')}',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: _presses.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.settings, size: 64, color: Colors.grey.shade300),
                                      const SizedBox(height: 16),
                                      Text(
                                        context.tr('no_presses_message'),
                                        style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                                      ),
                                      Text(
                                        context.tr('add_press_hint'),
                                        style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _presses.length,
                                  itemBuilder: (context, index) {
                                    final press = _presses[index];
                                    final hasActiveShift = _provider.hasActiveShiftForPress(press.id);
                                    final shift = _provider.getShiftForPress(press.id);
                                    
                                    return Card(
                                      margin: const EdgeInsets.symmetric(vertical: 4),
                                      child: ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: hasActiveShift ? Colors.green : Colors.grey,
                                          child: Text(
                                            press.diameterInInches.toStringAsFixed(1),
                                            style: const TextStyle(color: Colors.white, fontSize: 12),
                                          ),
                                        ),
                                        title: Text(
                                          press.name,
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(context.trP('press_size_label', {'size': press.sizeLabel})),
                                            Text('${context.tr('diameter_label')}: ${press.diameterInInches.toStringAsFixed(1)} ${context.tr('inch_suffix').trim()}'),
                                            if (hasActiveShift && shift != null)
                                              Text(
                                                '🟢 ${context.tr('active_shift_label')} #${shift.shiftNumber} - ${context.tr('supervisor_label_short')}: ${shift.supervisor}',
                                                style: const TextStyle(color: Colors.green, fontSize: 12),
                                              )
                                            else
                                              Text(
                                                '⚪ ${context.tr('no_active_shift_label')}',
                                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                                              ),
                                          ],
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                              onPressed: () => _editPressName(press),
                                              tooltip: context.tr('edit_press_tooltip'),
                                            ),
                                            if (!hasActiveShift)
                                              IconButton(
                                                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                                onPressed: () => _deletePress(press),
                                                tooltip: context.tr('delete_press_tooltip'),
                                              ),
                                          ],
                                        ),
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
}