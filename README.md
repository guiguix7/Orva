# Orva

Aplicativo Flutter pessoal para organizar metas, checklists, rotina, hobbies, notas e diário. O projeto prioriza dados locais, uso offline, estados vazios honestos e métricas calculadas a partir de registros reais.

## Escopo implementado

- **Home:** foco opcional por dia, saudação com nome local opcional, progresso real dos itens elegíveis de checklists, resumo de metas, rotina planejada e sessões de hobbies da semana. O menu de criação rápida abre formulários reais.
- **Metas:** criação, edição, progresso manual de 0 a 100%, categoria personalizada, datas, indicador/valor-alvo, meta superior, histórico de progresso, conclusão, reabertura, arquivamento, restauração e exclusão confirmada.
- **Checklists:** listas de data única, recorrência diária, dias específicos da semana e templates reutilizáveis; itens adicionáveis/editáveis/reordenáveis/removíveis; conclusão por ocorrência; histórico por data; arquivar, restaurar e excluir com o histórico após confirmação.
- **Rotina e tempo planejado:** blocos por dia da semana ou data, categorias, vínculos opcionais com meta/hobby, duplicação, detecção de sobreposições e soma/minutos por categoria. Horários planejados não são exibidos como horas executadas.
- **Hobbies:** cadastro, meta semanal opcional, registro/edição/exclusão de sessões, total real da semana, histórico, arquivamento/restauração e exclusão confirmada.
- **Notas:** criação, edição, exclusão confirmada, pesquisa por título/conteúdo e tags simples.
- **Diário:** uma entrada por data, edição, busca por conteúdo/humor/tags, humor opcional e exclusão confirmada.
- **Categorias:** catálogo local personalizável para metas, rotina e hobbies.
- **Configurações:** nome local opcional, tema claro/escuro/sistema, exportação e importação de backup JSON versionado.

Agenda, guia de estudos, notificações, gráficos históricos avançados, sincronização em nuvem, widgets e recursos de IA não são apresentados como concluídos; pertencem às fases futuras descritas na especificação.

## Tecnologias

- Flutter e Dart.
- Riverpod para estado e acesso às dependências.
- Drift sobre SQLite local.
- `intl` para datas em português.
- `file_picker`, `cross_file` e `share_plus` para selecionar e compartilhar backups.
- Testes unitários, de widgets e um fluxo de integração de criação, leitura e exclusão de nota.

O esquema SQLite está descrito explicitamente em `lib/core/database/app_database.dart`, atualmente na versão `2`, com criação e migração via `MigrationStrategy`. Essa opção evita depender de arquivos Dart gerados por `build_runner` neste ponto inicial. Se o banco evoluir, crie migrations versionadas e testes para cada upgrade.

## Como executar

1. Instale o Flutter SDK compatível com a restrição Dart declarada em `pubspec.yaml` e configure o Android SDK/iOS toolchain conforme a plataforma.
2. No diretório do projeto, execute:

   ```bash
   flutter doctor
   flutter pub get
   flutter analyze
   flutter test
   flutter run
   ```

3. Para rodar o teste de fluxo na interface, inicie um emulador/dispositivo e execute:

   ```bash
   flutter test integration_test/app_flow_test.dart
   ```

4. Para gerar uma compilação de Android, execute `flutter build apk` em um ambiente com SDK Android configurado.

Este ambiente de preparação não contém o executável `flutter` nem `dart`; por isso, a compilação Flutter, o `flutter analyze` e a execução dos testes não puderam ser confirmados aqui. As instruções acima devem ser rodadas antes de publicar ou distribuir o aplicativo.

## Dados e privacidade

- Não existem metas, checklists, rotinas, hobbies, notas, entradas de diário ou estatísticas de exemplo inseridas na primeira abertura.
- Os dados da aplicação ficam no banco SQLite local do dispositivo. Não há conta, sincronização, telemetria ou envio de notas/diário para serviços externos neste MVP.
- Armazenamento local não significa que o banco esteja criptografado. O conteúdo do diário e das notas deve ser tratado como dado privado no dispositivo.
- A importação valida o formato e a versão do backup, solicita confirmação e aplica substituição em transação. Se qualquer inserção falhar, a transação deve reverter a alteração.
- O backup inclui tabelas e vínculos do schema atual. A versão de formato atual é `2`; arquivos com outras versões são recusados em vez de importados silenciosamente.

