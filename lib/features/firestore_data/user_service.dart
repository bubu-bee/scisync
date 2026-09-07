import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // --- 1. THE LIVE STREAM (FIXED) ---
  // Returns an empty stream instead of throwing a synchronous exception if user is null
  Stream<DocumentSnapshot> getUserStream() {
    final String? userId = _auth.currentUser?.uid;

    if (userId == null) {
      return const Stream.empty(); // <--- Prevents the red box crash!
    }

    return _firestore.collection('users').doc(userId).snapshots();
  }

  // --- 2. TEXT UPDATER ---
  // Saves the typed Name and LinkedIn URL
  Future<void> updateProfileDetails(String newName, String newLinkedIn) async {
    final String? userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      await _firestore.collection('users').doc(userId).update({
        'name': newName,
        'linkedinUrl': newLinkedIn,
      });
    } catch (e) {
      print("Error updating profile: $e");
      rethrow;
    }
  }

  // --- 3. IMAGE UPLOADER ---
  // Opens the camera roll and saves the photo to Firebase Storage
  Future<void> uploadProfilePicture() async {
    final String? userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image == null) return;

      Reference storageRef = _storage.ref().child('profile_pics/$userId.jpg');
      await storageRef.putFile(File(image.path));

      String downloadUrl = await storageRef.getDownloadURL();
      await _firestore.collection('users').doc(userId).update({
        'profileImageUrl': downloadUrl,
      });
    } catch (e) {
      print("Error uploading image: $e");
      rethrow;
    }
  }
}
