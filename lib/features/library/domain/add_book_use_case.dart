import '../../../shared/models/book.dart';
import '../data/book_repository.dart';

class AddBookUseCase {
  final BookRepository _repository;

  AddBookUseCase(this._repository);

  Future<Book> call({
    required String title,
    String? author,
    String? coverUrl,
    int? totalPages,
    String? genre,
    String? publisher,
    BookStatus status = BookStatus.wantToRead,
    int? rating,
  }) {
    return _repository.insert({
      'title': title,
      if (author != null) 'author': author,
      if (coverUrl != null) 'cover_url': coverUrl,
      if (totalPages != null) 'total_pages': totalPages,
      if (genre != null) 'genre': genre,
      if (publisher != null) 'publisher': publisher,
      'status': status.dbValue,
      if (rating != null) 'rating': rating,
    });
  }
}
