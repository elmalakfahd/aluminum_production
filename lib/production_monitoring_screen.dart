import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'models.dart';
import 'services.dart';
import 'planning_screen.dart'; 
import 'app_localization.dart';
import 'shift_detail_screen.dart';
import 'all_shifts_screen.dart';

class CuttingRecordModel {
  final String id;
  final String factoryId;
  final String shiftId;
  final String dieId;
  final String dieName;
  final String pressName;
  final int billetCount;
  final double metricWeightKgPerM;
  final double barLengthM;
  final double barWeightKg;
  final int goodBarCount;
  final int pendingBarCount;
  final String pendingReason;
  final int scrapBarCount;
  final double goodWeightKg;
  final double pendingWeightKg;
  final double scrapWeightKg;
  final String recordedBy;
  final DateTime createdAt;

  CuttingRecordModel({required this.id, required this.factoryId, required this.shiftId, required this.dieId, this.dieName = '', this.pressName = '', this.billetCount = 0, this.metricWeightKgPerM = 0, this.barLengthM = 0, this.barWeightKg = 0, this.goodBarCount = 0, this.pendingBarCount = 0, this.pendingReason = '', this.scrapBarCount = 0, this.goodWeightKg = 0, this.pendingWeightKg = 0, this.scrapWeightKg = 0, this.recordedBy = '', DateTime? createdAt}) : createdAt = createdAt ?? DateTime.now();

  factory CuttingRecordModel.fromJson(String id, Map<dynamic, dynamic> j) => CuttingRecordModel(
        id: id,
        factoryId: j['factoryId']?.toString() ?? '',
        shiftId: j['shiftId']?.toString() ?? '',
        dieId: j['dieId']?.toString() ?? '',
        dieName: j['dieName']?.toString() ?? '',
        pressName: j['pressName']?.toString() ?? '',
        billetCount: j['billetCount'] is int ? j['billetCount'] as int : int.tryParse(j['billetCount']?.toString() ?? '') ?? 0,
        metricWeightKgPerM: j['metricWeightKgPerM'] is num ? (j['metricWeightKgPerM'] as num).toDouble() : double.tryParse(j['metricWeightKgPerM']?.toString() ?? '') ?? 0,
        barLengthM: j['barLengthM'] is num ? (j['barLengthM'] as num).toDouble() : double.tryParse(j['barLengthM']?.toString() ?? '') ?? 0,
        barWeightKg: j['barWeightKg'] is num ? (j['barWeightKg'] as num).toDouble() : double.tryParse(j['barWeightKg']?.toString() ?? '') ?? 0,
        goodBarCount: j['goodBarCount'] is int ? j['goodBarCount'] as int : int.tryParse(j['goodBarCount']?.toString() ?? '') ?? 0,
        pendingBarCount: j['pendingBarCount'] is int ? j['pendingBarCount'] as int : int.tryParse(j['pendingBarCount']?.toString() ?? '') ?? 0,
        pendingReason: j['pendingReason']?.toString() ?? '',
        scrapBarCount: j['scrapBarCount'] is int ? j['scrapBarCount'] as int : int.tryParse(j['scrapBarCount']?.toString() ?? '') ?? 0,
        goodWeightKg: j['goodWeightKg'] is num ? (j['goodWeightKg'] as num).toDouble() : double.tryParse(j['goodWeightKg']?.toString() ?? '') ?? 0,
        pendingWeightKg: j['pendingWeightKg'] is num ? (j['pendingWeightKg'] as num).toDouble() : double.tryParse(j['pendingWeightKg']?.toString() ?? '') ?? 0,
        scrapWeightKg: j['scrapWeightKg'] is num ? (j['scrapWeightKg'] as num).toDouble() : double.tryParse(j['scrapWeightKg']?.toString() ?? '') ?? 0,
        recordedBy: j['recordedBy']?.toString() ?? '',
        createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {'factoryId': factoryId, 'shiftId': shiftId, 'dieId': dieId, 'dieName': dieName, 'pressName': pressName, 'billetCount': billetCount, 'metricWeightKgPerM': metricWeightKgPerM, 'barLengthM': barLengthM, 'barWeightKg': barWeightKg, 'goodBarCount': goodBarCount, 'pendingBarCount': pendingBarCount, 'pendingReason': pendingReason, 'scrapBarCount': scrapBarCount, 'goodWeightKg': goodWeightKg, 'pendingWeightKg': pendingWeightKg, 'scrapWeightKg': scrapWeightKg, 'recordedBy': recordedBy, 'createdAt': createdAt.toIso8601String()};
}

class ProductionMonitoringScreen extends StatefulWidget {
  final String? initialFilter;

