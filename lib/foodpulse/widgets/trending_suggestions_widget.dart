import 'package:flutter/material.dart';
import '../services/foodpulse_service.dart';
import 'vote_button_widget.dart';

class TrendingSuggestionsWidget extends StatefulWidget {
  const TrendingSuggestionsWidget({super.key});

  @override
  State<TrendingSuggestionsWidget> createState() => _TrendingSuggestionsWidgetState();
}

class _TrendingSuggestionsWidgetState extends State<TrendingSuggestionsWidget> {
  List<dynamic> items = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTrending();
  }

  Future<void> _loadTrending() async {
    try {
      final data = await FoodPulseService.getTrending();
      if (mounted) {
        setState(() {
          items = data;
          isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (items.isEmpty) {
      return const SizedBox(
        height: 100,
        child: Center(
          child: Text('No trending suggestions yet.', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            '🔥 Popular Student Requests',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Container(
                width: 220,
                margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item['name'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      (item['category'] ?? 'general').toString().toUpperCase(),
                      style: TextStyle(fontSize: 11, color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${item['vote_count'] ?? 0} votes',
                          style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
                        ),
                        VoteButtonWidget(
                          suggestionId: item['suggestion_id'] ?? '',
                          initialVoteCount: item['vote_count'] ?? 0,
                          onVoteChanged: (newCount, voted) {
                            if (voted) {
                              FoodPulseService.vote(item['suggestion_id']);
                            } else {
                              FoodPulseService.removeVote(item['suggestion_id']);
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
