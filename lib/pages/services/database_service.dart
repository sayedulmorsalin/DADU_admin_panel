import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _namesDocId = 'all_product_names';



  Future<List<Map<String, dynamic>>> getProducts() async {
    final snapshot = await _db
        .collection('products')
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();

      return {
        "id": doc.id,
        "name": data['name'],
        "price": data['price'],
        "details": data['details'],
        "videoLink": data['videoLink'] ?? '',
        "brand": data['brand'] ?? 'Others',
        "clicked": data['clicked'] ?? 0,
        "image5": data['image5'],
        "image20": data['image20'],

        // 🔥 ADD FLASH SELL FIELDS
        "fl-price": data['fl-price'] ?? null,
        "oldPrice": data['oldPrice'] ?? null,
        "flash-expire": data['flash-expire'] ?? null,
      };
    }).toList();
  }


  Future<void> updateProduct(String id, Map<String, dynamic> data) {
    return _db.collection('products').doc(id).update(data);
  }

  Future<void> deleteProduct(String id) {
    return _db.collection('products').doc(id).delete();
  }


  Future<DocumentReference> addProduct(Map<String, dynamic> data) {
    return _db.collection('products').add({
      ...data,
      "createdAt": Timestamp.now(),
      "clicked": 0,
    });
  }

  // New methods for product names collection
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
      final snapshot = await FirebaseFirestore.instance
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
              // Create a proper order object with user info
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
        final timestampA = a['timestamp'] ?? a['created_at'] ?? a['order_date'] ?? 0;
        final timestampB = b['timestamp'] ?? b['created_at'] ?? b['order_date'] ?? 0;

        // For descending order (latest first)
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
      final snapshot = await FirebaseFirestore.instance
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
              // Create a proper order object with user info
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
        final timestampA = a['timestamp'] ?? a['created_at'] ?? a['order_date'] ?? 0;
        final timestampB = b['timestamp'] ?? b['created_at'] ?? b['order_date'] ?? 0;

        // For descending order (latest first)
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
      final snapshot = await FirebaseFirestore.instance
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
              // Create a proper order object with user info
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
        final timestampA = a['timestamp'] ?? a['created_at'] ?? a['order_date'] ?? 0;
        final timestampB = b['timestamp'] ?? b['created_at'] ?? b['order_date'] ?? 0;

        // For descending order (latest first)
        return timestampB.compareTo(timestampA);
      });

      return allOrders;

    } catch (e) {
      print('Error getting orders: $e');
      return [];
    }
  }




  Future<void> moveItemsToShip({
    required String userEmail,
  }) async {
    final usersRef = FirebaseFirestore.instance.collection('users');

    // Find the user document by email
    final querySnapshot = await usersRef.where('email', isEqualTo: userEmail).limit(1).get();

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

      // Move all orders from to_verify to to_ship
      toShip.addAll(toVerify);

      // Clear to_verify array
      toVerify.clear();

      // Update Firestore document
      transaction.update(userDoc, {
        'to_verify': toVerify,
        'to_ship': toShip,
      });
    });
  }




  Future<void> moveItemsToCompleted({
    required String userEmail,
  }) async {
    final usersRef = FirebaseFirestore.instance.collection('users');

    // Find the user document by email
    final querySnapshot = await usersRef.where('email', isEqualTo: userEmail).limit(1).get();

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

      // Move all orders from to_ship to completed
      completed.addAll(toShip);

      // Clear to_ship array
      toShip.clear();

      // Update Firestore document
      transaction.update(userDoc, {
        'to_ship': toShip,
        'completed': completed,
      });
    });
  }


  Future<void> removeItemsFromVerify({
    required String userEmail,
  }) async {
    final usersRef = FirebaseFirestore.instance.collection('users');

    // Find the user document by email
    final querySnapshot = await usersRef.where('email', isEqualTo: userEmail).limit(1).get();

    if (querySnapshot.docs.isEmpty) {
      throw Exception("User not found for email: $userEmail");
    }

    final userDoc = querySnapshot.docs.first.reference;

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(userDoc);
      if (!snapshot.exists) throw Exception("User document not found");

      // Clear the entire to_verify array
      transaction.update(userDoc, {
        'to_verify': [],
      });
    });
  }


  Future<void> removeItemsFromShip({
    required String userEmail,
  }) async {
    final usersRef = FirebaseFirestore.instance.collection('users');

    // Find the user document by email
    final querySnapshot = await usersRef.where('email', isEqualTo: userEmail).limit(1).get();

    if (querySnapshot.docs.isEmpty) {
      throw Exception("User not found for email: $userEmail");
    }

    final userDoc = querySnapshot.docs.first.reference;

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(userDoc);
      if (!snapshot.exists) throw Exception("User document not found");

      // Clear the entire to_ship array
      transaction.update(userDoc, {
        'to_ship': [],
      });
    });
  }





