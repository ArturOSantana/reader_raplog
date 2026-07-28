/// Banco de frases da "Inspiração do Dia".
///
/// Cada [InspirationQuote] pertence a um [InspirationContext] que descreve
/// o momento do usuário. O [DailyInspirationService] seleciona a frase
/// adequada com base nos eventos do app.
library;

// ── Contextos de inspiração ───────────────────────────────────────────────────

enum InspirationContext {
  /// Chegou o horário configurado para ler.
  readingTime,

  /// Faltam poucas horas para acabar o dia sem ler.
  streakAtRisk,

  /// Terminou a sessão do dia — ofensiva mantida.
  streakKept,

  /// Bateu o recorde pessoal de ofensiva.
  streakRecord,

  /// Concluiu um livro.
  bookCompleted,

  /// Meta diária atingida.
  dailyGoalMet,

  /// Meta semanal atingida.
  weeklyGoalMet,

  /// Adicionou um novo amigo.
  newFriend,

  /// Um amigo concluiu um livro.
  friendCompletedBook,

  /// Encontro do clube de leitura hoje.
  clubMeeting,

  /// Nova votação aberta no clube.
  clubVote,

  /// Nova conquista desbloqueada.
  achievementUnlocked,

  /// Sessão à noite (após 21h).
  eveningReading,

  /// Sessão pela manhã (antes das 10h).
  morningReading,

  /// Domingo — começo da semana.
  sunday,

  /// Primeiro livro cadastrado.
  firstBook,

  /// Primeira sessão de leitura.
  firstSession,

  /// Acumulou 60 min ou mais numa sessão.
  longSession,
}

// ── Modelo ────────────────────────────────────────────────────────────────────

class InspirationQuote {
  final String quote;
  final String? author;
  final InspirationContext context;

  const InspirationQuote({
    required this.quote,
    this.author,
    required this.context,
  });
}

// ── Banco de frases ───────────────────────────────────────────────────────────