## Decisões de implementação

- **Tarefas rápidas de hoje:** a ação rápida cria/usa um checklist de data única chamado `Tarefas avulsas · AAAA-MM-DD`, e cada ação é um item real do checklist. Ele só é criado quando o usuário adiciona uma tarefa.
- **Histórico de checklist:** cada execução está separada da definição recorrente. Os itens de ocorrência guardam texto e ordem como snapshot; alterar a definição não reescreve ocorrências já registradas. Uma restrição única por checklist/data evita duplicação.
- **Progresso de metas:** no MVP é explicitamente manual. A relação entre metas pode ser cadastrada, mas percentuais não são inferidos pelo texto e não são automaticamente agregados a partir de metas filhas.
- **Categorias:** os rótulos usados em registros são valores independentes do catálogo de sugestões; excluir uma sugestão não apaga rótulos já gravados.
- **Modelos semanais:** salvar a semana copia os blocos recorrentes existentes; aplicar um modelo substitui os blocos recorrentes atuais e mantém os blocos vinculados a datas específicas. A operação de aplicação é confirmada antes de executar.
- **Tempo realizado:** o MVP registra sessões reais em hobbies. Blocos da rotina são somente planejamento e não são convertidos automaticamente em sessões executadas.
- **Fontes:** Fraunces, Inter e JetBrains Mono não foram encontradas nos arquivos enviados. O tema usa as fontes serifada/monoespaçada disponíveis no sistema como fallback, sem download de fontes em tempo de execução.

## Estrutura

```text
lib/
  app.dart
  main.dart
  core/
    database/       # esquema SQLite, migração e repositório
    theme/          # temas claro/escuro e cores do Orva
    widgets/        # componentes e utilitários reutilizáveis
  features/
    home/
    goals/
    checklists/
    routine/
    hobbies/
    notes/
    journal/
    more/
    settings/
test/
integration_test/
```

## Limitações conhecidas antes da distribuição

- Este pacote ainda precisa passar por `flutter pub get`, análise estática, testes e build no ambiente com Flutter SDK.
- O backup exportado deve ser salvo pelo usuário em um local seguro; o aplicativo não mantém uma cópia remota.
- Não existe bloqueio biométrico/PIN nem criptografia adicional do banco local.
- Rotina planejada e sessões de hobbies são fontes distintas; não há timer de execução nem conversão automática entre elas.

## Evolução incremental — entrega de 12/10/2026

Esta revisão preserva o esquema SQLite e o backup existentes (sem migrations destrutivas).
Foram integradas as seguintes melhorias:

- Formulário de metas: início predefinido na data de criação; sugestão de prazo por dia/semana/mês/trimestre/ano com calendário real e possibilidade de ajuste manual. Para uma meta já existente, as datas permanecem como foram salvas.
- Preferência `Automático por horário`: tema claro entre 07:00 e 18:59, escuro entre 19:00 e 06:59. Atualização a cada minuto ou na retomada do aplicativo. Persistência na tabela existente de configurações.
- Home: gráfico circular do dia com categorias planejadas, ocupação líquida, intervalo ainda não definido e expansão por atividades concretas. Sobreposições são contadas uma vez, priorizando a categoria do bloco que começa antes; em empates, a ordem do banco. O gráfico representa planejamento, não tempo realizado.
- Regras puras de calendário, ocupação e tema, com testes dedicados em `test/calculations_test.dart`.

### Pendências da especificação ampliada

