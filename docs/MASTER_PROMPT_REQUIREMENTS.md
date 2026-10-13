# Matriz de requisitos — Prompt Master Orva 2.0

Este documento acompanha a diferença entre o que o prompt exige, o que o repositório contém e o que já foi validado. Atualize a matriz em cada fase; não classifique uma função como concluída só por existir uma tela ou uma implementação parcial.

## Critérios de status

- **Concluído e validado:** fluxo integrado, persistência verificada e testes pertinentes executados.
- **Implementado, aguardando validação:** alteração escrita e integrada, mas a validação prevista ainda está em andamento.
- **Parcialmente implementado:** há parte funcional do requisito, mas faltam fluxos ou integrações relevantes.
- **Bloqueado por configuração externa:** depende de credenciais, autorização, configuração de plataforma ou dispositivo não disponível.
- **Não iniciado:** não há implementação funcional suficiente no código atual.

## Auditoria da base

- Plataforma: Flutter/Dart; prioridade Android, com diretórios iOS/Web presentes.
- Estado: Riverpod + Drift/SQLite, arquitetura offline-first.
- Identificador Android: `com.appguilherme.orva` — preservado nesta fase.
- Schema Drift atual: versão 3; evolução por `MigrationStrategy`.
- Backup JSON atual: formato `orva_backup`, versão 3; importação valida estrutura e substitui dados em transação.
- Dados locais do perfil, notas e diário não estão criptografados em repouso no SQLite. A UI não deve prometer criptografia do banco.
- A configuração Firebase encontrada tem opções Android. O arquivo nativo `google-services.json` não é versionado e configurações iOS/Web não estão presentes no repositório.

## Matriz por módulo

