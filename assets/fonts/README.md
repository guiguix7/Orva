# Fontes do Orva (passo manual pendente)

O ambiente usado para evoluir este projeto não tem acesso à internet, então
não foi possível baixar os arquivos binários das fontes exigidas pelo
prompt mestre (Fraunces, Inter, JetBrains Mono). O código já está pronto
para usá-las — só falta colocar os arquivos aqui.

## O que fazer

1. Baixe as fontes (todas são abertas, licença SIL Open Font License):
   - Fraunces: https://fonts.google.com/specimen/Fraunces
   - Inter: https://fonts.google.com/specimen/Inter
   - JetBrains Mono: https://www.jetbrains.com/lp/mono/

2. Coloque os arquivos `.ttf` nesta pasta (`assets/fonts/`), por exemplo:
   - `Fraunces-Regular.ttf`, `Fraunces-SemiBold.ttf`
   - `Inter-Regular.ttf`, `Inter-Medium.ttf`, `Inter-SemiBold.ttf`
   - `JetBrainsMono-Regular.ttf`, `JetBrainsMono-Medium.ttf`

3. Descomente o bloco `fonts:` em `pubspec.yaml` (está pronto, só comentado)
   e ajuste os nomes de arquivo se baixar pesos diferentes.

4. Rode `flutter pub get` novamente.

Até que isso seja feito, o app funciona normalmente: `lib/core/theme/orva_theme.dart`
referencia os nomes 'Fraunces', 'Inter' e 'JetBrainsMono' com uma lista de
fallback (`fontFamilyFallback`) para fontes do sistema, então a interface
não quebra — ela só usa a tipografia padrão da plataforma em vez da
identidade visual específica do Orva até os arquivos serem adicionados.