Login Google, permissões e sincronização Calendar API, PIN/biometria reais, onboarding de saúde, agenda visual completa, sessões realizadas, alimentação, gráficos históricos, biblioteca de citações verificadas e incorporação de Fraunces/Inter/JetBrains Mono **não foram implementados nesta etapa**. Não utilize versões falsas desses fluxos. O login Google depende de configuração de OAuth/Google Cloud e testes em Android. O bloqueio local depende de mecanismos seguros nativos. Os dados da base atual permanecem locais e não são associados a uma identidade Google.

### Verificação

O ambiente de autoria desta entrega não dispõe de `flutter` nem `dart`. Os testes e a compilação precisam ser executados em um ambiente Flutter configurado:

```sh
flutter pub get
flutter analyze
flutter test
flutter run
```

Não foram inseridos dados pessoais fictícios.

## Evolução incremental — entrega de 12/10/2026 (etapa 2)

Esta revisão preserva o esquema SQLite e o backup das etapas anteriores,
com uma migração aditiva (`schemaVersion` 2 → 3, tabela `weight_entries`
nova, nenhuma tabela ou coluna existente alterada/removida).

### Adicionado nesta etapa

- **Perfil do usuário:** nome, data de nascimento (com cálculo de idade),
  altura e gênero (opções inclusivas), tudo opcional, editável, guardado
  localmente em `settings` — `lib/features/profile/profile_page.dart`.
- **Histórico de peso e IMC:** tabela `weight_entries` nova; cada registro é
  datado e peso anterior nunca é sobrescrito. IMC calculado apenas quando
  peso+altura existem; para idade informada abaixo de 20 anos, o app não
  classifica o IMC pelas faixas de adulto (não há percentis por idade/sexo
  implementados).
- **Bloqueio local (PIN + biometria opcional):** PIN nunca é salvo em texto
  puro (hash SHA-256 salgado, `lib/core/security/pin_security.dart`); tela
  de bloqueio real na abertura e ao retomar do segundo plano
  (`lib/features/security/lock_screen.dart`); biometria via `local_auth`
  com tratamento de indisponibilidade. Chaves de segurança são
  explicitamente excluídas do backup JSON.
- **Frases filosóficas:** biblioteca local de 30 citações com autoria
  verificada, seleção determinística por data, ativável/desativável,
  card discreto na Home — `lib/features/quotes/quotes_data.dart`.
- **Tipografia:** `orva_theme.dart` agora referencia Fraunces/Inter/JetBrains
  Mono com fallback seguro para fontes do sistema. Os arquivos `.ttf` não
  foram incluídos (sem acesso à internet neste ambiente) — ver
  `assets/fonts/README.md` para o passo manual de adicioná-los.
- Testes novos em `test/security_and_profile_test.dart` (hashing de PIN,
  frase determinística por data).

### Ainda não implementado

Login Google e sincronização com o Google Agenda (exigem credenciais OAuth
reais e testes em dispositivo que este ambiente não permite), redesenho
visual completo da agenda (grade horária, arrastar/redimensionar), módulo
de alimentação/dieta, estatísticas históricas avançadas com `fl_chart`,
tema automático por minuto exato em segundo plano (depende de testes em
dispositivo real). Não trate nenhum desses como funcional.

### Verificação

Sem `flutter`/`dart` disponíveis neste ambiente, a verificação foi
estática: todos os imports locais resolvem, chaves/parênteses de todos os
arquivos em `lib/` batem, e os providers referenciados em `app.dart`
existem onde são declarados. Isso **não substitui** rodar:

```
flutter pub get
flutter analyze
flutter test
flutter run
```


## Estabilização de segurança e navegação — 13/10/2026

Esta revisão incremental aplica correções sobre a base existente, sem recriar o app nem alterar o namespace Android ou o schema SQLite:

