part of '../screens.dart';

class JobStartCodePanel extends StatefulWidget {
  const JobStartCodePanel({
    super.key,
    required this.requestId,
    required this.isProvider,
  });
  final String requestId;
  final bool isProvider;
  @override
  State<JobStartCodePanel> createState() => _JobStartCodePanelState();
}

class _JobStartCodePanelState extends State<JobStartCodePanel> {
  final input = TextEditingController();
  bool busy = false;
  String? code;
  DateTime? expiresAt;
  String? message;
  Timer? clock;
  @override
  void initState() {
    super.initState();
    clock = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted && code != null) setState(() {});
    });
  }

  @override
  void dispose() {
    clock?.cancel();
    input.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy) return;
    if (widget.isProvider && !RegExp(r'^\d{6}$').hasMatch(input.text.trim())) {
      setState(() {
        message = 'Enter the six-digit code shown on the driver phone.';
      });
      return;
    }
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final result = await JobStartService().send(
        widget.requestId,
        widget.isProvider ? 'verify' : 'issue',
        code: widget.isProvider ? input.text.trim() : null,
      );
      if (!mounted) return;
      setState(() {
        if (widget.isProvider) {
          message = 'Job start confirmed. You can begin the approved work.';
          input.clear();
        } else {
          code = result['code'] as String;
          expiresAt = DateTime.fromMillisecondsSinceEpoch(
            result['expiresAt'] as int,
          );
        }
      });
    } catch (error) {
      if (mounted)
        setState(() {
          message = error.toString().replaceFirst('Bad state: ', '');
        });
    } finally {
      if (mounted)
        setState(() {
          busy = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final expired = expiresAt != null && !expiresAt!.isAfter(DateTime.now());
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Confirm job start',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              widget.isProvider
                  ? 'Ask the driver for their code after you meet. Verify it before starting work.'
                  : 'Generate a code only after meeting your provider. Share it in person when ready to start.',
            ),
            if (!widget.isProvider && code != null) ...[
              const SizedBox(height: 12),
              Text(
                expired ? 'Code expired' : code!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  letterSpacing: expired ? 0 : 6,
                ),
              ),
              Text(
                expired
                    ? 'Generate a replacement code.'
                    : 'Valid for 10 minutes. Keep this screen open.',
                textAlign: TextAlign.center,
              ),
            ],
            if (widget.isProvider) ...[
              const SizedBox(height: 12),
              TextField(
                controller: input,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Driver job start code',
                ),
              ),
            ],
            if (message != null) ...[const SizedBox(height: 8), Text(message!)],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: busy ? null : submit,
              icon: const Icon(Icons.verified_user_outlined),
              label: Text(
                busy
                    ? 'Please wait...'
                    : widget.isProvider
                    ? 'Verify and start job'
                    : code == null
                    ? 'Generate job start code'
                    : 'Generate replacement code',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
