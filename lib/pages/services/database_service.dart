import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

class _ApiDocRef {
  final String id;
  _ApiDocRef(this.id);
}

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _namesDocId = 'all_product_names';
  final String _baseUrl = 'https://api.dadubd.com';

  Future<List<Map<String, dynamic>>> getProducts({int page = 1, int limit = 20}) async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/products?page=$page&limit=$limit'))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final dynamic decoded = json.decode(response.body);
        List<dynamic> data = [];

        if (decoded is List) {
          data = decoded;
        } else if (decoded is Map) {
          if (decoded.containsKey('products') && decoded['products'] is List) {
            data = decoded['products'];
          } else if (decoded.containsKey('data') && decoded['data'] is List) {
            data = decoded['data'];
          } else if (decoded.containsKey('items') && decoded['items'] is List) {
            data = decoded['items'];
          } else {
            // Fallback: look for any list in the response
            for (var entry in decoded.entries) {
              if (entry.value is List) {
                data = entry.value;
                break;
              }
            }
          }
        }

        if (data.isEmpty && page == 1) {
          return _getProductsFromFirestore();
        }

        return data.map((item) {
          final map = Map<String, dynamic>.from(item);

          String primaryImage = '';
          String thumbImage = '';

          // Recursive search for anything that looks like an image URL
          String findImageUrl(dynamic data) {
            if (data == null) return '';
            if (data is String) {
              String s = data.trim();
              if (s.isEmpty) return '';

              String low = s.toLowerCase();
              // Aggressive URL/Path detection
              if (low.startsWith('http') ||
                  low.contains('pub-') ||
                  low.contains('r2.dev') ||
                  low.contains('cloudinary') ||
                  low.contains('firebasestorage') ||
                  low.contains('.jpg') ||
                  low.contains('.png') ||
                  low.contains('.jpeg') ||
                  low.contains('.webp') ||
                  low.contains('/images/') ||
                  low.contains('/storage/')) {
                return s;
              }
              // If it's a string with a slash and looks like an image key
              if (s.contains('/') &&
                  (low.contains('img') || low.contains('bnimg') || low.length > 15)) {
                return s;
              }
            } else if (data is Map) {
              // Priority search
              final keys = data.keys.toList();
              for (var key in keys) {
                String k = key.toString().toLowerCase();
                if (k == 'image20' ||
                    k == 'image5' ||
                    k == 'image_url' ||
                    k == 'imageurl' ||
                    k == 'image' ||
                    k == 'url' ||
                    k == 'thumb' ||
                    k == 'pic' ||
                    k == 'img' ||
                    k.startsWith('img') ||
                    k.contains('image')) {
                  String found = findImageUrl(data[key]);
                  if (found.isNotEmpty) return found;
                }
              }
              // Exhaustive search
              for (var v in data.values) {
                if (v is String || v is Map || v is List) {
                  String found = findImageUrl(v);
                  if (found.isNotEmpty) return found;
                }
              }
            } else if (data is List) {
              for (var v in data) {
                String found = findImageUrl(v);
                if (found.isNotEmpty) return found;
              }
            }
            return '';
          }

          primaryImage = findImageUrl(map);

          // Try to find a second one for the thumbnail
          if (map.containsKey('image5') && map['image5'] != null) {
            thumbImage = map['image5'].toString();
          } else {
            thumbImage = primaryImage;
          }

          // Helper to normalize URLs
          String normalizeUrl(String url) {
            if (url.isEmpty || url.startsWith('http') || url.contains('pub-')) return url;
            if (url.startsWith('/')) return '$_baseUrl$url';
            if (!url.contains('/')) return '$_baseUrl/images/$url';
            return '$_baseUrl/$url';
          }

          return {
            "id": map['id']?.toString() ?? map['_id']?.toString() ?? '',
            "name": map['name']?.toString() ?? '',
            "price": map['price']?.toString() ?? '0',
            "flashSell": map['flashSell'] == true || map['isFlashSell'] == true,
            "freeGift": map['freeGift'] == true || map['isFreeGift'] == true,
            "details": map['details']?.toString() ?? '',
            "videoLink": map['videoLink']?.toString() ?? '',
            "brand": map['brand']?.toString() ?? 'Others',
            "category": map['category']?.toString() ?? 'Others',
            "deliveryFee": map['deliveryFee']?.toString() ?? '0',
            "freeCoin": int.tryParse(map['freeCoin']?.toString() ?? '0') ?? 0,
            "size": map['size']?.toString() ?? '',
            "stock": map['stock']?.toString() ?? 'Available',
            "clicked": map['clicked'] ?? 0,
            "image5": normalizeUrl(thumbImage),
            "image20": normalizeUrl(primaryImage),
            "image2": normalizeUrl(map['image2']?.toString() ?? ''),
            "image3": normalizeUrl(map['image3']?.toString() ?? ''),
            "fl-price": map['fl-price'] ?? map['flashPrice'],
            "oldPrice": map['oldPrice'],
            "flash-expire": map['flash-expire'] ?? map['flashExpire'],
            "newArrival": map['newArrival'] == true || map['isNewArrival'] == true,
          };
        }).toList();
      } else {
        return page == 1 ? _getProductsFromFirestore() : [];
      }
    } catch (e) {
      print("Error fetching products from API: $e");
      return page == 1 ? _getProductsFromFirestore() : [];
    }
  }

  Future<List<Map<String, dynamic>>> _getProductsFromFirestore() async {
    try {
      final snapshot = await _db.collection('products').get();

      return snapshot.docs.map((doc) {
        final data = doc.data();

        return {
          "id": doc.id,
          "name": data['name']?.toString() ?? '',
          "price": data['price']?.toString() ?? '0',
          "flashSell": data['flashSell'] == true,
          "freeGift": data['freeGift'] == true,
          "details": data['details']?.toString() ?? '',
          "videoLink": data['videoLink']?.toString() ?? '',
          "brand": data['brand']?.toString() ?? 'Others',
          "category": data['category']?.toString() ?? 'Others',
          "deliveryFee": data['deliveryFee']?.toString() ?? '0',
          "freeCoin": int.tryParse(data['freeCoin']?.toString() ?? '0') ?? 0,
          "size": data['size']?.toString() ?? '',
          "stock": data['stock']?.toString() ?? 'Available',
          "clicked": data['clicked'] ?? 0,
          "image5": data['image5']?.toString() ?? data['imageUrl']?.toString() ?? data['image_url']?.toString() ?? '',
          "image20": data['image20']?.toString() ?? data['imageUrl']?.toString() ?? data['image_url']?.toString() ?? '',
          "image2": data['image2']?.toString() ?? '',
          "image3": data['image3']?.toString() ?? '',
          "fl-price": data['fl-price'],
          "oldPrice": data['oldPrice'],
          "flash-expire": data['flash-expire'],
          "newArrival": data['newArrival'],
        };
      }).toList();
    } catch (e) {

      print("Firestore fallback error: $e");
      return [];
    }
  }

  Future<DateTime?> getFlashSellTimer() async {
    final doc = await _db.collection('flash_sell_timer').doc('current').get();

    if (!doc.exists) return null;

    final data = doc.data();
    final value = data?['time'];

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

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

  Future<void> updateProduct(String id, Map<String, dynamic> data) async {
    try {
      final apiData = _sanitizeForApi(data);
      if (data.containsKey('image20')) {
        apiData['image'] = data['image20'];
        apiData['imageUrl'] = data['image20'];
        apiData['image_url'] = data['image20'];
      }
      if (data.containsKey('image5')) {
        apiData['thumbnail'] = data['image5'];
      }

      final response = await http.put(
        Uri.parse('$_baseUrl/products/$id'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(apiData),
      );

      if (response.statusCode != 200) {
        await _db.collection('products').doc(id).update(data);
      }
    } catch (e) {
      await _db.collection('products').doc(id).update(data);
    }
  }

  Future<void> addToFlashSell(String id, Map<String, dynamic> data) async {
    // 1. Update main product (API + Firestore)
    await updateProduct(id, data);

    // 2. Add to flash_sell_products collection
    // We fetch the full product data first to ensure we have everything in the new collection
    try {
      final doc = await _db.collection('products').doc(id).get();
      if (doc.exists) {
        final fullData = doc.data()!;
        await _db.collection('flash_sell_products').doc(id).set({
          ...fullData,
          ...data,
          "updatedAt": FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print("Error adding to flash_sell_products: $e");
    }
  }

  Future<void> removeFromFlashSell(String id, Map<String, dynamic> data) async {
    // 1. Update main product (API + Firestore)
    await updateProduct(id, data);

    // 2. Remove from flash_sell_products collection
    try {
      await _db.collection('flash_sell_products').doc(id).delete();
    } catch (e) {
      print("Error removing from flash_sell_products: $e");
    }
  }

  Future<void> deleteProduct(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/products/$id'),
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        await _db.collection('products').doc(id).delete();
      }
    } catch (e) {
      await _db.collection('products').doc(id).delete();
    }
  }

  Future<dynamic> addProduct(Map<String, dynamic> data) async {
    try {
      final apiData = _sanitizeForApi(data);
      if (data.containsKey('image20')) {
        apiData['image'] = data['image20'];
        apiData['imageUrl'] = data['image20'];
        apiData['image_url'] = data['image20'];
      }
      if (data.containsKey('image5')) {
        apiData['thumbnail'] = data['image5'];
        apiData['thumb'] = data['image5'];
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/products'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(apiData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return _ApiDocRef(responseData['id']?.toString() ?? '');
      } else {
        return await _db.collection('products').add({
          ...data,
          "createdAt": Timestamp.now(),
          "clicked": 0,
        });
      }
    } catch (e) {
      return await _db.collection('products').add({
        ...data,
        "createdAt": Timestamp.now(),
        "clicked": 0,
      });
    }
  }

  Map<String, dynamic> _sanitizeForApi(Map<String, dynamic> data) {
    final Map<String, dynamic> sanitized = Map<String, dynamic>.from(data);
    sanitized.removeWhere((key, value) => value is FieldValue || value is Timestamp);
    return sanitized;
  }

  Future<void> _updateNamesDocument(List<String> names) async {
    await _db.collection('product_names').doc(_namesDocId).set({
      'names': names,
    }, SetOptions(merge: true));
  }

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
      await _updateNamesDocument(names);
    }
  }

  Future<void> updateProductName(String oldName, String newName) async {
    final names = await getProductNames();
    final index = names.indexOf(oldName);
    if (index != -1) {
      names[index] = newName;
      await _updateNamesDocument(names);
    }
  }

  Future<void> removeProductName(String name) async {
    final names = await getProductNames();
    names.remove(name);
    await _updateNamesDocument(names);
  }

  Future<int> getAnonymousUserCount() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('anonymous_users').get();
    return snapshot.size;
  }

  Future<int> getTodayLoginCount() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    final snapshot =
        await FirebaseFirestore.instance
            .collection('logins')
            .where(
              'timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
            )
            .get();

    return snapshot.docs.length;
  }

  Future<List<Map<String, dynamic>>> getAllOrdersVerify() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .where('to_verify', isGreaterThan: [])
              .get();

      List<Map<String, dynamic>> allOrders = [];

      for (final userDoc in snapshot.docs) {
        final userData = userDoc.data();
        final toVerify = userData['to_verify'] as List<dynamic>?;

        if (toVerify != null && toVerify.isNotEmpty) {
          for (final order in toVerify) {
            if (order is Map<String, dynamic>) {
              final orderWithUserInfo = {
                ...order,
                'user_document_id': userDoc.id,
                'user_email': userData['email'],
                'user_name': userData['name'],
                'user_phone': userData['phone'],
                'order_source': 'user_collection',
              };
              allOrders.add(orderWithUserInfo);
            }
          }
        }
      }

      allOrders.sort((a, b) {
        final timestampA =
            a['timestamp'] ?? a['created_at'] ?? a['order_date'] ?? 0;
        final timestampB =
            b['timestamp'] ?? b['created_at'] ?? b['order_date'] ?? 0;

        return timestampB.compareTo(timestampA);
      });

      return allOrders;
    } catch (e) {
      print('Error getting orders: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAllShipped() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .where('to_ship', isGreaterThan: [])
              .get();

      List<Map<String, dynamic>> allOrders = [];

      for (final userDoc in snapshot.docs) {
        final userData = userDoc.data();
        final toShip = userData['to_ship'] as List<dynamic>?;

        if (toShip != null && toShip.isNotEmpty) {
          for (final order in toShip) {
            if (order is Map<String, dynamic>) {
              final orderWithUserInfo = {
                ...order,
                'user_document_id': userDoc.id,
                'user_email': userData['email'],
                'user_name': userData['name'],
                'user_phone': userData['phone'],
                'order_source': 'user_collection',
              };
              allOrders.add(orderWithUserInfo);
            }
          }
        }
      }

      allOrders.sort((a, b) {
        final timestampA =
            a['timestamp'] ?? a['created_at'] ?? a['order_date'] ?? 0;
        final timestampB =
            b['timestamp'] ?? b['created_at'] ?? b['order_date'] ?? 0;

        return timestampB.compareTo(timestampA);
      });

      return allOrders;
    } catch (e) {
      print('Error getting orders: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAllDelivered() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .where('completed', isGreaterThan: [])
              .get();

      List<Map<String, dynamic>> allOrders = [];

      for (final userDoc in snapshot.docs) {
        final userData = userDoc.data();
        final toShip = userData['completed'] as List<dynamic>?;

        if (toShip != null && toShip.isNotEmpty) {
          for (final order in toShip) {
            if (order is Map<String, dynamic>) {
              final orderWithUserInfo = {
                ...order,
                'user_document_id': userDoc.id,
                'user_email': userData['email'],
                'user_name': userData['name'],
                'user_phone': userData['phone'],
                'order_source': 'user_collection',
              };
              allOrders.add(orderWithUserInfo);
            }
          }
        }
      }

      allOrders.sort((a, b) {
        final timestampA =
            a['timestamp'] ?? a['created_at'] ?? a['order_date'] ?? 0;
        final timestampB =
            b['timestamp'] ?? b['created_at'] ?? b['order_date'] ?? 0;

        return timestampB.compareTo(timestampA);
      });

      return allOrders;
    } catch (e) {
      print('Error getting orders: $e');
      return [];
    }
  }

  Future<void> moveItemsToShip({required String userEmail}) async {
    final usersRef = FirebaseFirestore.instance.collection('users');

    final querySnapshot =
        await usersRef.where('email', isEqualTo: userEmail).limit(1).get();

    if (querySnapshot.docs.isEmpty) {
      throw Exception("User not found for email: $userEmail");
    }

    final userDoc = querySnapshot.docs.first.reference;

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(userDoc);
      if (!snapshot.exists) throw Exception("User document not found");

      final data = snapshot.data()!;

      final toVerify = List<dynamic>.from(data['to_verify'] ?? []);
      final toShip = List<dynamic>.from(data['to_ship'] ?? []);

      toShip.addAll(toVerify);

      toVerify.clear();

      transaction.update(userDoc, {'to_verify': toVerify, 'to_ship': toShip});
    });
  }

  Future<void> moveItemsToCompleted({required String userEmail}) async {
    final usersRef = FirebaseFirestore.instance.collection('users');

    final querySnapshot =
        await usersRef.where('email', isEqualTo: userEmail).limit(1).get();

    if (querySnapshot.docs.isEmpty) {
      throw Exception("User not found for email: $userEmail");
    }

    final userDoc = querySnapshot.docs.first.reference;

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(userDoc);
      if (!snapshot.exists) throw Exception("User document not found");

      final data = snapshot.data()!;

      final toShip = List<dynamic>.from(data['to_ship'] ?? []);
      final completed = List<dynamic>.from(data['completed'] ?? []);

      completed.addAll(toShip);

      toShip.clear();
      transaction.update(userDoc, {'to_ship': toShip, 'completed': completed});
    });
  }

  Future<void> removeItemsFromVerify({required String userEmail}) async {
    final usersRef = FirebaseFirestore.instance.collection('users');

    final querySnapshot =
        await usersRef.where('email', isEqualTo: userEmail).limit(1).get();

    if (querySnapshot.docs.isEmpty) {
      throw Exception("User not found for email: $userEmail");
    }

    final userDoc = querySnapshot.docs.first.reference;

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(userDoc);
      if (!snapshot.exists) throw Exception("User document not found");

      transaction.update(userDoc, {'to_verify': []});
    });
  }

  Future<void> removeItemsFromShip({required String userEmail}) async {
    final usersRef = FirebaseFirestore.instance.collection('users');

    final querySnapshot =
        await usersRef.where('email', isEqualTo: userEmail).limit(1).get();

    if (querySnapshot.docs.isEmpty) {
      throw Exception("User not found for email: $userEmail");
    }

    final userDoc = querySnapshot.docs.first.reference;

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(userDoc);
      if (!snapshot.exists) throw Exception("User document not found");

      transaction.update(userDoc, {'to_ship': []});
    });
  }

  Future<List<Map<String, dynamic>>> getAllReceived() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .where('to_receive', isGreaterThan: [])
              .get();

      List<Map<String, dynamic>> allOrders = [];

      for (final userDoc in snapshot.docs) {
        final userData = userDoc.data();
        final toReceive = userData['to_receive'] as List<dynamic>?;

        if (toReceive != null && toReceive.isNotEmpty) {
          for (final order in toReceive) {
            if (order is Map<String, dynamic>) {
              final orderWithUserInfo = {
                ...order,
                'user_document_id': userDoc.id,
                'user_email': userData['email'],
                'user_name': userData['name'],
                'user_phone': userData['phone'],
                'order_source': 'user_collection',
              };
              allOrders.add(orderWithUserInfo);
            }
          }
        }
      }

      allOrders.sort((a, b) {
        final timestampA =
            a['timestamp'] ?? a['created_at'] ?? a['order_date'] ?? 0;
        final timestampB =
            b['timestamp'] ?? b['created_at'] ?? b['order_date'] ?? 0;

        return timestampB.compareTo(timestampA);
      });

      return allOrders;
    } catch (e) {
      print('Error getting orders: $e');
      return [];
    }
  }

  Future<void> moveItemsToReceive({required String userEmail}) async {
    final usersRef = FirebaseFirestore.instance.collection('users');

    final querySnapshot =
        await usersRef.where('email', isEqualTo: userEmail).limit(1).get();

    if (querySnapshot.docs.isEmpty) {
      throw Exception("User not found for email: $userEmail");
    }

    final userDoc = querySnapshot.docs.first.reference;

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(userDoc);
      if (!snapshot.exists) throw Exception("User document not found");

      final data = snapshot.data()!;

      final toShip = List<dynamic>.from(data['to_ship'] ?? []);
      final toReceive = List<dynamic>.from(data['to_receive'] ?? []);

      toReceive.addAll(toShip);

      toShip.clear();

      transaction.update(userDoc, {'to_ship': toShip, 'to_receive': toReceive});
    });
  }

  Future<void> moveReceiveToCompleted({required String userEmail}) async {
    final usersRef = FirebaseFirestore.instance.collection('users');

    final querySnapshot =
        await usersRef.where('email', isEqualTo: userEmail).limit(1).get();

    if (querySnapshot.docs.isEmpty) {
      throw Exception("User not found for email: $userEmail");
    }

    final userDoc = querySnapshot.docs.first.reference;

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(userDoc);
      if (!snapshot.exists) throw Exception("User document not found");

      final data = snapshot.data()!;

      final toReceive = List<dynamic>.from(data['to_receive'] ?? []);
      final completed = List<dynamic>.from(data['completed'] ?? []);

      completed.addAll(toReceive);

      toReceive.clear();
      transaction.update(userDoc, {'to_receive': toReceive, 'completed': completed});
    });
  }

  Future<void> removeItemsFromReceive({required String userEmail}) async {
    final usersRef = FirebaseFirestore.instance.collection('users');

    final querySnapshot =
        await usersRef.where('email', isEqualTo: userEmail).limit(1).get();

    if (querySnapshot.docs.isEmpty) {
      throw Exception("User not found for email: $userEmail");
    }

    final userDoc = querySnapshot.docs.first.reference;

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(userDoc);
      if (!snapshot.exists) throw Exception("User document not found");

      transaction.update(userDoc, {'to_receive': []});
    });
  }

  Stream<int> getReceiveCountStream() {
    return _db
        .collection('users')
        .where('to_receive', isGreaterThan: [])
        .snapshots()
        .map((snapshot) => snapshot.size);
  }

  Stream<int> getVerifyCountStream() {
    return _db
        .collection('users')
        .where('to_verify', isGreaterThan: [])
        .snapshots()
        .map((snapshot) => snapshot.size);
  }

  Stream<int> getShippingCountStream() {
    return _db
        .collection('users')
        .where('to_ship', isGreaterThan: [])
        .snapshots()
        .map((snapshot) => snapshot.size);
  }

  Future<int> getTotalDownloadCount() async {
    final aggregate = await _db.collection('anonymous_users').count().get();
    return aggregate.count ?? 0;
  }

  Future<int> getTotalRegisteredCountStream() async {
    final aggregate = await _db.collection('users').count().get();
    return aggregate.count ?? 0;
  }

  Stream<int> getCompletedCountStream() {
    return _db
        .collection('users')
        .where('completed', isGreaterThan: [])
        .snapshots()
        .map((snapshot) => snapshot.size);
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
        return bTime!.compareTo(aTime!);
      });

      return combined.take(20).toList();
    });
  }

  Future<int> getTodayLogins() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final startTimestamp = Timestamp.fromDate(startOfDay);

    final users =
        await _db
            .collection('users')
            .where('lastLogin', isGreaterThanOrEqualTo: startTimestamp)
            .get();

    final anonymous =
        await _db
            .collection('anonymous_users')
            .where('lastLogin', isGreaterThanOrEqualTo: startTimestamp)
            .get();

    return users.size + anonymous.size;
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

  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    if (email.isEmpty) {
      throw ArgumentError('Email cannot be empty');
    }

    try {
      final usersRef = FirebaseFirestore.instance.collection('users');
      final querySnapshot =
          await usersRef.where('email', isEqualTo: email).limit(1).get();

      if (querySnapshot.docs.isEmpty) {
        return null; // User not found
      }

      final doc = querySnapshot.docs.first;
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id; // Add document ID to returned data

      return data;
    } catch (e) {
      print('Error fetching user by email: $e');
      rethrow; // Let caller handle error
    }
  }

  Future<void> updateUserByEmail(
    String email,
    Map<String, dynamic> updatedData,
  ) async {
    final usersRef = FirebaseFirestore.instance.collection('users');

    final querySnapshot = await usersRef.where('email', isEqualTo: email).get();

    if (querySnapshot.docs.isNotEmpty) {
      final docId = querySnapshot.docs.first.id;

      await usersRef.doc(docId).update(updatedData);
      print('User updated successfully.');
    } else {
      print('No user found with this email.');
    }
  }

  Future<void> createNotificationForUserByEmail({
    required String email,
    required String title,
    required String body,
    String deepLink = '',
    bool highPriority = true,
    bool withSound = true,
  }) async {
    final Map<String, dynamic>? user = await getUserByEmail(email);

    if (user == null || (user['id']?.toString().isEmpty ?? true)) {
      throw Exception('User not found for notification: $email');
    }

    await _db.collection('notifications').add({
      'title': title,
      'body': body,
      'audience': 'Specific User',
      'userId': user['id'],
      'deepLink': deepLink,
      'sentBy': 'admin_verify',
      'status': 'queued',
      'highPriority': highPriority,
      'withSound': withSound,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> sendPushNotification({
    required String email,
    required String title,
    required String body,
  }) async {
    final Map<String, dynamic>? user = await getUserByEmail(email);

    if (user == null || (user['id']?.toString().isEmpty ?? true)) {
      throw Exception('User not found for notification: $email');
    }

    await _db.collection('order_push_notifications').add({
      'title': title,
      'body': body,
      'userId': user['id'],
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<Map<String, dynamic>>> getBanners() async {
    try {
      QuerySnapshot querySnapshot = await _db.collection('banners').get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {'id': doc.id, 'imageUrl': data['imageUrl']};
      }).toList();
    } catch (e) {
      print("Error fetching active banners: $e");
      return [];
    }
  }

  Future<void> addBanner(String bannerUrl) async {
    try {
      await _db.collection('banners').add({
        'imageUrl': bannerUrl,
        'createdAt': Timestamp.now(),
      });
    } catch (e) {
      print("Error adding banner: $e");
      rethrow;
    }
  }

  Future<void> deleteBanner(String bannerId) async {
    try {
      await _db.collection('banners').doc(bannerId).delete();
    } catch (e) {
      print("Error deleting banner: $e");
      rethrow;
    }
  }

  Future<void> setPaymentNumber({
    required String number,
    String? bkash,
    String? nagad,
    String? rocket,
  }) async {
    await FirebaseFirestore.instance
        .collection("paymentNumber")
        .doc('9O1UpVqUrdyuTqiA3YQH')
        .set({
          'number': number,
          'bkash': bkash ?? '',
          'nagad': nagad ?? '',
          'rocket': rocket ?? '',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<List<Map<String, dynamic>>> getAllFreeGiftRecevier() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .where('gift', isEqualTo: true)
              .get();

      List<Map<String, dynamic>> allReceivers = [];

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        allReceivers.add(data);
      }

      return allReceivers;
    } catch (e) {
      print('Error getting free gift receivers: $e');
      return [];
    }
  }

  Future<void> closeGiftDraw() async {
    try {
      final usersSnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .where('gift', isEqualTo: true)
              .get();

      for (final doc in usersSnapshot.docs) {
        await doc.reference.update({'gift': false});
      }

      final productsSnapshot =
          await FirebaseFirestore.instance
              .collection('products')
              .where('freeGift', isEqualTo: true)
              .get();

      for (final doc in productsSnapshot.docs) {
        await doc.reference.update({'freeGift': false});
      }
    } catch (e) {
      print('Error closing gift draw: $e');
      rethrow;
    }
  }

  Future<void> updateGiftWinner(Map<String, dynamic> winner) async {
    await FirebaseFirestore.instance.collection("free_gift").doc("winner").set({
      "name": winner['name'] ?? winner['user_name'] ?? "Unknown",

      /// combine district + thana
      "location": "${winner['district'] ?? ''} ${winner['thana'] ?? ''}".trim(),

      "user_id": winner['user_id'] ?? winner['uid'] ?? "",

      "time": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<Map<String, dynamic>> getAdAnalyticsStream() {
    return _db
        .collection("ad_analytics")
        .doc("monthly_reward_ads")
        .snapshots()
        .map((snapshot) => snapshot.data() ?? {});
  }

  Future<void> deleteCompletedOrder({
    required String userDocId,
    required Map<String, dynamic> orderData,
  }) async {
    final userRef = _db.collection('users').doc(userDocId);
    try {
      await _db.runTransaction((transaction) async {
        final userSnapshot = await transaction.get(userRef);
        if (!userSnapshot.exists) {
          throw Exception("User not found");
        }
        final userData = userSnapshot.data();
        if (userData == null) {
          throw Exception("User data is null");
        }

        final completedOrders = List<dynamic>.from(userData['completed'] ?? []);

        completedOrders.removeWhere((order) {
          if (order is Map<String, dynamic>) {
            return order['timestamp'] == orderData['timestamp'];
          }
          return false;
        });

        transaction.update(userRef, {'completed': completedOrders});
      });
    } catch (e) {
      print("Error deleting order: $e");
      rethrow;
    }
  }
}
