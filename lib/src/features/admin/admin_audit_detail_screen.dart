part of '../../screens.dart';

class _AdminAuditScreen extends StatelessWidget {
  const _AdminAuditScreen({required this.data});
  final Map<String, dynamic> data;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Audit record')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        for (final key in [
          'kind',
          'target',
          'actor',
          'createdAt',
          'reason',
          'before',
          'after',
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: SelectableText('$key\n${data[key]}'),
          ),
      ],
    ),
  );
}
