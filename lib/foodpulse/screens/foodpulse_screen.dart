import 'package:flutter/material.dart';
import '../services/foodpulse_service.dart';
import '../widgets/trending_suggestions_widget.dart';
import '../widgets/vote_button_widget.dart';
import '../widgets/fp_notification_panel.dart';
import 'suggest_item_screen.dart';
import 'my_suggestions_screen.dart';

class FoodPulseScreen extends StatefulWidget {
  const FoodPulseScreen({super.key});

  @override
  State<FoodPulseScreen> createState() => _FoodPulseScreenState();
}

class _FoodPulseScreenState extends State<FoodPulseScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> allSuggestions = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSuggestions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSuggestions() async {
    try {
      final res = await FoodPulseService.getSuggestions();
      if (mounted) {
        setState(() {
          allSuggestions = res;
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
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.poll, color: Colors.purple),
            SizedBox(width: 8),
            Text('FoodPulse'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'My Suggestions',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MySuggestionsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => isLoading = true);
              _loadSuggestions();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Community Menu'),
            Tab(text: 'Notifications'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final refresh = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const SuggestItemScreen()),
          );
          if (refresh == true) {
            _loadSuggestions();
          }
        },
        icon: const Icon(Icons.lightbulb),
        label: const Text('Suggest Item'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Community Menu & Trending
          RefreshIndicator(
            onRefresh: _loadSuggestions,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const TrendingSuggestionsWidget(),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'All Community Suggestions',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (allSuggestions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          'No food suggestions yet. Be the first to suggest one!',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: allSuggestions.length,
                      itemBuilder: (context, index) {
                        final item = allSuggestions[index];

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
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.purple.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        (item['category'] ?? 'general').toString().toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.purple,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (item['description'] != null && item['description'].toString().isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    item['description'],
                                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    if (item['suggested_price'] != null)
                                      Text(
                                        'Price: ₹${item['suggested_price']}',
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                      )
                                    else
                                      const SizedBox.shrink(),
                                    VoteButtonWidget(
                                      suggestionId: item['id'] ?? '',
                                      initialVoteCount: item['vote_count'] ?? 0,
                                      onVoteChanged: (newCount, voted) {
                                        if (voted) {
                                          FoodPulseService.vote(item['id']);
                                        } else {
                                          FoodPulseService.removeVote(item['id']);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),

          // Tab 2: Notifications
          const SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: FoodPulseNotificationPanel(),
          ),
        ],
      ),
    );
  }
}
