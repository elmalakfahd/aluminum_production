import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'models.dart';
import 'services.dart';
import 'app_localization.dart';
// ✅ تم حذف import 'material_stock_detail_screen.dart' لأن الملف غير موجود حالياً

// ============================================================
// 📦 شاشة إدارة رصيد الخامة
// ============================================================
class MaterialStockScreen extends StatefulWidget {
  const MaterialStockScreen({super.key});

  @override
  State<MaterialStockScreen> createState() => _MaterialStockScreenState();
}

class _MaterialStockScreenState extends State<MaterialStockScreen> {
  late ShiftProvider _provider;
  List<MaterialStockModel> _stocks = [];
  bool _isLoading = true;
  bool _isAdding = false;
  String _filterAlloy = 'all';
  String _filterOrigin = 'all';

  final TextEditingController _diameterController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  String _selectedAlloy = '6063';
  String _selectedOrigin = 'imported';

  final List<Map<String, String>> _originOptions = [
    {'value': 'imported', 'label': '🌍 مستوردة'},
    {'value': 'local', 'label': '🇪🇬 محلي'},
    {'value': 'local_foundry', 'label': '🏭 محلي - مسبك'},
  ];

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
      setState(() {
        _stocks = List.from(_provider.materialStocks);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      Fluttertoast.showToast(
        msg: 'خطأ في تحميل البيانات: $e',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  List<MaterialStockModel> get _filteredStocks {
    return _stocks.where((stock) {
      bool matchAlloy = _filterAlloy == 'all' || stock.alloy == _filterAlloy;
      bool matchOrigin = _filterOrigin == 'all' || stock.origin == _filterOrigin;
      return matchAlloy && matchOrigin;
    }).toList();
  }

  // ✅ حساب المجموع الكلي لكل قطر
  Map<double, double> _getTotalStockByDiameter() {
    final Map<double, double> result = {};
    for (var stock in _stocks) {
      result[stock.diameter] = (result[stock.diameter] ?? 0) + stock.stock;
    }
    return result;
  }

  Future<void> _addStock() async {
    final diameter = double.tryParse(_diameterController.text);
    final amount = double.tryParse(_amountController.text);

    if (diameter == null || diameter <= 0) {
      Fluttertoast.showToast(
        msg: '⚠️ الرجاء إدخال قطر صحيح',
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
      return;
    }

    if (amount == null || amount <= 0) {
      Fluttertoast.showToast(
        msg: '⚠️ الرجاء إدخال كمية صحيحة',
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
      return;
    }

    setState(() => _isAdding = true);

    try {
      final existing = _stocks.where((s) =>
          s.diameter == diameter &&
          s.alloy == _selectedAlloy &&
          s.origin == _selectedOrigin
      ).toList();

      MaterialStockModel stock;
      if (existing.isNotEmpty) {
        stock = existing.first.addStock(amount);
      } else {
        final diameterStr = diameter.toStringAsFixed(1).replaceAll('.', '_');
        stock = MaterialStockModel(
          id: 'stock_${diameterStr}_${_selectedAlloy}_${_selectedOrigin}_${DateTime.now().millisecondsSinceEpoch}',
          diameter: diameter,
          stock: amount,
          factoryId: _provider.currentFactoryId,
          alloy: _selectedAlloy,
          origin: _selectedOrigin,
          notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        );
      }

      await _provider.service.saveMaterialStock(_provider.currentFactoryId, stock);
      await _loadData();

      _diameterController.clear();
      _amountController.clear();
      _notesController.clear();
      _selectedAlloy = '6063';
      _selectedOrigin = 'imported';

      setState(() => _isAdding = false);

      final originLabel = _getOriginLabel(_selectedOrigin);
      Fluttertoast.showToast(
        msg: '✅ تم إضافة ${amount.toStringAsFixed(2)} طن من سبيكة $_selectedAlloy ($originLabel) للقطر ${diameter.toStringAsFixed(1)} بوصة',
        backgroundColor: Colors.green,
        textColor: Colors.white,
        toastLength: Toast.LENGTH_LONG,
      );
    } catch (e) {
      setState(() => _isAdding = false);
      Fluttertoast.showToast(
        msg: '❌ خطأ: $e',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  String _getOriginLabel(String origin) {
    for (var option in _originOptions) {
      if (option['value'] == origin) {
        return option['label']!;
      }
    }
    return origin;
  }

  Color _getOriginColor(String origin) {
    switch (origin) {
      case 'imported': return Colors.blue;
      case 'local': return Colors.green;
      case 'local_foundry': return Colors.orange;
      default: return Colors.grey;
    }
  }

  Color _getOriginTextColor(String origin) {
    switch (origin) {
      case 'imported': return Colors.blue.shade700;
      case 'local': return Colors.green.shade700;
      case 'local_foundry': return Colors.orange.shade700;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final canAdd = _provider.canAddMaterialStock;
    final filteredStocks = _filteredStocks;
    final totalByDiameter = _getTotalStockByDiameter();

    return Scaffold(
      appBar: AppBar(
        title: Text('📦 رصيد الخامة'),
        backgroundColor: Colors.amber,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadData,
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (canAdd)
                  Card(
                    color: Colors.amber.shade50,
                    margin: const EdgeInsets.all(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.add, color: Colors.amber),
                              SizedBox(width: 8),
                              Text(
                                '➕ إضافة رصيد خامة',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _diameterController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: '📏 القطر (بوصة)',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                    hintText: '7',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  controller: _amountController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: '⚖️ الكمية (طن)',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                    hintText: '100',
                                  ),
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
                                  decoration: const InputDecoration(
                                    labelText: '🔧 السبيكة',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  items: AlloyModel.getAlloyNames().map((alloy) =>
                                    DropdownMenuItem(
                                      value: alloy,
                                      child: Text(alloy),
                                    )
                                  ).toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() => _selectedAlloy = value);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _selectedOrigin,
                                  decoration: const InputDecoration(
                                    labelText: '🌍 بلد المنشأ',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  items: _originOptions.map((option) =>
                                    DropdownMenuItem(
                                      value: option['value'],
                                      child: Text(option['label']!),
                                    )
                                  ).toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() => _selectedOrigin = value);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _notesController,
                            decoration: const InputDecoration(
                              labelText: '📝 ملاحظات (اختياري)',
                              border: OutlineInputBorder(),
                              isDense: true,
                              hintText: 'مثال: شحنة جديدة من المصنع',
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isAdding ? null : _addStock,
                              icon: _isAdding
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.black,
                                      ),
                                    )
                                  : const Icon(Icons.save),
                              label: Text(
                                _isAdding ? 'جاري الإضافة...' : '💾 إضافة رصيد',
                                style: const TextStyle(fontSize: 14),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // ✅ عرض المجموع الكلي لكل قطر
                if (totalByDiameter.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '📊 إجمالي الرصيد حسب القطر',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: totalByDiameter.entries.map((entry) {
                              final diameter = entry.key;
                              final total = entry.value;
                              return Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.amber.shade300),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      '${diameter.toStringAsFixed(1)}"',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    Text(
                                      '${total.toStringAsFixed(2)} طن',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: total < 50 ? Colors.red : Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _filterAlloy,
                          decoration: const InputDecoration(
                            labelText: '🔧 السبيكة',
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: 'all',
                              child: Text('جميع السبائك'),
                            ),
                            ...AlloyModel.getAlloyNames().map((alloy) =>
                              DropdownMenuItem(
                                value: alloy,
                                child: Text(alloy),
                              )
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _filterAlloy = value);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _filterOrigin,
                          decoration: const InputDecoration(
                            labelText: '🌍 المنشأ',
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: 'all',
                              child: Text('جميع المناشئ'),
                            ),
                            ..._originOptions.map((option) =>
                              DropdownMenuItem(
                                value: option['value'],
                                child: Text(option['label']!),
                              )
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _filterOrigin = value);
                            }
                          },
                        ),
                      ),
                    ],
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
                              '📋 رصيد الخامات',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade100,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${filteredStocks.length} صنف',
                                style: TextStyle(color: Colors.amber.shade700, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: filteredStocks.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.inventory, size: 64, color: Colors.grey.shade300),
                                      const SizedBox(height: 16),
                                      Text(
                                        'لا يوجد رصيد خامات',
                                        style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                                      ),
                                      if (canAdd)
                                        Text(
                                          'أضف رصيداً جديداً من الأعلى',
                                          style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                                        ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: filteredStocks.length,
                                  itemBuilder: (context, index) {
                                    final stock = filteredStocks[index];
                                    final originLabel = _getOriginLabel(stock.origin);
                                    final originColor = _getOriginColor(stock.origin);
                                    final originTextColor = _getOriginTextColor(stock.origin);

                                    return InkWell(
                                      onTap: () {
                                        // ✅ سيتم إضافة شاشة التفاصيل قريباً
                                        Fluttertoast.showToast(
                                          msg: '📦 سيتم إضافة شاشة التفاصيل قريباً',
                                          backgroundColor: Colors.orange,
                                          textColor: Colors.white,
                                        );
                                      },
                                      borderRadius: BorderRadius.circular(8),
                                      child: Card(
                                        margin: const EdgeInsets.symmetric(vertical: 4),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            border: Border(
                                              left: BorderSide(
                                                color: stock.stock < 50 ? Colors.red : Colors.green,
                                                width: 4,
                                              ),
                                            ),
                                          ),
                                          child: ListTile(
                                            leading: CircleAvatar(
                                              backgroundColor: Colors.amber,
                                              child: Text(
                                                stock.diameter.toStringAsFixed(1),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            title: Text(
                                              'قطر ${stock.diameter.toStringAsFixed(1)} بوصة',
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                            subtitle: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('🔧 السبيكة: ${stock.alloy}'),
                                                Row(
                                                  children: [
                                                    Text('🌍 المنشأ: '),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                      decoration: BoxDecoration(
                                                        color: originColor.withOpacity(0.1),
                                                        borderRadius: BorderRadius.circular(8),
                                                        border: Border.all(color: originColor),
                                                      ),
                                                      child: Text(
                                                        originLabel,
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          color: originTextColor,
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (stock.notes != null)
                                                  Text(
                                                    '📝 ${stock.notes}',
                                                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                                                  ),
                                                Text(
                                                  '📅 ${DateFormat('yyyy-MM-dd HH:mm').format(stock.updatedAt)}',
                                                  style: const TextStyle(fontSize: 9, color: Colors.grey),
                                                ),
                                              ],
                                            ),
                                            trailing: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  crossAxisAlignment: CrossAxisAlignment.end,
                                                  children: [
                                                    Text(
                                                      '${stock.stock.toStringAsFixed(2)} طن',
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.bold,
                                                        color: stock.stock < 50 ? Colors.red : Colors.green,
                                                      ),
                                                    ),
                                                    if (stock.stock < 50)
                                                      const Text(
                                                        '⚠️ منخفض',
                                                        style: TextStyle(fontSize: 9, color: Colors.red),
                                                      ),
                                                    const Icon(
                                                      Icons.arrow_forward_ios,
                                                      size: 14,
                                                      color: Colors.grey,
                                                    ),
                                                  ],
                                                ),
                                              ],
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
                ),
              ],
            ),
    );
  }
}