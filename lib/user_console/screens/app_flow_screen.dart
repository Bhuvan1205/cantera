import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/services/api_client.dart';
import '../../theme/app_colors.dart';

import '../services/auth_service.dart';
import '../services/order_service.dart';
import '../../wallet/services/wallet_service.dart';
import 'cart_screen.dart';

import 'menu_screen.dart';
import 'order_detail_screen.dart';
import 'order_history_screen.dart';
import 'profile_screen.dart';
import 'queue_screen.dart';
import 'qr_scanner_screen.dart';

class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  Map<String, Map<String, dynamic>> cart = {};
  bool _isPlacingOrder = false;
  bool isAdmin = false;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _menuStream;

  @override
  void initState() {
    super.initState();
    _menuStream = FirebaseFirestore.instance.collection('Menu').snapshots();
    _loadAdminStatus();
  }

  Future<void> _loadAdminStatus() async {
    final admin = await AuthService.isCurrentUserAdmin();
    if (!mounted) return;

    setState(() {
      isAdmin = admin;
    });
  }

  void addToCart(MenuItem item) {
    setState(() {
      if (cart.containsKey(item.id)) {
        cart[item.id]!['quantity'] += 1;
      } else {
        cart[item.id] = {
          'name': item.name,
          'price': item.price,
          'imageUrl': item.imageUrl,
          'quantity': 1,
          'category': item.category,
        };
      }
    });
  }

  void removeFromCartItem(MenuItem item) {
    removeFromCart(item.id);
  }

  void incrementCartItem(String id) {
    setState(() {
      if (cart.containsKey(id)) {
        cart[id]!['quantity'] += 1;
      }
    });
  }

  void removeFromCart(String id) {
    setState(() {
      if (!cart.containsKey(id)) return;
      if (cart[id]!['quantity'] > 1) {
        cart[id]!['quantity'] -= 1;
      } else {
        cart.remove(id);
      }
    });
  }

  void clearCart() => setState(() => cart.clear());

  void _openHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  List<CartItemData> _currentCartItems() {
    return cart.entries
        .map((e) => CartItemData.fromCartEntry(e.key, e.value))
        .toList();
  }

  void _openCart() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReviewOrderScreen(
          cartItems: _currentCartItems(),
          cartItemsBuilder: _currentCartItems,
          isPlacingOrder: _isPlacingOrder,
          onDecrease: removeFromCart,
          onIncrease: incrementCartItem,
          onRemove: (id) => setState(() => cart.remove(id)),
          onPlaceOrder: placeOrder,
          onHomeTap: _openHome,
          onOrdersTap: _openOrders,
          onQueueTap: _openQueue,
        ),
      ),
    );
  }

  void _openOrders() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OrderHistoryPage(
          onOpenHome: _openHome,
          onOpenCart: _openCart,
          onOpenQueue: _openQueue,
        ),
      ),
    );
  }

  void _openQueue() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QueueScreen(
          onHomeTap: _openHome,
          onOrdersTap: _openOrders,
          onCartTap: _openCart,
        ),
      ),
    );
  }

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          isAdmin: isAdmin,
          onOpenScanner: isAdmin ? _openScanner : null,
        ),
      ),
    );
  }

  void _openScanner() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QrScannerScreen(
          isAdmin: isAdmin,
          markAsDelivered: _handleDeliveredScan,
        ),
      ),
    );
  }

  /// Routes every QR scan through OrderService which handles all schema
  /// variants (new subcollection, old categoryTokens, legacy plain orderId).
  Future<String> _handleDeliveredScan(String scannedValue) async {
    return await OrderService.handleQrScan(scannedValue);
  }

  /// Delegates order creation to [OrderService.placeOrderViaBackend].
  /// The FastAPI backend atomically handles stock reservation, price verification,
  /// wallet debit, token generation, and order creation.
  Future<void> placeOrder(
    BuildContext cartContext,
    OrderPaymentMethod method,
  ) async {
    Object? traceException;
    StackTrace? traceStack;

    try {
      if (cart.isEmpty || _isPlacingOrder) return;

      setState(() => _isPlacingOrder = true);

      final navigator = Navigator.of(cartContext);
      final userId = FirebaseAuth.instance.currentUser!.uid;

      final orderId = await OrderService.placeOrderViaBackend(
        cart: cart,
        userId: userId,
        paymentMethod: method == OrderPaymentMethod.wallet ? 'wallet' : 'direct',
      );

      clearCart();
      if (mounted) setState(() => _isPlacingOrder = false);
      if (!cartContext.mounted) return;

      await navigator.pushReplacement(
        MaterialPageRoute(
          builder: (_) => OrderDetailPage(orderId: orderId),
        ),
      );
    } catch (e, stack) {
      traceException = e;
      traceStack = stack;

      if (mounted) setState(() => _isPlacingOrder = false);
      if (!cartContext.mounted) return;

      final messenger = ScaffoldMessenger.of(cartContext);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Order failed: ${e.toString().replaceFirst('Exception: ', '')}'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      debugPrint(
        'STEP 1\n'
        'Executed: YES\n'
        'Timestamp: ${DateTime.now().toUtc().toIso8601String()}\n'
        'Exception: ${traceException == null ? 'None' : '${traceException.runtimeType}: $traceException'}'
        '${traceStack == null ? '' : '\nStackTrace:\n$traceStack'}',
      );
    }
  }

  List<MenuItem> _toMenuItems(

    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.map((doc) {
      final data = doc.data();
      final rawName = data['name'] as String? ?? 'unknown';
      final stock = ((data['stock'] ?? 0) as num).toInt();
      final price = ((data['price'] ?? 0) as num).toInt();
      final category = (data['category'] ?? 'General') as String;
      final isAvailable = (data['isAvailable'] ?? true) as bool;
      // Non-quantifiable items: Mess category + Tea + Coffee.
      // For these, isAvailable is the sole ordering gate (stock ignored).
      final isNonQuantifiable = _isNonQuantifiable(rawName, category);
      return MenuItem(
        id: doc.id,
        name: _toTitleCase(rawName),
        category: category,
        price: price,
        stockLabel: _stockLabelForItem(stock, isAvailable, isNonQuantifiable),
        canAddToCart: isNonQuantifiable ? isAvailable : (isAvailable && stock > 0),
        imageUrl: _resolveImageUrl(
          rawName,
          data['imageUrl'] as String? ?? '',
        ),
      );
    }).toList();
  }

  /// Returns true for items that are not countable by individual units.
  /// Mess items, Continental items, Tea, and Coffee use an on/off availability toggle instead.
  bool _isNonQuantifiable(String rawName, String category) {
    final cat = category.toLowerCase();
    final name = rawName.trim().toLowerCase();
    return cat == 'mess' || cat == 'continental' || name == 'tea' || name == 'coffee';
  }

  String _stockLabelForItem(int stock, bool isAvailable, bool isNonQuantifiable) {
    if (isNonQuantifiable) {
      return isAvailable ? 'AVAILABLE' : 'UNAVAILABLE';
    }
    if (!isAvailable) return 'UNAVAILABLE';
    if (stock == 0) return 'OUT OF STOCK';
    if (stock <= 5) return 'LOW STOCK';
    return 'IN STOCK';
  }

  String _resolveImageUrl(String rawName, String firestoreImageUrl) {
    final normalized = rawName.trim().toLowerCase();

    const curatedImages = <String, String>{
      // ── Bakery ─────────────────────────────────────────────────────────────
      'egg puff':                    'Menu item pictures/Bakery/Bakery/Eggpuff.jpg',
      'veg puff':                    'Menu item pictures/Bakery/Bakery/Vegpuff.png',
      'samosa (big)':                'Menu item pictures/Bakery/Bakery/Bigsamosa.png',
      'samosa (small, 4 pieces)':    'Menu item pictures/Bakery/Bakery/Smallsamosa_4.png',
      'small samosa half plate':     'Menu item pictures/Bakery/Bakery/Smallsamosa_2.png',
      'cream bun':                   'Menu item pictures/Bakery/Bakery/CreamBun.png',
      'maska bun':                   'Menu item pictures/Bakery/Bakery/MaskaBun.png',
      'dilpasand':                   'Menu item pictures/Bakery/Bakery/DilPasand.png',
      'dilkhush':                    'Menu item pictures/Bakery/Bakery/DilKush.png',
      'love bite':                   'Menu item pictures/Bakery/Bakery/lovebite.jpg',
      'oreo biscuit':                'Menu item pictures/Bakery/Bakery/oreo.jpg',
      'hide & seek biscuit':         'Menu item pictures/Bakery/Bakery/hidenseek.jpg',
      'lays':                        'Menu item pictures/Bakery/Bakery/lays.jpg',
      'kurkure':                     'Menu item pictures/Bakery/Bakery/kurkure.png',
      'bingo 20':                    'Menu item pictures/Bakery/Bakery/bingo.jpg',
      'bingo tedhe medhe':           'Menu item pictures/Bakery/Bakery/bingoteedemeede.jpg',
      'snickers':                    'Menu item pictures/Bakery/Bakery/snikers_20.png',
      'munch':                       'Menu item pictures/Bakery/Bakery/munch_10.png',
      'munch 5':                     'Menu item pictures/Bakery/Bakery/munch_5.png',
      '5 star':                      'Menu item pictures/Bakery/Bakery/5star.jpg',
      'dairy milk':                  'Menu item pictures/Bakery/Bakery/Dairymilk_20.jpg',
      'pineapple pastry':            'Menu item pictures/Bakery/Bakery/pineapplepastry.png',
      'black forest pastry':         'Menu item pictures/Bakery/Bakery/blackforestpastry.png',
      'badam milk':                  'Menu item pictures/Bakery/Bakery/badammilk.png',
      'water bottle':                'Menu item pictures/Bakery/Bakery/waterbottle.png',
      'thums up':                    'Menu item pictures/Bakery/Bakery/thumbsup_20.png',
      'pulpy orange':                'Menu item pictures/Bakery/Bakery/pulpyorange_20.png',
      'diet coke':                   'Menu item pictures/Bakery/Bakery/dietcoke.png',
      'maaza':                       'Menu item pictures/Bakery/Bakery/maaza_20.png',
      'maaza 10':                    'Menu item pictures/Bakery/Bakery/maaza_10.png',
      'fanta':                       'Menu item pictures/Bakery/Bakery/fanta.png',
      'coca-cola':                   'Menu item pictures/Bakery/Bakery/cococola_20.png',
      'smooth 20':                   'Menu item pictures/Bakery/Bakery/smoodh_20.png',
      'appy fizz':                   'Menu item pictures/Bakery/Bakery/appyfizz.png',
      'appy fizz tin':               'Menu item pictures/Bakery/Bakery/appyfizzcan_40.png',
      'mogu mogu':                   'Menu item pictures/Bakery/Bakery/mogumogu_40.png',
      'red bull':                    'Menu item pictures/Bakery/Bakery/redbull.png',
      'monster':                     'Menu item pictures/Bakery/Bakery/monster.png',
      'bru cold coffee':             'Menu item pictures/Bakery/Bakery/brucoldcoffee.png',
      'campa 20':                    'Menu item pictures/Bakery/Bakery/campa_20.png',
      'jeera soda':                  'Menu item pictures/Bakery/Bakery/jeerasoda_10.png',
      'butter milk':                 'Menu item pictures/Bakery/Bakery/buttermilk.png',
      // ── Beverages ──────────────────────────────────────────────────────────
      'tea':                         'Menu item pictures/Beverages/Beverages/tea.webp',
      'coffee':                      'Menu item pictures/Beverages/Beverages/coffee.jpg',
      'milk':                        'Menu item pictures/Beverages/Beverages/Milk.jpg',
      'horlicks':                    'Menu item pictures/Beverages/Beverages/Horlicks.jpg',
      'boost':                       'Menu item pictures/Beverages/Beverages/Boost.png',
      'lemon tea':                   'Menu item pictures/Beverages/Beverages/Lemon Tea.jpg',
      'green tea':                   'Menu item pictures/Beverages/Beverages/Green Tea.jpg',
      'black coffee':                'Menu item pictures/Beverages/Beverages/Black Coffee.jpg',
      'mosambi juice':               'Menu item pictures/Beverages/Beverages/Mosambi juice.jpg',
      'pineapple juice':             'Menu item pictures/Beverages/Beverages/Pineapple juice.jpg',
      'grape juice':                 'Menu item pictures/Beverages/Beverages/Grape juice.jpg',
      'watermelon juice':            'Menu item pictures/Beverages/Beverages/Watermelon juice.jpg',
      'muskmelon juice':             'Menu item pictures/Beverages/Beverages/Muskmelon juice.jpg',
      'sapota juice':                'Menu item pictures/Beverages/Beverages/Sapota juice.jpg',
      'cut fruit bowl':              'Menu item pictures/Beverages/Beverages/Fruit bowl.jpg',
      'mango milkshake':             'Menu item pictures/Beverages/Beverages/Mango milkshake.jpg',
      'oreo milkshake':              'Menu item pictures/Beverages/Beverages/Oreo milkshake.jpg',
      'strawberry milkshake':        'Menu item pictures/Beverages/Beverages/Strawberry milkshake.jpg',
      'chocolate milkshake':         'Menu item pictures/Beverages/Beverages/Chocolate milkshake.jpg',
      // ── Mess — Traditional items ────────────────────────────────────────────
      'idly':                        'Menu item pictures/Mess/Mess/Idly.jpg',
      'vada':                        'Menu item pictures/Mess/Mess/Vada.jpg',
      'poori':                       'Menu item pictures/Mess/Mess/Poori.jpg',
      'plain dosa':                  'Menu item pictures/Mess/Mess/Plain dosa.jpg',
      'masala dosa':                 'Menu item pictures/Mess/Mess/Masala dosa.jpg',
      'onion dosa':                  'Menu item pictures/Mess/Mess/Onion dosa.jpg',
      'veg meals':                   'Menu item pictures/Mess/Mess/Veg meals.jpg',
      'special meals':               'Menu item pictures/Mess/Mess/special meals.jpg',
      'jeera rice':                  'Menu item pictures/Mess/Mess/Jeera rice.jpg',
      'curd rice':                   'Menu item pictures/Mess/Mess/Curd rice.jpg',
      'curd':                        'Menu item pictures/Mess/Mess/Curd.jpg',
      'curry':                       'Menu item pictures/Mess/Mess/Curry.jpg',
      'sweet':                       'Menu item pictures/Mess/Mess/Sweet.jpg',
      'parota with kurma':           'Menu item pictures/Mess/Mess/Parota with kurma.jpg',
      // ── Mess — Noodles & Rice ───────────────────────────────────────────────
      'veg noodles':                 'Menu item pictures/Mess/Mess/veg noodles.png',
      'veg manchuria':               'Menu item pictures/Mess/Mess/veg manchurain.png',
      'paneer fried rice':           'Menu item pictures/Mess/Mess/paneer fried rice.png',
      'schezwan noodles':            'Menu item pictures/Mess/Mess/schezwan noodles.png',
      'veg fried rice':              'Menu item pictures/Mess/Mess/veg fried rice.png',
      'manchuria noodles':           'Menu item pictures/Mess/Mess/manchurian noodles.png',
      'manchuria fried rice':        'Menu item pictures/Mess/Mess/manchurian fried rice.png',
      'shezwan fried rice':          'Menu item pictures/Mess/Mess/schezwan fried rice.png',
      'shezwan manchuria':           'Menu item pictures/Mess/Mess/schezwan manchuria.png',
      // ── Mess — Sandwiches & Burgers ────────────────────────────────────────
      'veg grilled sandwich':        'Menu item pictures/Mess/Mess/veg grilled sandwich.png',
      'veg cheese sandwich':         'Menu item pictures/Mess/Mess/veg cheese sandwich.png',
      'tandoori veg burger sandwich':'Menu item pictures/Mess/Mess/tandoori veg burger.png',
      'paneer cheese sandwich':      'Menu item pictures/Mess/Mess/paneer cheese sandwich.png',
      'chipotle paneer cheese sandwich': 'Menu item pictures/Mess/Mess/chipotle paneer cheese sandwich.png',
      'tandoori paneer cheese sandwich': 'Menu item pictures/Mess/Mess/tandoori paneer cheese sandwich.png',
      'classic veg burger':          'Menu item pictures/Mess/Mess/veg burger.png',
      'veg cheese burger':           'Menu item pictures/Mess/Mess/veg cheese burger.png',
      'tandoori veg burger':         'Menu item pictures/Mess/Mess/tandoori veg burger.png',
      'chipotle cheese burger':      'Menu item pictures/Mess/Mess/chipotle cheese burger.png',
      'veg hot dog':                 'Menu item pictures/Continental/Continental/Veg hotdog.jpg',
      'paneer hot dog':              'Menu item pictures/Continental/Continental/Paneer hotdog.jpg',
      // ── Mess — Fries & Snacks ──────────────────────────────────────────────
      'salted fries':                'Menu item pictures/Mess/Mess/salted fries.png',
      'peri peri fries':             'Menu item pictures/Mess/Mess/peri peri fries.png',
      'veg cheese nuggets':          'Menu item pictures/Mess/Mess/veg cheese balls.png',
      'chilli potato pops':          'Menu item pictures/Mess/Mess/chili potato pops.png',
      'veggie finger':               'Menu item pictures/Mess/Mess/veggie fingers.png',
      'veg cheese balls':            'Menu item pictures/Mess/Mess/veg cheese balls.png',
      // ── Mess — Pizza ───────────────────────────────────────────────────────
      'margherita pizza':            'Menu item pictures/Continental/Continental/Margherita.jpg',
      'garden fresh pizza':          'Menu item pictures/Continental/Continental/Garden Fresh.jpg',
      'paneer tikka pizza':          'Menu item pictures/Continental/Continental/Paneer tikka pizza.jpg',
      'bbq paneer pizza':            'Menu item pictures/Continental/Continental/BBQ paneer pizza.jpg',
      'cheese corn pizza':           'Menu item pictures/Continental/Continental/Cheese corn.jpg',
      'tangy tomato pizza':          'Menu item pictures/Continental/Continental/Tangy tomato pizza.jpg',
    };

    final curated = curatedImages[normalized];
    if (curated != null) {
      return curated;
    }

    return firestoreImageUrl;
  }

  /// Capitalizes the first letter of each word for display only.
  /// The backend data is never modified.
  String _toTitleCase(String s) {
    return s.split(' ').map((word) {
      if (word.isEmpty) return word;
      return '${word[0].toUpperCase()}${word.substring(1)}';
    }).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _menuStream,
      builder: (context, snapshot) {
        final isLoading =
            snapshot.connectionState == ConnectionState.waiting;
            
        if (snapshot.hasError) {
          if (kDebugMode) {
            debugPrint('\n=== FIRESTORE ERROR ===');
            debugPrint('Collection Name: Menu');
            debugPrint('Operation: Stream (GET)');
            debugPrint('User UID: ${FirebaseAuth.instance.currentUser?.uid ?? 'NULL'}');
            debugPrint('Exception: ${snapshot.error}');
            debugPrint('=======================\n');
          }
        }

        final items = (snapshot.hasData && snapshot.data!.docs.isNotEmpty)
            ? _toMenuItems(snapshot.data!.docs)
            : <MenuItem>[];

        final categories = [
          'All Items',
          ...{...items.map((i) => i.category)},
        ];

        return MenuScreen(
          items: items,
          categories: categories,
          isLoading: isLoading,
          onAddToCart: addToCart,
          onRemoveFromCart: removeFromCartItem,
          cart: cart,
          userName: FirebaseAuth.instance.currentUser?.displayName,
          onCartTap: _openCart,
          onOrdersTap: _openOrders,
          onQueueTap: _openQueue,
          onProfileTap: _openProfile,
        );
      },
    );
  }
}

