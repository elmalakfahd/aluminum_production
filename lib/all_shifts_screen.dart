import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'models.dart';
import 'services.dart';
import 'app_localization.dart';
import 'shift_detail_screen.dart';

// ============================================================
// 📋 شاشة جميع الورديات - عرض كل تفاصيل القوالب
// ============================================================
class AllShiftsScreen extends StatefulWidget {
  final String? initialFilter;

  const AllShiftsScreen({super.key, this.initialFilter});

  @override
  State<AllShiftsScreen> createState() => _AllShiftsScreenState();
}

class _AllShiftsScreenState extends State<AllShiftsScreen> {
  late ShiftProvider _provider;
  List<ShiftModel> _filteredShifts = [];
  bool _isLoading = true;

  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedPressId;
  final TextEditingController _supervisorController = TextEditingController();
  final TextEditingController _dieNameController = TextEditingController();

  String _filterStatus = 'all';

  final Map<String, bool> _expandedShifts = {};

  @override
  void initState() {
    super.initState();
    _filterStatus = widget.initialFilter ?? 'all';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _provider = Provider.of<ShiftProvider>(context, listen: false);
      _loadData();
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await _provider.loadAllData();
      _applyFilters();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      var shifts = List<ShiftModel>.from(_provider.allShifts);

      if (_filterStatus == 'active') {
        shifts = shifts.where((s) => s.isActive).toList();
      } else if (_filterStatus == 'completed') {
        shifts = shifts.where((s) => !s.isActive).toList();
      }

      if (_startDate != null) {
        shifts = shifts.where((s) {
          final shiftDate = DateTime.tryParse(s.date);
          return shiftDate != null && shiftDate.isAfter(_startDate!.subtract(const Duration(days: 1)));
        }).toList();
      }
      if (_endDate != null) {
        shifts = shifts.where((s) {
          final shiftDate = DateTime.tryParse(s.date);
          return shiftDate != null && shiftDate.isBefore(_endDate!.add(const Duration(days: 1)));
        }).toList();
      }

      if (_selectedPressId != null && _selectedPressId!.isNotEmpty) {
        shifts = shifts.where((s) => s.pressId == _selectedPressId).toList();
      }

      final supervisorQuery = _supervisorController.text.trim().toLowerCase();
      if (supervisorQuery.isNotEmpty) {
        shifts = shifts.where((s) => s.supervisor.toLowerCase().contains(supervisorQuery)).toList();
      }

      final dieQuery = _dieNameController.text.trim().toLowerCase();
      if (dieQuery.isNotEmpty) {
        shifts = shifts.where((s) {
          return s.dies.any((die) => die.name.toLowerCase().contains(dieQuery));
        }).toList();
      }

      shifts.sort((a, b) {
        final aDate = a.endedAt ?? a.createdAt;
        final bDate = b.endedAt ?? b.createdAt;
        return bDate.compareTo(aDate);
      });

      _filteredShifts = shifts;
      _isLoading = false;
    });
  }

  void _clearFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _selectedPressId = null;
      _supervisorController.clear();
      _dieNameController.clear();
      _filterStatus = 'all';
    });
    _applyFilters();
  }

  @override
  void dispose() {
    _supervisorController.dispose();
    _dieNameController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ShiftProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('all_shifts_title')),
        backgroundColor: Colors.purple,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadData,
            tooltip: context.tr('refresh_plain'),
          ),
          IconButton(
            icon: const Icon(Icons.clear_all, color: Colors.white),
            onPressed: _clearFilters,
            tooltip: context.tr('clear_filters'),
          ),
        ],
      ),
      body: _isLoading || provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildFilterBar(),
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '📋 ${context.tr('all_shifts_title')}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_filteredShifts.length} ${context.tr('shift_word')}',
                          style: TextStyle(color: Colors.purple.shade700, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                
                Expanded(
                  child: _filteredShifts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.history, size: 64, color: Colors.grey.shade300),
                              const SizedBox(height: 16),
                              Text(
                                context.tr('no_shifts'),
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                              ),
                              Text(
                                context.tr('try_adjusting_filters'),
                                style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: _filteredShifts.length,
                          itemBuilder: (context, index) {
                            final shift = _filteredShifts[index];
                            return _buildShiftCard(context, provider, shift);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Container(
                constraints: const BoxConstraints(minWidth: 120),
                child: DropdownButtonFormField<String>(
                  value: _filterStatus,
                  isDense: true,
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
                    _applyFilters();
                  },
                ),
              ),
              
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _startDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setState(() => _startDate = date);
                    _applyFilters();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _startDate != null ? Colors.purple : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.purple.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today, size: 14, color: _startDate != null ? Colors.white : Colors.purple),
                      const SizedBox(width: 4),
                      Text(
                        _startDate != null ? '📅 ${DateFormat('yyyy-MM-dd').format(_startDate!)}' : context.tr('from_date'),
                        style: TextStyle(
                          fontSize: 12,
                          color: _startDate != null ? Colors.white : Colors.purple,
                        ),
                      ),
                      if (_startDate != null)
                        GestureDetector(
                          onTap: () {
                            setState(() => _startDate = null);
                            _applyFilters();
                          },
                          child: const Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                    ],
                  ),
                ),
              ),
              
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _endDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setState(() => _endDate = date);
                    _applyFilters();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _endDate != null ? Colors.purple : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.purple.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today, size: 14, color: _endDate != null ? Colors.white : Colors.purple),
                      const SizedBox(width: 4),
                      Text(
                        _endDate != null ? '📅 ${DateFormat('yyyy-MM-dd').format(_endDate!)}' : context.tr('to_date'),
                        style: TextStyle(
                          fontSize: 12,
                          color: _endDate != null ? Colors.white : Colors.purple,
                        ),
                      ),
                      if (_endDate != null)
                        GestureDetector(
                          onTap: () {
                            setState(() => _endDate = null);
                            _applyFilters();
                          },
                          child: const Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                    ],
                  ),
                ),
              ),
              
              Consumer<ShiftProvider>(
                builder: (context, provider, _) {
                  final presses = provider.presses;
                  return Container(
                    constraints: const BoxConstraints(minWidth: 120),
                    child: DropdownButtonFormField<String>(
                      value: _selectedPressId,
                      isDense: true,
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
                        ...presses.map((press) =>
                          DropdownMenuItem(
                            value: press.id,
                            child: Text(press.name),
                          )
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedPressId = value);
                        _applyFilters();
                      },
                    ),
                  );
                },
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _supervisorController,
                  decoration: InputDecoration(
                    labelText: context.tr('supervisor_label_short'),
                    border: const OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: const Icon(Icons.person, size: 16),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  onChanged: (_) => _applyFilters(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _dieNameController,
                  decoration: InputDecoration(
                    labelText: context.tr('die_name_label'),
                    border: const OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: const Icon(Icons.inventory, size: 16),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  onChanged: (_) => _applyFilters(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShiftCard(BuildContext context, ShiftProvider provider, ShiftModel shift) {
    final press = provider.getPressById(shift.pressId);
    final isActive = shift.isActive;
    final isExpanded = _expandedShifts[shift.id] ?? false;
    
    final efficiency = press != null ? shift.getEfficiency(press.targetTonsPerHour) : 0.0;
    final efficiencyColor = provider.getEfficiencyColor(efficiency);
    final efficiencyEmoji = provider.getEfficiencyEmoji(efficiency);
    
    final totalScrap = shift.totalScrapWeight;
    final totalScrapPct = shift.totalScrapPercentage;
    final scrapColor = _getScrapColor(totalScrapPct);
    
    final shiftDate = shift.endedAt ?? shift.createdAt;
    final dateFormatted = DateFormat('yyyy-MM-dd HH:mm').format(shiftDate);

    int totalGoodBars = 0;
    int totalScrapBars = 0;
    int totalRelatedBars = 0;
    for (var die in shift.dies) {
      totalGoodBars += die.goodBarCount ?? 0;
      totalScrapBars += die.scrapBarCount ?? 0;
      totalRelatedBars += die.relatedBarCount ?? 0;
    }

    final dies = shift.dies.where((d) => d.status != DieStatus.draft).toList();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          ListTile(
            dense: true,
            leading: CircleAvatar(
              backgroundColor: isActive ? Colors.green : Colors.grey,
              radius: 20,
              child: Text(
                '${shift.shiftNumber}',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    press?.name ?? shift.pressName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.green : Colors.grey,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isActive ? context.tr('active_status') : context.tr('finished_status'),
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('👤 ${shift.supervisor} | 🔧 ${shift.technician}'),
                Text('📊 ${shift.totalDies} ${context.tr('dies_word')} | 🔢 ${shift.totalBillets} ${context.tr('billets_word')} | ⚖️ ${shift.totalWeightFormatted}'),
                Row(
                  children: [
                    Text(context.tr('efficiency_label'), style: const TextStyle(fontSize: 11)),
                    Text(
                      '${efficiency.toStringAsFixed(1)}% $efficiencyEmoji',
                      style: TextStyle(fontSize: 11, color: efficiencyColor, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Text('📅 $dateFormatted', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ],
            ),
            trailing: IconButton(
              icon: Icon(
                isExpanded ? Icons.expand_less : Icons.expand_more,
                color: Colors.purple,
              ),
              onPressed: () {
                setState(() {
                  _expandedShifts[shift.id] = !isExpanded;
                });
              },
            ),
          ),
          
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _statItem(context.tr('duration_word'), shift.actualDurationFormatted, Colors.blue),
                            _statItem(context.tr('work_time'), shift.totalWorkFormatted, Colors.green),
                            _statItem(context.tr('downtime_between_dies'), shift.gapFormatted, Colors.orange),
                          ],
                        ),
                        const Divider(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _statItem(context.tr('total_weight_label'), shift.totalWeightFormatted, Colors.blueGrey),
                            _statItem(context.tr('avg_productivity_label2'), shift.averageProductivityFormatted, Colors.purple),
                            _statItem(
                              context.tr('shift_efficiency_label'),
                              '${efficiency.toStringAsFixed(1)}% $efficiencyEmoji',
                              efficiencyColor,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // ✅ عرض جميع تفاصيل القوالب كما في الصورة
                  if (dies.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.inventory, size: 18, color: Colors.blue),
                        const SizedBox(width: 6),
                        Text(
                          '📋 القوالب (${dies.length})',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ...dies.map((die) => _buildDieCard(context, provider, shift, die)),
                  ],
                  
                  const SizedBox(height: 8),
                  
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
                      icon: const Icon(Icons.visibility, size: 16),
                      label: Text(context.tr('view_shift_details')),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.purple,
                        side: const BorderSide(color: Colors.purple),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ✅ بطاقة القالب مع جميع التفاصيل (كما في الصورة)
  Widget _buildDieCard(BuildContext context, ShiftProvider provider, ShiftModel shift, DieModel die) {
    final hasData = die.hasProductionData;
    final scrapColor = _getScrapColor(die.scrapPercentage);
    final press = provider.getPressById(shift.pressId);
    final targetTonsPerHour = press?.targetTonsPerHour ?? 0.0;
    final dieEfficiency = die.getEfficiency(targetTonsPerHour);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      color: Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // رقم القالب واسمه
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: hasData ? Colors.green : Colors.orange,
                  radius: 14,
                  child: Text(
                    '${shift.dies.indexOf(die) + 1}',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    die.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: hasData ? Colors.green : Colors.orange,
                    ),
                  ),
                ),
                // عدد الفتحات
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${die.holes} فتحات',
                    style: TextStyle(fontSize: 10, color: Colors.blue.shade700),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 6),
            
            // تفاصيل القالب الكاملة
            Wrap(
              spacing: 4,
              runSpacing: 2,
              children: [
                _detailChip('📏 القطر', press?.diameterInInches.toStringAsFixed(1) ?? '?', Colors.deepOrange),
                _detailChip('📏 طول القطعة', die.pieceLength != null ? '${die.pieceLength!.toStringAsFixed(1)} م' : '---', Colors.deepOrange),
                _detailChip('📈 الإنتاجية', die.productivityFormatted, Colors.purple),
                _detailChip('⏱️ المدة', die.durationFormatted, Colors.blue),
                _detailChip('⚖️ الوزن', die.totalWeightFormatted, Colors.green),
                _detailChip('🔢 البليت', '${die.billetCount}', Colors.teal),
                _detailChip('⚡ السرعة', die.ramSpeed.toStringAsFixed(1), Colors.orange),
                _detailChip('🌡️ الحرارة', '${die.billetTemperature.toStringAsFixed(0)}°C', Colors.red),
                _detailChip('📏 الطول', '${die.billetLength.toStringAsFixed(0)} مم', Colors.indigo),
                _detailChip('🔧 السبيكة', die.alloy, Colors.purple),
                _detailChip('⏰ الخروج', DateFormat('HH:mm').format(die.exitTime), Colors.blue),
                _detailChip('📏 طول الفرش', die.tableLength != null ? '${die.tableLength!.toStringAsFixed(1)} م' : '---', Colors.deepOrange),
                _detailChip('📊 كفاءة الإنتاج', '${dieEfficiency.toStringAsFixed(1)}%', provider.getEfficiencyColor(dieEfficiency)),
                if (die.productionEfficiency > 0)
                  _detailChip('📈 كفاءة الإنتاج', '${die.productionEfficiency.toStringAsFixed(1)}%', Colors.green),
              ],
            ),
            
            const SizedBox(height: 4),
            
            // ملخص الخردة إذا كان هناك بيانات إنتاج
            if (hasData) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: scrapColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: scrapColor.withOpacity(0.3)),
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 2,
                  children: [
                    _scrapChip('✅ الأعواد المنتجة', '${die.goodBarCount ?? 0}', Colors.green),
                    _scrapChip('🗑️ الخردة', '${die.scrapBarCount ?? 0}', Colors.orange),
                    _scrapChip('🔗 المتعلقات', '${die.relatedBarCount ?? 0}', Colors.blue),
                    _scrapChip('نسبة الخردة', '${die.scrapPercentage.toStringAsFixed(1)}%', scrapColor),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _detailChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _scrapChip(String label, String value, Color color) {
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