import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../main.dart';

class StorageService {
  final _picker = ImagePicker();

  // Pick image from gallery or camera
  Future<File?> pickImage({bool fromCamera = false}) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      print('Error picking image: $e');
      return null;
    }
  }

  // Pick video
  Future<File?> pickVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 3),
      );

      if (video != null) {
        return File(video.path);
      }
      return null;
    } catch (e) {
      print('Error picking video: $e');
      return null;
    }
  }

  // Pick any file
  Future<File?> pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result != null && result.files.single.path != null) {
        return File(result.files.single.path!);
      }
      return null;
    } catch (e) {
      print('Error picking file: $e');
      return null;
    }
  }

  // Upload file to Supabase Storage
  Future<String?> uploadFile({
    required File file,
    required String bucket,
    required String path,
  }) async {
    try {
      // Debug: print current auth info to help diagnose RLS failures
      try {
        debugPrint('🔐 Supabase auth user id: ${supabase.auth.currentUser?.id}');
        debugPrint('🔐 Supabase session: ${supabase.auth.currentSession != null}');
      } catch (e) {
        // ignore
      }
      final bytes = await file.readAsBytes();
      final fileExt = file.path.split('.').last;
      final fileName = '$path.$fileExt';

      await supabase.storage.from(bucket).uploadBinary(
            fileName,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
            ),
          );

      // Get public URL
      final publicUrl = supabase.storage.from(bucket).getPublicUrl(fileName);

      return publicUrl;
    } catch (e) {
      print('Error uploading file: $e');
      return null;
    }
  }

  // Delete file from storage
  Future<bool> deleteFile({
    required String bucket,
    required String path,
  }) async {
    try {
      await supabase.storage.from(bucket).remove([path]);
      return true;
    } catch (e) {
      print('Error deleting file: $e');
      return false;
    }
  }

  // Get file size in MB
  double getFileSizeInMB(File file) {
    final bytes = file.lengthSync();
    return bytes / (1024 * 1024);
  }
}