part of '../screens.dart';

/// Shares the approved road pattern without making routes transparent.
class RaScaffold extends StatelessWidget {
  const RaScaffold({
    super.key,
    this.appBar,
    this.body,
    this.backgroundColor,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.extendBodyBehindAppBar = false,
    this.extendBody = false,
    this.resizeToAvoidBottomInset,
    this.preventLeave = false,
    this.leaveMessage = 'You have unsaved changes. Leave without saving?',
  });

  final bool preventLeave;
  final String leaveMessage;
  final PreferredSizeWidget? appBar;
  final Widget? body;
  final Color? backgroundColor;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final bool extendBodyBehindAppBar;
  final bool extendBody;
  final bool? resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) => _RaLeaveGuard(
    preventLeave: preventLeave,
    message: leaveMessage,
    child: Scaffold(
      appBar: appBar,
      backgroundColor: backgroundColor,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      extendBody: extendBody,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _RoleRoadPattern(
                    dark: Theme.of(context).brightness == Brightness.dark,
                  ),
                ),
              ),
            ),
          ),
          if (body != null) body!,
        ],
      ),
    ),
  );
}

Future<bool> _confirmProviderSignOut(BuildContext context) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Sign out of RoadAssist?'),
          content: const Text(
            'You will be taken offline and stop receiving new requests. '
            'If you have an active job, signing out does not cancel it. '
            'Finish the job or contact your driver before leaving.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Stay signed in'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sign out'),
            ),
          ],
        ),
      ) ??
      false;
}

class _RaLeaveGuard extends StatefulWidget {
  const _RaLeaveGuard({
    required this.preventLeave,
    required this.message,
    required this.child,
  });
  final bool preventLeave;
  final String message;
  final Widget child;
  @override
  State<_RaLeaveGuard> createState() => _RaLeaveGuardState();
}

class _RaLeaveGuardState extends State<_RaLeaveGuard> {
  bool allowed = false;
  bool asking = false;
  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop: allowed || !widget.preventLeave,
    onPopInvokedWithResult: (didPop, result) async {
      if (didPop || asking || !widget.preventLeave) return;
      asking = true;
      final leave = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Leave this page?'),
          content: Text(widget.message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Stay'),
            ),
            if (!widget.message.startsWith('Please wait'))
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Discard changes'),
              ),
          ],
        ),
      );
      asking = false;
      if (leave != true || !mounted) return;
      setState(() => allowed = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop(result);
      });
    },
    child: widget.child,
  );
}