- **Biometria Android:** a Activity usa `FlutterFragmentActivity` e o manifesto declara `USE_BIOMETRIC`. A configuração considera suporte do aparelho e biometria efetivamente cadastrada, não apenas a presença de hardware.
- **PIN local:** novos PINs usam PBKDF2-HMAC-SHA256 com salt aleatório e hash versionado. Hashes antigos em SHA-256 salgado continuam verificáveis e são atualizados após a validação bem-sucedida. Isso não criptografa o banco SQLite.
- **Tentativas de PIN:** a contagem é persistida localmente; após cinco falhas há uma pausa de 30 segundos, com aumento progressivo até 15 minutos. Um PIN correto limpa o contador; desativar o bloqueio limpa a configuração de segurança.
- **Tela de bloqueio:** usa a cor de fundo do tema atual para manter contraste no modo claro e escuro. Falhas da biometria mantêm o PIN como alternativa.
- **Voltar no Android:** em uma aba principal diferente de Hoje, a primeira ação de voltar retorna à Home; na raiz da Home o comportamento padrão do Android é preservado.
- **Home:** saudação corrigida para usar “Boa noite” entre 18:00 e 04:59 e atualizada enquanto a tela permanece aberta. O cartão “Foco do dia” agora tem uma única ação principal e o botão de criação rápida é compacto para reduzir sobreposição de conteúdo.
- **Testes adicionados:** limites da saudação, compatibilidade dos hashes antigos, geração/verificação PBKDF2, persistência de tentativas e limpeza do bloqueio.

**Validação pendente:** os testes Flutter, a análise estática e o build Android precisam ser executados em um ambiente com Flutter/Dart e Android SDK. A biometria, o retorno do background e o gesto físico de voltar também exigem validação em emulador/dispositivo; não devem ser considerados comprovados apenas por estas alterações de código.


- **Console de diagnóstico:** nova tela disponível em Mais somente em builds de desenvolvimento; captura erros Flutter/Dart, falhas de banco e de desbloqueio local, com filtros, busca, limite de 500 eventos em memória, limpeza e exportação. Mensagens de exceção arbitrárias não são exportadas; tokens, PINs e e-mails têm redatores adicionais.
- **Ocupação do tempo:** gráfico e lista de categorias são apresentados lado a lado em áreas largas e empilhados em telas estreitas, mantendo os horários sobrepostos contados uma única vez.
- **Testes adicionais:** sanitização de tokens/e-mails, omissão de detalhes privados de exceções e limite de histórico do console. Os testes foram escritos, mas não executados neste ambiente sem Flutter/Dart.


## Matriz de requisitos do Prompt Master — estado honesto desta revisão

Os estados abaixo distinguem o que já existe no código do que esta revisão tocou. “Implementado, aguardando validação” significa que há código no branch, mas ainda faltam execução de testes/build e, quando aplicável, verificação num Android real. Nenhum item é marcado como “Concluído e validado” nesta revisão porque esses comandos não puderam ser executados.

