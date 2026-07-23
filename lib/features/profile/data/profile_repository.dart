import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/user_profile.dart';

class ProfileRepository {
  final SupabaseClient _client;

  ProfileRepository(this._client);

  String get _userId => _client.auth.currentUser!.id;

  Future<UserProfile?> fetch() async {
    final data = await _client
        .from('profiles')
        .select()
        .eq('id', _userId)
        .maybeSingle();
    if (data == null) return null;
    return UserProfile.fromMap(data);
  }

  Future<UserProfile> upsert(Map<String, dynamic> fields) async {
    final data = await _client
        .from('profiles')
        .upsert({...fields, 'id': _userId})
        .select()
        .single();
    return UserProfile.fromMap(data);
  }

  /// Faz upload da imagem para o bucket `avatars` e retorna a URL pública.
  Future<String> uploadAvatar(File imageFile) async {
    final ext = imageFile.path.split('.').last.toLowerCase();
    final path = '$_userId/avatar.$ext';
    await _client.storage
        .from('avatars')
        .upload(path, imageFile, fileOptions: const FileOptions(upsert: true));
    return _client.storage.from('avatars').getPublicUrl(path);
  }
}
