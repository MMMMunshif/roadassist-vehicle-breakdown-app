part of '../../screens.dart';

class _ChatInboxScreen extends StatelessWidget {
  const _ChatInboxScreen({required this.isProvider});
  final bool isProvider;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Messages')),
    body: _ChatInbox(isProvider: isProvider),
  );
}