| Área/requisito | Estado nesta revisão | Escopo real / pendência principal |
|---|---|---|
| Auditoria da base, preservação do projeto e namespace Android | Parcialmente implementado | A revisão foi feita sobre o repositório existente; namespace mantido e nenhuma migration destrutiva adicionada. A inspeção local do ZIP e a execução da toolchain não ficaram disponíveis. |
| PIN local e bloqueio | Implementado, aguardando validação | PBKDF2-HMAC-SHA256 versionado, migração transparente de hashes antigos, limite de tentativas persistente, limpeza atômica e fallback por PIN. Testar recuperação e concorrência em dispositivo. |
| Biometria Android real | Implementado, aguardando validação | Activity compatível com FragmentActivity, permissão, tema de inicialização e distinção por versão Android; ainda requer teste com biometria cadastrada, cancelamento e background. |
| Console interno de diagnóstico | Implementado, aguardando validação | Eventos Flutter/Dart, falhas de banco e bloqueio local, filtros, pesquisa, histórico limitado em memória e exportação com sanitização; teste de ponta a ponta pendente. |
| Voltar em abas secundárias | Implementado, aguardando validação | Volta à Home antes de permitir sair da raiz; validar botão, gesto e formulários/modal em dispositivo. |
| Contraste da tela bloqueada | Implementado, aguardando validação | Fundo deriva do tema ativo; falta validação visual/contraste WCAG e leitor de tela. |
| FAB, foco do dia e saudação | Implementado, aguardando validação | FAB compacto, ação primária única para definir/editar foco e saudação por horário corrigida/atualizada; falta teste visual em múltiplos tamanhos. |
| Cartão de ocupação | Implementado, aguardando validação | Layout responsivo para gráfico/legenda e sobreposições já calculadas sem duplicar a duração total. A regra segue baseada em blocos planejados existentes, não execução. |
| Home e integração contextual | Parcialmente implementado | Resumo local existente de checklists, metas, rotina e hobbies. Personalização/reordenação de seções e todos os indicadores do prompt não foram concluídos. |
| Metas | Parcialmente implementado | CRUD local, progresso manual, prazos sugeridos, metas superiores e histórico existentes. Progresso automático por sessões, agregação ponderada e fluxos semanais/mensais completos continuam pendentes. |
| Checklists e hábitos | Parcialmente implementado | Ocorrências recorrentes e snapshots históricos existentes. Hábitos como módulo próprio, todas as regras de recorrência e estatísticas completas continuam pendentes. |
| Rotina e calendário | Parcialmente implementado | Blocos locais, templates semanais, duplicação e conflito/ocupação básicos existentes. Grade interativa dia/semana/mês, eventos cruzando meia-noite, exceções de série e arrastar/redimensionar não estão concluídos. |
| Obrigações e necessidades recorrentes | Implementado, aguardando validação | Regras locais de recorrência, snapshots de ocorrência, exceções por data (pular/alterar/remover), divisão de intervalos noturnos e integração na linha do tempo/ocupação. Falta validar em runtime, expandir regras avançadas e testar timezone/DST. |
| Hobbies | Parcialmente implementado | Cadastro, sessões realizadas e metas semanais básicas existentes. Integração automática completa com metas e estatísticas históricas precisa ser construída. |
| Estudos | Implementado, aguardando validação | Matérias, hierarquia de assuntos/subtópicos, estado, sessões reais, revisões, vínculo opcional com meta, resumo semanal e criação de blocos de estudo planejados na rotina. Ainda falta progressão automática de metas e testes de interface/integração. |
| Alimentação/dieta | Implementado, aguardando validação | Catálogo de alimentos com fonte manual de nutrientes, planos recorrentes e pontuais, duração/horário opcional, itens com snapshots, registro/edição separado do consumo real e resumo diário de valores conhecidos/parciais. Ainda não há tabela nutricional online nem prescrição/recomendação dietética. |
| Peso e IMC | Parcialmente implementado | Há registros locais de peso e uma função de cálculo de IMC. A camada de experiência/limitações por faixa etária e os gráficos precisam de validação/expansão. |
| Estatísticas históricas | Parcialmente implementado | A Home oferece resumos locais; painéis semanais/mensais, comparação planejado-realizado e gráficos completos ainda não existem. |
| Google Sign-In/Firebase Auth e onboarding | Bloqueado por configuração externa | O projeto contém dependências/configuração Firebase, mas o fluxo funcional de conta, onboarding e segregação de contas ainda não está implementado. São necessárias credenciais/configuração do proprietário e testes reais. |
| Google Calendar | Bloqueado por configuração externa | Consentimento OAuth, leitura/escrita, cache e prevenção de duplicações não implementados. Depende de configuração do Google Cloud e testes de autorização/quotas. |
| Notificações locais | Não iniciado | Agendamento, permissões por versão do Android e atualização/cancelamento de lembretes pendentes. |
| Notas e diário | Parcialmente implementado | CRUD local, pesquisa e tags básicas existentes. Criptografia do banco/diário não implementada; SQLite local não deve ser considerado criptografado. |
| Frases filosóficas | Parcialmente implementado | Biblioteca offline, seleção diária e opção para desativar existentes. Rever atribuição/licenciamento na futura expansão. |
| Temas e personalização | Parcialmente implementado | Claro/escuro/sistema e automático por horário existentes. Horários configuráveis, preferências completas e personalização geral da Home ainda pendentes. |
| Backup e restauração | Parcialmente implementado | JSON versionado com validação, confirmação e transação já existente. Proteger backups com criptografia e cobrir futuros módulos quando implementados. |
| Segurança dos dados em repouso | Parcialmente implementado | PIN é derivado/armazenado como hash, mas isso não cifra as tabelas SQLite. Criptografia do diário/banco não implementada. |
| Testes, analyze e build | Implementado, aguardando validação | Testes adicionais foram escritos para cálculos, hashes, limite de tentativas e sanitização. `flutter pub get`, `dart format`, `flutter analyze`, `flutter test` e build APK não foram executados neste ambiente. |

