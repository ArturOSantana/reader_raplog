import '../../../shared/models/reading_session.dart';
import '../data/session_repository.dart';

class StartSessionUseCase {
  final SessionRepository _repository;

  StartSessionUseCase(this._repository);

  Future<ReadingSession> call({
    required String bookId,
    required int startPage,
  }) {
    return _repository.startSession(bookId: bookId, startPage: startPage);
  }
}
