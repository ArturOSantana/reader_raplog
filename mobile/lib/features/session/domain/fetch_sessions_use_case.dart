import '../../../shared/models/reading_session.dart';
import '../data/session_repository.dart';

class FetchSessionsUseCase {
  final SessionRepository _repository;

  FetchSessionsUseCase(this._repository);

  Future<List<ReadingSession>> call(String bookId) {
    return _repository.fetchByBook(bookId);
  }
}