Esta branch é uma **entrega parcial de estabilização (principalmente Fase 1)**, e não a conclusão integral das 35 partes do Prompt Master. As pendências da tabela continuam abertas e devem permanecer visíveis nos próximos ciclos de desenvolvimento.


## Entrega incremental — Estudos, Alimentação e Obrigações

Esta revisão acrescenta migração de schema 3 para 4 e telas reais para três áreas. Os registros são locais; nenhuma conta, API paga ou conjunto de dados fictícios foi introduzido.

### Estudos
- Cadastre e arquive matérias; opcionalmente vincule cada matéria a uma meta existente.
- Organize assuntos e subtópicos hierárquicos, avance o estado de aprendizado e preserve assuntos que tenham histórico.
- Registre uma sessão realizada com data, início, duração, observações e meta relacionada.
- Registre revisões/testes/resumos com confiança de 1 a 5 e observações futuras.
- Use **Planejar** para inserir um bloco datado na Rotina. O bloco planejado não cria uma sessão realizada nem incrementa automaticamente a meta.

### Alimentação e saúde
- Cadastre alimentos e informe apenas os valores nutricionais conhecidos; a origem dos valores fica visível. Não há busca em tabela externa e nenhum valor ausente é inferido.
- Planeje refeições pontuais/recorrentes. A refeição só entra na ocupação do tempo se houver horário e duração explícitos.
- Registre o que foi realmente consumido em separado do planejamento. Ao abrir um plano para registrar o consumo, os itens planejados aparecem como sugestões editáveis — o usuário confirma antes de salvar.
- Corrija um registro de consumo preservando os snapshots nutricionais, mesmo se o alimento do catálogo foi alterado ou removido.
- O resumo diário diferencia valores conhecidos de um total parcial; não deve ser interpretado como recomendação clínica ou nutricional.

### Obrigações recorrentes
- Cadastre uma regra única, diária ou semanal, com intervalo de início/fim, prioridade e período de vigência.
- Um fim anterior ao início representa um intervalo que atravessa a meia-noite. O evento continua vinculado ao dia em que começou e é dividido em dois blocos apenas para mostrar a ocupação diária.
- Para uma data específica, dispense a ocorrência, altere nome/categoria/horário só naquele dia ou remova a exceção.
- A lista de histórico usa snapshots; editar a regra não reescreve ocorrências já concluídas.
- Obrigações e refeições com duração explícita são mostradas junto da Rotina diária e entram no cálculo por união dos intervalos. Sobreposições são sinalizadas e não são somadas duas vezes no total líquido.
- As sugestões “Sono”, “Escola” e “Refeição” apenas abrem um formulário; nada é ativado sem ação do usuário.

### Banco e backup
- Schema 4 é aditivo: as tabelas anteriores são mantidas e uma migration cria apenas as tabelas dos novos módulos.
- Backup agora usa versão 4, inclui as tabelas novas e exclui dados de autenticação local.
- Importação de backup versão 3 cria coleções vazias para os módulos novos e preserva os dados que já existiam no arquivo antigo.

### Testes adicionados
Os testes de repositório cobrem hierarquia/sessões/revisões de estudo, separação entre planejamento e consumo com snapshots nutricionais, projeção de intervalos noturnos/exceções e migração de backup v3. Os testes foram escritos, mas ainda não executados porque a toolchain Flutter/Dart não está disponível neste ambiente.
