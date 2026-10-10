import 'package:flutter_test/flutter_test.dart';
import 'package:road_assist/src/models/provider_document_correction.dart';

void main() {
  final app = <String, dynamic>{
    'revision': 2,
    'legalName': 'Saved Name',
    'documents': {
      'selfie': 'old face',
      'nicFront': 'saved front',
      'nicBack': 'old back',
    },
  };
  final moderation = <String, dynamic>{
    'verification': 'pending',
    'correctionRequest': {
      'revision': 2,
      'documents': ['selfie', 'nicBack'],
    },
  };
  test(
    'corrections preserve unselected documents and all application details',
    () {
      final request = ProviderDocumentCorrection.active(app, moderation)!;
      final updated = request.replaceDocuments(app, {
        'selfie': 'new face',
        'nicBack': 'new back',
      });
      expect(updated['legalName'], 'Saved Name');
      expect(updated['documents'], {
        'selfie': 'new face',
        'nicFront': 'saved front',
        'nicBack': 'new back',
      });
      expect((app['documents'] as Map)['selfie'], 'old face');
    },
  );
  test('reject missing, unchanged and unrequested replacement documents', () {
    final request = ProviderDocumentCorrection.active(app, moderation)!;
    for (final replacements in [
      <String, String>{'selfie': 'new'},
      {'selfie': 'old face', 'nicBack': 'new'},
      {'selfie': 'new', 'nicBack': 'new', 'nicFront': 'tampered'},
    ]) {
      expect(
        () => request.replaceDocuments(app, replacements),
        throwsStateError,
      );
    }
  });
  test(
    'withdrawn, stale, rejected and duplicate correction requests are inactive',
    () {
      expect(
        ProviderDocumentCorrection.active({...app, 'revision': 3}, moderation),
        isNull,
      );
      expect(
        ProviderDocumentCorrection.active({
          ...app,
          'applicationStatus': 'withdrawn',
        }, moderation),
        isNull,
      );
      expect(
        ProviderDocumentCorrection.active(app, {
          ...moderation,
          'verification': 'rejected',
        }),
        isNull,
      );
      expect(
        ProviderDocumentCorrection.active(app, {
          'verification': 'pending',
          'correctionRequest': {
            'revision': 2,
            'documents': ['selfie', 'selfie'],
          },
        }),
        isNull,
      );
    },
  );
}
