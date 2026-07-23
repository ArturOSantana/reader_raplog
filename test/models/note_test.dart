import 'package:flutter_test/flutter_test.dart';
import 'package:readlog/shared/models/note.dart';

void main() {
  // ── NoteTypeX ─────────────────────────────────────────────────────────────

  group('NoteTypeX.label', () {
    test('retorna os labels corretos', () {
      expect(NoteType.observation.label, 'Observacao');
      expect(NoteType.reflection.label, 'Reflexao');
      expect(NoteType.highlight.label, 'Destaque');
    });
  });

  group('NoteTypeX.dbValue', () {
    test('retorna os valores de BD corretos', () {
      expect(NoteType.observation.dbValue, 'observation');
      expect(NoteType.reflection.dbValue, 'reflection');
      expect(NoteType.highlight.dbValue, 'highlight');
    });
  });

  group('NoteTypeX.fromDb', () {
    test('converte strings do BD corretamente', () {
      expect(NoteTypeX.fromDb('observation'), NoteType.observation);
      expect(NoteTypeX.fromDb('reflection'), NoteType.reflection);
      expect(NoteTypeX.fromDb('highlight'), NoteType.highlight);
    });

    test('retorna observation para valor desconhecido', () {
      expect(NoteTypeX.fromDb('unknown'), NoteType.observation);
    });
  });

  // ── Note.fromMap ──────────────────────────────────────────────────────────

  group('Note.fromMap', () {
    final map = {
      'id': 'note-1',
      'user_id': 'user-1',
      'book_id': 'book-1',
      'type': 'reflection',
      'content': 'Passagem muito marcante',
      'page_number': 42,
      'created_at': '2024-06-01T10:00:00.000Z',
      'updated_at': '2024-06-01T10:00:00.000Z',
    };

    test('faz parse de todos os campos', () {
      final note = Note.fromMap(map);
      expect(note.id, 'note-1');
      expect(note.userId, 'user-1');
      expect(note.bookId, 'book-1');
      expect(note.type, NoteType.reflection);
      expect(note.content, 'Passagem muito marcante');
      expect(note.pageNumber, 42);
    });

    test('aceita pageNumber nulo', () {
      final m = Map<String, dynamic>.from(map);
      m['page_number'] = null;
      final note = Note.fromMap(m);
      expect(note.pageNumber, isNull);
    });
  });

  // ── Note equality (Equatable) ─────────────────────────────────────────────

  group('Note equality', () {
    test('notas com o mesmo id, bookId, type e content são iguais', () {
      final t = DateTime(2024, 6, 1);
      final note1 = Note(
        id: 'n-1',
        userId: 'u-1',
        bookId: 'b-1',
        type: NoteType.observation,
        content: 'Texto',
        createdAt: t,
        updatedAt: t,
      );
      final note2 = Note(
        id: 'n-1',
        userId: 'u-1',
        bookId: 'b-1',
        type: NoteType.observation,
        content: 'Texto',
        createdAt: t,
        updatedAt: t,
      );
      expect(note1, equals(note2));
    });
  });
}
