import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/services/api_client.dart';
import '../../theme/app_colors.dart';

/// Re-themed auxiliary admin menu screen utilizing the design tokens of the Premium Organic system.
class AdminMenuScreen extends StatefulWidget {
  const AdminMenuScreen({super.key});

  @override
  State<AdminMenuScreen> createState() => _AdminMenuScreenState();
}

class _AdminMenuScreenState extends State<AdminMenuScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: true,
        title: const Text('Manage Menu'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('Menu').snapshots(),
        builder: (context, menuSnapshot) {
          if (menuSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          if (menuSnapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${menuSnapshot.error}',
                style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
              ),
            );
          }

          final docs = menuSnapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'No menu items found',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _AdminMenuItemCard(
                  document: docs[index],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _AdminMenuItemCard extends StatefulWidget {
  const _AdminMenuItemCard({required this.document});

  final QueryDocumentSnapshot<Map<String, dynamic>> document;

  @override
  State<_AdminMenuItemCard> createState() => _AdminMenuItemCardState();
}

class _AdminMenuItemCardState extends State<_AdminMenuItemCard> {
  late final TextEditingController _priceController;
  late final TextEditingController _stockController;
  bool _isSavingPrice = false;
  bool _isSavingStock = false;
  bool _isSavingAvailability = false;

  @override
  void initState() {
    super.initState();
    final data = widget.document.data();
    _priceController = TextEditingController(
      text: (((data['price'] ?? 0) as num).toInt()).toString(),
    );
    _stockController = TextEditingController(
      text: (((data['stock'] ?? 0) as num).toInt()).toString(),
    );
  }

  @override
  void didUpdateWidget(covariant _AdminMenuItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final data = widget.document.data();
    final latestPrice = (((data['price'] ?? 0) as num).toInt()).toString();
    final latestStock = (((data['stock'] ?? 0) as num).toInt()).toString();

    if (_priceController.text != latestPrice) {
      _priceController.text = latestPrice;
    }
    if (_stockController.text != latestStock) {
      _stockController.text = latestStock;
    }
  }

  @override
  void dispose() {
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _updateNumericField({
    required String field,
    required String value,
  }) async {
    final parsed = int.tryParse(value);
    if (parsed == null) return;

    final data = widget.document.data();
    final currentValue = ((data[field] ?? 0) as num).toInt();
    if (parsed == currentValue) return;

    setState(() {
      if (field == 'price') {
        _isSavingPrice = true;
      } else {
        _isSavingStock = true;
      }
    });

    try {
      final backendField = field == 'price' ? 'price' : 'stock';
      await ApiClient.instance.patch(
        '/api/inventory/${widget.document.id}',
        body: {backendField: parsed},
      );
    } finally {
      if (mounted) {
        setState(() {
          if (field == 'price') {
            _isSavingPrice = false;
          } else {
            _isSavingStock = false;
          }
        });
      }
    }
  }

  Future<void> _updateAvailability(bool value) async {
    setState(() {
      _isSavingAvailability = true;
    });

    try {
      await ApiClient.instance.patch(
        '/api/inventory/${widget.document.id}',
        body: {'is_available': value},
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingAvailability = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.document.data();
    final name = (data['name'] as String? ?? 'Unknown').trim();
    final category = (data['category'] as String? ?? '').toLowerCase();
    final isAvailable = (data['isAvailable'] ?? true) as bool;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _EditableNumberField(
                  label: 'Price',
                  controller: _priceController,
                  suffix: _isSavingPrice
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        )
                      : null,
                  onChanged: (value) => _updateNumericField(
                    field: 'price',
                    value: value,
                  ),
                ),
              ),
              if (category != 'mess' && category != 'continental') ...[
                const SizedBox(width: 12),
                Expanded(
                  child: _EditableNumberField(
                    label: 'Stock',
                    controller: _stockController,
                    suffix: _isSavingStock
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                          )
                        : null,
                    onChanged: (value) => _updateNumericField(
                      field: 'stock',
                      value: value,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Available',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              if (_isSavingAvailability)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                ),
              const SizedBox(width: 8),
              Switch(
                value: isAvailable,
                onChanged: _isSavingAvailability ? null : _updateAvailability,
                activeThumbColor: AppColors.primary,
                activeTrackColor: AppColors.primary.withValues(alpha: 0.16),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EditableNumberField extends StatelessWidget {
  const _EditableNumberField({
    required this.label,
    required this.controller,
    required this.onChanged,
    this.suffix,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: onChanged,
      style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textMuted),
        suffixIcon: suffix == null
            ? null
            : Padding(
                padding: const EdgeInsets.all(12),
                child: suffix,
              ),
      ),
    );
  }
}
