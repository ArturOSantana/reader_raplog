import '../../../shared/models/book.dart';
import '../data/book_repository.dart';

class FetchBooksUseCase {
  final BookRepository _repository;

  FetchBooksUseCase(this._repository);

  Future<List<Book>> call({BookStatus? status}) {
    return _repository.fetchAll(status: status);
  }
}
