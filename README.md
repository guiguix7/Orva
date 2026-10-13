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

O esquema SQLite está descrito explicitamente em `lib/core/database/app_database.dart`, atualmente na versão `3`, com migrações versionadas via `MigrationStrategy` (inclui templates de rotina e registros de peso). Essa opção evita depender de arquivos Dart gerados por `build_runner` neste ponto inicial. Se o banco evoluir, crie migrations versionadas e testes para cada upgrade.

## Estado da primeira estabilização

As correções em andamento na branch `fix/phase-1-stability` centralizam as faixas horárias da saudação (incluindo 00:00–04:59 como “Boa noite”), atualizam dados com data local quando a Home atravessa a meia-noite, simplificam as ações do foco diário, retiram o botão flutuante que podia encobrir cartões e fazem o botão Voltar retornar à Home quando uma aba secundária está selecionada. Também foi adicionado tratamento de fallback para erros na tela de desbloqueio.

Essas alterações precisam passar pela execução de `flutter analyze`, `flutter test` e build Android no CI antes de serem consideradas validadas. Login Google, agenda Google, hábitos, alimentação completa e o restante dos módulos descritos no Prompt Master permanecem requisitos maiores pendentes; não são declarados concluídos por esta estabilização.

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
