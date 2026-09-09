// ============================================================
// firestore_service.dart
// ------------------------------------------------------------
// Wraps all Cloud Firestore reads/writes in one class.
// Firestore structure used in this project (Day 1):
//
//   users/{uid}              -> AppUser profile (role, links)
//   locations/{childUid}     -> latest GPS point for a child
//     (we overwrite the same doc every 10s to keep it simple;
//      a "history" subcollection can be added in Sprint 2)
//   sos_alerts/{autoId}      -> one document per emergency alert
//
// This class is intentionally simple/beginner-friendly for
// Sprint 1. It can be refactored into repositories later.
// ============================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/location_model.dart';
import '../models/sos_model.dart';
import '../models/safe_place_model.dart';
import '../models/geofence_event_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ---------------- USERS ----------------

  // Save a new user profile after signup (role = parent/child).
  Future<void> createUserProfile(AppUser user) async {
    await _db.collection('users').doc(user.uid).set(user.toMap());
  }

  // Fetch a user's profile (used to check their role after login).
  Future<AppUser?> getUserProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromMap(doc.data()!);
  }

  // Real-time version of getUserProfile(). The Parent Dashboard uses
  // this so that "linkedUid" updates live the moment a child links to
  // this parent, instead of relying on the profile snapshot captured
  // once at login (which would otherwise stay null until re-login).
  Stream<AppUser?> streamUserProfile(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return AppUser.fromMap(doc.data()!);
    });
  }

  // --------------------------------------------------------
  // PARENT-CHILD LINKING (simple version for Day 1)
  // A parent generates a 6-digit "linkCode". The child enters
  // that code, and we store each other's uid as "linkedUid".
  // --------------------------------------------------------
  Future<void> linkChildToParent({
    required String childUid,
    required String linkCode,
  }) async {
    // Find the parent who owns this code.
    final query = await _db
        .collection('users')
        .where('linkCode', isEqualTo: linkCode)
        .where('role', isEqualTo: 'parent')
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw Exception('Invalid link code. Please check with your parent.');
    }

    final parentDoc = query.docs.first;
    final parentUid = parentDoc.id;

    // Update the child's record with the parent's uid.
    await _db.collection('users').doc(childUid).update({'linkedUid': parentUid});
    // Update the parent's record with the child's uid.
    await _db.collection('users').doc(parentUid).update({'linkedUid': childUid});
  }

  // ---------------- LOCATIONS ----------------

  // Called every 10 seconds by LocationService to update the
  // child's live position. We use set() with the childUid as
  // the document ID so each child only ever has ONE current doc.
  Future<void> updateLocation(LocationModel location) async {
    await _db
        .collection('locations')
        .doc(location.childUid)
        .set(location.toMap());
  }

  // Real-time stream the Parent Dashboard listens to, so the
  // map marker moves automatically whenever the child's
  // location document changes.
  Stream<LocationModel?> streamChildLocation(String childUid) {
    return _db.collection('locations').doc(childUid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return LocationModel.fromMap(doc.data()!);
    });
  }

  // ---------------- SOS ALERTS ----------------

  // Called when the child taps the big SOS button.
  Future<void> createSosAlert(SosAlert alert) async {
    await _db.collection('sos_alerts').add(alert.toMap());
  }

  // Parent listens to this stream to get notified instantly
  // whenever a new "active" SOS alert is created for their child.
  Stream<List<SosAlert>> streamActiveAlerts(String childUid) {
    return _db
        .collection('sos_alerts')
        .where('childUid', isEqualTo: childUid)
        .where('status', isEqualTo: 'active')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => SosAlert.fromMap(d.data())).toList());
  }

  // Stream past emergency / SOS alerts for the History screen.
  Stream<List<SosAlert>> streamAlertHistory(String childUid) {
    return _db
        .collection('sos_alerts')
        .where('childUid', isEqualTo: childUid)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => SosAlert.fromMap(d.data())).toList());
  }

  // ---------------- SAFETY REQUESTS ("I'M SAFE") ----------------

  // Called when child taps "🟢 I'm Safe" button.
  Future<void> createSafetyRequest({
    required String childUid,
    required String childName,
  }) async {
    await _db.collection('safety_requests').doc(childUid).set({
      'childUid': childUid,
      'childName': childName,
      'status': 'pending', // "pending", "approved", "rejected", or "cancelled"
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // Listen to safety request state for a child in real time.
  Stream<Map<String, dynamic>?> streamSafetyRequest(String childUid) {
    return _db.collection('safety_requests').doc(childUid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return doc.data();
    });
  }

  // Parent approves child's "I'm Safe" request -> pauses location.
  Future<void> approveSafetyRequest(String childUid) async {
    await _db.collection('safety_requests').doc(childUid).update({
      'status': 'approved',
      'resolvedAt': DateTime.now().toIso8601String(),
    });
  }

  // Parent rejects child's request ("Keep Tracking") -> keeps location active.
  Future<void> rejectSafetyRequest(String childUid) async {
    await _db.collection('safety_requests').doc(childUid).update({
      'status': 'rejected',
      'resolvedAt': DateTime.now().toIso8601String(),
    });
  }

  // Reset or cancel safety request (e.g. when SOS is triggered).
  Future<void> resetSafetyRequest(String childUid) async {
    await _db.collection('safety_requests').doc(childUid).delete();
  }

  // ---------------- SAFE PLACES ----------------

  // Create or update a SafePlace document in Firestore.
  Future<void> saveSafePlace(SafePlace place) async {
    await _db.collection('safe_places').doc(place.id).set(place.toMap());
  }

  // Delete a SafePlace document.
  Future<void> deleteSafePlace(String placeId) async {
    await _db.collection('safe_places').doc(placeId).delete();
  }

  // Stream all SafePlaces created by a specific guardian.
  Stream<List<SafePlace>> streamGuardianSafePlaces(String guardianUid) {
    return _db
        .collection('safe_places')
        .where('guardianUid', isEqualTo: guardianUid)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => SafePlace.fromMap(d.data(), docId: d.id))
            .toList());
  }

  // Stream active SafePlaces that apply to a monitored entity or all entities under this guardian.
  Stream<List<SafePlace>> streamActiveSafePlaces({
    required String guardianUid,
    String? monitoredUid,
  }) {
    return _db
        .collection('safe_places')
        .where('guardianUid', isEqualTo: guardianUid)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => SafePlace.fromMap(d.data(), docId: d.id))
            .where((p) => p.monitoredUid == null || p.monitoredUid == monitoredUid)
            .toList());
  }

  // ---------------- GEOFENCE EVENTS ----------------

  // Store a confirmed geofence event (ENTER / EXIT / UNEXPECTED_EXIT).
  Future<void> recordGeofenceEvent(GeofenceEvent event) async {
    await _db.collection('geofence_events').doc(event.id).set(event.toMap());
  }

  // Stream geofence events for a monitored entity, newest first.
  Stream<List<GeofenceEvent>> streamGeofenceEvents(String monitoredUid) {
    return _db
        .collection('geofence_events')
        .where('monitoredUid', isEqualTo: monitoredUid)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => GeofenceEvent.fromMap(d.data(), docId: d.id))
            .toList());
  }
}
