import 'package:flutter/material.dart';
import '../services/foodpulse_service.dart';
import '../../config/app_config.dart';

/// Minimal blue popup dialog for submitting a food suggestion.
class SuggestionModal extends StatefulWidget {
  const SuggestionModal({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => const SuggestionModal(),
    );
  }

  @override
  State<SuggestionModal> createState() => _SuggestionModalState();
}

class _SuggestionModalState extends State<SuggestionModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  
  String _selectedSection = AppConfig.canteenSections.first;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final res = await FoodPulseService.submitSuggestion(
        name: _nameController.text.trim(),
        description: '',
        category: _selectedSection.toLowerCase(),
      );

      if (!mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res['message'] ?? 'Suggestion sent successfully!',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xFF6B46C1), // Purple theme accent
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      final message = e.toString().replaceAll('Exception: ', '');
      setState(() {
        _isSubmitting = false;
        _errorMessage = message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 16,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          // Blue theme popup container
          gradient: const LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0284C7).withValues(alpha: 0.25),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Row with Close Icon
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lightbulb_rounded,
                      color: Color(0xFF38BDF8),
                      size: 24,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Title
              const Text(
                'Suggest a Food Item',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),

              // Subtitle
              const Text(
                'Have a dish you want to see in the canteen?',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 20),

              // Error banner if any
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Color(0xFFFCA5A5), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 12.5, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Food Item Name Field
              const Text(
                'Food Item Name *',
                style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'e.g. Cold Coffee, Peri Peri Fries',
                  hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                  filled: true,
                  fillColor: const Color(0xFF0F172A).withValues(alpha: 0.6),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF334155)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().length < 2) {
                    return 'Please enter a valid item name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Section Dropdown Field
              const Text(
                'Section in Canteen *',
                style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _selectedSection,
                dropdownColor: const Color(0xFF1E293B),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF38BDF8)),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF0F172A).withValues(alpha: 0.6),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF334155)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
                  ),
                ),
                items: AppConfig.canteenSections.map((sec) {
                  return DropdownMenuItem(
                    value: sec,
                    child: Text(sec),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedSection = val);
                },
              ),
              const SizedBox(height: 24),

              // Purple Rounded Button
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED), // Deep Purple
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shadowColor: const Color(0xFF7C3AED).withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Send Suggestion',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
