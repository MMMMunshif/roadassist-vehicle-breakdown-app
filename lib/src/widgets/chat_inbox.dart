part of '../screens.dart';

class _ChatInbox extends StatefulWidget {
  const _ChatInbox({
    required this.isProvider,
    this.buttonOnly = false,
    this.preview = false,
  });
  final bool isProvider, buttonOnly, preview;
  @override
  State<_ChatInbox> createState() => _ChatInboxState();
}

class _ChatInboxState extends State<_ChatInbox> {
  ChatInboxController? inbox;
  @override
  void initState() {
    super.initState();
    if (signedIn) {
      inbox = ChatInboxController(isProvider: widget.isProvider);
    }
  }

  @override
  void dispose() {
    inbox?.dispose();
    super.dispose();
  }

  void openThread(String id) {
    final job = inbox!.jobs[id]!;
    push(
      context,
      ChatScreen(
        requestId: id,
        peerName:
            job[widget.isProvider ? 'driverName' : 'providerName'] as String? ??
            'Chat',
        peerPhone:
            job[widget.isProvider ? 'driverPhone' : 'providerPhone']
                as String? ??
            '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = inbox;
    if (controller == null) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (widget.buttonOnly) {
          return Badge(
            isLabelVisible: controller.unread > 0,
            label: Text(
              controller.unread > 99 ? '99+' : '${controller.unread}',
            ),
            child: IconButton(
              tooltip: 'Messages',
              icon: const Icon(Icons.chat_outlined),
              onPressed: () => push(
                context,
                _ChatInboxScreen(isProvider: widget.isProvider),
              ),
            ),
          );
        }
        final ids = controller.threadIds
            .where((id) => !widget.preview || controller.unreadFor(id) > 0)
            .toList();
        if (widget.preview && ids.isEmpty && !controller.hasError)
          return const SizedBox.shrink();
        final tiles = <Widget>[
          if (controller.hasError)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Could not load some conversations. Check your connection and account access.',
              ),
            ),
          if (controller.loading) const LinearProgressIndicator(),
          if (!controller.loading && ids.isEmpty && !controller.hasError)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No conversations yet. Messages from active and completed jobs appear here.',
              ),
            ),
          for (final id in (widget.preview ? ids.take(3) : ids))
            ListTile(
              leading: Badge(
                isLabelVisible: controller.unreadFor(id) > 0,
                label: Text('${controller.unreadFor(id)}'),
                child: const Icon(Icons.chat_outlined),
              ),
              title: Text(
                controller.jobs[id]![widget.isProvider
                            ? 'driverName'
                            : 'providerName']
                        as String? ??
                    'Chat',
              ),
              subtitle: Text(
                '${controller.conversations[id]!.last['imageData'] != null ? 'Photo' : controller.conversations[id]!.last['text'] ?? ''}\n${requestIssueLabel(controller.jobs[id]!)} - ${controller.jobs[id]!['status'] ?? ''}',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => openThread(id),
            ),
        ];
        if (!widget.preview) return ListView(children: tiles);
        return Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                title: Text('Unread messages (${controller.unread})'),
                trailing: TextButton(
                  onPressed: () => push(
                    context,
                    _ChatInboxScreen(isProvider: widget.isProvider),
                  ),
                  child: const Text('View all'),
                ),
              ),
              ...tiles,
            ],
          ),
        );
      },
    );
  }
}
