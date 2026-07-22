import '../data/book_repository.dart';

class DeleteBookUseCase {
  final BookRepository _repository;

  DeleteBookUseCase(this._repository);

  Future<void> call(String bookId) {
    return _repository.delete(bookId);
  }
}
