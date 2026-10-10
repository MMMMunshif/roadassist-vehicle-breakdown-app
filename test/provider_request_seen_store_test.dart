import 'package:flutter_test/flutter_test.dart';
import 'package:road_assist/src/services/provider_request_seen_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'viewed requests persist per provider and new requests remain unseen',
    () async {
      final store = ProviderRequestSeenStore();

      await store.markSeen('provider-1', ['request-1']);

      expect(await store.load('provider-1'), {'request-1'});
      expect(await store.load('provider-2'), isEmpty);
      expect(await store.load('provider-1'), isNot(contains('request-2')));
    },
  );
}
