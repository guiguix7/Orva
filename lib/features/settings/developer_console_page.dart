import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/logging/orva_diagnostics.dart';
import '../../core/theme/orva_theme.dart';
import '../../core/widgets/orva_widgets.dart';

class DeveloperConsolePage extends StatefulWidget {
  const DeveloperConsolePage({super.key});

  @override
  State<DeveloperConsolePage> createState() => _DeveloperConsolePageState();
}

class _DeveloperConsolePageState extends State<DeveloperConsolePage> {
  final _searchController = TextEditingController();
  DiagnosticSeverity? _severityFilter;

  OrvaDiagnostics get _diagnostics => OrvaDiagnostics.instance;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _clear() async {
    if (_diagnostics.events.isEmpty) return;
    final confirmed = await confirmAction(
      context,
      title: 'Limpar o console?',
      message: 'Os registros de diagnóstico em memória serão removidos. Isso não altera os dados pessoais do Orva.',
      actionLabel: 'Limpar registros',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    _diagnostics.clear();
  }

  Future<void> _export() async {
    final text = _diagnostics.exportText();
    if (text.trim().isEmpty) {
      showOrvaMessage(context, 'Ainda não há registros para exportar.');
      return;
    }
    try {
      await SharePlus.instance.share(ShareParams(
        title: 'Diagnóstico do Orva',
        text: text,
      ));
    } catch (error) {
      if (mounted) showOrvaError(context, error);
    }
  }

  Color _colorFor(DiagnosticSeverity severity, BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return switch (severity) {
      DiagnosticSeverity.debug => colors.onSurfaceVariant,
      DiagnosticSeverity.info => OrvaColors.information,
      DiagnosticSeverity.warning => OrvaColors.mustard,
      DiagnosticSeverity.error => colors.error,
      DiagnosticSeverity.critical => OrvaColors.terracotta,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Console de desenvolvimento'),
        actions: [
          IconButton(
            tooltip: 'Exportar diagnóstico sanitizado',
            onPressed: _export,
            icon: const Icon(Icons.ios_share_outlined),
          ),
          IconButton(
            tooltip: 'Limpar registros',
            onPressed: _clear,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _diagnostics,
          builder: (context, _) {
            final query = _searchController.text.trim().toLowerCase();
            final filtered = _diagnostics.events.where((event) {
              final matchesSeverity =
                  _severityFilter == null || event.severity == _severityFilter;
              final haystack = [
                event.id,
                event.module,
                event.category,
                event.message,
                event.timestamp.toIso8601String(),
              ].join(' ').toLowerCase();
              return matchesSeverity && (query.isEmpty || haystack.contains(query));
            }).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Somente desenvolvimento · até ${OrvaDiagnostics.maxEvents} registros em memória',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Buscar por módulo, categoria ou mensagem',
                        ),
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            FilterChip(
                              label: const Text('Todos'),
                              selected: _severityFilter == null,
                              onSelected: (_) => setState(() => _severityFilter = null),
                            ),
                            const SizedBox(width: 8),
                            for (final severity in DiagnosticSeverity.values) ...[
                              FilterChip(
                                label: Text(severity.name.toUpperCase()),
                                selected: _severityFilter == severity,
                                onSelected: (_) => setState(() {
                                  _severityFilter =
                                      _severityFilter == severity ? null : severity;
                                }),
                              ),
                              const SizedBox(width: 8),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${filtered.length} registro(s)',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: filtered.isEmpty
                      ? const OrvaEmptyState(
                          icon: Icons.terminal_rounded,
                          title: 'Nenhum registro encontrado',
                          message: 'Erros e eventos de desenvolvimento aparecerão aqui quando forem capturados.',
                          compact: true,
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final event = filtered[index];
                            final color = _colorFor(event.severity, context);
                            return OrvaSurface(
                              padding: EdgeInsets.zero,
                              child: ExpansionTile(
                                tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                leading: Icon(Icons.circle, color: color, size: 12),
                                title: Text(
                                  '${event.severity.name.toUpperCase()} · ${event.category}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 5),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${event.timestamp.toLocal().toIso8601String().replaceFirst('T', ' ')} · ${event.module}',
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        event.message,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                children: [
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: SelectableText('ID: ${event.id}'),
                                  ),
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: SelectableText(event.message),
                                  ),
                                  if (event.stackTrace != null) ...[
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: SelectableText(event.stackTrace!),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
