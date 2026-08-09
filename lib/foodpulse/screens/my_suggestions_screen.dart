import 'package:flutter/material.dart';
import '../services/foodpulse_service.dart';

class MySuggestionsScreen extends StatefulWidget {
  const MySuggestionsScreen({super.key});

  @override
  State<MySuggestionsScreen> createState() => _MySuggestionsScreenState();
}

class _MySuggestionsScreenState extends State<MySuggestionsScreen> {
  List<dynamic> mySuggestions = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMySuggestions();
  }

  Future<void> _loadMySuggestions() async {
    try {
      final res = await FoodPulseService.getMySuggestions();
      if (mounted) {
        setState(() {
          mySuggestions = res;
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'in_trial':
        return Colors.deepOrange;
      case 'permanent':
        return Colors.purple;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Suggestions'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : mySuggestions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.lightbulb_outline, size: 48, color: Colors.grey),
                      SizedBox(height: 12),
                      Text('You have not suggested any items yet.', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: mySuggestions.length,
                  itemBuilder: (context, index) {
                    final item = mySuggestions[index];
                    final status = item['status'] ?? 'pending';
                    final color = _getStatusColor(status);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    item['name'] ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    status.toUpperCase(),
                                    style: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (item['description'] != null && item['description'].toString().isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                item['description'],
                                style: const TextStyle(fontSize: 13, color: Colors.grey),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Text(
                                  'Category: ${(item['category'] ?? '').toString().toUpperCase()}',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                const Spacer(),
                                Text(
                                  '👍 ${item['vote_count'] ?? 0} Votes',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