Future<void> markAsDelivered(String orderId, String currentStatus) async {
  if (currentStatus.toLowerCase() == 'delivered') return;

  await ApiClient.instance.patch('/api/orders/$orderId/status', body: {
    'status': 'delivered',
  });
}


class OrderHistoryPage extends StatefulWidget {
  const OrderHistoryPage({
    super.key,
    this.onOpenHome,
    this.onOpenCart,
    this.onOpenQueue,
  });

  final VoidCallback? onOpenHome;
  final VoidCallback? onOpenCart;
  final VoidCallback? onOpenQueue;

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  late Future<QuerySnapshot<Map<String, dynamic>>> _ordersFuture;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  void _fetchOrders() {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    _ordersFuture = FirebaseFirestore.instance
        .collection('Orders')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .get(const GetOptions(source: Source.serverAndCache));
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _fetchOrders();
    });
    await _ordersFuture;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
      future: _ordersFuture,
      builder: (context, snapshot) {
        final isLoading =
            snapshot.connectionState == ConnectionState.waiting;

        if (snapshot.hasError) {
          if (kDebugMode) {
            debugPrint('\n=== FIRESTORE ERROR ===');
            debugPrint('Collection Name: Orders');
            debugPrint('Operation: GET');
            debugPrint('User UID: ${FirebaseAuth.instance.currentUser?.uid ?? 'NULL'}');
            debugPrint('Exception: ${snapshot.error}');
            debugPrint('=======================\n');
          }
          return Scaffold(
            backgroundColor: AppColors.bg,
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }

        final orders = snapshot.hasData
            ? snapshot.data!.docs.map(_toOrderHistoryItem).toList()
            : <OrderHistoryItem>[];

        return OrderHistoryScreen(
          orders: orders,
          isLoading: isLoading,
          onTap: (item) => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OrderDetailPage(orderId: item.id),
            ),
          ),
          onHomeTap: widget.onOpenHome,
          onQueueTap: widget.onOpenQueue,
          onCartNavTap: widget.onOpenCart,
          onRefresh: _handleRefresh,
        );
      },
    );
  }
}