const List<InspirationQuote> kInspirationQuotes = [
  // ── Horário de leitura ────────────────────────────────────────────────────

  InspirationQuote(
    quote: 'A leitura é para a mente o que o exercício é para o corpo.',
    author: 'Joseph Addison',
    context: InspirationContext.readingTime,
  ),
  InspirationQuote(
    quote:
        'Um leitor vive mil vidas antes de morrer. Quem nunca lê vive apenas uma.',
    author: 'George R. R. Martin',
    context: InspirationContext.readingTime,
  ),
  InspirationQuote(
    quote: 'Ler é conversar com os maiores homens dos séculos passados.',
    author: 'René Descartes',
    context: InspirationContext.readingTime,
  ),
  InspirationQuote(
    quote: 'Hoje é um ótimo dia para aprender algo que você ainda não sabe.',
    context: InspirationContext.readingTime,
  ),
  InspirationQuote(
    quote: 'Os livros são companhias silenciosas que nunca deixam de ensinar.',
    context: InspirationContext.readingTime,
  ),
  InspirationQuote(
    quote: 'Cada página lida é um passo a mais na pessoa que você deseja se tornar.',
    context: InspirationContext.readingTime,
  ),
  InspirationQuote(
    quote: 'Uma sala sem livros é como um corpo sem alma.',
    author: 'Cícero',
    context: InspirationContext.readingTime,
  ),
  InspirationQuote(
    quote: 'A leitura engrandece a alma.',
    author: 'Voltaire',
    context: InspirationContext.readingTime,
  ),
  InspirationQuote(
    quote:
        'Os livros são a prova de que os seres humanos são capazes de fazer magia.',
    author: 'Carl Sagan',
    context: InspirationContext.readingTime,
  ),

  // ── Streak em risco ───────────────────────────────────────────────────────

  InspirationQuote(
    quote: 'Não desista por causa de um dia difícil.',
    context: InspirationContext.streakAtRisk,
  ),
  InspirationQuote(
    quote: 'A disciplina pesa gramas. O arrependimento pesa toneladas.',
    author: 'Jim Rohn',
    context: InspirationContext.streakAtRisk,
  ),
  InspirationQuote(
    quote: 'A constância constrói resultados que a motivação jamais sustentará.',
    context: InspirationContext.streakAtRisk,
  ),
  InspirationQuote(
    quote: 'Hoje são apenas alguns minutos. Amanhã eles se tornam um hábito.',
    context: InspirationContext.streakAtRisk,
  ),
  InspirationQuote(
    quote: 'Não quebre uma sequência construída com tanto esforço.',
    context: InspirationContext.streakAtRisk,
  ),
  InspirationQuote(
    quote: 'Não deixe que um dia apague semanas de dedicação.',
    context: InspirationContext.streakAtRisk,
  ),
  InspirationQuote(
    quote:
        'Disciplina é escolher o que você mais quer em vez do que quer agora.',
    context: InspirationContext.streakAtRisk,
  ),

  // ── Streak mantida ────────────────────────────────────────────────────────

  InspirationQuote(
    quote:
        'Somos aquilo que fazemos repetidamente. A excelência, portanto, é um hábito.',
    author: 'Aristóteles',
    context: InspirationContext.streakKept,
  ),
  InspirationQuote(
    quote: 'Começar é de todos; perseverar é dos santos.',
    author: 'São Josemaria Escrivá',
    context: InspirationContext.streakKept,
  ),
  InspirationQuote(
    quote: 'O sucesso é a soma de pequenos esforços repetidos dia após dia.',
    author: 'Robert Collier',
    context: InspirationContext.streakKept,
  ),
  InspirationQuote(
    quote: 'Grandes jornadas são vencidas um passo de cada vez.',
    context: InspirationContext.streakKept,
  ),
  InspirationQuote(
    quote: 'Sua ofensiva é construída um dia de cada vez.',
    context: InspirationContext.streakKept,
  ),
  InspirationQuote(
    quote: 'A constância transforma esforço em identidade.',
    context: InspirationContext.streakKept,
  ),
  InspirationQuote(
    quote: 'Grandes leitores não nascem prontos. Eles aparecem todos os dias.',
    context: InspirationContext.streakKept,
  ),
  InspirationQuote(
    quote: 'O hábito é mais forte que a motivação.',
    context: InspirationContext.streakKept,
  ),
  InspirationQuote(
    quote: 'Você está provando para si mesmo que consegue.',
    context: InspirationContext.streakKept,
  ),
  InspirationQuote(
    quote: 'Cada dia conta.',
    context: InspirationContext.streakKept,
  ),
  InspirationQuote(
    quote: 'Hoje é mais um tijolo na construção do seu hábito.',
    context: InspirationContext.streakKept,
  ),
  InspirationQuote(
    quote: 'A vitória pertence a quem continua.',
    context: InspirationContext.streakKept,
  ),
  InspirationQuote(
    quote: 'A sequência de hoje é a força de amanhã.',
    context: InspirationContext.streakKept,
  ),

  // ── Novo recorde de streak ────────────────────────────────────────────────

  InspirationQuote(
    quote: 'Não tenha medo de ir devagar. Tenha medo apenas de ficar parado.',
    author: 'Provérbio chinês',
    context: InspirationContext.streakRecord,
  ),
  InspirationQuote(
    quote: 'Hoje você venceu a pessoa que era ontem.',
    context: InspirationContext.streakRecord,
  ),
  InspirationQuote(
    quote: 'Toda grande conquista começa com a decisão de continuar.',
    context: InspirationContext.streakRecord,
  ),
  InspirationQuote(
    quote: 'O obstáculo no caminho torna-se o caminho.',
    author: 'Marco Aurélio',
    context: InspirationContext.streakRecord,
  ),
  InspirationQuote(
    quote:
        'A felicidade da tua vida depende da qualidade dos teus pensamentos.',
    author: 'Marco Aurélio',
    context: InspirationContext.streakRecord,
  ),

  // ── Livro concluído ───────────────────────────────────────────────────────

  InspirationQuote(
    quote: 'Hoje um leitor. Amanhã um líder.',
    author: 'Margaret Fuller',
    context: InspirationContext.bookCompleted,
  ),
  InspirationQuote(
    quote: 'Um livro termina, mas o conhecimento permanece.',
    context: InspirationContext.bookCompleted,
  ),
  InspirationQuote(
    quote: 'Todo livro muda alguma coisa em quem o lê.',
    context: InspirationContext.bookCompleted,
  ),
  InspirationQuote(
    quote: 'Sua biblioteca cresceu e você também.',
    context: InspirationContext.bookCompleted,
  ),
  InspirationQuote(
    quote:
        'Os livros são espelhos: neles vemos apenas o que já existe dentro de nós.',
    author: 'Carlos Ruiz Zafón',
    context: InspirationContext.bookCompleted,
  ),
  InspirationQuote(
    quote: 'Aprender nunca esgota a mente.',
    author: 'Leonardo da Vinci',
    context: InspirationContext.bookCompleted,
  ),

  // ── Meta diária ───────────────────────────────────────────────────────────

  InspirationQuote(
    quote: 'Pequenos progressos diários produzem grandes resultados.',
    context: InspirationContext.dailyGoalMet,
  ),
  InspirationQuote(
    quote: 'O segredo do sucesso está na constância.',
    context: InspirationContext.dailyGoalMet,
  ),
  InspirationQuote(
    quote: 'Você cumpriu o compromisso que fez consigo mesmo.',
    context: InspirationContext.dailyGoalMet,
  ),
  InspirationQuote(
    quote: 'Nenhuma grande coisa é criada de repente.',
    author: 'Epicteto',
    context: InspirationContext.dailyGoalMet,
  ),
  InspirationQuote(
    quote: 'Celebre o progresso, mas nunca deixe de caminhar.',
    context: InspirationContext.dailyGoalMet,
  ),

  // ── Meta semanal ──────────────────────────────────────────────────────────

  InspirationQuote(
    quote: 'Você está mais perto do seu objetivo do que estava ontem.',
    context: InspirationContext.weeklyGoalMet,
  ),
  InspirationQuote(
    quote: 'A persistência transforma metas em realidade.',
    context: InspirationContext.weeklyGoalMet,
  ),
  InspirationQuote(
    quote: 'Um pouco de progresso todos os dias gera grandes resultados.',
    context: InspirationContext.weeklyGoalMet,
  ),

  // ── Novo amigo ────────────────────────────────────────────────────────────

  InspirationQuote(
    quote: 'Boas leituras ficam ainda melhores quando são compartilhadas.',
    context: InspirationContext.newFriend,
  ),
  InspirationQuote(
    quote: 'O conhecimento cresce quando inspira outras pessoas.',
    context: InspirationContext.newFriend,
  ),

  // ── Amigo concluiu livro ──────────────────────────────────────────────────

  InspirationQuote(
    quote: 'O conhecimento cresce quando inspira outras pessoas.',
    context: InspirationContext.friendCompletedBook,
  ),
  InspirationQuote(
    quote: 'Grandes jornadas ficam melhores em boa companhia.',
    context: InspirationContext.friendCompletedBook,
  ),

  // ── Encontro do clube ─────────────────────────────────────────────────────

  InspirationQuote(
    quote: 'Uma boa conversa pode revelar um livro completamente diferente.',
    context: InspirationContext.clubMeeting,
  ),
  InspirationQuote(
    quote: 'Toda grande leitura merece uma grande discussão.',
    context: InspirationContext.clubMeeting,
  ),

  // ── Nova votação ──────────────────────────────────────────────────────────

  InspirationQuote(
    quote: 'Está na hora de escolher a próxima aventura.',
    context: InspirationContext.clubVote,
  ),
  InspirationQuote(
    quote: 'Qual será o próximo capítulo da jornada do clube?',
    context: InspirationContext.clubVote,
  ),

  // ── Nova conquista ────────────────────────────────────────────────────────

  InspirationQuote(
    quote: 'Cada conquista é construída por pequenas vitórias.',
    context: InspirationContext.achievementUnlocked,
  ),
  InspirationQuote(
    quote: 'O impossível de ontem é a conquista de hoje.',
    context: InspirationContext.achievementUnlocked,
  ),
  InspirationQuote(
    quote: 'Você está escrevendo uma bela história.',
    context: InspirationContext.achievementUnlocked,
  ),
  InspirationQuote(
    quote: 'Toda conquista começou com uma decisão.',
    context: InspirationContext.achievementUnlocked,
  ),

  // ── Leitura noturna ───────────────────────────────────────────────────────

  InspirationQuote(
    quote:
        'Terminar o dia aprendendo é uma excelente forma de começar o amanhã.',
    context: InspirationContext.eveningReading,
  ),
  InspirationQuote(
    quote:
        'Enquanto muitos encerram o dia, você decidiu crescer um pouco mais.',
    context: InspirationContext.eveningReading,
  ),
  InspirationQuote(
    quote: 'As pequenas coisas, feitas por amor, tornam-se grandes.',
    author: 'São Josemaria Escrivá',
    context: InspirationContext.eveningReading,
  ),
  InspirationQuote(
    quote: 'Enquanto adiamos, a vida passa.',
    author: 'Sêneca',
    context: InspirationContext.eveningReading,
  ),

  // ── Leitura matinal ───────────────────────────────────────────────────────

  InspirationQuote(
    quote:
        'Começar o dia aprendendo muda a forma como você vive o restante dele.',
    context: InspirationContext.morningReading,
  ),
  InspirationQuote(
    quote: 'Invista alguns minutos em leitura. O retorno dura a vida inteira.',
    context: InspirationContext.morningReading,
  ),
  InspirationQuote(
    quote: 'Viva como se fosse morrer amanhã. Aprenda como se fosse viver para sempre.',
    author: 'Mahatma Gandhi',
    context: InspirationContext.morningReading,
  ),
  InspirationQuote(
    quote: 'Faze o que deves e está no que fazes.',
    author: 'São Josemaria Escrivá',
    context: InspirationContext.morningReading,
  ),

  // ── Domingo ───────────────────────────────────────────────────────────────

  InspirationQuote(
    quote: 'Uma semana melhor começa com alguns capítulos hoje.',
    context: InspirationContext.sunday,
  ),
  InspirationQuote(
    quote: 'O melhor momento para começar foi ontem. O segundo melhor é agora.',
    author: 'Provérbio chinês',
    context: InspirationContext.sunday,
  ),

  // ── Primeiro livro ────────────────────────────────────────────────────────

  InspirationQuote(
    quote: 'Toda biblioteca começa com um único livro.',
    context: InspirationContext.firstBook,
  ),
  InspirationQuote(
    quote: 'O primeiro passo é sempre o mais importante.',
    context: InspirationContext.firstBook,
  ),
  InspirationQuote(
    quote: 'A jornada de mil quilômetros começa com um único passo.',
    author: 'Lao Tsé',
    context: InspirationContext.firstBook,
  ),

  // ── Primeira sessão ───────────────────────────────────────────────────────

  InspirationQuote(
    quote: 'Bem-vindo à sua jornada de leitura.',
    context: InspirationContext.firstSession,
  ),
  InspirationQuote(
    quote: 'Que esta seja a primeira de muitas páginas.',
    context: InspirationContext.firstSession,
  ),
  InspirationQuote(
    quote: 'Todo grande leitor começou com uma primeira página.',
    context: InspirationContext.firstSession,
  ),

  // ── Sessão longa (≥ 60 min) ───────────────────────────────────────────────

  InspirationQuote(
    quote: 'Uma hora investida em conhecimento nunca é tempo perdido.',
    context: InspirationContext.longSession,
  ),
  InspirationQuote(
    quote: 'O conhecimento cresce página por página.',
    context: InspirationContext.longSession,
  ),
  InspirationQuote(
    quote: 'O conhecimento é um tesouro que acompanha seu dono por toda parte.',
    author: 'Provérbio chinês',
    context: InspirationContext.longSession,
  ),
  InspirationQuote(
    quote: 'Nunca confie em alguém que não tenha um livro favorito.',
    author: 'Lemony Snicket',
    context: InspirationContext.longSession,
  ),
];
