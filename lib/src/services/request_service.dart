import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/request_draft.dart';
import '../models/repair_revision.dart';

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
    final settings =
        (await _firestore.collection('appSettings').doc('operations').get())
            .data();
    if (settings?['maintenance'] == true)
      throw StateError(
        'New assistance requests are temporarily paused. ${settings?['notice'] ?? ''}',
      );
    final enabled = settings?['enabledServices'] as List?;
    if (enabled != null &&
        draft.issues.any((issue) => !enabled.contains(issue)))
      throw StateError(
        'One selected service is currently unavailable. Choose another service.',
      );
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
    final profileReference = _firestore.collection('users').doc(_userId);
    await _firestore.runTransaction((transaction) async {
      final profile = await transaction.get(profileReference);
      final activeRequestId = profile.data()?['activeRequestId'] as String?;
      if (activeRequestId != null && activeRequestId.isNotEmpty) {
        final activeRequest = await transaction.get(
          _requests.doc(activeRequestId),
        );
        if (activeRequest.exists &&
            const [
              'searching',
              'accepted',
              'en_route',
              'arrived',
            ].contains(activeRequest.data()?['status'])) {
          throw StateError('Complete or cancel your active request first.');
        }
      }
      transaction.set(document, {
        'driverId': _userId,
        'driverName': _auth.currentUser?.displayName ?? 'Driver',
        'driverPhone': profile.data()?['phone'] ?? '',
        'providerId': null,
        'preferredProviderId': draft.preferredProviderId,
        'preferredProviderName': draft.provider,
        'rejectedBy': <String>[],
        'status': 'searching',
        'workflowVersion': 2,
        'issue': draft.primaryIssue,
        'issues': draft.issues,
        'vehicleType': draft.vehicleType,
        if (draft.vehicleId != null) 'vehicleId': draft.vehicleId,
        if (draft.vehicleSnapshot != null)
          'vehicleSnapshot': draft.vehicleSnapshot,
        'modelYear': draft.modelYear,
        'registration': draft.registration,
        'description': draft.description,
        'notes': draft.notes,
        'priority': draft.priority,
        'partsPreference': draft.partsPreference,
        'vehiclePhotoUrls': draft.vehiclePhotoUrls,
        'photoAnnotations': draft.photoAnnotations
            .map((annotation) => annotation.toJson())
            .toList(),
        'locationLabel': draft.location,
        'landmark': draft.landmark,
        'locationAccuracyMeters': draft.locationAccuracyMeters,
        'latitude': draft.latitude,
        'longitude': draft.longitude,
        'serviceFee': 0,
        'dispatchFee': 0,
        'estimatedCost': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(profileReference, {
        'activeRequestId': document.id,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
    return document.id;
  }

  Future<void> updateSearchingRequest(String id, RequestDraft draft) async {
    await _firestore.runTransaction((transaction) async {
      final reference = _requests.doc(id);
      final request = await transaction.get(reference);
      final data = request.data();
      if (!request.exists || data?['driverId'] != _userId) {
        throw StateError('Only the request driver can edit this request.');
      }
      if (data?['status'] != 'searching' || data?['providerId'] != null) {
        throw StateError('The provider has already accepted this request.');
      }
      transaction.update(reference, {
        'description': draft.description,
        'notes': draft.notes,
        'vehiclePhotoUrls': draft.vehiclePhotoUrls,
        'photoAnnotations': draft.photoAnnotations
            .map((annotation) => annotation.toJson())
            .toList(),
        'locationLabel': draft.location,
        'landmark': draft.landmark,
        'locationAccuracyMeters': draft.locationAccuracyMeters,
        'latitude': draft.latitude,
        'longitude': draft.longitude,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
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
    String quoteType = 'direct',
  }) async {
    if (serviceFee < 0 || travelFee < 0 || extraFee < 0) {
      throw ArgumentError('Quote amounts must not be negative.');
    }
    final quotedTotal = serviceFee + travelFee + extraFee;
    final current = await _requests.doc(id).get();
    if (current.data()?['workflowVersion'] == 2) {
      final profile = await _firestore.collection('users').doc(_userId).get();
      await _requests.doc(id).collection('quotes').doc(_userId).set({
        'providerId': _userId,
        'quoteType': quoteType,
        'providerName': profile.data()?['displayName'] ?? 'Service Provider',
        'providerPhone': profile.data()?['phone'] ?? '',
        'serviceFee': serviceFee,
        'travelFee': travelFee,
        'extraFee': extraFee,
        'total': quotedTotal,
        'notes': quoteNotes.trim(),
        'providerDistanceKm': providerDistanceKm,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return;
    }
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
      final directoryReference = _firestore
          .collection('providerDirectory')
          .doc(_userId);
      final directory = await transaction.get(directoryReference);
      if ((directory.data()?['activeRequestId'] as String? ?? '').isNotEmpty) {
        throw StateError('Complete your active job before accepting another.');
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
      if (directory.exists)
        transaction.update(directoryReference, {'activeRequestId': id});
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchQuotes(String id) =>
      _requests.doc(id).collection('quotes').snapshots();

  Future<void> selectQuote(String id, String quoteId) async {
    await _firestore.runTransaction((tx) async {
      final ref = _requests.doc(id);
      final request = await tx.get(ref);
      final quote = await tx.get(ref.collection('quotes').doc(quoteId));
      final data = request.data();
      if (data?['driverId'] != _userId ||
          data?['status'] != 'searching' ||
          !quote.exists) {
        throw StateError('This request or offer is no longer available.');
      }
      final offer = quote.data()!;
      final providerRef = _firestore
          .collection('providerDirectory')
          .doc(quoteId);
      final provider = await tx.get(providerRef);
      if (!provider.exists ||
          provider.data()?['online'] != true ||
          (provider.data()?['activeRequestId'] as String? ?? '').isNotEmpty) {
        throw StateError('This provider is unavailable. Choose another offer.');
      }
      tx.update(ref, {
        'providerId': quoteId,
        'providerName': offer['providerName'],
        'providerPhone': offer['providerPhone'],
        'status': 'accepted',
        'selectedQuoteId': quoteId,
        'approvedQuoteType': offer['quoteType'] ?? 'direct',
        'serviceFee': offer['serviceFee'],
        'dispatchFee': offer['travelFee'],
        'extraFee': offer['extraFee'],
        'estimatedCost': offer['total'],
        'quoteNotes': offer['notes'],
        'providerDistanceKm': offer['providerDistanceKm'],
        'quoteApprovedAt': FieldValue.serverTimestamp(),
        'acceptedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      tx.update(providerRef, {'activeRequestId': id});
    });
  }

  Future<void> proposeRepair(String id, Map<String, dynamic> quote) async {
    final ref = _requests.doc(id);
    final revision = ref.collection('repairQuotes').doc();
    final service = quote['serviceFee'] as int;
    final travel = quote['travelFee'] as int;
    final extra = quote['extraFee'] as int;
    if (service < 0 ||
        travel < 0 ||
        extra < 0 ||
        (quote['quoteNotes'] as String).trim().isEmpty) {
      throw ArgumentError(
        'Enter non-negative fees and explain the diagnosis and work.',
      );
    }
    await _firestore.runTransaction((tx) async {
      final request = await tx.get(ref);
      final data = request.data();
      if (data?['providerId'] != _userId ||
          data?['status'] != 'arrived' ||
          data?['workflowVersion'] != 2) {
        throw StateError('Arrive before submitting a repair quote.');
      }
      if (data!['pendingRepairId'] != null) {
        throw StateError(
          'Wait for the driver to approve or reject the pending change.',
        );
      }
      final photos = List<String>.from(
        quote['evidencePhotoData'] as List? ?? [],
      );
      final reason = (quote['changeReason'] as String? ?? '').trim();
      final invalid = validateRepairRevision(
        previousTotal: (data['estimatedCost'] as num).toInt(),
        total: service + travel + extra,
        reason: reason,
        photos: photos,
      );
      if (invalid != null) throw ArgumentError(invalid);
      tx.set(revision, {
        'changeReason': reason,
        'evidencePhotoData': photos,
        'providerId': _userId,
        'previousTotal': data['estimatedCost'],
        'serviceFee': service,
        'travelFee': travel,
        'extraFee': extra,
        'total': service + travel + extra,
        'diagnosisAndWork': quote['quoteNotes'],
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.update(ref, {
        'pendingRepairId': revision.id,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> decideRepair(String id, String revisionId, bool approve) async {
    final ref = _requests.doc(id);
    await _firestore.runTransaction((tx) async {
      final request = await tx.get(ref);
      final revision = await tx.get(
        ref.collection('repairQuotes').doc(revisionId),
      );
      final data = request.data();
      if (data?['driverId'] != _userId ||
          data?['status'] != 'arrived' ||
          data?['pendingRepairId'] != revisionId ||
          !revision.exists) {
        throw StateError('This repair quote is no longer available.');
      }
      final quote = revision.data()!;
      tx.set(ref.collection('repairDecisions').doc(revisionId), {
        'driverId': _userId,
        'decision': approve ? 'approved' : 'rejected',
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.update(ref, {
        'pendingRepairId': null,
        'lastRepairDecisionId': revisionId,
        'lastRepairDecision': approve ? 'approved' : 'rejected',
        'repairDecisionAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        if (approve) ...{
          'approvedRepairId': revisionId,
          'estimatedCost': quote['total'],
          'serviceFee': quote['serviceFee'],
          'dispatchFee': quote['travelFee'],
          'extraFee': quote['extraFee'],
          'providerDiagnosis': quote['diagnosisAndWork'],
        },
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
      final directoryReference = _firestore
          .collection('providerDirectory')
          .doc(_userId);
      final directory = await transaction.get(directoryReference);
      if (data?['workflowVersion'] == 2 &&
          (data?['pendingRepairId'] != null ||
              (data?['approvedQuoteType'] == 'inspection' &&
                  data?['approvedRepairId'] == null))) {
        throw StateError(
          'The driver must approve the repair before completion.',
        );
      }
      if (data?['workflowVersion'] == 2 &&
          finalCost > (data?['estimatedCost'] as num).toInt()) {
        throw StateError(
          'The final charge cannot exceed the driver-approved offer.',
        );
      }
      transaction.update(reference, {
        'status': 'completed',
        'finalCost': finalCost,
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (directory.data()?['activeRequestId'] == id) {
        transaction.update(directoryReference, {'activeRequestId': null});
      }
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
      final profileReference = _firestore.collection('users').doc(_userId);
      final request = await transaction.get(reference);
      final profile = await transaction.get(profileReference);
      final data = request.data();
      if (!request.exists || data?['driverId'] != _userId) {
        throw StateError('Only the request driver can cancel this request.');
      }
      final status = data?['status'] as String?;
      if (status == 'completed' || status == 'cancelled') {
        throw StateError('This request can no longer be cancelled.');
      }
      final providerId = data?['providerId'] as String?;
      final directoryReference = providerId == null
          ? null
          : _firestore.collection('providerDirectory').doc(providerId);
      final directory = directoryReference == null
          ? null
          : await transaction.get(directoryReference);
      transaction.update(reference, {
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (directoryReference != null &&
          directory?.data()?['activeRequestId'] == id) {
        transaction.update(directoryReference, {'activeRequestId': null});
      }
      if (profile.data()?['activeRequestId'] == id) {
        transaction.update(profileReference, {
          'activeRequestId': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<void> recordPayment(String id, String method) async {
    if (!const ['cash', 'external'].contains(method))
      throw ArgumentError('Unsupported payment method.');
    final ref = _requests.doc(id);
    await _firestore.runTransaction((tx) async {
      final snapshot = await tx.get(ref);
      final data = snapshot.data();
      if (data?['status'] != 'completed')
        throw StateError('Complete service before recording payment.');
      if (data?['driverId'] == _userId &&
          data?['driverReportedPayment'] != true) {
        tx.update(ref, {
          'driverReportedPayment': true,
          'paymentMethod': method,
          'paymentReportedAt': FieldValue.serverTimestamp(),
        });
      } else if (data?['providerId'] == _userId &&
          data?['driverReportedPayment'] == true &&
          data?['paymentMethod'] == method) {
        tx.update(ref, {
          'providerConfirmedPayment': true,
          'paymentConfirmedAt': FieldValue.serverTimestamp(),
        });
      } else {
        throw StateError('This payment cannot be changed.');
      }
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