class OrderDetailPage extends StatelessWidget {
  final String orderId;

  const OrderDetailPage({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('Orders').doc(orderId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.bg,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        if (snapshot.hasError) {
          if (kDebugMode) {
            debugPrint('\n=== FIRESTORE ERROR ===');
            debugPrint('Collection Name: Orders');
            debugPrint('Document Path: Orders/$orderId');
            debugPrint('Operation: Stream (GET)');
            debugPrint('User UID: ${FirebaseAuth.instance.currentUser?.uid ?? 'NULL'}');
            debugPrint('Exception: ${snapshot.error}');
            debugPrint('=======================\n');
          }
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(
            backgroundColor: AppColors.bg,
            body: Center(
              child: Text('Order not found'),
            ),
          );
        }

        final data = snapshot.data!.data()!;
        final rawItems = (data['items'] as List<dynamic>? ?? []);

        final items = rawItems
            .map((e) => _toOrderItemData(e as Map<String, dynamic>))
            .toList();

        final String orderStatus = (data['status'] as String? ?? 'placed');

        final bool isRefundPendingVal = orderStatus.toLowerCase() == 'refund_pending';
        final shortId = orderId.length >= 4
            ? orderId.substring(0, 4).toUpperCase()
            : orderId.toUpperCase();

        return OrderDetailScreen(
          orderId: orderId,
          orderNumber: '#CC-$shortId',
          status: _normalizeOrderStatus(data['status'] as String?),
          tokenNumber: ((data['tokenNumber'] ?? 0) as num).toInt(),
          items: items,
          total: (data['total'] as num).toInt(),
          onHomeTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
          isRefundPending: isRefundPendingVal,
          onRefundRequest: () async {
            await ApiClient.instance.post('/api/wallet/refunds/request', body: {
              'order_id': orderId,
              'reason': 'User cancelled placed order',
            });
          },
        );
      },
    );
  }
}

