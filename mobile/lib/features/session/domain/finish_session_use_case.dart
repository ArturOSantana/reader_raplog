import '../../../shared/models/reading_session.dart';
import '../data/session_repository.dart';

class FinishSessionUseCase {
  final SessionRepository _repository;

  FinishSessionUseCase(this._repository);

  Future<ReadingSession> call({
    required String sessionId,
    required int endPage,
    String? notes,
  }) {
    return _repository.finishSession(
      sessionId: sessionId,
      endPage: endPage,
      notes: notes,
    );
  }
}
