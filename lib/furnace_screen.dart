import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'models.dart';
import 'services.dart';
import 'furnace_dies_screen.dart';

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
        msg: 'خطأ في تحميل البيانات: $e',
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

  // ✅ إضافة فرن جديد (نشط تلقائياً)
  // ✅ تحديث "مضمون" للأفران بعد أي عملية عليها (إضافة/تشغيل/إيقاف/حذف/تحديث حرارة)
  // بيعمل تحميل كامل عادي، وبعدين تحديث مباشر للأفران وحدها من قاعدة البيانات،
  // عشان لو أي جزء تاني في التحميل الكامل (مستخدمين/ورديات/قوالب) فشل بصمت،
  // الأفران المعروضة تفضل مطابقة لقاعدة البيانات فعلياً ومتختفيش.
  // [optimistic] هو آخر نسخة معروفة للفرن اللي عملنا عليها save بنجاح؛ لو قراءة السيرفر
  // (لأي تأخير في الشبكة) لسه ما استلمتهاش، بنفضل نعرضها بدل ما تختفي من الشاشة.
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
            // السيرفر لسه ما رجّعش آخر نسخة (تأخير شبكة بسيط) - منسيبش الفرن يختفي
            _furnaces = [...freshFurnaces, optimistic];
          } else {
            _furnaces = freshFurnaces;
          }
        });
      }
    } catch (e) {
      print('⚠️ خطأ في التحديث المباشر للأفران: $e');
    }
  }

  Future<void> _addFurnace() async {
    final name = _furnaceNameController.text.trim();
    final targetTemp = double.tryParse(_targetTempController.text);
    final hollowTime = double.tryParse(_hollowTimeController.text) ?? 210.0;
    final solidTime = double.tryParse(_solidTimeController.text) ?? 120.0;

    if (name.isEmpty) {
      setState(() {
        _lastMessage = '⚠️ الرجاء إدخال اسم الفرن';
        _isMessageSuccess = false;
      });
      return;
    }

    if (targetTemp == null || targetTemp <= 0) {
      setState(() {
        _lastMessage = '⚠️ الرجاء إدخال درجة حرارة مستهدفة صحيحة';
        _isMessageSuccess = false;
      });
      return;
    }

    if (_selectedPressId == null || _selectedPressId!.isEmpty) {
      setState(() {
        _lastMessage = '⚠️ الرجاء اختيار المكبس المرتبط بالفرن';
        _isMessageSuccess = false;
      });
      return;
    }

    if (!_canManagePress(_selectedPressId!)) {
      setState(() {
        _lastMessage = '⚠️ ليس لديك صلاحية لإدارة هذا المكبس';
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
        _lastMessage = '⚠️ المكبس غير موجود';
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
        _lastMessage = '⚠️ يوجد فرن بالفعل للمكبس ${press!.name} (${existingFurnace!.name})';
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
        isActive: true, // ✅ الفرن نشط افتراضياً
      );

      await _provider.service.saveFurnace(_provider.currentFactoryId, newFurnace);
      
      _furnaceNameController.clear();
      _targetTempController.clear();
      _hollowTimeController.clear();
      _solidTimeController.clear();
      _selectedPressId = null;
      
      await _reloadAfterFurnaceAction(optimistic: newFurnace);

      setState(() {
        _lastMessage = '✅ تم إضافة الفرن: $name (للمكبس: ${press!.name}) - الحالة: نشط';
        _isMessageSuccess = true;
      });

      Fluttertoast.showToast(
        msg: '✅ تم إضافة الفرن: $name (للمكبس: ${press!.name})',
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
    } catch (e) {
      setState(() {
        _lastMessage = '❌ خطأ: $e';
        _isMessageSuccess = false;
      });
      Fluttertoast.showToast(
        msg: '❌ خطأ: $e',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  Future<void> _startFurnace(FurnaceModel furnace) async {
    final startTemp = double.tryParse(_startTempController.text);
    if (startTemp == null || startTemp <= 0) {
      setState(() {
        _lastMessage = '⚠️ الرجاء إدخال درجة حرارة البداية';
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
        _lastMessage = '✅ تم تشغيل الفرن ${furnace.name} (دورة تسخين نشطة)';
        _isMessageSuccess = true;
      });

      Fluttertoast.showToast(
        msg: '✅ تم تشغيل الفرن ${furnace.name}',
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
    } catch (e) {
      setState(() {
        _lastMessage = '❌ خطأ: $e';
        _isMessageSuccess = false;
      });
      Fluttertoast.showToast(
        msg: '❌ خطأ: $e',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  Future<void> _stopFurnace(FurnaceModel furnace) async {
    final endTemp = double.tryParse(_endTempController.text);
    if (endTemp == null || endTemp <= 0) {
      setState(() {
        _lastMessage = '⚠️ الرجاء إدخال درجة حرارة النهاية';
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
        _lastMessage = '✅ تم إيقاف الفرن ${furnace.name} (انتهت دورة التسخين)';
        _isMessageSuccess = true;
      });

      Fluttertoast.showToast(
        msg: '✅ تم إيقاف الفرن ${furnace.name}',
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
    } catch (e) {
      setState(() {
        _lastMessage = '❌ خطأ: $e';
        _isMessageSuccess = false;
      });
      Fluttertoast.showToast(
        msg: '❌ خطأ: $e',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  Future<void> _deleteFurnace(FurnaceModel furnace) async {
    if (!_canManagePress(furnace.pressId)) {
      Fluttertoast.showToast(
        msg: '⚠️ ليس لديك صلاحية لحذف هذا الفرن',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف الفرن "${furnace.name}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _provider.service.deleteFurnace(_provider.currentFactoryId, furnace.id);
                await _reloadAfterFurnaceAction();
                setState(() {
                  _lastMessage = '✅ تم حذف الفرن: ${furnace.name}';
                  _isMessageSuccess = true;
                });
                Fluttertoast.showToast(
                  msg: '✅ تم حذف الفرن: ${furnace.name}',
                  backgroundColor: Colors.red,
                  textColor: Colors.white,
                );
              } catch (e) {
                setState(() {
                  _lastMessage = '❌ خطأ: $e';
                  _isMessageSuccess = false;
                });
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

  void _showStartFurnaceDialog(FurnaceModel furnace) {
    _selectedFurnaceId = furnace.id;
    _startTempController.clear();
    _cycleNotesController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('🔥 تشغيل الفرن - ${furnace.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('أدخل درجة حرارة البداية:'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _startTempController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '🌡️ درجة الحرارة (°C)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _cycleNotesController,
              decoration: const InputDecoration(
                labelText: '📝 ملاحظات (اختياري)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
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
            child: const Text('▶️ تشغيل'),
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
        title: Text('⏹️ إيقاف الفرن - ${furnace.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('أدخل بيانات نهاية الدورة:'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _endTempController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '🌡️ درجة الحرارة النهائية (°C)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _maxTempController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '📈 أعلى درجة',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _minTempController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '📉 أدنى درجة',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _cycleNotesController,
              decoration: const InputDecoration(
                labelText: '📝 ملاحظات (اختياري)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
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
            child: const Text('⏹️ إيقاف'),
          ),
        ],
      ),
    );
  }

  // ✅ تحديث الحرارة الحالية للفرن أثناء التسخين/التثبيت
  final TextEditingController _updateTempController = TextEditingController();

  void _showUpdateTemperatureDialog(FurnaceModel furnace) {
    _updateTempController.text = furnace.currentTemperature > 0
        ? furnace.currentTemperature.toStringAsFixed(0)
        : '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('🌡️ تحديث الحرارة - ${furnace.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('الحرارة المستهدفة: ${furnace.targetTemperature}°C'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _updateTempController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '🌡️ الحرارة الحالية الآن (°C)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              final temp = double.tryParse(_updateTempController.text);
              if (temp == null || temp < 0) {
                Fluttertoast.showToast(
                  msg: '⚠️ الرجاء إدخال درجة حرارة صحيحة',
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
                  msg: '✅ تم تحديث الحرارة إلى $temp°C',
                  backgroundColor: Colors.green,
                  textColor: Colors.white,
                );
                await _reloadAfterFurnaceAction(optimistic: updatedFurnace);
              } catch (e) {
                Fluttertoast.showToast(
                  msg: '❌ خطأ في تحديث الحرارة: $e',
                  backgroundColor: Colors.red,
                  textColor: Colors.white,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('تحديث'),
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
      case FurnaceStatus.idle: return '🟤 خامل';
      case FurnaceStatus.heating: return '🟠 تسخين';
      case FurnaceStatus.holding: return '🟢 تثبيت';
      case FurnaceStatus.cooling: return '🔵 تبريد';
      case FurnaceStatus.error: return '🔴 خطأ';
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
  Widget build(BuildContext context) {
    final readyCount = _diesInFurnace.where((die) {
      final furnace = _provider.getFurnaceById(die.furnaceId ?? '');
      return furnace != null ? die.isReady(furnace) : false;
    }).length;
    
    final notReadyCount = _diesInFurnace.length - readyCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('🔥 إدارة الأفران'),
        backgroundColor: Colors.orange,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'تحديث',
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
                        _statItem('🟢 جاهز', '$readyCount', Colors.green),
                        _statItem('🔴 غير جاهز', '$notReadyCount', Colors.red),
                        _statItem('🔥 أفران', '${_furnaces.length}', Colors.orange),
                      ],
                    ),
                  ),
                  
                  const TabBar(
                    tabs: [
                      Tab(text: '🔥 الأفران', icon: Icon(Icons.fireplace)),
                      Tab(text: '📋 القوالب في الفرن', icon: Icon(Icons.inventory)),
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
                const Row(
                  children: [
                    Icon(Icons.add, color: Colors.orange),
                    SizedBox(width: 8),
                    Text(
                      '➕ إضافة فرن جديد',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                        decoration: const InputDecoration(
                          labelText: 'اسم الفرن',
                          border: OutlineInputBorder(),
                          isDense: true,
                          hintText: 'مثال: فرن المكبس 7 بوصة',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _targetTempController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '°C المستهدفة',
                          border: OutlineInputBorder(),
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
                        decoration: const InputDecoration(
                          labelText: '⏱️ وقت الهولو (دقائق)',
                          border: OutlineInputBorder(),
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
                        decoration: const InputDecoration(
                          labelText: '⏱️ وقت الصوليد (دقائق)',
                          border: OutlineInputBorder(),
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
                  decoration: const InputDecoration(
                    labelText: '📏 المكبس المرتبط',
                    border: OutlineInputBorder(),
                    isDense: true,
                    helperText: 'اختر المكبس الذي يخصه هذا الفرن',
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
                    label: const Text('إضافة فرن'),
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
                          'لا توجد أفران',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                        ),
                        Text(
                          'أضف فرناً جديداً من الأعلى',
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
                      
                      // ✅ حالة الفرن
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
                                  isActive ? '🟢 نشط' : '🔴 غير نشط',
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
                              Text('🎯 ${furnace.targetTemperature}°C | 🌡️ ${furnace.currentTemperature}°C'),
                              Text('⏱️ هولو: ${furnace.hollowHeatingTime}د | صوليد: ${furnace.solidHeatingTime}د'),
                              Text('📊 القوالب: $totalDies | 🟢 جاهز: $readyDies'),
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
                                tooltip: 'عرض القوالب في الفرن',
                              ),
                              if (canManage) ...[
                                if (furnace.status == FurnaceStatus.idle)
                                  IconButton(
                                    icon: const Icon(Icons.play_circle, color: Colors.green),
                                    onPressed: () => _showStartFurnaceDialog(furnace),
                                    tooltip: '▶️ تشغيل الفرن',
                                  ),
                                // ✅ زر التحكم في الحرارة الحالية متاح دايماً، مش بس وقت التسخين
                                IconButton(
                                  icon: const Icon(Icons.thermostat, color: Colors.orange),
                                  onPressed: () => _showUpdateTemperatureDialog(furnace),
                                  tooltip: '🌡️ تحديث الحرارة الحالية',
                                ),
                                if (furnace.status == FurnaceStatus.heating || furnace.status == FurnaceStatus.holding)
                                  IconButton(
                                    icon: const Icon(Icons.stop_circle, color: Colors.red),
                                    onPressed: () => _showStopFurnaceDialog(furnace),
                                    tooltip: '⏹️ إيقاف الفرن',
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteFurnace(furnace),
                                  tooltip: 'حذف',
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
                                  _infoRow('📏 المكبس', furnace.pressName),
                                  _infoRow('🎯 الحرارة المستهدفة', '${furnace.targetTemperature}°C'),
                                  _infoRow('🌡️ الحرارة الحالية', '${furnace.currentTemperature}°C'),
                                  _infoRow('⏱️ وقت الهولو', '${furnace.hollowHeatingTime} دقيقة'),
                                  _infoRow('⏱️ وقت الصوليد', '${furnace.solidHeatingTime} دقيقة'),
                                  _infoRow('📊 القوالب في الفرن', '$totalDies قالب'),
                                  _infoRow('🟢 الجاهزة للكبس', '$readyDies قالب'),
                                  _infoRow('📅 تاريخ الإنشاء', DateFormat('yyyy-MM-dd HH:mm').format(furnace.createdAt)),
                                  _infoRow('📊 الحالة', _getStatusText(furnace.status)),
                                  _infoRow('📋 حالة التشغيل', isActive ? '🟢 نشط' : '🔴 غير نشط'),
                                  
                                  if (totalDies > 0) ...[
                                    const Divider(),
                                    const Text(
                                      '📋 القوالب في هذا الفرن:',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
                                                  ? '✅ جاهز للكبس' 
                                                  : '⏳ ${die.getRemainingTimeFormatted(furnace)}',
                                              style: const TextStyle(fontSize: 10),
                                            ),
                                            if (die.furnaceEntryTime != null)
                                              Text(
                                                '📥 دخول: ${DateFormat('yyyy-MM-dd HH:mm').format(die.furnaceEntryTime!)}',
                                                style: const TextStyle(fontSize: 9, color: Colors.blue),
                                              ),
                                            if (die.furnaceExitTime != null)
                                              Text(
                                                '📤 خروج: ${DateFormat('yyyy-MM-dd HH:mm').format(die.furnaceExitTime!)}',
                                                style: const TextStyle(fontSize: 9, color: Colors.green),
                                              ),
                                            Text(
                                              '⏱️ المطلوب: ${die.getRequiredHeatingTime(furnace)} دقيقة',
                                              style: const TextStyle(fontSize: 9, color: Colors.grey),
                                            ),
                                            Text(
                                              '📐 الأبعاد: ${die.dimensionsFormatted}',
                                              style: const TextStyle(fontSize: 9, color: Colors.purple),
                                            ),
                                          ],
                                        ),
                                        trailing: Text(
                                          '${die.dieType == "hollow" ? "هولو" : "صوليد"}',
                                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                                        ),
                                      );
                                    }),
                                  ],
                                  
                                  if (furnace.cycles.isNotEmpty) ...[
                                    const Divider(),
                                    const Text(
                                      '📋 دورات التسخين السابقة',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
                                            '🎯 ${cycle.targetTemperature}°C | ⏱️ ${cycle.durationFormatted} | 📦 ${cycle.dieIds.length} قالب',
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
                    const Text(
                      '📋 جميع القوالب في الأفران',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_diesInFurnace.length} قالب',
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
                                'لا توجد قوالب في الفرن',
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'أضف قالباً جديداً من شاشة الفرن',
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
                            final remaining = furnace != null ? die.getRemainingTimeFormatted(furnace) : 'غير معروف';
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
                                      Text('🔧 ${die.dieType == "hollow" ? "هولو" : "صوليد"}'),
                                      Text('📐 الأبعاد: ${die.dimensionsFormatted}'),
                                      Text('⏱️ وقت التسخين: ${furnace != null ? die.getRequiredHeatingTime(furnace) : "غير معروف"} دقيقة'),
                                      Text('⏳ مضى: $elapsedHours ساعة'),
                                      
                                      if (die.furnaceEntryTime != null)
                                        Text(
                                          '📥 دخول: ${DateFormat('yyyy-MM-dd HH:mm').format(die.furnaceEntryTime!)}',
                                          style: const TextStyle(fontSize: 10, color: Colors.blue),
                                        ),
                                      
                                      if (die.furnaceExitTime != null)
                                        Text(
                                          '📤 خروج: ${DateFormat('yyyy-MM-dd HH:mm').format(die.furnaceExitTime!)}',
                                          style: const TextStyle(fontSize: 10, color: Colors.green),
                                        ),
                                      
                                      Text(
                                        isReady 
                                            ? '✅ جاهز للكبس' 
                                            : '⏳ متبقي: $remaining',
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
                                    label: const Text('عرض', style: TextStyle(fontSize: 10)),
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