import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/theme/orva_theme.dart';
import '../hobbies/hobbies_page.dart';
import '../journal/journal_page.dart';
import '../notes/notes_page.dart';
import '../routine/routine_page.dart';
import '../studies/study_page.dart';
import '../nutrition/nutrition_page.dart';
import '../obligations/obligations_page.dart';
import '../settings/settings_page.dart';
import '../settings/developer_console_page.dart';
import '../settings/categories_page.dart';
import '../profile/profile_page.dart';
import '../../core/widgets/orva_widgets.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) => SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 28), children: [
    Text('Mais', style: Theme.of(context).textTheme.headlineMedium),
    const SizedBox(height: 6),
    Text('Outras áreas do seu espaço pessoal.', style: Theme.of(context).textTheme.bodyMedium),
    const SizedBox(height: 22),
    _ModuleTile(icon: Icons.schedule_outlined, title: 'Rotina e tempo', subtitle: 'Planeje blocos e veja a distribuição por categoria.', tint: OrvaColors.information, onTap: () => _open(context, const RoutinePage())),
    const SizedBox(height: 10),
    _ModuleTile(icon: Icons.repeat_rounded, title: 'Obrigações recorrentes', subtitle: 'Necessidades fixas, ocorrências, sono noturno e exceções por data.', tint: OrvaColors.information, onTap: () => _open(context, const ObligationsPage())),
    const SizedBox(height: 10),
    _ModuleTile(icon: Icons.school_outlined, title: 'Estudos', subtitle: 'Matérias, tópicos, sessões reais e revisões.', tint: OrvaColors.primary, onTap: () => _open(context, const StudyPage())),
    const SizedBox(height: 10),
    _ModuleTile(icon: Icons.restaurant_outlined, title: 'Alimentação e saúde', subtitle: 'Catálogo de alimentos, refeições planejadas e consumo registrado.', tint: OrvaColors.terracotta, onTap: () => _open(context, const NutritionPage())),
    const SizedBox(height: 10),
    _ModuleTile(icon: Icons.sports_esports_outlined, title: 'Hobbies', subtitle: 'Registre sessões e acompanhe metas semanais.', tint: OrvaColors.terracotta, onTap: () => _open(context, const HobbiesPage())),
    const SizedBox(height: 10),
    _ModuleTile(icon: Icons.edit_note_outlined, title: 'Notas', subtitle: 'Pesquise e organize ideias e aprendizados.', tint: const Color(0xFF7A9B76), onTap: () => _open(context, const NotesPage())),
    const SizedBox(height: 10),
    _ModuleTile(icon: Icons.menu_book_outlined, title: 'Diário', subtitle: 'Registros privados organizados por data.', tint: const Color(0xFF8B6B9E), onTap: () => _open(context, const JournalPage())),
    const SizedBox(height: 10),
    _ModuleTile(icon: Icons.label_outline_rounded, title: 'Categorias', subtitle: 'Crie, renomeie e organize suas categorias personalizadas.', tint: OrvaColors.mustard, onTap: () => _open(context, const CategoriesPage())),
    const SizedBox(height: 10),
    _ModuleTile(icon: Icons.person_outline_rounded, title: 'Perfil', subtitle: 'Nome, data de nascimento, altura e histórico de peso.', tint: const Color(0xFF4A7A9E), onTap: () => _open(context, const ProfilePage())),
    const SizedBox(height: 10),
    _ModuleTile(icon: Icons.tune_rounded, title: 'Configurações', subtitle: 'Perfil local, tema e backup dos dados.', tint: OrvaColors.primary, onTap: () => _open(context, const SettingsPage())),
    if (kDebugMode) ...[
      const SizedBox(height: 10),
      _ModuleTile(icon: Icons.terminal_rounded, title: 'Console de desenvolvimento', subtitle: 'Diagnósticos sanitizados desta sessão.', tint: OrvaColors.information, onTap: () => _open(context, const DeveloperConsolePage())),
    ],
    const SizedBox(height: 20),
    const OrvaSurface(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.lock_outline_rounded, color: OrvaColors.primary), SizedBox(width: 10), Expanded(child: Text('Privado por padrão. As funções essenciais não dependem de uma conta nem de conexão com a internet.'))])),
    const SizedBox(height: 18),
    Text('A grade completa de calendário dia/semana/mês e os gráficos históricos avançados continuam em desenvolvimento.', style: Theme.of(context).textTheme.bodySmall),
  ]));

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({required this.icon, required this.title, required this.subtitle, required this.tint, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OrvaSurface(onTap: onTap, child: Row(children: [
    Container(width: 48, height: 48, decoration: BoxDecoration(color: tint.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: tint, size: 24)),
    const SizedBox(width: 14),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 4), Text(subtitle, style: Theme.of(context).textTheme.bodySmall)])),
    const SizedBox(width: 8), const Icon(Icons.chevron_right_rounded, color: OrvaColors.tertiaryText),
  ]));
}
