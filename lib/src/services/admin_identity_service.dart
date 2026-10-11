import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminIdentity {
  const AdminIdentity({
    required this.id,
    required this.name,
    this.email = '',
    this.phone = '',
    this.unavailable = false,
  });
  final String id, name, email, phone;
  final bool unavailable;
  String get label => [
    name,
    if (email.isNotEmpty && email != name) email,
    if (phone.isNotEmpty) phone,
  ].join(' | ');
}

class AdminIdentityService {
  final _pending = <String, Future<AdminIdentity>>{};
  final resolved = <String, AdminIdentity>{};
  Future<AdminIdentity> user(String id) => _pending.putIfAbsent(id, () async {
    AdminIdentity result;
    try {
      final data =
          (await FirebaseFirestore.instance.collection('users').doc(id).get())
              .data();
      final self = FirebaseAuth.instance.currentUser;
      final name = data?['displayName']?.toString().trim() ?? '';
      final email =
          data?['email']?.toString().trim() ??
          (self?.uid == id ? self?.email ?? '' : '');
      result = AdminIdentity(
        id: id,
        name: name.isNotEmpty
            ? name
            : self?.uid == id && self?.displayName?.isNotEmpty == true
            ? self!.displayName!
            : email.isNotEmpty
            ? email
            : 'Account name unavailable',
        email: email,
        phone: data?['phone']?.toString() ?? '',
        unavailable: data == null && self?.uid != id,
      );
    } catch (_) {
      result = AdminIdentity(
        id: id,
        name: 'Account details unavailable',
        unavailable: true,
      );
    }
    resolved[id] = result;
    return result;
  });
  Future<Map<String, String>> audit(Map<String, dynamic> data) async {
    final actor = data['actor']?.toString() ?? '',
        target = data['target']?.toString() ?? '';
    final actorName = actor.isEmpty
        ? 'Administrator not recorded'
        : (await user(actor)).label;
    String targetName;
    if (data['kind'] == 'settings') {
      targetName = 'Platform operations';
    } else if (data['kind'] == 'complaint' || data['kind'] == 'job') {
      try {
        final job =
            (await FirebaseFirestore.instance
                    .collection('requests')
                    .doc(target)
                    .get())
                .data();
        targetName = job == null
            ? 'Assistance request unavailable'
            : '${job['driverName'] ?? 'Driver name unavailable'} - ${job['providerName'] ?? 'Provider unassigned'}';
      } catch (_) {
        targetName = 'Assistance request details unavailable';
      }
    } else {
      targetName = target.isEmpty
          ? 'Target not recorded'
          : (await user(target)).label;
    }
    return {'actor': actorName, 'target': targetName};
  }
}
