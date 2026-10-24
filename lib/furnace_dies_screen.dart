import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'models.dart';
import 'services.dart';
import 'die_correction_screens.dart';

class FurnaceDiesScreen extends StatefulWidget {
  final String? pressId;
  final String? pressName;

  const FurnaceDiesScreen({
    super.key,
    this.pressId,
    this.pressName,
  });

  @override
  State<FurnaceDiesScreen> createState() => _FurnaceDiesScreenState();
}

class _FurnaceDiesScreenState extends State<FurnaceDiesScreen> {
  late ShiftProvider _provider;
  List<DieModel> _diesInFurnace = [];
  List<DieModel> _filteredDies = [];
  // ✅ القوالب التي خرجت بالفعل من الفرن (سجل الخروج)
  List<DieModel> _exitedDies = [];
  // ✅ التبديل بين عرض القوالب الموجودة حالياً في الفرن وعرض القوالب التي خرجت
  bool _showExited = false;
  // ✅ خريطة تربط كل قالب بمعرّف الوردية الفعلية التي يوجد بها،
  // لاستخدامها عند تحديث القالب (كبس/إخراج) في المكان الصحيح
  final Map<String, String> _dieShiftIds = {};
  bool _isLoading = true;
  String? _lastMessage;
  bool _isMessageSuccess = true;

  final TextEditingController _dieNameController = TextEditingController();
  final TextEditingController _widthController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  String _selectedDieType = 'hollow';
  String? _selectedPressId;

  // ✅ متغير لتحديث الوقت المتبقي تلقائياً
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _provider = Provider.of<ShiftProvider>(context, listen: false);
      _loadData();
      