  const ProductionMonitoringScreen({super.key, this.initialFilter});

  @override
  State<ProductionMonitoringScreen> createState() => _ProductionMonitoringScreenState();
}

class _ProductionMonitoringScreenState extends State<ProductionMonitoringScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  String _filterStatus = 'all';
  String? _selectedPressId;

  @override
  void initState() {
    super.initState();
    _filterStatus = widget.initialFilter ?? 'all';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('production_monitoring_title')),
        backgroundColor: Colors.indigo,
        elevation: 2,
        actions: [
          const LanguageToggleButton(compact: true),
          Consumer<ShiftProvider>(
            builder: (context, provider, _) => IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              tooltip: context.tr('refresh_plain'),
              onPressed: () => provider.loadAllData(),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: TextFormField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: context.tr('search_by_die_name'),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.15),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              style: const TextStyle(color: Colors.white),
              onChanged: (value) {
                setState(() => _searchQuery = value.toLowerCase().trim());
              },
            ),
          ),
        ),
      ),
      body: Consumer<ShiftProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          List<ShiftModel> allShifts = List.from(provider.allShifts);
          
          if (_filterStatus == 'active') {
            allShifts = allShifts.where((s) => s.isActive).toList();
          } else if (_filterStatus == 'completed') {
            allShifts = allShifts.where((s) => !s.isActive).toList();
          }

          if (_selectedPressId != null && _selectedPressId!.isNotEmpty) {
            allShifts = allShifts.where((s) => s.pressId == _selectedPressId).toList();
          }

          allShifts.sort((a, b) {
            if (a.isActive && !b.isActive) return -1;
            if (!a.isActive && b.isActive) return 1;
            final aDate = a.endedAt ?? a.createdAt;
            final bDate = b.endedAt ?? b.createdAt;
            return bDate.compareTo(aDate);
          });

          final Map<String, List<ShiftModel>> shiftsByPress = {};
          for (var shift in allShifts) {
            final key = shift.pressId;
            if (!shiftsByPress.containsKey(key)) {
              shiftsByPress[key] = [];
            }
            shiftsByPress[key]!.add(shift);
          }

          List<DieModel> allDiesWithData = [];
          for (var shift in allShifts) {
            for (var die in shift.dies) {
              if (die.hasProductionData) {
                allDiesWithData.add(die);
              }
            }
          }

          List<DieModel> filteredDies = allDiesWithData;
          if (_searchQuery.isNotEmpty) {
            filteredDies = allDiesWithData.where((die) {
              return die.name.toLowerCase().contains(_searchQuery);
            }).toList();
          }

          if (_searchQuery.isNotEmpty && filteredDies.isNotEmpty) {
            return _buildSearchResults(context, provider, filteredDies);
          }

          if (allShifts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.factory_outlined, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text(
                    context.tr('production_monitoring_empty'),
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AllShiftsScreen(initialFilter: 'all'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.history, size: 20),
                  label: Text(
                    context.tr('all_previous_shifts'),
                    style: const TextStyle(fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    minimumSize: const Size(double.infinity, 45),
                  ),
                ),
              ),
              
              _buildFilterBar(context, provider),
              _buildOverallSummary(context, allDiesWithData, allShifts),
              
              const SizedBox(height: 8),
              
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  children: shiftsByPress.entries.map((entry) {
                    final pressId = entry.key;
                    final shifts = entry.value;
                    final press = provider.getPressById(pressId);
                    
                    return _buildPressSection(
                      context, 
                      provider, 
                      press, 
                      shifts,
                    );
                  }).toList(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context, ShiftProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          // ✅ إصلاح Overflow بحاوية مرنة
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _filterStatus,
              isExpanded: true, // ✅ يمنع Overflow
              decoration: InputDecoration(
                labelText: context.tr('shift_status'),
                border: const OutlineInputBorder(),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('📋 جميع الورديات')),
                DropdownMenuItem(value: 'active', child: Text('🟢 النشطة فقط')),
                DropdownMenuItem(value: 'completed', child: Text('🔴 المنتهية فقط')),
              ],
              onChanged: (value) {
                setState(() => _filterStatus = value!);
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _selectedPressId,
              isExpanded: true, // ✅ يمنع Overflow
              decoration: InputDecoration(
                labelText: context.tr('press_label_short'),
                border: const OutlineInputBorder(),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('جميع المكابس'),
                ),
                ...provider.presses.map((press) =>
                  DropdownMenuItem(
                    value: press.id,
                    child: Text(press.name, overflow: TextOverflow.ellipsis),
                  )
                ),
              ],
              onChanged: (value) {
                setState(() => _selectedPressId = value);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallSummary(BuildContext context, List<DieModel> diesWithData, List<ShiftModel> shifts) {
    final totalPressed = diesWithData.fold(0.0, (sum, d) => sum + d.totalWeight);
    final totalGood = diesWithData.fold(0.0, (sum, d) => sum + d.goodBarsWeightKg);
    final totalScrap = diesWithData.fold(0.0, (sum, d) => sum + d.totalScrapWeightKg);
    final overallPct = totalPressed > 0 ? (totalScrap / totalPressed) * 100 : 0.0;
    final pctColor = _getScrapColor(overallPct);

    String fmt(double w) {
      if (w >= 1000) return '${(w / 1000).toStringAsFixed(2)} طن';
      return '${w.toStringAsFixed(2)} كجم';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: Colors.indigo.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.insights, color: Colors.indigo),
                const SizedBox(width: 8),
                Text(
                  '📊 ${context.tr('overall_summary_title')} (${shifts.length} وردية)',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _summaryChip(context.tr('total_pressed_weight'), fmt(totalPressed), Colors.blueGrey),
                _summaryChip(context.tr('total_good_weight'), fmt(totalGood), Colors.green),
                _summaryChip(context.tr('total_scrap_weight'), fmt(totalScrap), Colors.red),
                _summaryChip(context.tr('dies_with_data_count'), '${diesWithData.length}', Colors.indigo),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
              decoration: BoxDecoration(
                color: pctColor.withOpacity(0.12),
                border: Border.all(color: pctColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(context.tr('overall_scrap_percentage'), style: TextStyle(color: pctColor, fontWeight: FontWeight.bold, fontSize: 12)),
                  Text(
                    '${overallPct.toStringAsFixed(1)}%',
                    style: TextStyle(color: pctColor, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 9, color: color)),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildPressSection(
    BuildContext context,
    ShiftProvider provider,
    PressModel? press,
    List<ShiftModel> shifts,
  ) {
    final pressName = press?.name ?? shifts.first.pressName;
    final activeCount = shifts.where((s) => s.isActive).length;
    final completedCount = shifts.length - activeCount;
    final totalDies = shifts.fold(0, (sum, s) => sum + s.dies.length);
    final totalWeight = shifts.fold(0.0, (sum, s) => sum + s.totalWeight);

    final totalScrap = shifts.fold(0.0, (sum, s) => sum + s.totalScrapWeight);
    final totalScrapPct = shifts.fold(0.0, (sum, s) => sum + s.totalScrapPercentage);
    final avgScrapPct = shifts.isNotEmpty ? totalScrapPct / shifts.length : 0.0;

    final diameter = press?.diameterInInches ?? 0;
    final stock = provider.getMaterialStockForDiameter(diameter);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.indigo,
                  radius: 18,
                  child: Text(
                    press?.diameterInInches.toStringAsFixed(1) ?? '?',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pressName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        '📊 $totalDies قالب | ⚖️ ${_formatWeight(totalWeight)} | 🗑️ ${_formatWeight(totalScrap)} (${avgScrapPct.toStringAsFixed(1)}%)',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: stock < 50 ? Colors.red.shade100 : Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '📦 ${stock.toStringAsFixed(2)} طن',
                    style: TextStyle(
                      fontSize: 11,
                      color: stock < 50 ? Colors.red : Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: activeCount > 0 ? Colors.green : Colors.grey,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${shifts.length} وردية',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
                if (activeCount > 0)
                  Container(
                    margin: const EdgeInsets.only(left: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '🟢 $activeCount نشطة',
                      style: TextStyle(fontSize: 10, color: Colors.green.shade700),
                    ),
                  ),
                if (completedCount > 0)
                  Container(
                    margin: const EdgeInsets.only(left: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '🔴 $completedCount منتهية',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                    ),
                  ),
              ],
            ),
          ),
          
          ...shifts.map((shift) => _buildShiftCard(context, provider, shift)),
        ],
      ),
    );
  }

  Widget _buildShiftCard(BuildContext context, ShiftProvider provider, ShiftModel shift) {
    final press = provider.getPressById(shift.pressId);
    final isActive = shift.isActive;
    final totalScrap = shift.totalScrapWeight;
    final totalScrapPct = shift.totalScrapPercentage;
    final scrapColor = _getScrapColor(totalScrapPct);
    final hasData = shift.diesWithProductionData > 0;
    final totalDies = shift.dies.length;
    final recordedDies = shift.diesWithProductionData;

    final efficiency = press != null ? shift.getEfficiency(press.targetTonsPerHour) : 0.0;
    final efficiencyColor = provider.getEfficiencyColor(efficiency);
    final efficiencyEmoji = provider.getEfficiencyEmoji(efficiency);

    final shiftDate = shift.endedAt ?? shift.createdAt;
    final dateFormatted = DateFormat('yyyy-MM-dd HH:mm').format(shiftDate);

    final dies = shift.dies.where((d) => d.status != DieStatus.draft).toList();

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ShiftDetailScreen(shiftId: shift.id),
          ),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isActive ? Colors.green.shade50 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? Colors.green.shade300 : Colors.grey.shade300,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isActive ? Colors.green : Colors.grey,
                  radius: 14,
                  child: Text(
                    '${shift.shiftNumber}',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'الوردية #${shift.shiftNumber}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isActive ? Colors.green : Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: isActive ? Colors.green : Colors.grey,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isActive ? context.tr('active_status') : context.tr('finished_status'),
                              style: const TextStyle(color: Colors.white, fontSize: 8),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '👤 ${shift.supervisor} | 🔧 ${shift.technician}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      Text(
                        '📅 $dateFormatted',
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      shift.totalWeightFormatted,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Text(
                      '📊 $recordedDies/$totalDies مسجلة',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 6),
            
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                _infoChip('⏱️ ${shift.actualDurationFormatted}', Colors.blue),
                _infoChip('⚡ ${efficiency.toStringAsFixed(1)}% $efficiencyEmoji', efficiencyColor),
                if (hasData)
                  _infoChip('🗑️ ${_formatWeight(totalScrap)} (${totalScrapPct.toStringAsFixed(1)}%)', scrapColor),
                if (!hasData)
                  _infoChip('⏳ لم تسجل بعد', Colors.orange),
              ],
            ),
            
            const SizedBox(height: 6),
            
            if (dies.isNotEmpty) ...[
              const Text(
                '📋 القوالب:',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
              ),
              ...dies.map((die) => _buildDieSummary(context, provider, shift, die)),
            ],
            
            const SizedBox(height: 6),
            
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ShiftDetailScreen(shiftId: shift.id),
                        ),
                      );
                    },
                    icon: const Icon(Icons.visibility, size: 14),
                    label: Text(
                      '📋 عرض التفاصيل',
                      style: const TextStyle(fontSize: 11),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.indigo,
                      side: const BorderSide(color: Colors.indigo),
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      minimumSize: const Size(0, 28),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                if (!isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '✅ مكتملة',
                      style: TextStyle(fontSize: 9, color: Colors.grey),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDieSummary(BuildContext context, ShiftProvider provider, ShiftModel shift, DieModel die) {
    final hasData = die.hasProductionData;
    final pctColor = _getScrapColor(die.scrapPercentage);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Icon(
            hasData ? Icons.check_circle : Icons.pending,
            size: 12,
            color: hasData ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              die.name,
              style: TextStyle(
                fontSize: 11,
                color: hasData ? Colors.black87 : Colors.grey.shade600,
                fontWeight: hasData ? FontWeight.w500 : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (hasData) ...[
            Text(
              die.totalWeightFormatted,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: pctColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${die.scrapPercentage.toStringAsFixed(1)}%',
                style: TextStyle(fontSize: 9, color: pctColor),
              ),
            ),
          ] else ...[
            Text(
              '⏳ غير مسجل',
              style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showCuttingEntry(BuildContext context, ShiftProvider provider, ShiftModel shift, DieModel die) async {
    final metric = TextEditingController();
    final length = TextEditingController();
    final good = TextEditingController();
    final pending = TextEditingController();
    final pendingReason = TextEditingController();
    final scrap = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('✂️ تسجيل تقطيع ${die.name}'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: metric, decoration: const InputDecoration(labelText: 'الوزن المتري كجم/م'), keyboardType: TextInputType.number),
          TextField(controller: length, decoration: const InputDecoration(labelText: 'طول العود م'), keyboardType: TextInputType.number),
          TextField(controller: good, decoration: const InputDecoration(labelText: 'عدد الأعواد المنتجة'), keyboardType: TextInputType.number),
          TextField(controller: pending, decoration: const InputDecoration(labelText: 'عدد أعواد المتعلقات'), keyboardType: TextInputType.number),
          TextField(controller: pendingReason, decoration: const InputDecoration(labelText: 'سبب المتعلقات')),
          TextField(controller: scrap, decoration: const InputDecoration(labelText: 'عدد السكراب'), keyboardType: TextInputType.number),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حفظ'))],
      ),
    );
    if (ok == true) {
      final m = double.tryParse(metric.text) ?? 0;
      final l = double.tryParse(length.text) ?? 0;
      final g = int.tryParse(good.text) ?? 0;
      final p = int.tryParse(pending.text) ?? 0;
      final s = int.tryParse(scrap.text) ?? 0;
      if (m <= 0 || l <= 0 || (g + p + s) <= 0) return;
      final barWeight = m * l;
      final updatedDie = die.copyWith(barWeightKg: barWeight, goodBarCount: g, relatedBarCount: p, scrapBarCount: s, productionRecordedAt: DateTime.now());
      await provider.updateDieInShift(shift.id, updatedDie);
      final factoryId = provider.currentFactoryId;
      final id = '${shift.id}_${die.id}';
      await FirebaseDatabase.instance.ref('factories/$factoryId/cuttingRecords/$id').set(CuttingRecordModel(id: id, factoryId: factoryId, shiftId: shift.id, dieId: die.id, dieName: die.name, pressName: shift.pressName, billetCount: die.billetCount, metricWeightKgPerM: m, barLengthM: l, barWeightKg: barWeight, goodBarCount: g, pendingBarCount: p, pendingReason: pendingReason.text.trim(), scrapBarCount: s, goodWeightKg: g * barWeight, pendingWeightKg: p * barWeight, scrapWeightKg: s * barWeight, recordedBy: FirebaseAuth.instance.currentUser?.email ?? '').toJson());
      await PlanningService.deductFromProduction(factoryId: factoryId, dieName: die.name, barLengthM: l, producedBars: g);
      if (mounted) Fluttertoast.showToast(msg: '✅ تم تسجيل إنتاج ${die.name}', backgroundColor: Colors.green, textColor: Colors.white);
    }
  }

  Future<void> _showDieDetails(BuildContext context, ShiftProvider provider, ShiftModel shift, DieModel die) async {
    final factoryId = provider.currentFactoryId;
    final snap = await FirebaseDatabase.instance.ref('factories/$factoryId/cuttingRecords/${shift.id}_${die.id}').get();
    CuttingRecordModel? record;
    if (snap.value is Map) record = CuttingRecordModel.fromJson('${shift.id}_${die.id}', snap.value as Map);
    if (!mounted) return;
    showDialog(context: context, builder: (context) => AlertDialog(title: Text('📊 ${die.name}'), content: Text(record == null
        ? 'بليت: ${die.billetCount}\nأعواد جيدة: ${die.goodBarCount ?? 0}\nمتعلقات: ${die.relatedBarCount ?? 0}\nسكراب: ${die.scrapBarCount ?? 0}'
        : 'بليت: ${record.billetCount}\nالوزن المتري: ${record.metricWeightKgPerM} كجم/م\nطول العود: ${record.barLengthM} م\nوزن العود: ${record.barWeightKg} كجم\nأعواد جيدة: ${record.goodBarCount} = ${record.goodWeightKg} كجم\nمتعلقات: ${record.pendingBarCount} = ${record.pendingWeightKg} كجم\nسبب المتعلقات: ${record.pendingReason}\nسكراب: ${record.scrapBarCount} = ${record.scrapWeightKg} كجم'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق'))]));
  }

  Widget _buildSearchResults(BuildContext context, ShiftProvider provider, List<DieModel> dies) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '🔍 ${context.tr('search_results')} (${dies.length})',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.clear, color: Colors.grey),
                onPressed: () {
                  setState(() {
                    _searchController.clear();
                    _searchQuery = '';
                  });
                },
                tooltip: context.tr('clear_search'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: dies.length,
              itemBuilder: (context, index) {
                final die = dies[index];
                ShiftModel? parentShift;
                for (final shift in provider.allShifts) {
                  if (shift.dies.any((d) => d.id == die.id)) {
                    parentShift = shift;
                    break;
                  }
                }
                if (parentShift == null) return const SizedBox.shrink();
                return _buildDieCard(context, provider, parentShift, die, highlight: true);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDieCard(BuildContext context, ShiftProvider provider, ShiftModel shift, DieModel die, {bool highlight = false}) {
    final hasData = die.hasProductionData;
    final pctColor = _getScrapColor(die.scrapPercentage);

    return InkWell(
      onTap: () {
        if (hasData) {
          _showDieDetails(context, provider, shift, die);
        } else {
          _showCuttingEntry(context, provider, shift, die);
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: highlight ? Colors.indigo.shade50 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: highlight ? Colors.indigo : Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    die.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${context.tr('pressed_quantity_label')}: ${die.totalWeightFormatted}',
                    style: TextStyle(fontSize: 11, color: Colors.blue.shade800),
                  ),
                ),
              ],
            ),
            Text(
              '📋 الوردية #${shift.shiftNumber} - ${shift.pressName}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 4),
            if (hasData) ...[
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  _resultChip(context.tr('good_weight_label'), die.goodBarsWeightFormatted, Colors.green),
                  _resultChip(context.tr('scrap_bars_weight_label'), die.scrapBarsWeightFormatted, Colors.orange),
                  _resultChip(context.tr('related_bars_label'), die.relatedBarsWeightFormatted, Colors.blue),
                ],
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                decoration: BoxDecoration(
                  color: pctColor.withOpacity(0.12),
                  border: Border.all(color: pctColor),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${context.tr('total_scrap_label')}: ${die.totalScrapWeightFormatted}',
                      style: TextStyle(fontSize: 11, color: pctColor, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${context.tr('scrap_percentage_label')}: ${die.scrapPercentageFormatted}',
                      style: TextStyle(fontSize: 12, color: pctColor, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
            ] else ...[
              Text(
                context.tr('no_production_data_yet'),
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 4),
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ShiftDetailScreen(shiftId: shift.id),
                    ),
                  );
                },
                icon: const Icon(Icons.visibility, size: 14),
                label: Text(
                  '📋 عرض التفاصيل',
                  style: const TextStyle(fontSize: 11),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.indigo,
                  side: const BorderSide(color: Colors.indigo),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  minimumSize: const Size(0, 28),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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

  Widget _infoChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _resultChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(fontSize: 9, color: color),
      ),
    );
  }
}