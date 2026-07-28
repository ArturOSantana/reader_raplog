/// Implementação da Media Pipeline via Supabase Storage (Fase 2A).
///
/// Compressão de imagens: stub — delega para o pacote `flutter_image_compress`
/// quando disponível (injetável via MediaCompressor).
/// Em produção: trocar compressor por CloudflareImagesCompressor ou similar.
library;

import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/storage_provider.dart';
import 'media_pipeline.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Interface do compressor (Provider Pattern)
// ─────────────────────────────────────────────────────────────────────────────

/// Contrato para compressão de imagens.
/// Implementação default: passthrough (sem compressão).
abstract interface class MediaCompressor {
  Future<Uint8List> compress(
    Uint8List bytes,
    String mimeType, {
    int maxWidthPx,
    int qualityPercent,
  });
  String get compressorName;
}

/// Passthrough — sem compressão (desenvolvimento/stub).
class PassthroughCompressor implements MediaCompressor {
  const PassthroughCompressor();

  @override
  Future<Uint8List> compress(
    Uint8List bytes,
    String mimeType, {
    int maxWidthPx = 1200,
    int qualityPercent = 85,
  }) async =>
      bytes;

  @override
  String get compressorName => 'PassthroughCompressor';
}

// ─────────────────────────────────────────────────────────────────────────────
// SupabaseMediaPipeline
// ─────────────────────────────────────────────────────────────────────────────

class SupabaseMediaPipeline implements MediaPipeline {
  SupabaseMediaPipeline({
    required StorageProvider storage,
    required SupabaseClient supabase,
    MediaCompressor? compressor,
  })  : _storage = storage,
        _supabase = supabase,
        _compressor = compressor ?? const PassthroughCompressor();

  final StorageProvider _storage;
  final SupabaseClient _supabase;
  final MediaCompressor _compressor;

  // ── MediaPipeline ────────────────────────────────────────────────────────

  @override
  Future<MediaUploadResult> uploadImage({
    required Uint8List bytes,
    required String mimeType,
    required MediaAssetType assetType,
    required String userId,
    String? filename,
  }) async {
    // 1. Validação MIME
    if (!MediaAllowedMimes.image.contains(mimeType)) {
      throw MimeNotAllowedError(mimeType);
    }

    // 2. Validação de tamanho
    final sizeLimit = assetType == MediaAssetType.avatar
        ? MediaSizeLimits.avatar
        : MediaSizeLimits.cover;

    if (bytes.lengthInBytes > sizeLimit) {
      throw FileTooLargeError(bytes.lengthInBytes, sizeLimit);
    }

    // 3. Compressão
    final compressed = await _compressor.compress(
      bytes,
      mimeType,
      maxWidthPx: assetType == MediaAssetType.avatar ? 400 : 800,
      qualityPercent: 85,
    );

    // 4. Upload para storage
    final bucket = _bucketFor(assetType);
    final path = '$userId/${_filename(filename, mimeType)}';
    final result = await _storage.upload(
      bucket: bucket,
      path: path,
      bytes: compressed,
      mimeType: 'image/webp', // normalizado para WebP em produção
    );

    // 5. Registro na tabela media_assets
    await _supabase.from('media_assets').insert({
      'user_id': userId,
      'type': assetType.name,
      'original_url': result.publicUrl,
      'processed_url': result.publicUrl,
      'mime_type': result.mimeType,
      'size_bytes': result.sizeBytes,
      'status': 'ready',
    });

    return MediaUploadResult(
      originalUrl: result.publicUrl,
      processedUrl: result.publicUrl,
      mimeType: result.mimeType,
      sizeBytes: result.sizeBytes,
    );
  }

  @override
  Future<MediaUploadResult> uploadDocument({
    required Uint8List bytes,
    required String mimeType,
    required String userId,
    String? filename,
  }) async {
    if (!MediaAllowedMimes.document.contains(mimeType)) {
      throw MimeNotAllowedError(mimeType);
    }
    if (bytes.lengthInBytes > MediaSizeLimits.document) {
      throw FileTooLargeError(bytes.lengthInBytes, MediaSizeLimits.document);
    }

    final path = '$userId/${_filename(filename, mimeType)}';
    final result = await _storage.upload(
      bucket: StorageBuckets.documents,
      path: path,
      bytes: bytes,
      mimeType: mimeType,
    );

    return MediaUploadResult(
      originalUrl: result.publicUrl,
      mimeType: result.mimeType,
      sizeBytes: result.sizeBytes,
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _bucketFor(MediaAssetType type) {
    return switch (type) {
      MediaAssetType.avatar    => StorageBuckets.avatars,
      MediaAssetType.cover     => StorageBuckets.bookCovers,
      MediaAssetType.clubCover => StorageBuckets.clubMedia,
      MediaAssetType.attachment => StorageBuckets.documents,
    };
  }

  static String _filename(String? name, String mimeType) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final ext = mimeType.split('/').last;
    return name != null ? '${name.replaceAll(' ', '_')}_$ts.$ext' : '$ts.$ext';
  }
}
