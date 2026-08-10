import 'package:flutter/material.dart';

class VoteButtonWidget extends StatefulWidget {
  final String suggestionId;
  final int initialVoteCount;
  final bool initialVoted;
  final Function(int newCount, bool voted)? onVoteChanged;

  const VoteButtonWidget({
    super.key,
    required this.suggestionId,
    required this.initialVoteCount,
    this.initialVoted = false,
    this.onVoteChanged,
  });

  @override
  State<VoteButtonWidget> createState() => _VoteButtonWidgetState();
}

class _VoteButtonWidgetState extends State<VoteButtonWidget> {
  late int voteCount;
  late bool isVoted;
  bool isProcessing = false;

  @override
  void initState() {
    super.initState();
    voteCount = widget.initialVoteCount;
    isVoted = widget.initialVoted;
  }

  void _toggleVote() {
    if (isProcessing) return;
    setState(() {
      isProcessing = true;
      if (isVoted) {
        voteCount = (voteCount > 0) ? voteCount - 1 : 0;
        isVoted = false;
      } else {
        voteCount += 1;
        isVoted = true;
      }
    });

    if (widget.onVoteChanged != null) {
      widget.onVoteChanged!(voteCount, isVoted);
    }

    setState(() {
      isProcessing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _toggleVote,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isVoted
              ? Theme.of(context).primaryColor
              : Theme.of(context).primaryColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isVoted ? Icons.thumb_up : Icons.thumb_up_outlined,
              size: 16,
              color: isVoted ? Colors.white : Theme.of(context).primaryColor,
            ),
            const SizedBox(width: 6),
            Text(
              '$voteCount',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isVoted ? Colors.white : Theme.of(context).primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
