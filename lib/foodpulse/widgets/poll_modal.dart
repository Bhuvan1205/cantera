import 'package:flutter/material.dart';
import '../services/foodpulse_service.dart';

/// Modal popup for Community Polling.
class PollModal extends StatefulWidget {
  const PollModal({super.key, this.initialPollData});

  final Map<String, dynamic>? initialPollData;

  static Future<void> show(BuildContext context, {Map<String, dynamic>? pollData}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => PollModal(initialPollData: pollData),
    );
  }

  @override
  State<PollModal> createState() => _PollModalState();
}

class _PollModalState extends State<PollModal> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  Map<String, dynamic>? _poll;
  String? _selectedOptionId;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialPollData != null) {
      _poll = widget.initialPollData;
      _isLoading = false;
    } else {
      _fetchPoll();
    }
  }

  Future<void> _fetchPoll() async {
    try {
      final poll = await FoodPulseService.getActivePoll();
      if (!mounted) return;
      setState(() {
        _poll = poll;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _submitVote() async {
    if (_poll == null || _selectedOptionId == null) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final res = await FoodPulseService.votePoll(
        pollId: _poll!['id'].toString(),
        optionId: _selectedOptionId!,
      );

      if (!mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res['message'] ?? 'Vote submitted successfully!',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xFF7C3AED),
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
          // Dark sleek container with purple accent border
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.2),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: _isLoading
            ? const SizedBox(
                height: 180,
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                ),
              )
            : _poll == null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.poll_outlined, color: Color(0xFF94A3B8), size: 44),
                      const SizedBox(height: 12),
                      const Text(
                        'No Active Poll',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Check back later for new canteen menu polls!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                      ),
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close', style: TextStyle(color: Color(0xFF38BDF8))),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Top Row with Section Badge and Close Icon
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6).withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.bar_chart_rounded, color: Color(0xFFA78BFA), size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  (_poll!['section'] ?? 'General').toString().toUpperCase(),
                                  style: const TextStyle(
                                    color: Color(0xFFA78BFA),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
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
                        'Active Poll',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Question
                      Text(
                        _poll!['question'] ?? 'Which item would you like to see added to the canteen?',
                        style: const TextStyle(
                          color: Color(0xFFE2E8F0),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Error message banner
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
                        const SizedBox(height: 12),
                      ],

                      // Options List (Radio Buttons)
                      RadioGroup<String>(
                        groupValue: _selectedOptionId,
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedOptionId = val);
                          }
                        },
                        child: Column(
                          children: List.generate(
                            (_poll!['options'] as List? ?? []).length,
                            (index) {
                              final opt = (_poll!['options'] as List)[index];
                              final optId = opt['id'].toString();
                              final optText = opt['text'].toString();
                              final isSelected = _selectedOptionId == optId;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedOptionId = optId;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFF7C3AED).withValues(alpha: 0.2)
                                          : const Color(0xFF1E293B).withValues(alpha: 0.7),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFFA78BFA)
                                            : const Color(0xFF334155),
                                        width: isSelected ? 1.5 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Radio<String>(
                                          value: optId,
                                          activeColor: const Color(0xFFA78BFA),
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            optText,
                                            style: TextStyle(
                                              color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                                              fontSize: 14,
                                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Purple Submit Vote Button
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: (_selectedOptionId == null || _isSubmitting) ? null : _submitVote,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7C3AED),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFF4C1D95).withValues(alpha: 0.4),
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
                                  'Submit Vote',
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
    );
  }
}
