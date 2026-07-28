/// Interface de armazenamento de arquivos da plataforma Lumen.
///
/// Desacopla o app do Supabase Storage, S3, Cloudflare R2 ou qualquer outro
/// serviço de object storage.
library;

import 'dart:typed_data';

// ─────────────────────────────────────────────────────────────────────────────
// Value objects
// ─────────────────────────────────────────────────────────────────────────────

class UploadResult {
  final String path;
  final String publicUrl;
  final int sizeBytes;
  final String mimeType;

  const UploadResult({
    required this.path,
    required this.publicUrl,
    required this.sizeBytes,
    required this.mimeType,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Buckets canônicos
// ─────────────────────────────────────────────────────────────────────────────

abstract final class StorageBuckets {
  StorageBuckets._();

  static const String avatars    = 'avatars';
  static const String bookCovers = 'book-covers';
  static const String clubMedia  = 'club-media';
  static const String documents  = 'documents';
}

// ─────────────────────────────────────────────────────────────────────────────
// Interface
// ─────────────────────────────────────────────────────────────────────────────

abstract interface class StorageProvider {
  /// Faz upload de [bytes] para [bucket]/[path].
  /// Retorna o resultado com URL pública.
  Future<UploadResult> upload({
    required String bucket,
    required String path,
    required Uint8List bytes,
    required String mimeType,
  });

  /// Remove o arquivo em [bucket]/[path].
  Future<void> delete({required String bucket, required String path});

  /// Retorna a URL pública de [bucket]/[path] sem fazer uma requisição de rede.
  String publicUrl({required String bucket, required String path});
}