| Requisito / módulo | Estado observado | Status | Próxima etapa objetiva |
|---|---|---|---|
| Arquitetura Flutter/Riverpod/Drift | Base modular existente, banco local e repositório SQL | Parcialmente implementado | Continuar modularização apenas quando melhorar testabilidade; preservar schema/dados |
| Home e resumo diário | Saudação, checklist de hoje, metas ativas, rotina planejada e hobbies | Parcialmente implementado | Ligar eventos/calendário, estatísticas completas e sessões de estudo/alimentação |
| Saudação por horário | Função determinística e teste das fronteiras adicionados na branch | Implementado, aguardando validação | Confirmar analyzer/testes e conferir mudança enquanto Home permanece aberta |
| Atualização de Home à meia-noite | Timer local de Home e recarga por data adicionados | Implementado, aguardando validação | Validar sem interação do usuário e com app retomado do background |
| Foco do dia | Definir/editar/concluir/reabrir, armazenado em settings por data | Implementado, aguardando validação | Acrescentar testes de widget e persistência após reinício |
| Botão flutuante / conteúdo coberto | FAB removido; criação rápida movida ao cabeçalho | Implementado, aguardando validação | Validar telas pequenas, fontes ampliadas e teclado |
| Navegação e botão Voltar | PopScope leva de aba secundária à Home; rotas de detalhe continuam com Navigator | Implementado, aguardando validação | Validar botão físico, gesto e telas secundárias em aparelho Android |
| Console interno de erros | Tratamento de erros em alguns fluxos, sem console estruturado/filtros/exportação | Não iniciado | Criar logger sanitizado, ErrorWidget/FlutterError/PlatformDispatcher, tela somente debug e teste de sanitização |
| Tema claro/escuro/sistema | Três modos disponíveis; tema dia/noite automático com faixas fixas | Parcialmente implementado | Personalizar horários, expor automático por horário de forma explícita, testar todos os componentes |
| Contraste/acessibilidade | Tema e widgets reutilizáveis existentes; correções pontuais na tela de bloqueio | Parcialmente implementado | Auditar WCAG AA, foco, leitor de tela, escala de fonte, touch targets e movimento |
| Perfil local | Tela/campos locais existentes | Parcialmente implementado | Completar validações, edição e política de acesso por conta |
| Login Google/Firebase Auth | Dependências e options Android presentes; fluxo de autenticação real não integrado ao onboarding | Bloqueado por configuração externa | Configurar Firebase Auth, Google provider, OAuth client, SHA-1/SHA-256 e fluxo real; testar cancelamento/logout/sessão |
| Onboarding | Não há fluxo completo integrado ao primeiro acesso | Não iniciado | Boas-vindas, login real, perfil opcional e política clara de dados locais |
| Bloqueio PIN/biometria | PIN local, preferência biométrica, fallback e alterações nativas desta branch | Implementado, aguardando validação | CI, testes do PIN legado/PBKDF2 e testes físicos de sucesso/cancelamento/background |
| Segurança do PIN | PBKDF2-HMAC-SHA256 com 100.000 iterações, comparação resistente a diferenças de conteúdo, compatibilidade legado e cooldown progressivo adicionados | Implementado, aguardando validação | Conferir testes e tempo de desbloqueio em dispositivos modestos |
| Criptografia do SQLite | Banco local sem criptografia em repouso | Não iniciado | Avaliar modelo de ameaça, opção compatível com Drift e migração não destrutiva; não confundir PIN com criptografia |
| Metas manuais | Criação/edição, datas, categoria, hierarquia, histórico manual, conclusão/arquivamento | Parcialmente implementado | Datas por período, filtros semana/mês, testes de hierarquia e progresso |
| Metas por registros automáticos | Campos de modo de progresso existem, mas progresso não é agregado integralmente a partir de tarefas/sessões | Parcialmente implementado | Definir fontes de verdade, evitar dupla contagem e implementar explicação e testes |
| Submetas e progresso ponderado | Relações parent/child existem; agregação automática completa não é declarada | Parcialmente implementado | Pesos, regras para alvo ausente, prevenção de ciclos/dupla contagem e histórico |
| Checklists | CRUD, itens, ocorrências, histórico e algumas recorrências/templates | Parcialmente implementado | Recorrência mensal/personalizada, exceções, vínculo de hábitos e regressão de histórico |
| Hábitos | Ocorrências de checklist podem servir casos simples, mas não há módulo completo de hábito | Parcialmente implementado | Registro próprio/visualização de consistência, dispensas e períodos sem punição |
| Rotina/tempo planejado | Blocos por dia da semana ou data, templates, conflitos e totais planejados | Parcialmente implementado | Calendário dia/semana/mês, séries e exceções, eventos noturnos atravessando datas |
| Ocupação 24 h | União dos intervalos e atribuição de categoria implementadas como cálculos puros | Parcialmente implementado | Validar integração visual e separar visão planejada/realizada em dados reais |
| Visão de 14 h | Não é um módulo configurável completo | Não iniciado | Calcular a janela disponível a partir de sono/obrigações configuradas, nunca constante fixa |
| Hobbies | Cadastro, sessões reais, histórico e total semanal | Parcialmente implementado | Estatísticas mês/ano, integração segura com metas/rotina e não duplicar sessões |
| Guia de estudos | Sem módulo funcional dedicado | Não iniciado | Matérias, tópicos, sessões, revisões e vínculos reais com metas/agenda |
| Dieta e alimentos | Sem cadastro nutricional/refeições; existem somente fundações isoladas de saúde | Não iniciado | Catálogo manual sem valores inventados, unidades, refeições e origem de nutrientes |
| Alimentação planejada versus consumida | Sem entidades/fluxos completos | Não iniciado | Entidades separadas, totais parciais explícitos e testes de consumo diferente do plano |
| Peso/IMC | Tabela e histórico de peso existem; cálculo de IMC no repositório | Parcialmente implementado | Gráfico, validações, exclusão/edição e tratamento de menores/adultos |
| Estatísticas semanais/mensais | Resumo diário e cálculos de tempo existem; não há painel histórico completo | Parcialmente implementado | Métricas agregadas por período, planejado versus realizado e estados vazios honestos |
| Google Calendar — leitura | APIs Google presentes como dependências, sem OAuth/calendário unificado funcional | Bloqueado por configuração externa | Consentimento OAuth, seleção de calendários, cache e origem de eventos |
| Google Calendar — escrita/sync | Não integrado; login Google sozinho não concede escopos de Agenda | Não iniciado | Só depois de validar leitura; IDs remotos, conflitos, recorrências, fila e desconexão |
| Notas | Criar/editar/excluir, pesquisa e tags simples | Parcialmente implementado | Arquivar e relacionar com metas/estudos, se útil |
| Diário | Entrada por data, edição, busca, humor/tag opcional | Parcialmente implementado | Controles de privacidade, busca completa e política de retenção/exportação |
| Citações filosóficas | Biblioteca local com seleção diária e indicação de autoria verificada | Parcialmente implementado | Preferência de desativação/personalização e revisar licenças/atribuições |
| Inteligência contextual determinística | Alguns resumos/cálculos e conflitos disponíveis | Parcialmente implementado | Próximo compromisso, tempo livre confiável e resumos baseados apenas em registros |
| Assistente generativo | Não implementado; correto não simular chat | Não iniciado | Só introduzir provedor configurado, consentimento, custos e política de privacidade |
| Notificações locais | Sem sistema completo de agendamento/cancelamento | Não iniciado | Permissão sob consentimento, canais Android, mudanças de versão, privacidade na tela bloqueada |
| Criação rápida | Formulários reais para tarefa, meta, nota, diário, bloco de rotina e hobby | Parcialmente implementado | Adicionar evento, alimentação/estudo após módulos reais existirem |
| Backup/exportação | JSON versionado; PIN/tokens de segurança excluídos; importação validada/transacional | Parcialmente implementado | Exportação criptografada opcional, testes de schema antigo/novo e reconciliação futura de módulos |
| Migrations/integridade | MigrationStrategy, schema v3 e histórico preservado em entidades existentes | Parcialmente implementado | Testar upgrade de cada versão instalada e consistência de FKs/recorrências |
| Firebase/telemetria | Inicialização opcional para manter app local; analytics explícito removido no Gradle | Implementado, aguardando validação | Confirmar Android build e autenticação só após configuração externa |
| Build e análise automatizados | Workflow GitHub Actions criado para pub get, analyze, test e APK debug | Implementado, aguardando validação | Corrigir toda falha do workflow e registrar o SHA validado |
| Testes unitários | Há testes de cálculos, repositório e PIN/perfil | Parcialmente implementado | Expandir cálculo automático de metas, recorrência, janela disponível, nutrição, IMC e datas |
| Testes de widgets | Testes básicos de componentes presentes | Parcialmente implementado | Home, login/onboarding, metas, calendário, dieta, configurações, erros e estados vazios |
| Testes de integração | Um fluxo de notas existe | Parcialmente implementado | Fluxos meta→registro→estatísticas, recorrência→calendário e plano alimentar→consumo |
| Android em dispositivo físico | Não há validação de aparelho declarada | Bloqueado por configuração externa | Testar biometria, voltar/gestos, permissões, notificação, background, rotação e tamanhos |

