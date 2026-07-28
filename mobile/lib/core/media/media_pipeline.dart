/// Media Pipeline — spec §8
///
/// Todo upload passa por este pipeline antes de chegar ao StorageProvider.
///
/// Fluxo obrigatório:
///   bytes → validação MIME → limite de tamanho → compressão (stub) → upload → registro
///
/// Nunca salvar arquivo diretamente no storage sem passar por aqui.
library;

import 'dart:typed_data';

// ─────────────────────────────────────────────────────────────────────────────
// Tipos e constantes
// ─────────────────────────────────────────────────────────────────────────────

/// Tipos MIME aceitos por tipo de media.
abstract final class MediaAllowedMimes {
  MediaAllowedMimes._();

  static const List<String> image = [
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/gif',
  ];

  static const List<String> document = [
    'application/pdf',
  ];

  static const List<String> all = [...image, ...document];
}

/// Limites de tamanho por tipo (bytes).
abstract final class MediaSizeLimits {
  MediaSizeLimits._();

  static const int avatar   = 2 * 1024 * 1024;  // 2 MB
  static const int cover    = 5 * 1024 * 1024;  // 5 MB
  static const int document = 20 * 1024 * 1024; // 20 MB
}

/// Tipos de media tratados pelo pipeline.
enum MediaAssetType { avatar, cover, clubCover, attachment }

// ─────────────────────────────────────────────────────────────────────────────
// Resultado
// ─────────────────────────────────────────────────────────────────────────────

class MediaUploadResult {
  final String originalUrl;
  final String? processedUrl;
  final String? thumbnailUrl;
  final String mimeType;
  final int sizeBytes;

  const MediaUploadResult({
    required this.originalUrl,
    this.processedUrl,
    this.thumbnailUrl,
    required this.mimeType,
    required this.sizeBytes,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Erros
// ─────────────────────────────────────────────────────────────────────────────

sealed class MediaPipelineError implements Exception {
  const MediaPipelineError(this.message);
  final String message;
  @override
  String toString() => 'MediaPipelineError: $message';
}

final class MimeNotAllowedError extends MediaPipelineError {
  MimeNotAllowedError(String mime)
      : super('MIME type não permitido: $mime');
}

final class FileTooLargeError extends MediaPipelineError {
  FileTooLargeError(int sizeBytes, int limitBytes)
      : super(
            'Arquivo muito grande: ${(sizeBytes / 1024 / 1024).toStringAsFixed(1)} MB '
            '(limite: ${(limitBytes / 1024 / 1024).toStringAsFixed(0)} MB)');
}

// ─────────────────────────────────────────────────────────────────────────────
// Interface
// ─────────────────────────────────────────────────────────────────────────────

abstract interface class MediaPipeline {
  /// Processa e faz upload de uma imagem.
  ///
  /// Lança [MimeNotAllowedError] ou [FileTooLargeError] em caso de violação.
  Future<MediaUploadResult> uploadImage({
    required Uint8List bytes,
    required String mimeType,
    required MediaAssetType assetType,
    required String userId,
    String? filename,
  });

  /// Processa e faz upload de um documento.
  Future<MediaUploadResult> uploadDocument({
    required Uint8List bytes,
    required String mimeType,
    required String userId,
    String? filename,
  });
}
