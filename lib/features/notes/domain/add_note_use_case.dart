import '../../../shared/models/note.dart';
import '../data/note_repository.dart';

class AddNoteUseCase {
  final NoteRepository _repository;

  AddNoteUseCase(this._repository);

  Future<Note> call({
    required String bookId,
    required NoteType type,
    required String content,
    int? pageNumber,
  }) {
    return _repository.insert(
      bookId: bookId,
      type: type,
      content: content,
      pageNumber: pageNumber,
    );
  }
}
