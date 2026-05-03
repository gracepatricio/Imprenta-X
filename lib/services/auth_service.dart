import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── ID generation ─────────────────────────────────────────────────────────

  Future<int> _getNextCounter(String type) async {
    final ref = _firestore.collection('Counters').doc(type);
    return _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final last = snap.exists ? ((snap.data()?['last_id'] ?? 0) as int) : 0;
      final next = last + 1;
      tx.set(ref, {'last_id': next});
      return next;
    });
  }

  Future<String> generateCustomerId() async {
    final id = await _getNextCounter('customer');
    return 'CUS-${id.toString().padLeft(3, '0')}';
  }

  Future<String> generateEmployeeId() async {
    final id = await _getNextCounter('employee');
    return 'EMP-${id.toString().padLeft(3, '0')}';
  }

  // ── Register ──────────────────────────────────────────────────────────────

  /// Creates a Firebase Auth account and sends a verification email.
  /// The Firestore record is NOT created here — call [finalizeRegistration]
  /// after the user clicks the verification link.
  Future<({User? user, String? error})> createAccount(
      String email, String password, String fullName) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await cred.user!.updateDisplayName(fullName);
      await cred.user!.sendEmailVerification();
      return (user: cred.user, error: null);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        final msg = await _handleExistingEmail(email);
        return (user: null, error: msg);
      }
      return (user: null, error: e.message);
    } catch (e) {
      return (user: null, error: 'Registration failed: $e');
    }
  }

  /// Creates the Firestore user record after email verification is confirmed.
  Future<String?> finalizeRegistration(
      String uid, String email, String fullName) async {
    try {
      final customerId = await generateCustomerId();
      await _firestore.collection('User').doc(uid).set({
        'email':        email,
        'full_name':    fullName,
        'customer_id':  customerId,
        'employee_id':  null,
        'user_role':    'customer',
        'date_created': FieldValue.serverTimestamp(),
      });
      return 'success';
    } catch (e) {
      return 'Failed to complete registration: $e';
    }
  }

  Future<String?> _handleExistingEmail(String email) async {
    try {
      final indexDoc = await _firestore
          .collection('email_index')
          .doc(email)
          .get();

      if (indexDoc.exists) {
        final status = indexDoc.data()?['status'] as String? ?? '';
        if (status == 'deleted' || status == 'reclaiming') {
          _firestore
              .collection('email_index')
              .doc(email)
              .set({'status': 'reclaiming'})
              .catchError((_) {});
          try { await _auth.sendPasswordResetEmail(email: email); } catch (_) {}
          return 'account_reclaim_needed';
        }
      }
    } catch (_) {}

    return 'An account with this email already exists. Please sign in.';
  }

  // ── Login ─────────────────────────────────────────────────────────────────

  Future<String?> login(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = cred.user!.uid;
      final doc = await _firestore.collection('User').doc(uid).get();

      // No Firestore doc → hard-deleted account reclaimed via password reset.
      if (!doc.exists) {
        return await _restoreAsCustomer(uid, email, cred.user);
      }

      // Soft-deleted account.
      if (doc.data()?['is_deleted'] == true) {
        // Accept BOTH 'reclaiming' (unauthenticated write succeeded) and
        // 'deleted' (write failed but admin flag is still there) so that a
        // permission-denied on the write never blocks the reclaim flow.
        bool canRestore = false;
        try {
          final indexDoc = await _firestore
              .collection('email_index')
              .doc(email)
              .get();
          final status = indexDoc.data()?['status'] as String? ?? '';
          // Only restore if the user went through the OTP registration flow
          // ('reclaiming'). 'deleted' means admin-blocked — keep them out.
          canRestore = status == 'reclaiming';
        } catch (_) {}

        if (canRestore) {
          _firestore
              .collection('email_index')
              .doc(email)
              .delete()
              .catchError((_) {});
          return await _restoreAsCustomer(uid, email, cred.user,
              existingDocRef: doc.reference);
        }

        await _auth.signOut();
        return 'This account has been deactivated. Please contact support.';
      }

      return doc['user_role'] as String?;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'Login failed';
    }
  }

  Future<String> _restoreAsCustomer(
      String uid, String email, User? firebaseUser,
      {DocumentReference? existingDocRef}) async {
    final customerId = await generateCustomerId();
    final name = firebaseUser?.displayName ??
        firebaseUser?.email?.split('@')[0] ??
        'Customer';
    final data = {
      'email':        email,
      'full_name':    name,
      'customer_id':  customerId,
      'employee_id':  null,
      'user_role':    'customer',
      'is_deleted':   false,
      'date_created': FieldValue.serverTimestamp(),
    };
    if (existingDocRef != null) {
      await existingDocRef.set(data);
    } else {
      await _firestore.collection('User').doc(uid).set(data);
    }
    return 'customer';
  }

  // ── Role management ───────────────────────────────────────────────────────

  Future<String?> promoteToEmployee(String uid) async {
    try {
      final empId = await generateEmployeeId();
      await _firestore.collection('User').doc(uid).update({
        'user_role':   'employee',
        'employee_id': empId,
        'customer_id': null,
      });
      return 'success';
    } catch (_) { return 'Failed'; }
  }

  Future<String?> promoteToAdmin(String uid) async {
    try {
      await _firestore.collection('User').doc(uid).update({
        'user_role':   'admin',
        'customer_id': null,
        'employee_id': null,
      });
      return 'success';
    } catch (_) { return 'Failed'; }
  }

  Future<String?> demoteToCustomer(String uid) async {
    try {
      final customerId = await generateCustomerId();
      await _firestore.collection('User').doc(uid).update({
        'user_role':   'customer',
        'customer_id': customerId,
        'employee_id': null,
      });
      return 'success';
    } catch (_) { return 'Failed'; }
  }
}
