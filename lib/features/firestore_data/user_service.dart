import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // --- 1. THE LIVE STREAM ---
  // Fetches the specific room for the logged-in student
  Stream<DocumentSnapshot> getUserStream() {
    final String? userId = _auth.currentUser?.uid;

    if (userId == null) {
      throw Exception("Error: No user is currently logged in.");
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
  // Opens the camera roll and saves the photo to Google Cloud
  Future<void> uploadProfilePicture() async {
    final String? userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image == null) return;

      // Save to Firebase Storage using the user's ID as the filename
      Reference storageRef = _storage.ref().child('profile_pics/$userId.jpg');
      await storageRef.putFile(File(image.path));

      // Grab the secure URL and attach it to the Firestore profile
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