## Alterações desta branch

- Refatorada a regra de saudação para fronteiras 05:00, 12:00 e 18:00 com testes unitários.
- Home passa a atualizar o relógio/contexto durante uso contínuo e a recarregar dados por data.
- Foco diário agora tem ações explícitas de definir, concluir e reabrir.
- Criação rápida saiu da posição flutuante que podia sobrepor conteúdo.
- Voltar de uma aba secundária retorna à Home.
- PIN novo usa PBKDF2-HMAC-SHA256; PIN legado é migrado somente depois de verificação correta.
- Após cinco tentativas erradas, aplica-se cooldown progressivo de 30 s até 300 s; metadados de bloqueio ficam fora do backup JSON.
- Corrigida configuração nativa do plugin local_auth para Android e descrição Face ID no iOS.
- Firebase é opcional na inicialização local-first e o Gradle não inclui mais a dependência explícita de Firebase Analytics.
- CI foi criada para rodar análise, testes e build Android debug.

## Validação pendente desta branch

1. Consultar o workflow de CI no SHA mais recente e corrigir todo erro real de analyze/test/build.
2. Executar testes de widget/integrados quando o ambiente comportar um backend de banco de testes apropriado.
3. Validar biometria e navegação em dispositivo Android físico; não declarar teste físico antes disso.
4. Resolver configuração Firebase/OAuth com o proprietário antes de ativar Login Google ou Google Agenda.
5. Atualizar este documento após cada fase, movendo o status apenas quando os critérios de aceitação forem cumpridos.

## Ordem recomendada para as próximas fases

1. Finalizar esta estabilização após CI e build passarem.
2. Implementar console de erros estruturado e sanitizado para debug.
3. Implementar onboarding/perfil/login Google real depois da configuração externa.
4. Implementar progresso automático e explicável das metas a partir de registros reais.
5. Evoluir calendário/recorrências/exceções e planejado versus realizado.
6. Construir guia de estudos, dieta/alimentação e estatísticas semanais/mensais.
7. Integrar Google Calendar por etapas após OAuth.
8. Adicionar notificações locais, preferências completas de tema/acessibilidade e reforçar backup/segurança.

