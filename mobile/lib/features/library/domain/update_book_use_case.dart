import '../../../shared/models/book.dart';
import '../data/book_repository.dart';

class UpdateBookUseCase {
  final BookRepository _repository;

  UpdateBookUseCase(this._repository);

  Future<Book> call(String bookId, Map<String, dynamic> fields) {
    return _repository.update(bookId, fields);
  }
}
