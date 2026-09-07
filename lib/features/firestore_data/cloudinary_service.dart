import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';

class CloudinaryService {
  // Replace with your actual Cloudinary Cloud Name from your dashboard
  static final String cloudName = 'ycsckeeu';

  // Set to your exact unsigned preset name
  static final String uploadPreset = 'scisync_preset';

  /// Picks an image and uploads it to Cloudinary using the scisync_preset
  static Future<String?> uploadImage({
    ImageSource source = ImageSource.gallery,
  }) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 80, // Compresses slightly for faster uploads
      );

      if (image == null) return null; // User canceled the picker

      debugPrint("Uploading image to Cloudinary (scisync_preset)...");

      final cloudinary = CloudinaryPublic(
        cloudName,
        uploadPreset,
        cache: false,
      );

      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          image.path,
          resourceType: CloudinaryResourceType.Image,
          folder:
              'scisync_uploads', // Optional folder inside your Cloudinary media library
        ),
      );

      debugPrint("Upload successful! Secure URL: ${response.secureUrl}");
      return response
          .secureUrl; // Returns the public HTTPS URL of the uploaded image
    } catch (e) {
      debugPrint("Error uploading image to Cloudinary: $e");
      return null;
    }
  }
}
