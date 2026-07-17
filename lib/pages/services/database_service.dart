import 'dart:async';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/api_service.dart';
import '../../constants/constants.dart';

class ApiDocRef {
  final String id;
  ApiDocRef(this.id);
}

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _namesDocId = 'all_product_names';
  final String _baseUrl = apiBaseUrl;

  Future<List<Map<String, dynamic>>> getProducts({int page = 1, int limit = 20}) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '/products?page=$page&limit=$limit&t=$timestamp';
      
      // Using the new ApiService for authenticated requests
      final dynamic decoded = await ApiService().get(path);
      
      if (decoded != null) {
        List<dynamic> data = [];

        if (decoded is List) {
          data = decoded;
        } else if (decoded is Map) {
          data = decoded['data'] ?? decoded['products'] ?? decoded['items'] ?? [];
        }

        // Fetch flash sell products from Firestore to overlay
        Map<String, Map<String, dynamic>> flashMap = {};
        try {
          final flashSnapshot = await _db.collection('flash_sell_products').get().timeout(const Duration(seconds: 5));
          flashMap = {
            for (var doc in flashSnapshot.docs) doc.id: doc.data()
          };
        } catch (e) {
          // Firebase Overlay skipped
        }

        return data.map((item) {
          final map = Map<String, dynamic>.from(item);
          final String productId = map['id']?.toString() ?? map['_id']?.toString() ?? '';

          String normalizeUrl(String url) {
            if (url.isEmpty || url.startsWith('http') || url.contains('pub-')) return url;
            if (url.startsWith('/')) return '$_baseUrl$url';
            return '$_baseUrl/images/$url';
          }

          final result = {
            "id": productId,
            "name": map['name']?.toString() ?? '',
            "price": map['price']?.toString() ?? '0',
            "flashSell": map['flashSell'] == true || map['isFlashSell'] == true,
            "freeGift": map['freeGift'] == true || map['isFreeGift'] == true,
            "details": map['details']?.toString() ?? '',
            "videoLink": map['videoLink']?.toString() ?? '',
            "brand": map['brand']?.toString() ?? 'Others',
            "category": map['catagory']?.toString() ?? map['category']?.toString() ?? 'Others',
            "deliveryFee": map['deliveryFee']?.toString() ?? '0',
            "freeCoin": int.tryParse(map['freeCoin']?.toString() ?? '0') ?? 0,
            "size": map['size']?.toString() ?? '',
            "stock": (map['stock'] == 1 || map['stock'] == '1' || map['stock'] == 'Available') ? 'Available' : 'Not Available',
            "developerCommission": map['developerCommission']?.toString() ?? '0',
            "clicked": map['clicked'] ?? 0,
            "image5": normalizeUrl(map['imageThree']?.toString() ?? map['image5']?.toString() ?? ''),
            "image20": normalizeUrl(map['imagePrimary']?.toString() ?? map['image20']?.toString() ?? ''),
            "image2": normalizeUrl(map['imageOne']?.toString() ?? map['image2']?.toString() ?? ''),
            "image3": normalizeUrl(map['imageTwo']?.toString() ?? map['image3']?.toString() ?? ''),
            "fl-price": map['fl-price'] ?? map['flashPrice'],
            "oldPrice": map['oldPrice'],
            "flash-expire": map['flash-expire'] ?? map['flashExpire'],
            "newArrival": map['newArrival'] == true || map['isNewArrival'] == true,
            "createdAt": map['createdAt'],
          };

          if (flashMap.containsKey(productId)) {
            final fData = flashMap[productId]!;
            if (fData.containsKey('flashSell')) result['flashSell'] = fData['flashSell'] == true;
            if (fData.containsKey('price')) result['price'] = fData['price'].toString();
            if (fData.containsKey('oldPrice')) result['oldPrice'] = fData['oldPrice']?.toString();
            if (fData.containsKey('fl-price')) result['fl-price'] = fData['fl-price']?.toString();
            if (fData.containsKey('flash-expire')) result['flash-expire'] = fData['flash-expire'];
          }

          return result;
        }).toList();
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  Future<void> updateProduct(String id, Map<String, dynamic> data) async {
    try {
      final Map<String, dynamic> apiData = {
        'name': data['name']?.toString() ?? '',
        'price': double.tryParse(data['price'].toString()) ?? 0.0,
        'details': data['details']?.toString() ?? '',
        'videoLink': data['videoLink']?.toString() ?? '',
        'brand': data['brand']?.toString() ?? '',
        'catagory': data['category']?.toString() ?? 'Others',
        'imagePrimary': data['image20']?.toString() ?? '',
        'imageOne': data['image2']?.toString() ?? '',
        'imageTwo': data['image3']?.toString() ?? '',
        'imageThree': data['image5']?.toString() ?? '',
        'freeCoin': int.tryParse(data['freeCoin']?.toString() ?? '0') ?? 0,
        'size': data['size']?.toString() ?? '',
        'stock': data['stock'] == 'Available' ? 1 : 0,
        'deliveryFee': data['deliveryFee']?.toString() ?? '0',
        'developerCommission': double.tryParse(data['developerCommission'].toString()) ?? 0.0,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      await ApiService().put('/products/$id', body: apiData);
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> addProduct(Map<String, dynamic> data) async {
    try {
      final Map<String, dynamic> apiData = {
        'name': data['name']?.toString() ?? '',
        'price': double.tryParse(data['price'].toString()) ?? 0.0,
        'details': data['details']?.toString() ?? '',
        'videoLink': data['videoLink']?.toString() ?? '',
        'brand': data['brand']?.toString() ?? '',
        'catagory': data['category']?.toString() ?? 'Others',
        'imagePrimary': data['image20']?.toString() ?? '',
        'imageOne': data['image2']?.toString() ?? '',
        'imageTwo': data['image3']?.toString() ?? '',
        'imageThree': data['image5']?.toString() ?? '',
        'freeCoin': int.tryParse(data['freeCoin']?.toString() ?? '0') ?? 0,
        'size': data['size']?.toString() ?? '',
        'stock': data['stock'] == 'Available' ? 1 : 0,
        'deliveryFee': data['deliveryFee']?.toString() ?? '0',
        'developerCommission': double.tryParse(data['developerCommission'].toString()) ?? 0.0,
        'createdAt': DateTime.now().toIso8601String(), // Send timestamp
      };

      final responseData = await ApiService().post('/products', body: apiData);
      return ApiDocRef(responseData['id']?.toString() ?? '');
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteProduct(String id) async {
    await ApiService().delete('/products/$id');
  }

  // Flash Sell Timer Methods
  Future<DateTime?> getFlashSellTimer() async {
    final doc = await _db.collection('flash_sell_timer').doc('current').get();
    if (!doc.exists) return null;
    final value = doc.data()?['time'];
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  Future<void> setFlashSellTimer(DateTime timer) {
    return _db.collection('flash_sell_timer').doc('current').set({
      'time': Timestamp.fromDate(timer),
    });
  }

  Future<void> deleteFlashSellTimer() {
    return _db.collection('flash_sell_timer').doc('current').delete();
  }

  Future<void> addToFlashSell(String id, Map<String, dynamic> data) async {
    await _db.collection('flash_sell_products').doc(id).set({
      'id': id,
      ...data,
      "updatedAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> removeFromFlashSell(String id, Map<String, dynamic> data) async {
    await _db.collection('flash_sell_products').doc(id).delete();
  }

  // Name management methods
  Future<List<String>> getProductNames() async {
    final doc = await _db.collection('product_names').doc(_namesDocId).get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      return List<String>.from(data['names'] ?? []);
    }
    return [];
  }

  Future<void> addProductName(String name) async {
    final names = await getProductNames();
    if (!names.contains(name)) {
      names.add(name);
      await _db.collection('product_names').doc(_namesDocId).set({'names': names}, SetOptions(merge: true));
    }
  }

  Future<void> updateProductName(String oldName, String newName) async {
    final names = await getProductNames();
    final index = names.indexOf(oldName);
    if (index != -1) {
      names[index] = newName;
      await _db.collection('product_names').doc(_namesDocId).set({'names': names}, SetOptions(merge: true));
    }
  }

  Future<void> removeProductName(String name) async {
    final names = await getProductNames();
    names.remove(name);
    await _db.collection('product_names').doc(_namesDocId).set({'names': names}, SetOptions(merge: true));
  }

  // Analytics & Orders
  Future<int> getAnonymousUserCount() async => (await _db.collection('anonymous_users').get()).size;

  Future<int> getTodayLoginCount() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    return (await _db.collection('logins').where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay)).get()).docs.length;
  }

  Future<List<Map<String, dynamic>>> getAllOrdersVerify() async => _getOrders('to_verify');
  Future<List<Map<String, dynamic>>> getAllShipped() async => _getOrders('to_ship');
  Future<List<Map<String, dynamic>>> getAllDelivered() async => _getOrders('completed');
  Future<List<Map<String, dynamic>>> getAllReceived() async => _getOrders('to_receive');

  Future<List<Map<String, dynamic>>> _getOrders(String field) async {
    final snapshot = await _db.collection('users').where(field, isGreaterThan: []).get();
    List<Map<String, dynamic>> allOrders = [];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final items = data[field] as List<dynamic>?;
      if (items != null) {
        for (final item in items) {
          if (item is Map<String, dynamic>) {
            allOrders.add({...item, 'user_document_id': doc.id, 'user_email': data['email'], 'user_name': data['name'], 'user_phone': data['phone']});
          }
        }
      }
    }
    allOrders.sort((a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));
    return allOrders;
  }

  Stream<int> getVerifyCountStream() => _db.collection('users').where('to_verify', isGreaterThan: []).snapshots().map((s) => s.size);
  Stream<int> getShippingCountStream() => _db.collection('users').where('to_ship', isGreaterThan: []).snapshots().map((s) => s.size);
  Stream<int> getReceiveCountStream() => _db.collection('users').where('to_receive', isGreaterThan: []).snapshots().map((s) => s.size);
  Stream<int> getCompletedCountStream() => _db.collection('users').where('completed', isGreaterThan: []).snapshots().map((s) => s.size);

  Future<int> getTotalDownloadCount() async => (await _db.collection('anonymous_users').count().get()).count ?? 0;
  Future<int> getTotalRegisteredCountStream() async => (await _db.collection('users').count().get()).count ?? 0;

  Stream<Map<String, dynamic>> getAdAnalyticsStream() => _db.collection("ad_analytics").doc("monthly_reward_ads").snapshots().map((s) => s.data() ?? {});

  Future<void> deleteCompletedOrder({required String userDocId, required Map<String, dynamic> orderData}) async {
    await _db.runTransaction((t) async {
      final ref = _db.collection('users').doc(userDocId);
      final data = (await t.get(ref)).data();
      final completed = List<dynamic>.from(data?['completed'] ?? []);
      completed.removeWhere((o) => o is Map && o['timestamp'] == orderData['timestamp']);
      t.update(ref, {'completed': completed});
    });
  }

  Stream<int> getTodayLoginsStream() {
    final controller = StreamController<int>();
    StreamSubscription<QuerySnapshot>? usersSub;
    StreamSubscription<QuerySnapshot>? anonymousSub;
    Timer? dayChangeTimer;

    void startListening(DateTime dayStart) {
      final startTimestamp = Timestamp.fromDate(dayStart);

      final usersQuery = _db
          .collection('users')
          .where('lastLogin', isGreaterThanOrEqualTo: startTimestamp);
      final anonymousQuery = _db
          .collection('anonymous_users')
          .where('lastLogin', isGreaterThanOrEqualTo: startTimestamp);

      int userCount = 0;
      int anonymousCount = 0;

      void updateTotal() {
        if (!controller.isClosed) {
          controller.add(userCount + anonymousCount);
        }
      }

      usersSub = usersQuery.snapshots().listen((snapshot) {
        userCount = snapshot.size;
        updateTotal();
      });

      anonymousSub = anonymousQuery.snapshots().listen((snapshot) {
        anonymousCount = snapshot.size;
        updateTotal();
      });

      final nextMidnight = dayStart.add(const Duration(days: 1));
      dayChangeTimer = Timer(nextMidnight.difference(DateTime.now()), () {
        usersSub?.cancel();
        anonymousSub?.cancel();
        startListening(nextMidnight);
      });
    }

    controller.onListen = () {
      final now = DateTime.now();
      startListening(DateTime(now.year, now.month, now.day));
    };

    controller.onCancel = () {
      usersSub?.cancel();
      anonymousSub?.cancel();
      dayChangeTimer?.cancel();
    };

    return controller.stream;
  }

  Stream<List<QueryDocumentSnapshot>> getRecentLogins() {
    final usersStream = _db
        .collection('users')
        .orderBy('lastLogin', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) => snapshot.docs);

    final anonymousStream = _db
        .collection('anonymous_users')
        .orderBy('lastLogin', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) => snapshot.docs);

    return usersStream.asyncMap((userDocs) async {
      final anonDocs = await anonymousStream.first;
      final combined = [...userDocs, ...anonDocs];

      combined.sort((a, b) {
        final aTime = a['lastLogin'] as Timestamp?;
        final bTime = b['lastLogin'] as Timestamp?;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

      return combined.take(20).toList();
    });
  }
  
  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    final s = await _db.collection('users').where('email', isEqualTo: email).limit(1).get();
    if (s.docs.isEmpty) return null;
    return {...s.docs.first.data(), 'id': s.docs.first.id};
  }

  Future<void> addBanner(String url) => _db.collection('banners').add({'imageUrl': url, 'createdAt': Timestamp.now()});
  Future<void> deleteBanner(String id) => _db.collection('banners').doc(id).delete();
  Future<List<Map<String, dynamic>>> getBanners() async => (await _db.collection('banners').get()).docs.map((d) => {'id': d.id, 'imageUrl': d.data()['imageUrl']}).toList();
  
  Future<void> moveItemsToShip({required String userEmail}) => _moveOrder(userEmail, 'to_verify', 'to_ship');
  Future<void> moveItemsToReceive({required String userEmail}) => _moveOrder(userEmail, 'to_ship', 'to_receive');
  Future<void> moveReceiveToCompleted({required String userEmail}) => _moveOrder(userEmail, 'to_receive', 'completed');

  Future<void> _moveOrder(String email, String from, String to) async {
    final s = await _db.collection('users').where('email', isEqualTo: email).limit(1).get();
    final ref = s.docs.first.reference;
    await _db.runTransaction((t) async {
      final data = (await t.get(ref)).data()!;
      final listFrom = List<dynamic>.from(data[from] ?? []);
      final listTo = List<dynamic>.from(data[to] ?? []);
      listTo.addAll(listFrom);
      t.update(ref, {from: [], to: listTo});
    });
  }

  Future<void> removeItemsFromVerify({required String userEmail}) async {
    final s = await _db.collection('users').where('email', isEqualTo: userEmail).limit(1).get();
    if (s.docs.isNotEmpty) await s.docs.first.reference.update({'to_verify': []});
  }

  Future<void> removeItemsFromShip({required String userEmail}) async {
    final s = await _db.collection('users').where('email', isEqualTo: userEmail).limit(1).get();
    if (s.docs.isNotEmpty) await s.docs.first.reference.update({'to_ship': []});
  }

  Future<void> removeItemsFromReceive({required String userEmail}) async {
    final s = await _db.collection('users').where('email', isEqualTo: userEmail).limit(1).get();
    if (s.docs.isNotEmpty) await s.docs.first.reference.update({'to_receive': []});
  }

  Future<void> sendPushNotification({required String email, required String title, required String body}) async {
    final user = await getUserByEmail(email);
    if (user != null) {
      await _db.collection('order_push_notifications').add({
        'title': title,
        'body': body,
        'userId': user['id'],
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> updateUserByEmail(String email, Map<String, dynamic> data) async {
    final s = await _db.collection('users').where('email', isEqualTo: email).limit(1).get();
    if (s.docs.isNotEmpty) await s.docs.first.reference.update(data);
  }

  Future<void> setPaymentNumber({required String number, String? bkash, String? nagad, String? rocket}) async {
    await _db.collection("paymentNumber").doc('9O1UpVqUrdyuTqiA3YQH').set({
      'number': number,
      'bkash': bkash ?? '',
      'nagad': nagad ?? '',
      'rocket': rocket ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<List<Map<String, dynamic>>> getAllFreeGiftRecevier() async {
    final s = await _db.collection('users').where('gift', isEqualTo: true).get();
    return s.docs.map((d) => {...d.data(), 'id': d.id}).toList();
  }

  Future<void> closeGiftDraw() async {
    final batch = _db.batch();
    final users = await _db.collection('users').where('gift', isEqualTo: true).get();
    for (var d in users.docs) batch.update(d.reference, {'gift': false});
    final products = await _db.collection('products').where('freeGift', isEqualTo: true).get();
    for (var d in products.docs) batch.update(d.reference, {'freeGift': false});
    await batch.commit();
  }

  Future<void> updateGiftWinner(Map<String, dynamic> winner) async {
    await _db.collection("free_gift").doc("winner").set({
      "name": winner['name'] ?? winner['user_name'] ?? "Unknown",
      "location": "${winner['district'] ?? ''} ${winner['thana'] ?? ''}".trim(),
      "user_id": winner['user_id'] ?? winner['uid'] ?? "",
      "time": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Sell Analytics Methods
  Stream<QuerySnapshot<Map<String, dynamic>>> getMonthlyAnalyticsStream() {
    return _db.collection('sell_analytics').orderBy('monthKey', descending: true).snapshots();
  }

  Future<void> syncMonthlyAnalytics() async {
    final List<Map<String, dynamic>> allDeliveredOrders = await getAllDelivered();
    final Map<String, Map<String, dynamic>> monthlyData = {};

    for (final order in allDeliveredOrders) {
      DateTime? orderDate;
      if (order['timestamp'] is Timestamp) {
        orderDate = (order['timestamp'] as Timestamp).toDate();
      } else if (order['order_date'] != null) {
        orderDate = DateTime.fromMillisecondsSinceEpoch(order['order_date']);
      }

      if (orderDate == null) continue;

      final monthKey = "${orderDate.year}-${orderDate.month.toString().padLeft(2, '0')}";
      final monthName = DateFormat('MMMM yyyy').format(orderDate);

      if (!monthlyData.containsKey(monthKey)) {
        monthlyData[monthKey] = {
          'monthKey': monthKey,
          'monthName': monthName,
          'totalSales': 0.0,
          'totalOrders': 0,
          'updatedAt': FieldValue.serverTimestamp(),
        };
      }

      final total = double.tryParse(order['total']?.toString() ?? '0') ?? 0.0;
      monthlyData[monthKey]!['totalSales'] += total;
      monthlyData[monthKey]!['totalOrders'] += 1;
    }

    // Use a batch to update Firestore
    final batch = _db.batch();
    for (final entry in monthlyData.entries) {
      final ref = _db.collection('sell_analytics').doc(entry.key);
      batch.set(ref, entry.value, SetOptions(merge: true));
    }
    await batch.commit();
  }
}
