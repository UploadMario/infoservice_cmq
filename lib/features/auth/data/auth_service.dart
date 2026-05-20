import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = credential.user;
    if (user == null) return credential;

    await user.updateDisplayName(name.trim());
    await _firestore.collection('usuarios').doc(user.uid).set({
      'uid': user.uid,
      'nombre': name.trim(),
      'correo': email.trim().toLowerCase(),
      'rol': 'vendedor',
      'estado': 'activo',
      'empresa': 'infoservice',
      'creadoEn': FieldValue.serverTimestamp(),
      'actualizadoEn': FieldValue.serverTimestamp(),
    });

    return credential;
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getCurrentUserData() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(code: 'no-user', message: 'No hay sesión activa.');
    }
    return _firestore.collection('usuarios').doc(user.uid).get();
  }

  Future<void> signOut() => _auth.signOut();
}