// Real-time verify count
  Stream<int> getVerifyCountStream() {
    return _db
        .collection('users')
        .where('to_verify', isGreaterThan: [])
        .snapshots()
        .map((snapshot) => snapshot.size);
  }

// Real-time shipping count
  Stream<int> getShippingCountStream() {
    return _db
        .collection('users')
        .where('to_ship', isGreaterThan: [])
        .snapshots()
        .map((snapshot) => snapshot.size);
  }
  // Real-time Total download count
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


// Get recent logins from both collections
  Stream<List<QueryDocumentSnapshot>> getRecentLogins() {
    final usersStream = _db.collection('users')
        .orderBy('lastLogin', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) => snapshot.docs);

    final anonymousStream = _db.collection('anonymous_users')
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

// Update today logins count method
  Future<int> getTodayLogins() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final startTimestamp = Timestamp.fromDate(startOfDay);

    final users = await _db.collection('users')
        .where('lastLogin', isGreaterThanOrEqualTo: startTimestamp)
        .get();

    final anonymous = await _db.collection('anonymous_users')
        .where('lastLogin', isGreaterThanOrEqualTo: startTimestamp)
        .get();

    return users.size + anonymous.size;
  }

  // Add to DatabaseService
  Stream<int> getTodayLoginsStream() {
    final controller = StreamController<int>();
    StreamSubscription<QuerySnapshot>? usersSub;
    StreamSubscription<QuerySnapshot>? anonymousSub;
    Timer? dayChangeTimer;

    void startListening(DateTime dayStart) {
      final startTimestamp = Timestamp.fromDate(dayStart);

      // Users collection
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

      // Listen to users collection
      usersSub = usersQuery.snapshots().listen((snapshot) {
        userCount = snapshot.size;
        updateTotal();
      });

      // Listen to anonymous collection
      anonymousSub = anonymousQuery.snapshots().listen((snapshot) {
        anonymousCount = snapshot.size;
        updateTotal();
      });

      // Schedule next day reset
      final nextMidnight = dayStart.add(const Duration(days: 1));
      dayChangeTimer = Timer(
        nextMidnight.difference(DateTime.now()),
            () {
          usersSub?.cancel();
          anonymousSub?.cancel();
          startListening(nextMidnight); // Restart for new day
        },
      );
    }

    // Initialize with current day
    controller.onListen = () {
      final now = DateTime.now();
      startListening(DateTime(now.year, now.month, now.day));
    };

    // Cleanup resources
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
      final querySnapshot = await usersRef.where('email', isEqualTo: email).limit(1).get();

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


  Future<void> updateUserByEmail(String email, Map<String, dynamic> updatedData) async {
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


  // Add these methods to your DatabaseService class

// Banner management methods
  Future<List<Map<String, dynamic>>> getBanners() async {
    try {
      QuerySnapshot querySnapshot = await _db
          .collection('banners')
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'imageUrl': data['imageUrl'],
        };
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
}

