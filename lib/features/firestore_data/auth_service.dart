import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  // Singleton pattern for easy access across the app
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Stream to listen to login/logout state changes across the app.
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// Gets the currently logged-in user.
  User? get currentUser => _auth.currentUser;

  /// Signs up a new student and creates their profile with the full verification schema.
  Future<User?> signUp({
    required String email,
    required String password,
    required String name,
    required String batch,
    required String badgeNumber, // E.g., EUSL/TC/IS/2023/COM/1
    required String nic, // Used for barcode verification
    required String dob, // Date of Birth
  }) async {
    try {
      // 1. Create the secure user in Firebase Auth
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 2. Save their public profile data to the Firestore 'users' collection
      if (cred.user != null) {
        await _firestore.collection('users').doc(cred.user!.uid).set({
          'name': name,
          'email': email,
          'batch': batch,
          'badgeNumber': badgeNumber,
          'nic': nic,
          'dob': dob,
          'role': 'student',

          // VERIFICATION FLAG (Nimantha's scanner will change this to true later!)
          'isVerified': false,

          // Optional Profile Fields
          'linkedinUrl': null,
          'bio': null,
          'photoUrl': null,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      return cred.user;
    } catch (e) {
      rethrow;
    }
  }

  /// Signs in an existing user.
  Future<User?> signIn(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return cred.user;
    } catch (e) {
      rethrow;
    }
  }

  /// Logs the user out.
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
