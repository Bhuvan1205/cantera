import 'package:flutter/material.dart';
import 'suggestion_modal.dart';

/// Floating Action Button for Food Item Suggestion.
///
/// Features:
/// - Positioned bottom-right above bottom nav bar
/// - Eye-catching blue/purple gradient container
/// - Subtle breathing pulse animation
/// - Opens [SuggestionModal] popup on tap
class SuggestionFabWidget extends StatefulWidget {
  const SuggestionFabWidget({super.key});

  @override
  State<SuggestionFabWidget> createState() => _SuggestionFabWidgetState();
}

class _SuggestionFabWidgetState extends State<SuggestionFabWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        );
      },
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        elevation: 8,
        shadowColor: const Color(0xFF0284C7).withValues(alpha: 0.4),
        child: InkWell(
          onTap: () => SuggestionModal.show(context),
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF0284C7), Color(0xFF7C3AED)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.add_comment_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}
