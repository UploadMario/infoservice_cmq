import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FavoritesService extends ChangeNotifier {
  FavoritesService._();

  static final FavoritesService instance = FavoritesService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Set<String> _favoriteIds = {};
  StreamSubscription? _sub;
  StreamSubscription? _authSub;

  Set<String> get favoriteIds => Set.unmodifiable(_favoriteIds);

  void init() {
    _authSub?.cancel();
    _sub?.cancel();
    _favoriteIds.clear();
    final user = _auth.currentUser;
    if (user != null) {
      _sub = _firestore
          .collection('usuarios')
          .doc(user.uid)
          .collection('favoritos')
          .snapshots()
          .listen((snapshot) {
        _favoriteIds.clear();
        for (final doc in snapshot.docs) {
          _favoriteIds.add(doc.id);
        }
        notifyListeners();
      });
    }
    notifyListeners();

    _authSub = _auth.authStateChanges().listen((newUser) {
      _sub?.cancel();
      _favoriteIds.clear();
      if (newUser != null) {
        _sub = _firestore
            .collection('usuarios')
            .doc(newUser.uid)
            .collection('favoritos')
            .snapshots()
            .listen((snapshot) {
          _favoriteIds.clear();
          for (final doc in snapshot.docs) {
            _favoriteIds.add(doc.id);
          }
          notifyListeners();
        });
      }
      notifyListeners();
    });
  }

  bool isFavorite(String productId) => _favoriteIds.contains(productId);

  Future<void> toggle(String productId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final ref = _firestore
        .collection('usuarios')
        .doc(user.uid)
        .collection('favoritos')
        .doc(productId);

    if (_favoriteIds.contains(productId)) {
      await ref.delete();
    } else {
      await ref.set({'creado_en': FieldValue.serverTimestamp()});
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }
}
