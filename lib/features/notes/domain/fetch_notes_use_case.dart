import '../../../shared/models/note.dart';
import '../data/note_repository.dart';

class FetchNotesUseCase {
  final NoteRepository _repository;

  FetchNotesUseCase(this._repository);

  Future<List<Note>> call(String bookId) {
    return _repository.fetchByBook(bookId);
  }
}
