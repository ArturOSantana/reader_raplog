import '../data/note_repository.dart';

class DeleteNoteUseCase {
  final NoteRepository _repository;

  DeleteNoteUseCase(this._repository);

  Future<void> call(String noteId) {
    return _repository.delete(noteId);
  }
}