      // ✅ تحديث الوقت المتبقي كل 10 ثواني
      _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
        if (mounted) {
          _updateRemainingTimes();
        }
      });
    });
  }

  void _updateRemainingTimes() {
    // ✅ تحديث الواجهة فقط (دون إعادة تحميل البيانات)
    setState(() {});
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _dieNameController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
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

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await _provider.loadAllData();
      
      _diesInFurnace = [];
      _exitedDies = [];
      _dieShiftIds.clear();
      
      print('📋 جلب القوالب من جميع الورديات...');
      
      // ✅ جلب جميع القوالب في الفرن من جميع الورديات (النشطة والمنتهية)
      for (var shift in _provider.allShifts) {
        for (var die in shift.dies) {
          if (die.furnaceId == null || die.furnaceId!.isEmpty) continue;

          if (!die.isFurnaceReady) {
            // ✅ القالب لا يزال في الفرن (لم يخرج بعد)
            _diesInFurnace.add(die);
            // ✅ نتذكر الوردية الفعلية لهذا القالب لاستخدامها عند التحديث
            _dieShiftIds[die.id] = shift.id;
            print('📋 قالب في الفرن: ${die.name} (${die.dieType}) - دخول: ${die.furnaceEntryTime}');
          } else if (die.furnaceExitTime != null) {
            // ✅ القالب خرج بالفعل من الفرن - نحتفظ به لسجل "القوالب التي خرجت"
            _exitedDies.add(die);
            _dieShiftIds[die.id] = shift.id;
          }
        }
      }
      
      // ✅ تصفية حسب المكبس المختار
      if (widget.pressId != null && widget.pressId!.isNotEmpty) {
        _filteredDies = _diesInFurnace
            .where((die) => die.furnacePressId == widget.pressId)
            .toList();
        _exitedDies = _exitedDies
            .where((die) => die.furnacePressId == widget.pressId)
            .toList();
      } else {
        _filteredDies = _diesInFurnace;
      }
      
      // ✅ ترتيب تنازلي حسب وقت الدخول
      _filteredDies.sort((a, b) {
        final aTime = a.furnaceEntryTime ?? DateTime.now();
        final bTime = b.furnaceEntryTime ?? DateTime.now();
        return bTime.compareTo(aTime);
      });

      // ✅ ترتيب تنازلي حسب وقت الخروج (الأحدث خروجاً أولاً)، مع الاحتفاظ بآخر 50 فقط
      _exitedDies.sort((a, b) => b.furnaceExitTime!.compareTo(a.furnaceExitTime!));
      if (_exitedDies.length > 50) {
        _exitedDies = _exitedDies.sublist(0, 50);
      }
      
      print('📋 تم تحميل ${_filteredDies.length} قالب في الفرن، و ${_exitedDies.length} قالب خرج مسبقاً');
      for (var die in _filteredDies) {
        print('  - ${die.name} (${die.dieType}) - دخول: ${die.furnaceEntryTime}');
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

  Future<void> _addDieToFurnace() async {
    final name = _dieNameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _lastMessage = '⚠️ الرجاء إدخال اسم القالب';
        _isMessageSuccess = false;
      });
      return;
    }

    // ✅ التحقق من الأبعاد
    final width = double.tryParse(_widthController.text);
    final height = double.tryParse(_heightController.text);
    if (width == null || width <= 0 || height == null || height <= 0) {
      setState(() {
        _lastMessage = '⚠️ الرجاء إدخال أبعاد القالب بشكل صحيح (مثال: 230×130)';
        _isMessageSuccess = false;
      });
      return;
    }

    // ✅ تحديد المكبس
    String? targetPressId = widget.pressId;
    if (targetPressId == null || targetPressId.isEmpty) {
      targetPressId = _selectedPressId;
    }

    if (targetPressId == null || targetPressId.isEmpty) {
      setState(() {
        _lastMessage = '⚠️ الرجاء اختيار المكبس';
        _isMessageSuccess = false;
      });
      return;
    }

    // ✅ التحقق من صلاحية المستخدم
    if (!_canManagePress(targetPressId)) {
      setState(() {
        _lastMessage = '⚠️ ليس لديك صلاحية لإضافة قالب لهذا المكبس';
        _isMessageSuccess = false;
      });
      return;
    }

    // ✅ البحث عن المكبس
    PressModel? press = _provider.getPressById(targetPressId);
    if (press == null) {
      // ✅ محاولة البحث في المكابس الافتراضية
      press = PressModel.getPressById(targetPressId);
    }
    if (press == null) {
      setState(() {
        _lastMessage = '⚠️ المكبس غير موجود';
        _isMessageSuccess = false;
      });
      return;
    }

    // ✅ البحث عن الفرن الخاص بهذا المكبس (من القائمة المحملة محلياً)
    FurnaceModel? furnace = _provider.getFurnaceByPressId(targetPressId);

    // ✅ قبل افتراض عدم وجود فرن، تأكد مباشرة من قاعدة البيانات
    // لتفادي إنشاء فرن فارغ يمحو دورة تسخين نشطة بالفعل (بسبب
    // بيانات محلية غير محدثة بعد)
    if (furnace == null) {
      furnace = await _provider.service.getFurnace(
        _provider.currentFactoryId,
        'furnace_${press.id}',
      );
    }

    if (furnace == null) {
      // ✅ لا يوجد فرن فعلياً في قاعدة البيانات، ننشئ فرناً جديداً
      furnace = FurnaceModel(
        id: 'furnace_${press.id}',
        name: 'فرن ${press.name}',
        factoryId: _provider.currentFactoryId,
        targetTemperature: 480,
        createdAt: DateTime.now(),
        pressId: press.id,
        pressName: press.name,
        supervisorId: _provider.currentUserUid,
        hollowHeatingTime: 210.0,
        solidHeatingTime: 120.0,
        isActive: true,
      );
      await _provider.service.saveFurnace(_provider.currentFactoryId, furnace);
      // ✅ إعادة تحميل الأفران
      await _provider.loadAllData();
    }

    // ✅ تثبيت الفرن كقيمة غير قابلة للـ null بعد التأكد من وجوده،
    // لأن استخدامه لاحقاً داخل setState (closure) يفقد الـ promotion
    // التلقائي للمتغيرات القابلة للـ null في Dart
    final FurnaceModel currentFurnace = furnace;

    // ✅ البحث عن القالب في جميع الورديات (ونحفظ معرّف الوردية
    // الفعلية التي يوجد بها، لأن التحديث لاحقاً يجب أن يتم على
    // هذه الوردية بالتحديد وليس على الوردية النشطة الحالية)
    DieModel? foundDie;
    String? foundShiftId;
    for (var shift in _provider.allShifts) {
      for (var die in shift.dies) {
        if (die.name == name && 
            die.furnaceId == null && 
            die.pressId == targetPressId) {
          foundDie = die;
          foundShiftId = shift.id;
          break;
        }
      }
      if (foundDie != null) break;
    }

    // ✅ إذا لم يوجد القالب، ننشئه
    if (foundDie == null) {
      final newDie = DieModel(
        id: 'die_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        holes: 0,
        entryTime: DateTime.now(),
        exitTime: DateTime.now(),
        alloy: '6063',
        billetLength: 600,
        billetTemperature: 480,
        ramSpeed: 5,
        billetCount: 0,
        notes: 'تم إضافته من شاشة الفرن',
        pressId: press.id,
        pressSize: press.size,
        isActive: false,
        status: DieStatus.completed,
        furnaceId: null,
        furnaceEntryTime: null,
        furnaceExitTime: null,
        isFurnaceReady: false,
        dieType: _selectedDieType,
        furnacePressId: press.id,
        widthMm: width,
        heightMm: height,
      );
      
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final newShift = ShiftModel(
        factoryId: _provider.currentFactoryId,
        date: today,
        shiftNumber: 0,
        supervisor: 'نظام',
        technician: 'نظام',
        pressId: press.id,
        pressName: press.name,
        pressSize: press.size,
        supervisorUid: _provider.currentUserUid,
        dies: [newDie],
        isActive: false,
        createdAt: DateTime.now(),
        endedAt: DateTime.now(),
      );
      
      // ✅ نحفظ الوردية الجديدة ونحصل على معرّفها الحقيقي من Firebase
      foundShiftId = await _provider.service.saveShift(newShift);
      await _loadData();
      foundDie = newDie;
    }

    if (foundDie == null || foundShiftId == null || foundShiftId.isEmpty) {
      setState(() {
        _lastMessage = '⚠️ القالب "$name" غير موجود';
        _isMessageSuccess = false;
      });
      return;
    }

    // ✅ إضافة القالب إلى الفرن مع تسجيل وقت الدخول
    final updatedDie = foundDie.copyWith(
      furnaceId: currentFurnace.id,
      furnaceEntryTime: DateTime.now(),
      isFurnaceReady: false,
      furnacePressId: press.id,
      dieType: _selectedDieType,
      widthMm: width,
      heightMm: height,
    );
    
    // ✅ التحديث يتم داخل الوردية الصحيحة التي يوجد بها القالب فعلياً
    // (وليس الوردية النشطة الحالية) حتى يُحفظ التحديث فعلياً
    await _provider.updateDieInShift(foundShiftId, updatedDie);
    await DieTracking.recordDieFurnace(
      factoryId: _provider.currentFactoryId,
      codes: [foundDie.name],
      furnaceName: currentFurnace.name,
    );
    _dieNameController.clear();
    _widthController.clear();
    _heightController.clear();
    
    // ✅ إعادة تحميل البيانات
    await _provider.loadAllData();
    await _loadData();

    final typeName = _selectedDieType == 'hollow' ? 'هولو' : 'صوليد';
    final heatingTime = _selectedDieType == 'hollow' 
        ? currentFurnace.hollowHeatingTime 
        : currentFurnace.solidHeatingTime;
    
    setState(() {
      _lastMessage = '✅ تم إضافة القالب $name إلى فرن ${currentFurnace.name} (نوع: $typeName، وقت التسخين: ${heatingTime.toStringAsFixed(0)} دقيقة، الأبعاد: ${width.toStringAsFixed(0)}×${height.toStringAsFixed(0)} مم)';
      _isMessageSuccess = true;
    });

    Fluttertoast.showToast(
      msg: '✅ تم إضافة القالب $name إلى فرن ${currentFurnace.name}',
      backgroundColor: Colors.green,
      textColor: Colors.white,
    );
  }

  // ✅ دالة كبس القالب (تسجيل خروج بعد الكبس)
  Future<void> _markAsPressed(DieModel die) async {
    try {
      if (!_canManagePress(die.pressId)) {
        Fluttertoast.showToast(
          msg: '⚠️ ليس لديك صلاحية لكبس هذا القالب',
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        return;
      }

      // ✅ التحقق من وجود وقت دخول
      if (die.furnaceEntryTime == null) {
        Fluttertoast.showToast(
          msg: '⚠️ لا يوجد وقت دخول للقالب',
          backgroundColor: Colors.orange,
          textColor: Colors.white,
        );
        return;
      }

      final updatedDie = die.copyWith(
        furnaceExitTime: DateTime.now(),
        isFurnaceReady: true,
      );
      
      final shiftId = _dieShiftIds[die.id];
      if (shiftId == null || shiftId.isEmpty) {
        Fluttertoast.showToast(
          msg: '⚠️ تعذر تحديد الوردية الخاصة بالقالب، حاول تحديث الشاشة',
          backgroundColor: Colors.orange,
          textColor: Colors.white,
        );
        return;
      }
      await _provider.updateDieInShift(shiftId, updatedDie);
      await _provider.loadAllData();
      await _loadData();
      
      setState(() {
        _lastMessage = '✅ تم تسجيل كبس القالب ${die.name} (خروج من الفرن)';
        _isMessageSuccess = true;
      });
      
      Fluttertoast.showToast(
        msg: '✅ تم تسجيل كبس القالب ${die.name}',
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

  // ✅ دالة إخراج القالب يدوياً
  Future<void> _manualRemoveDie(DieModel die) async {
    try {
      if (!_canManagePress(die.pressId)) {
        Fluttertoast.showToast(
          msg: '⚠️ ليس لديك صلاحية لإخراج هذا القالب',
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        return;
      }

      // ✅ التحقق من وجود وقت دخول
      if (die.furnaceEntryTime == null) {
        Fluttertoast.showToast(
          msg: '⚠️ لا يوجد وقت دخول للقالب',
          backgroundColor: Colors.orange,
          textColor: Colors.white,
        );
        return;
      }

      // ✅ عرض حوار لتأكيد الإخراج اليدوي
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('📤 إخراج القالب يدوياً'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('هل أنت متأكد من إخراج القالب "${die.name}" من الفرن؟'),
              const SizedBox(height: 8),
              if (die.furnaceEntryTime != null)
                Text(
                  '📥 وقت الدخول: ${DateFormat('yyyy-MM-dd HH:mm').format(die.furnaceEntryTime!)}',
                  style: const TextStyle(fontSize: 12),
                ),
              Text(
                '📏 الأبعاد: ${die.dimensionsFormatted}',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'سيتم تسجيل وقت الخروج الحالي تلقائياً',
                        style: TextStyle(color: Colors.orange, fontSize: 12),
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
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                
                // ✅ تسجيل الخروج اليدوي
                final updatedDie = die.copyWith(
                  furnaceExitTime: DateTime.now(),
                  isFurnaceReady: true,
                );
                final shiftId = _dieShiftIds[die.id];
                if (shiftId == null || shiftId.isEmpty) {
                  Fluttertoast.showToast(
                    msg: '⚠️ تعذر تحديد الوردية الخاصة بالقالب، حاول تحديث الشاشة',
                    backgroundColor: Colors.orange,
                    textColor: Colors.white,
                  );
                  return;
                }
                await _provider.updateDieInShift(shiftId, updatedDie);
                await _provider.loadAllData();
                await _loadData();
                
                setState(() {
                  _lastMessage = '✅ تم إخراج القالب ${die.name} من الفرن يدوياً';
                  _isMessageSuccess = true;
                });
                
                Fluttertoast.showToast(
                  msg: '✅ تم إخراج القالب ${die.name} من الفرن',
                  backgroundColor: Colors.orange,
                  textColor: Colors.white,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('تأكيد الإخراج'),
            ),
          ],
        ),
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

  Future<void> _removeAllReadyDies() async {
    final readyDies = _filteredDies.where((die) {
      final furnace = _provider.getFurnaceById(die.furnaceId ?? '');
      return furnace != null ? die.isReady(furnace) : false;
    }).toList();
    
    if (readyDies.isEmpty) {
      setState(() {
        _lastMessage = '⚠️ لا توجد قوالب جاهزة للإخراج';
        _isMessageSuccess = false;
      });
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ تأكيد الإخراج'),
        content: Text('هل أنت متأكد من إخراج ${readyDies.length} قالب جاهز؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              for (var die in readyDies) {
                final updatedDie = die.copyWith(
                  furnaceId: null,
                  furnaceEntryTime: null,
                  furnaceExitTime: DateTime.now(),
                  isFurnaceReady: true,
                );
                final shiftId = _dieShiftIds[die.id];
                if (shiftId == null || shiftId.isEmpty) continue;
                await _provider.updateDieInShift(shiftId, updatedDie);
              }
              await _provider.loadAllData();
              await _loadData();
              setState(() {
                _lastMessage = '✅ تم إخراج ${readyDies.length} قالب جاهز';
                _isMessageSuccess = true;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('إخراج الكل'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ حساب الجاهزية بناءً على وقت التسخين من الفرن
    final readyCount = _filteredDies.where((die) {
      final furnace = _provider.getFurnaceById(die.furnaceId ?? '');
      return furnace != null ? die.isReady(furnace) : false;
    }).length;
    
    final notReadyCount = _filteredDies.length - readyCount;

    return Scaffold(
      appBar: AppBar(
        title: Text('🔥 القوالب في الفرن - ${widget.pressName ?? "جميع المكابس"}'),
        backgroundColor: Colors.orange,
        elevation: 2,
        actions: [
          if (readyCount > 0)
            IconButton(
              icon: const Icon(Icons.check_circle, color: Colors.white),
              onPressed: _removeAllReadyDies,
              tooltip: 'إخراج جميع القوالب الجاهزة',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.grey.shade100,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statItem('🟢 جاهز', '$readyCount', Colors.green),
                      _statItem('🔴 غير جاهز', '$notReadyCount', Colors.red),
                      _statItem('📦 المجموع', '${_filteredDies.length}', Colors.blue),
                      _statItem('📤 خرجت مؤخراً', '${_exitedDies.length}', Colors.grey.shade700),
                    ],
                  ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: Text('🔥 في الفرن (${_filteredDies.length})'),
                          selected: !_showExited,
                          onSelected: (_) => setState(() => _showExited = false),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: Text('📤 خرجت مؤخراً (${_exitedDies.length})'),
                          selected: _showExited,
                          onSelected: (_) => setState(() => _showExited = true),
                        ),
                      ),
                    ],
                  ),
                ),

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
                              '➕ إضافة قالب للفرن',
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
                                controller: _dieNameController,
                                decoration: const InputDecoration(
                                  labelText: 'اسم القالب',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  hintText: 'أدخل اسم القالب',
                                ),
                                onFieldSubmitted: (_) => _addDieToFurnace(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedDieType,
                                decoration: const InputDecoration(
                                  labelText: 'النوع',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'hollow',
                                    child: Text('هولو'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'solid',
                                    child: Text('صوليد'),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _selectedDieType = value;
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // ✅ أبعاد القالب
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _widthController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'العرض (مم)',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  hintText: '230',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text('×'),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _heightController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'الطول (مم)',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  hintText: '130',
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (widget.pressId == null || widget.pressId!.isEmpty)
                          const SizedBox(height: 8),
                        if (widget.pressId == null || widget.pressId!.isEmpty)
                          DropdownButtonFormField<String>(
                            value: _selectedPressId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: '📏 اختيار المكبس',
                              border: OutlineInputBorder(),
                              isDense: true,
                              helperText: 'اختر المكبس الذي تريد إضافة القالب لفرنه',
                            ),
                            items: _provider.presses.map((press) => 
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
                            onPressed: _addDieToFurnace,
                            icon: const Icon(Icons.add),
                            label: const Text('إضافة للفرن'),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _showExited ? '📤 القوالب التي خرجت من الفرن' : '📋 القوالب في الفرن',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${(_showExited ? _exitedDies : _filteredDies).length} قالب',
                                style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: (_showExited ? _exitedDies : _filteredDies).isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(_showExited ? Icons.history : Icons.inventory, size: 64, color: Colors.grey.shade300),
                                      const SizedBox(height: 16),
                                      Text(
                                        _showExited ? 'لا توجد قوالب خرجت من الفرن بعد' : 'لا توجد قوالب في الفرن',
                                        style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                                      ),
                                      if (widget.pressId != null)
                                        Text(
                                          'للمكبس ${widget.pressName}',
                                          style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                                        ),
                                      const SizedBox(height: 8),
                                      if (!_showExited)
                                        Text(
                                          'أضف قالباً جديداً من الأعلى',
                                          style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                                        ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: (_showExited ? _exitedDies : _filteredDies).length,
                                  itemBuilder: (context, index) {
                                    final die = (_showExited ? _exitedDies : _filteredDies)[index];
                                    final furnace = _provider.getFurnaceById(die.furnaceId ?? '');
                                    final isReady = furnace != null ? die.isReady(furnace) : false;
                                    final remaining = furnace != null ? die.getRemainingTimeFormatted(furnace) : 'غير معروف';
                                    final requiredTime = furnace != null ? die.getRequiredHeatingTime(furnace) : 0;
                                    final press = _provider.getPressById(die.pressId);
                                    if (press == null) {
                                      // ✅ محاولة البحث في المكابس الافتراضية
                                      final defaultPress = PressModel.getPressById(die.pressId);
                                      if (defaultPress != null) {
                                        // ✅ استخدام المكبس الافتراضي
                                      }
                                    }
                                    final elapsedMinutes = die.furnaceEntryTime != null
                                        ? DateTime.now().difference(die.furnaceEntryTime!).inMinutes
                                        : 0;
                                    final elapsedHours = (elapsedMinutes / 60).toStringAsFixed(1);
                                    
                                    // ✅ وقت الدخول مع التاريخ
                                    String entryTimeText = 'غير مسجل';
                                    if (die.furnaceEntryTime != null) {
                                      entryTimeText = DateFormat('yyyy-MM-dd HH:mm').format(die.furnaceEntryTime!);
                                    }
                                    
                                    // ✅ وقت الخروج مع التاريخ
                                    String exitTimeText = 'لم يخرج بعد';
                                    if (die.furnaceExitTime != null) {
                                      exitTimeText = DateFormat('yyyy-MM-dd HH:mm').format(die.furnaceExitTime!);
                                    }
                                    
                                    final canManage = _canManagePress(die.pressId);

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
                                              Text('⏱️ وقت التسخين المطلوب: ${requiredTime.toStringAsFixed(0)} دقيقة'),
                                              Text('⏳ مضى: $elapsedHours ساعة'),
                                              
                                              // ✅ وقت الدخول مع التاريخ
                                              Text(
                                                '📥 دخول: $entryTimeText',
                                                style: const TextStyle(fontSize: 10, color: Colors.blue),
                                              ),
                                              
                                              // ✅ وقت الخروج مع التاريخ (إذا تم الكبس أو الإخراج)
                                              if (die.furnaceExitTime != null)
                                                Text(
                                                  '📤 خروج: $exitTimeText',
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
                                              if (die.isFurnaceReady && die.furnaceExitTime != null)
                                                const Text(
                                                  '✅ تم إخراج القالب',
                                                  style: TextStyle(color: Colors.green, fontSize: 10),
                                                ),
                                            ],
                                          ),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              // ✅ زر كبس (تسجيل خروج بعد الكبس)
                                              if (!die.isFurnaceReady && canManage && die.furnaceEntryTime != null)
                                                ElevatedButton.icon(
                                                  onPressed: () => _markAsPressed(die),
                                                  icon: const Icon(Icons.build, size: 14),
                                                  label: const Text('🔨 كبس', style: TextStyle(fontSize: 10)),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.blue,
                                                    foregroundColor: Colors.white,
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    minimumSize: const Size(0, 28),
                                                  ),
                                                ),
                                              const SizedBox(width: 4),
                                              // ✅ زر إخراج يدوي
                                              if (!die.isFurnaceReady && canManage && die.furnaceEntryTime != null)
                                                ElevatedButton.icon(
                                                  onPressed: () => _manualRemoveDie(die),
                                                  icon: const Icon(Icons.exit_to_app, size: 14),
                                                  label: const Text('📤 إخراج', style: TextStyle(fontSize: 10)),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.orange,
                                                    foregroundColor: Colors.white,
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    minimumSize: const Size(0, 28),
                                                  ),
                                                ),
                                              if (!canManage || die.furnaceEntryTime == null)
                                                const Icon(
                                                  Icons.lock,
                                                  color: Colors.grey,
                                                  size: 16,
                                                ),
                                            ],
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
}