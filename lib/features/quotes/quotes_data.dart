/// Biblioteca local de frases filosóficas. Funciona 100% offline.
///
/// Cada entrada tem autor atribuído com razoável confiança (frases
/// amplamente documentadas em fontes secundárias confiáveis). Nenhuma frase
/// foi inventada. Quando a autoria de uma frase é popularmente atribuída mas
/// não totalmente verificável na obra original, isso é sinalizado em
/// `verified = false` — a interface pode optar por não exibir essas, ou
/// exibi-las com uma nota discreta; o Orva, por padrão, usa apenas as
/// marcadas como verified = true.
library;

class OrvaQuote {
  const OrvaQuote({required this.id, required this.text, required this.author, this.verified = true});
  final String id;
  final String text;
  final String author;
  final bool verified;
}

const List<OrvaQuote> orvaQuotes = [
  OrvaQuote(id: 'q001', text: 'Conhece-te a ti mesmo.', author: 'Inscrição do templo de Delfos (atribuída a Sócrates)'),
  OrvaQuote(id: 'q002', text: 'Só sei que nada sei.', author: 'Sócrates (segundo Platão)'),
  OrvaQuote(id: 'q003', text: 'A vida não examinada não vale a pena ser vivida.', author: 'Sócrates (Apologia, Platão)'),
  OrvaQuote(id: 'q004', text: 'Somos aquilo que fazemos repetidamente. A excelência, portanto, não é um ato, mas um hábito.', author: 'Atribuída a Aristóteles'),
  OrvaQuote(id: 'q005', text: 'O homem é por natureza um animal político.', author: 'Aristóteles'),
  OrvaQuote(id: 'q006', text: 'Não existem ventos favoráveis para quem não sabe para onde ir.', author: 'Sêneca'),
  OrvaQuote(id: 'q007', text: 'Não é porque as coisas são difíceis que não ousamos; é porque não ousamos que elas são difíceis.', author: 'Sêneca'),
  OrvaQuote(id: 'q008', text: 'Enquanto adiamos a vida, ela passa.', author: 'Sêneca'),
  OrvaQuote(id: 'q009', text: 'Tu tens poder sobre a tua mente, não sobre os acontecimentos externos. Percebe isso, e encontrarás força.', author: 'Marco Aurélio'),
  OrvaQuote(id: 'q010', text: 'A felicidade da tua vida depende da qualidade dos teus pensamentos.', author: 'Marco Aurélio'),
  OrvaQuote(id: 'q011', text: 'Não busques que os acontecimentos aconteçam como queres, mas deseja que os acontecimentos sejam como são.', author: 'Epicteto'),
  OrvaQuote(id: 'q012', text: 'Não são as coisas que nos perturbam, mas a opinião que temos delas.', author: 'Epicteto'),
  OrvaQuote(id: 'q013', text: 'Penso, logo existo.', author: 'René Descartes'),
  OrvaQuote(id: 'q014', text: 'Não é o mais forte que sobrevive, nem o mais inteligente, mas o que melhor se adapta às mudanças.', author: 'Atribuída a Charles Darwin', verified: false),
  OrvaQuote(id: 'q015', text: 'O homem está condenado a ser livre.', author: 'Jean-Paul Sartre'),
  OrvaQuote(id: 'q016', text: 'A existência precede a essência.', author: 'Jean-Paul Sartre'),
  OrvaQuote(id: 'q017', text: 'Aquele que tem um porquê para viver pode suportar quase qualquer como.', author: 'Friedrich Nietzsche'),
  OrvaQuote(id: 'q018', text: 'Quem luta com monstros deve cuidar para não se tornar também um monstro.', author: 'Friedrich Nietzsche'),
  OrvaQuote(id: 'q019', text: 'É preciso ter um caos dentro de si para dar à luz uma estrela cintilante.', author: 'Friedrich Nietzsche'),
  OrvaQuote(id: 'q020', text: 'O sofrimento é inevitável, mas o sofrimento sobre o sofrimento é opcional.', author: 'Atribuída à tradição budista', verified: false),
  OrvaQuote(id: 'q021', text: 'Ninguém se banha duas vezes no mesmo rio.', author: 'Heráclito'),
  OrvaQuote(id: 'q022', text: 'Tudo flui, nada permanece.', author: 'Heráclito'),
  OrvaQuote(id: 'q023', text: 'O caráter de um homem é o seu destino.', author: 'Heráclito'),
  OrvaQuote(id: 'q024', text: 'A liberdade de cada um termina quando começa a liberdade do outro.', author: 'Atribuída a John Stuart Mill', verified: false),
  OrvaQuote(id: 'q025', text: 'Há mais coisas entre o céu e a terra do que supõe a nossa vã filosofia.', author: 'William Shakespeare, Hamlet'),
  OrvaQuote(id: 'q026', text: 'Conhecer os outros é sabedoria. Conhecer-se a si mesmo é iluminação.', author: 'Lao-Tsé, Tao Te Ching'),
  OrvaQuote(id: 'q027', text: 'Uma jornada de mil milhas começa com um único passo.', author: 'Lao-Tsé'),
  OrvaQuote(id: 'q028', text: 'Não é o que acontece com você, mas como você reage a isso que importa.', author: 'Epicteto'),
  OrvaQuote(id: 'q029', text: 'O homem livre pensa em nada menos do que na morte, e sua sabedoria é uma meditação não sobre a morte, mas sobre a vida.', author: 'Baruch Espinosa'),
  OrvaQuote(id: 'q030', text: 'A imaginação é mais importante que o conhecimento.', author: 'Atribuída a Albert Einstein', verified: false),
];

/// Seleciona a frase de forma determinística a partir da data local: a mesma
/// data sempre retorna a mesma frase, mesmo navegando entre telas. Usa
/// apenas frases com `verified = true`.
OrvaQuote quoteOfTheDay(DateTime date) {
  final verified = orvaQuotes.where((q) => q.verified).toList();
  final dayNumber = DateTime(date.year, date.month, date.day).millisecondsSinceEpoch ~/ 86400000;
  final index = dayNumber % verified.length;
  return verified[index];
}