OrderHistoryItem _toOrderHistoryItem(
  QueryDocumentSnapshot<Map<String, dynamic>> doc,
) {
  final data = doc.data();
  final rawItems = (data['items'] as List<dynamic>?) ?? [];

  final String title;
  if (rawItems.isEmpty) {
    title = 'Order';
  } else {
    final firstName =
        (rawItems.first as Map<String, dynamic>)['name'] as String? ?? 'Item';
    title = rawItems.length > 1
        ? '$firstName + ${rawItems.length - 1} more'
        : firstName;
  }

  final ts = data['timestamp'] as Timestamp?;
  final String dateTime;
  if (ts != null) {
    final dt = ts.toDate().toLocal();
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    dateTime =
        '${months[dt.month - 1]} ${dt.day}, ${dt.year} - $hour:$minute $period';
  } else {
    dateTime = 'Processing...';
  }

  final status = _normalizeOrderStatus(data['status'] as String?);

  final shortId = doc.id.length >= 4
      ? doc.id.substring(0, 4).toUpperCase()
      : doc.id.toUpperCase();

  return OrderHistoryItem(
    id: doc.id,
    orderNumber: '# ORD-$shortId',
    title: title,
    dateTime: dateTime,
    total: (data['total'] as num).toInt(),
    status: status,
    tokenNumber: ((data['tokenNumber'] ?? 0) as num).toInt(),
    imageUrl: data['imageUrl'] as String?,
    actionLabel: status == 'delivered' ? 'REORDER' : null,
  );
}

OrderItemData _toOrderItemData(Map<String, dynamic> data) {
  return OrderItemData(
    name: data['name'] as String,
    quantityLabel: 'x${data['quantity']}',
    description: data['description'] as String?,
  );
}

String _normalizeOrderStatus(String? status) {
  switch ((status ?? 'pending').toLowerCase()) {
    case 'pending':
      return 'pending';
    case 'placed':
      return 'placed';
    case 'preparing':
      return 'preparing';
    case 'delivered':
      return 'delivered';
    case 'refund_pending':
      return 'refund_pending';
    case 'refunded':
    case 'cancelled':
      return 'cancelled';
    default:
      return 'pending';
  }
}
