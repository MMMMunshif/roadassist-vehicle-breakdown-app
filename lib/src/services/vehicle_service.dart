import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/vehicle.dart';

class VehicleService {
  final _db = FirebaseFirestore.instance;
  String get _uid =>
      FirebaseAuth.instance.currentUser?.uid ??
      (throw StateError('Sign in to manage your vehicles.'));
  DocumentReference<Map<String, dynamic>> get _owner =>
      _db.collection('users').doc(_uid);
  CollectionReference<Map<String, dynamic>> get _vehicles =>
      _owner.collection('vehicles');
  Future<Vehicle?> loadDefault() async {
    final owner = await _owner.get();
    final id = owner.data()?['defaultVehicleId'] as String?;
    if (id == null || id.isEmpty) return null;
    final document = await _vehicles.doc(id).get();
    if (!document.exists || document.data()?['archived'] != false) return null;
    return Vehicle.fromJson(document.id, document.data()!);
  }

  Stream<List<Vehicle>> watchVehicles() => _vehicles
      .where('archived', isEqualTo: false)
      .snapshots()
      .map(
        (s) =>
            s.docs.map((d) => Vehicle.fromJson(d.id, d.data())).toList()
              ..sort((a, b) => a.label.compareTo(b.label)),
      );

  Stream<List<Vehicle>> watchArchivedVehicles() => _vehicles
      .where('archived', isEqualTo: true)
      .snapshots()
      .map(
        (s) =>
            s.docs.map((d) => Vehicle.fromJson(d.id, d.data())).toList()
              ..sort((a, b) => a.label.compareTo(b.label)),
      );

  Future<void> save(Vehicle vehicle) async {
    if (vehicle.label.length > 50) {
      throw ArgumentError(
        'Make and model together must fit within 50 characters including the year.',
      );
    }
    final ref = vehicle.id.isEmpty
        ? _vehicles.doc()
        : _vehicles.doc(vehicle.id);
    await ref.set({
      ...vehicle.toJson(),
      'archived': false,
      'updatedAt': FieldValue.serverTimestamp(),
      if (vehicle.id.isEmpty) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setDefault(String id) => _db.runTransaction((tx) async {
    final vehicle = await tx.get(_vehicles.doc(id));
    if (!vehicle.exists || vehicle.data()?['archived'] != false) {
      throw StateError('This vehicle is no longer available.');
    }
    tx.update(_owner, {'defaultVehicleId': id});
  });
  Future<void> archive(String id) => _db.runTransaction((tx) async {
    final owner = await tx.get(_owner);
    tx.update(_vehicles.doc(id), {
      'archived': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (owner.data()?['defaultVehicleId'] == id) {
      tx.update(_owner, {'defaultVehicleId': null});
    }
  });

  Future<void> restore(String id) => _db.runTransaction((tx) async {
    final ref = _vehicles.doc(id);
    final vehicle = await tx.get(ref);
    if (!vehicle.exists || vehicle.data()?['archived'] != true) {
      throw StateError('This archived vehicle is no longer available.');
    }

    tx.update(ref, {
      'archived': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  });
}
