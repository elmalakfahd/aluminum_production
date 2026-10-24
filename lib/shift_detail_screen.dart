import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'models.dart';
import 'services.dart';
import 'app_localization.dart';

// ============================================================
// 📊 شاشة تفاصيل الوردية - عرض جميع القوالب مع بيانات الإنتاج
// ============================================================
class ShiftDetailScreen extends StatefulWidget {
  final String shiftId;

  const ShiftDetailScreen({super.key, required this.shiftId});

  @override
  State<ShiftDetailScreen> createState() => _ShiftDetailScreenState();
}

class _ShiftDetailScreenState extends State<ShiftDetailScreen> {
  late ShiftProvider _provider;
  ShiftModel? _shift;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isCalculating = false;

  final Map<String, TextEditingController> _barWeightControllers = {};
  final Map<String, TextEditingController> _goodBarsControllers = {};
  final Map<String, TextEditingController> _scrapBarsControllers = {};
  final Map<String, TextEditingController> _relatedBarsControllers = {};
  
  final Map<String, DieModel> _dieCache = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _provider = Provider.of<ShiftProvider>(context, listen: false);
      _loadShift();
    });
  }

  Future<void> _loadShift() async {
    setState(() => _isLoading = true);
    try {
      await _provider.loadShift(widget.shiftId);
      setState(() {
        _shift = _provider.currentShift;
        _isLoading = false;
        _initializeControllers();
      });
    } catch (e) {
      setState(() => _isLoading = false);
      Fluttertoast.showToast(
        msg: 'خطأ في تحميل الوردية: $e',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  void _initializeControllers() {
    if (_shift == null) return;

    for (var controller in _barWeightControllers.values) {
      controller.dispose();
    }
    for (var controller in _goodBarsControllers.values) {
      controller.dispose();
    }
    for (var controller in _scrapBarsControllers.values) {
      controller.dispose();
    }
    for (var controller in _relatedBarsControllers.values) {
      controller.dispose();
    }
    _barWeightControllers.clear();
    _goodBarsControllers.clear();
    _scrapBarsControllers.clear();
    _relatedBarsControllers.clear();
    _dieCache.clear();

    for (var die in _shift!.dies) {
      if (die.status == DieStatus.draft) continue;

      _dieCache[die.id] = die;

      final barWeightController = TextEditingController(
        text: die.barWeightKg != null ? die.barWeightKg!.toStringAsFixed(2) : '',
      );
      barWeightController.addListener(() {
        _updateCalculations(die.id);
      });
      _barWeightControllers[die.id] = barWeightController;

      final goodBarsController = TextEditingController(
        text: die.goodBarCount != null ? '${die.goodBarCount}' : '',
      );
      goodBarsController.addListener(() {
        _updateCalculations(die.id);
      });
      _goodBarsControllers[die.id] = goodBarsController;

      final scrapBarsController = TextEditingController(
        text: die.scrapBarCount != null ? '${die.scrapBarCount}' : '',
      );
      scrapBarsController.addListener(() {
        _updateCalculations(die.id);
      });
      _scrapBarsControllers[die.id] = scrapBarsController;

      final relatedBarsController = TextEditingController(
        text: die.relatedBarCount != null ? '${die.relatedBarCount}' : '',
      );
      relatedBarsController.addListener(() {
        _updateCalculations(die.id);
      });
      _relatedBarsControllers[die.id] = relatedBarsController;
    }
  }

  void _updateCalculations(String dieId) {
    if (_isCalculating) return;
    _isCalculating = true;

    try {
      final die = _dieCache[dieId];
      if (die == null) return;

      final barWeight = double.tryParse(_barWeightControllers[dieId]?.text ?? '');
      final goodBars = int.tryParse(_goodBarsControllers[dieId]?.text ?? '') ?? 0;
      final scrapBars = int.tryParse(_scrapBarsControllers[dieId]?.text ?? '') ?? 0;
      final relatedBars = int.tryParse(_relatedBarsControllers[dieId]?.text ?? '') ?? 0;

      final updatedDie = die.copyWith(
        barWeightKg: barWeight,
        goodBarCount: goodBars,
        scrapBarCount: scrapBars,
        relatedBarCount: relatedBars,
      );
      _dieCache[dieId] = updatedDie;

      setState(() {});
    } catch (e) {
      print('⚠️ خطأ في الحساب التلقائي: $e');
    } finally {
      _isCalculating = false;
    }
  }

  double _getCalculatedGoodWeight(DieModel die) {
    final cached = _dieCache[die.id];
    if (cached == null) return 0.0;
    final barWeight = cached.barWeightKg ?? 0;
    final goodBars = cached.goodBarCount ?? 0;
    return goodBars * barWeight;
  }

  double _getCalculatedTotalScrapWeight(DieModel die) {
    final cached = _dieCache[die.id];
    if (cached == null) return 0.0;
    final expected = die.totalWeight;
    final goodWeight = _getCalculatedGoodWeight(die);
    final relatedWeight = (cached.relatedBarCount ?? 0) * (cached.barWeightKg ?? 0);
    final scrap = expected - goodWeight - relatedWeight;
    return scrap < 0 ? 0.0 : scrap;
  }

  double _getCalculatedScrapPercentage(DieModel die) {
    final expected = die.totalWeight;
    if (expected <= 0) return 0.0;
    final scrap = _getCalculatedTotalScrapWeight(die);
    return (scrap / expected) * 100;
  }

  @override
  void dispose() {
    for (var controller in _barWeightControllers.values) {
      controller.dispose();
    }
    for (var controller in _goodBarsControllers.values) {
      controller.dispose();
    }
    for (var controller in _scrapBarsControllers.values) {
      controller.dispose();
    }
    for (var controller in _relatedBarsControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _saveDie(DieModel die) async {
    final barWeight = double.tryParse(_barWeightControllers[die.id]?.text ?? '');
    if (barWeight == null || barWeight <= 0) {
      Fluttertoast.showToast(
        msg: '⚠️ الرجاء إدخال وزن العود بشكل صحيح',
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
      return;
    }

    final goodBars = int.tryParse(_goodBarsControllers[die.id]?.text ?? '') ?? 0;
    final scrapBars = int.tryParse(_scrapBarsControllers[die.id]?.text ?? '') ?? 0;
    final relatedBars = int.tryParse(_relatedBarsControllers[die.id]?.text ?? '') ?? 0;

    if (goodBars <= 0 && scrapBars <= 0 && relatedBars <= 0) {
      Fluttertoast.showToast(
        msg: '⚠️ الرجاء إدخال بيانات الإنتاج',
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final updatedDie = die.copyWith(
        barWeightKg: barWeight,
        goodBarCount: goodBars,
        scrapBarCount: scrapBars,
        relatedBarCount: relatedBars,
        productionRecordedAt: DateTime.now(),
      );

      await _provider.updateDieInShift(_shift!.id, updatedDie);
      
      final updatedShift = _shift!.updateDie(updatedDie);
      setState(() {
        _shift = updatedShift;
        _isSaving = false;
        _dieCache[die.id] = updatedDie;
      });

      Fluttertoast.showToast(
        msg: '✅ تم حفظ بيانات القالب ${die.name}',
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
    } catch (e) {
      setState(() => _isSaving = false);
      Fluttertoast.showToast(
        msg: '❌ خطأ: $e',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  Future<void> _saveAllDies() async {
    if (_shift == null) return;

    setState(() => _isSaving = true);

    try {
      for (var die in _shift!.dies) {
        if (die.status == DieStatus.draft) continue;

        final barWeight = double.tryParse(_barWeightControllers[die.id]?.text ?? '');
        if (barWeight == null || barWeight <= 0) continue;

        final goodBars = int.tryParse(_goodBarsControllers[die.id]?.text ?? '') ?? 0;
        final scrapBars = int.tryParse(_scrapBarsControllers[die.id]?.text ?? '') ?? 0;
        final relatedBars = int.tryParse(_relatedBarsControllers[die.id]?.text ?? '') ?? 0;

        if (goodBars <= 0 && scrapBars <= 0 && relatedBars <= 0) continue;

        final updatedDie = die.copyWith(
          barWeightKg: barWeight,
          goodBarCount: goodBars,
          scrapBarCount: scrapBars,
          relatedBarCount: relatedBars,
          productionRecordedAt: DateTime.now(),
        );

        await _provider.updateDieInShift(_shift!.id, updatedDie);
        _shift = _shift!.updateDie(updatedDie);
        _dieCache[die.id] = updatedDie;
      }

      setState(() => _isSaving = false);

      Fluttertoast.showToast(
        msg: '✅ تم حفظ جميع بيانات الإنتاج',
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
    } catch (e) {
      setState(() => _isSaving = false);
      Fluttertoast.showToast(
        msg: '❌ خطأ: $e',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  double _getExpectedWeight(DieModel die) => die.totalWeight;

  Color _getScrapColor(double pct) {
    if (pct <= 5) return Colors.green;
    if (pct <= 12) return Colors.orange;
    return Colors.red;
  }

  String _formatWeight(double weight) {
    if (weight >= 1000) {
      return '${(weight / 1000).toStringAsFixed(2)} طن';
    }
    return '${weight.toStringAsFixed(2)} كجم';
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ShiftProvider>(context);
    final canEdit = provider.canEditProductionData;

    if (_isLoading || provider.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_shift == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('الوردية غير موجودة'),
          backgroundColor: Colors.red,
        ),
        body: const Center(child: Text('لم يتم العثور على الوردية')),
      );
    }

    final shift = _shift!;
    final press = provider.getPressById(shift.pressId);
    final isActive = shift.isActive;
    final dies = shift.dies.where((d) => d.status != DieStatus.draft).toList();

    final diameter = press?.diameterInInches ?? 0;
    final stock = provider.getMaterialStockForDiameter(diameter);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '📊 الوردية #${shift.shiftNumber} - ${press?.name ?? shift.pressName}',
          style: const TextStyle(fontSize: 14),
        ),
        backgroundColor: isActive ? Colors.green : Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadShift,
            tooltip: 'تحديث',
          ),
          if (dies.isNotEmpty && canEdit)
            IconButton(
              icon: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save, color: Colors.white),
              onPressed: _isSaving ? null : _saveAllDies,
              tooltip: 'حفظ الكل',
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: isActive ? Colors.green.shade50 : Colors.blue.shade50,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '👤 المشرف: ${shift.supervisor}  |  🔧 الفني: ${shift.technician}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '📅 ${DateFormat('yyyy-MM-dd HH:mm').format(shift.createdAt)}  |  ⏱️ ${shift.duration}  |  ⚖️ ${shift.totalWeightFormatted}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                          Text(
                            '📊 ${dies.length} قوالب  |  🔢 ${shift.totalBillets} بليت',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: isActive ? Colors.green : Colors.grey,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isActive ? '🟢 نشطة' : '🔴 منتهية',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: stock < 50 ? Colors.red.shade100 : Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.inventory, size: 16, color: Colors.amber),
                      const SizedBox(width: 6),
                      Text(
                        '📦 رصيد الخامة (قطر ${diameter.toStringAsFixed(1)} بوصة): ${stock.toStringAsFixed(2)} طن',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: stock < 50 ? Colors.red : Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 4),

          Expanded(
            child: dies.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          'لا توجد قوالب في هذه الوردية',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: dies.length,
                    itemBuilder: (context, index) {
                      final die = dies[index];
                      return _buildDieCard(die, index, canEdit: canEdit);
                    },
                  ),
          ),

          if (dies.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: _buildShiftSummary(),
            ),
        ],
      ),
    );
  }

  Widget _buildDieCard(DieModel die, int index, {required bool canEdit}) {
    final hasData = die.barWeightKg != null && die.barWeightKg! > 0;
    final expectedWeight = _getExpectedWeight(die);
    final goodWeight = _getCalculatedGoodWeight(die);
    final totalScrap = _getCalculatedTotalScrapWeight(die);
    final scrapPct = _getCalculatedScrapPercentage(die);
    final scrapColor = _getScrapColor(scrapPct);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: hasData ? Colors.green : Colors.orange,
                  radius: 14,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    die.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: hasData ? Colors.green : Colors.orange,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: hasData ? Colors.green.shade100 : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    hasData ? '✅ جاهز' : '⏳ غير مسجل',
                    style: TextStyle(
                      fontSize: 10,
                      color: hasData ? Colors.green : Colors.orange,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '⚖️ الوزن المتوقع:',
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                  ),
                  Text(
                    _formatWeight(expectedWeight),
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _barWeightControllers[die.id],
                    keyboardType: TextInputType.number,
                    enabled: canEdit,
                    decoration: InputDecoration(
                      labelText: '⚖️ وزن العود (كجم)',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _goodBarsControllers[die.id],
                    keyboardType: TextInputType.number,
                    enabled: canEdit,
                    decoration: InputDecoration(
                      labelText: '✅ الأعواد المنتجة',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _scrapBarsControllers[die.id],
                    keyboardType: TextInputType.number,
                    enabled: canEdit,
                    decoration: InputDecoration(
                      labelText: '🗑️ أعواد الخردة',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _relatedBarsControllers[die.id],
                    keyboardType: TextInputType.number,
                    enabled: canEdit,
                    decoration: InputDecoration(
                      labelText: '🔗 الأعواد المتعلقات',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('📊 النتائج المحسوبة:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      if (hasData || scrapPct > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: scrapColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: scrapColor),
                          ),
                          child: Text(
                            '${scrapPct.toStringAsFixed(1)}% خردة',
                            style: TextStyle(fontSize: 11, color: scrapColor, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('✅ الوزن الجيد:', style: const TextStyle(fontSize: 11)),
                      Text(
                        _formatWeight(goodWeight),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('🗑️ وزن الخردة الكلي:', style: const TextStyle(fontSize: 11)),
                      Text(
                        _formatWeight(totalScrap),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: scrapColor),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('📊 نسبة الخردة:', style: const TextStyle(fontSize: 11)),
                      Text(
                        '${scrapPct.toStringAsFixed(1)}%',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: scrapColor),
                      ),
                    ],
                  ),
                  if (hasData || scrapPct > 0)
                    LinearProgressIndicator(
                      value: scrapPct / 100,
                      backgroundColor: Colors.grey.shade200,
                      color: scrapColor,
                      minHeight: 4,
                    ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            if (canEdit)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : () => _saveDie(die),
                  icon: _isSaving
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save, size: 16),
                  label: Text(
                    hasData ? 'تحديث بيانات القالب' : '💾 حفظ بيانات القالب',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasData ? Colors.orange : Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_outline, size: 16, color: Colors.grey),
                    SizedBox(width: 8),
                    Text(
                      '🔒 للقراءة فقط',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftSummary() {
    if (_shift == null) return const SizedBox.shrink();

    double totalExpected = 0.0;
    double totalGood = 0.0;
    double totalScrap = 0.0;
    int totalDies = 0;

    for (var die in _shift!.dies) {
      if (die.status == DieStatus.draft) continue;
      final expected = _getExpectedWeight(die);
      final good = _getCalculatedGoodWeight(die);
      final scrap = _getCalculatedTotalScrapWeight(die);
      
      totalExpected += expected;
      totalGood += good;
      totalScrap += scrap;
      totalDies++;
    }

    final scrapPct = totalExpected > 0 ? (totalScrap / totalExpected) * 100 : 0.0;
    final scrapColor = _getScrapColor(scrapPct);
    
    // ✅ إضافة حساب الاستهلاك حسب السبيكة
    final consumptionByAlloy = _shift!.getConsumedWeightByAlloy();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.summarize, color: Colors.indigo),
            const SizedBox(width: 8),
            Text(
              '📊 ملخص الوردية ($totalDies قوالب)',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _summaryItem('⚖️ الوزن المتوقع', _formatWeight(totalExpected), Colors.blue),
            _summaryItem('✅ الوزن الجيد', _formatWeight(totalGood), Colors.green),
            _summaryItem('🗑️ وزن الخردة', _formatWeight(totalScrap), scrapColor),
            _summaryItem('📊 نسبة الخردة', '${scrapPct.toStringAsFixed(1)}%', scrapColor),
          ],
        ),
        if (totalExpected > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: LinearProgressIndicator(
              value: scrapPct / 100,
              backgroundColor: Colors.grey.shade200,
              color: scrapColor,
              minHeight: 6,
            ),
          ),
        
        // ✅ إضافة عرض الاستهلاك حسب السبيكة
        if (consumptionByAlloy.isNotEmpty) ...[
          const Divider(height: 16),
          const Text(
            '📊 الاستهلاك حسب السبيكة:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: consumptionByAlloy.entries.map((entry) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Text(
                  '${entry.key}: ${entry.value.toStringAsFixed(2)} طن',
                  style: const TextStyle(fontSize: 12),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _summaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}