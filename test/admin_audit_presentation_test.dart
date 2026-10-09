import 'package:flutter_test/flutter_test.dart';
import 'package:road_assist/src/models/admin_audit_presentation.dart';

void main() {
  test('Camel case labels never contain replacement placeholders', () {
    expect(
      AdminAuditPresentation.friendlyKey('verificationChecks'),
      'Verification Checks',
    );
    expect(AdminAuditPresentation.friendlyKey('lastAuditId'), 'Last Audit Id');
    expect(AdminAuditPresentation.friendlyKey('validUntil'), 'Valid Until');
  });
  test(
    'Audit action derives from saved changes rather than arbitrary reason text',
    () {
      expect(
        AdminAuditPresentation.action({
          'kind': 'account',
          'before': {},
          'after': {'verification': 'verified'},
          'reason': 'Random old reason',
        }),
        'Provider approved',
      );
      expect(
        AdminAuditPresentation.action({
          'kind': 'account',
          'before': {'verification': 'verified'},
          'after': {
            'verification': 'pending',
            'correctionRequest': {
              'documents': ['selfie'],
            },
          },
        }),
        'Document corrections requested',
      );
      expect(
        AdminAuditPresentation.action({
          'kind': 'account',
          'before': {'status': 'active'},
          'after': {'status': 'suspended'},
        }),
        'Account suspended',
      );
      expect(
        AdminAuditPresentation.action({'kind': 'complaint'}),
        'Complaint reviewed',
      );
    },
  );
  test(
    'Flag updates do not become correction events when nested request is unchanged',
    () {
      expect(
        AdminAuditPresentation.action({
          'kind': 'account',
          'before': {
            'verification': 'pending',
            'flagged': false,
            'correctionRequest': {
              'documents': ['selfie'],
            },
          },
          'after': {
            'verification': 'pending',
            'flagged': true,
            'correctionRequest': {
              'documents': ['selfie'],
            },
          },
        }),
        'Account flagged',
      );
      expect(
        AdminAuditPresentation.action({
          'kind': 'account',
          'before': {'verification': 'verified', 'verificationRevision': 1},
          'after': {'verification': 'verified', 'verificationRevision': 2},
        }),
        'Provider approved',
      );
    },
  );
}
