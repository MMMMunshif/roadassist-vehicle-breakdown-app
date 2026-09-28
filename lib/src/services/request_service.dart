import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/request_draft.dart';

class RequestService {
  RequestService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _requests =>
      _firestore.collection('requests');

  String get _userId {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Authentication is required.');
    return user.uid;
  }

  Future<String> createRequest(RequestDraft draft) async {
    final driverRequests = await _requests
        .where('driverId', isEqualTo: _userId)
        .get();
    final hasActiveRequest = driverRequests.docs.any((request) {
      return const [
        'searching',
        'accepted',
        'en_route',
        'arrived',
      ].contains(request.data()['status']);
    });
    if (hasActiveRequest) {
      throw StateError('Complete or cancel your active request first.');
    }
    final document = _requests.doc();
    final profile = await _firestore.collection('users').doc(_userId).get();
    await document.set({
      'driverId': _userId,
      'driverName': _auth.currentUser?.displayName ?? 'Driver',
      'driverPhone': profile.data()?['phone'] ?? '',
      'providerId': null,
      'preferredProviderId': draft.preferredProviderId,
      'preferredProviderName': draft.provider,
      'rejectedBy': <String>[],
      'status': 'searching',
      'issue': draft.issue,
      'vehicleType': draft.vehicleType,
      'modelYear': draft.modelYear,
      'registration': draft.registration,
      'description': draft.description,
      'notes': draft.notes,
      'vehiclePhotoUrls': draft.vehiclePhotoUrls,
      'locationLabel': draft.location,
      'latitude': draft.latitude,
      'longitude': draft.longitude,
      'serviceFee': draft.serviceFee,
      'dispatchFee': draft.dispatchFee,
      'estimatedCost': draft.estimatedCost,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return document.id;
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchRequest(String id) =>
      _requests.doc(id).snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> watchOpenRequests() => _requests
      .where('status', isEqualTo: 'searching')
      .orderBy('createdAt', descending: true)
      .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> watchDriverRequests() => _requests
      .where('driverId', isEqualTo: _userId)
      .orderBy('createdAt', descending: true)
      .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> watchProviderRequests() =>
      _requests
          .where('providerId', isEqualTo: _userId)
          .orderBy('createdAt', descending: true)
          .snapshots();

  Future<void> acceptRequest(
    String id, {
    required int serviceFee,
    required int travelFee,
    required int extraFee,
    required double providerDistanceKm,
    required String quoteNotes,
  }) async {
    if (serviceFee < 0 || travelFee < 0 || extraFee < 0) {
      throw ArgumentError('Quote amounts must not be negative.');
    }
    final quotedTotal = serviceFee + travelFee + extraFee;
    final assignedRequests = await _requests
        .where('providerId', isEqualTo: _userId)
        .get();
    final hasActiveJob = assignedRequests.docs.any((request) {
      return const [
        'accepted',
        'en_route',
        'arrived',
      ].contains(request.data()['status']);
    });
    if (hasActiveJob) {
      throw StateError('Complete your active job before accepting another.');
    }
    await _firestore.runTransaction((transaction) async {
      final reference = _requests.doc(id);
      final profileReference = _firestore.collection('users').doc(_userId);
      final request = await transaction.get(reference);
      final profile = await transaction.get(profileReference);
      if (!request.exists || request.data()?['status'] != 'searching') {
        throw StateError('This request is no longer available.');
      }
      final preferredProviderId =
          request.data()?['preferredProviderId'] as String? ?? '';
      if (preferredProviderId.isNotEmpty && preferredProviderId != _userId) {
        throw StateError('This request was sent to another provider.');
      }
      final lockedRequestId = profile.data()?['activeRequestId'] as String?;
      if (lockedRequestId != null &&
          lockedRequestId.isNotEmpty &&
          lockedRequestId != id) {
        final lockedRequest = await transaction.get(
          _requests.doc(lockedRequestId),
        );
        final lockedStatus = lockedRequest.data()?['status'] as String?;
        if (lockedRequest.exists &&
            const ['accepted', 'en_route', 'arrived'].contains(lockedStatus)) {
          throw StateError(
            'Complete your active job before accepting another.',
          );
        }
      }
      transaction.update(reference, {
        'providerId': _userId,
        'providerName':
            profile.data()?['displayName'] ??
            _auth.currentUser?.displayName ??
            'Service Provider',
        'providerPhone': profile.data()?['phone'] ?? '',
        'status': 'accepted',
        'serviceFee': serviceFee,
        'dispatchFee': travelFee,
        'extraFee': extraFee,
        'estimatedCost': quotedTotal,
        'providerDistanceKm': providerDistanceKm,
        'quoteNotes': quoteNotes.trim(),
        'quotedAt': FieldValue.serverTimestamp(),
        'acceptedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(profileReference, {
        'activeRequestId': id,
        'activeJobStartedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> rejectRequest(String id) async {
    await _firestore.runTransaction((transaction) async {
      final reference = _requests.doc(id);
      final request = await transaction.get(reference);
      final data = request.data();
      if (!request.exists || data?['status'] != 'searching') {
        throw StateError('This request is no longer available.');
      }
      final preferredProviderId = data?['preferredProviderId'] as String? ?? '';
      if (preferredProviderId.isNotEmpty && preferredProviderId != _userId) {
        throw StateError('This request was sent to another provider.');
      }
      final updates = <String, dynamic>{
        'rejectedBy': FieldValue.arrayUnion([_userId]),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (preferredProviderId == _userId) {
        updates.addAll({
          'preferredProviderId': '',
          'preferredProviderName': '',
          'fallbackStartedAt': FieldValue.serverTimestamp(),
        });
      }
      transaction.update(reference, updates);
    });
  }

  Future<void> expandProviderSearch(String id) async {
    await _firestore.runTransaction((transaction) async {
      final reference = _requests.doc(id);
      final request = await transaction.get(reference);
      final data = request.data();
      if (!request.exists || data?['driverId'] != _userId) {
        throw StateError('Only the request driver can expand this search.');
      }
      if (data?['status'] != 'searching') return;
      final preferredProviderId = data?['preferredProviderId'] as String? ?? '';
      if (preferredProviderId.isEmpty) return;
      transaction.update(reference, {
        'preferredProviderId': '',
        'preferredProviderName': '',
        'fallbackStartedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> advanceProviderStatus(String id, String nextStatus) async {
    const transitions = {'accepted': 'en_route', 'en_route': 'arrived'};
    await _firestore.runTransaction((transaction) async {
      final reference = _requests.doc(id);
      final request = await transaction.get(reference);
      final data = request.data();
      if (!request.exists || data?['providerId'] != _userId) {
        throw StateError('This job is not assigned to this provider.');
      }
      final currentStatus = data?['status'] as String?;
      if (transitions[currentStatus] != nextStatus) {
        throw StateError('Invalid request status transition.');
      }
      transaction.update(reference, {
        'status': nextStatus,
        '${nextStatus}At': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> completeProviderJob(String id, int finalCost) async {
    if (finalCost < 0) {
      throw ArgumentError.value(
        finalCost,
        'finalCost',
        'Must not be negative.',
      );
    }
    await _firestore.runTransaction((transaction) async {
      final reference = _requests.doc(id);
      final profileReference = _firestore.collection('users').doc(_userId);
      final request = await transaction.get(reference);
      final profile = await transaction.get(profileReference);
      final data = request.data();
      if (!request.exists || data?['providerId'] != _userId) {
        throw StateError('This job is not assigned to this provider.');
      }
      if (data?['status'] != 'arrived') {
        throw StateError('The provider must arrive before completing the job.');
      }
      transaction.update(reference, {
        'status': 'completed',
        'finalCost': finalCost,
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (profile.data()?['activeRequestId'] == id) {
        transaction.update(profileReference, {
          'activeRequestId': FieldValue.delete(),
          'activeJobStartedAt': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<void> cancelRequest(String id) async {
    await _firestore.runTransaction((transaction) async {
      final reference = _requests.doc(id);
      final request = await transaction.get(reference);
      final data = request.data();
      if (!request.exists || data?['driverId'] != _userId) {
        throw StateError('Only the request driver can cancel this request.');
      }
      final status = data?['status'] as String?;
      if (status == 'completed' || status == 'cancelled') {
        throw StateError('This request can no longer be cancelled.');
      }
      transaction.update(reference, {
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> submitDriverRating(String id, int rating) async {
    if (rating < 1 || rating > 5) {
      throw ArgumentError.value(rating, 'rating', 'Must be between 1 and 5.');
    }
    await _firestore.runTransaction((transaction) async {
      final reference = _requests.doc(id);
      final request = await transaction.get(reference);
      final data = request.data();
      if (!request.exists || data?['driverId'] != _userId) {
        throw StateError('Only the request driver can submit a rating.');
      }
      if (data?['status'] != 'completed') {
        throw StateError('Only completed requests can be rated.');
      }
      transaction.update(reference, {
        'driverRating': rating,
        'ratedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchMessages(String requestId) =>
      _requests
          .doc(requestId)
          .collection('messages')
          .orderBy('createdAt')
          .snapshots();

  Future<void> sendMessage(String requestId, String text) async {
    final value = text.trim();
    if (value.isEmpty) return;
    await _requests.doc(requestId).collection('messages').add({
      'senderId': _userId,
      'text': value,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> sendChatPhoto(String requestId, String imageData) async {
    if (imageData.isEmpty) return;
    await _requests.doc(requestId).collection('messages').add({
      'senderId': _userId,
      'text': '',
      'imageData': imageData,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markChatSeen(String requestId) async {
    final profile = await _firestore.collection('users').doc(_userId).get();
    final role = profile.data()?['role'] as String?;
    final field = role == 'provider'
        ? 'providerMessagesSeenAt'
        : 'driverMessagesSeenAt';
    await _requests.doc(requestId).update({
      field: FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateProviderLocation(
    String requestId, {
    required double latitude,
    required double longitude,
  }) => _requests.doc(requestId).update({
    'providerLatitude': latitude,
    'providerLongitude': longitude,
    'providerLocationUpdatedAt': FieldValue.serverTimestamp(),
  });

  Future<void> updateProviderDocumentation(
    String requestId, {
    required String serviceNotes,
    required List<String> servicePhotoData,
  }) async {
    if (serviceNotes.length > 500 || servicePhotoData.length > 3) {
      throw ArgumentError('Service documentation is too large.');
    }
    final reference = _requests.doc(requestId);
    final request = await reference.get();
    final data = request.data();
    if (!request.exists || data?['providerId'] != _userId) {
      throw StateError('This job is not assigned to this provider.');
    }
    if (!const ['accepted', 'en_route', 'arrived'].contains(data?['status'])) {
      throw StateError(
        'Documentation can only be updated during an active job.',
      );
    }
    await reference.update({
      'serviceNotes': serviceNotes.trim(),
      'servicePhotoData': servicePhotoData,
      'documentationUpdatedAt': FieldValue.serverTimestamp(),
    });
  }
}
