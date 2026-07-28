/// Implementação do StorageProvider via Supabase Storage.
library;

import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../storage_provider.dart';

class SupabaseStorageImpl implements StorageProvider {
  const SupabaseStorageImpl(this._supabase);

  final SupabaseClient _supabase;

  @override
  Future<UploadResult> upload({
    required String bucket,
    required String path,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    await _supabase.storage.from(bucket).uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: mimeType, upsert: true),
    );

    final url = _supabase.storage.from(bucket).getPublicUrl(path);
    return UploadResult(
      path: path,
      publicUrl: url,
      sizeBytes: bytes.lengthInBytes,
      mimeType: mimeType,
    );
  }

  @override
  Future<void> delete({required String bucket, required String path}) async {
    await _supabase.storage.from(bucket).remove([path]);
  }

  @override
  String publicUrl({required String bucket, required String path}) {
    return _supabase.storage.from(bucket).getPublicUrl(path);
  }
}
