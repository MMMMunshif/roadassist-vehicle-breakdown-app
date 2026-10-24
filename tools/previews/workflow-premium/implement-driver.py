from pathlib import Path
p=Path('lib/src/features/request/tracking_screen.dart');s=p.read_text(encoding='utf-8');a=s.index('  Widget buildStatusCard(');b=s.index('  Widget buildRequestSummary(',a)
s=s[:a]+'''  Widget buildStatusCard(BuildContext context) => ActiveAssistanceStatusCard(
    status: status,
    cancelled: cancelled,
    title: statusTitle,
    description: statusDescription,
    completionPending: completionPending,
  );

'''+s[b:]
# Make current stage and contact the first content, rather than placing the map first.
a=s.index('                  buildMap(context),',s.index('  Widget build(BuildContext context)',s.index('  Widget buildRecoveryCard')))
b=s.index('                  if (requestError != null)',a)
mapblock=s[a:b]
s=s[:a]+'''                  buildStatusCard(context),
                  const SizedBox(height: 14),
                  buildProviderCard(context),
                  const SizedBox(height: 14),
                  if (!cancelled && status < 2) ...[
'''+mapblock+'''                  ] else
                    ExpansionTile(
                      key: const PageStorageKey('assistance-map'),
                      tilePadding: const EdgeInsets.symmetric(horizontal: 8),
                      leading: const Icon(Icons.map_outlined),
                      title: const Text('Provider location'),
                      children: [
'''+mapblock+'''                      ],
                    ),
'''+s[b:]
# Remove duplicate contact and status cards from their old positions.
a=s.index('                  buildProviderCard(context),',s.index('                  if (requestError != null)',a))
s=s[:a]+s[a:].replace('                  buildProviderCard(context),\n','',1)
a=s.index('                  buildStatusCard(context),',a)
s=s[:a]+s[a:].replace('                  buildStatusCard(context),\n','',1)
# Place the real next actions before secondary request details.
a=s.index('                  if (!cancelled &&\n                      status == 2 &&\n                      arrivalNeedsConfirmation)')
b=s.index('                  if (cancelled && recoveryReason != null)',a)
actions=s[a:b];s=s[:a]+s[b:]
a=s.index('                  if (visitBilling && widget.requestId != null)\n                    WorkApprovalPanel')
s=s[:a]+actions+s[a:]
s=s.replace('                  buildRequestSummary(context),', '''                  ExpansionTile(
                    key: const PageStorageKey('assistance-details'),
                    tilePadding: const EdgeInsets.symmetric(horizontal: 8),
                    leading: const Icon(Icons.receipt_long_outlined),
                    title: const Text('Request details & charges'),
                    subtitle: Text(estimatedCost > 0 ? money(estimatedCost) : 'Price pending'),
                    children: [buildRequestSummary(context)],
                  ),''')
s=s.replace('            _RaTrackingBottomBar(', '            if (cancelled || status == 3) _RaTrackingBottomBar(')
p.write_text(s,encoding='utf-8')
