import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── Password generator ────────────────────────────────────────────────────

  static String generateTemporaryPassword() {
    const adjectives = [
      'Amber',
      'Brisk',
      'Coral',
      'Dusky',
      'Ember',
      'Flair',
      'Glint',
      'Haven',
      'Ivory',
      'Jade',
      'Karma',
      'Lunar',
      'Mango',
      'Noble',
      'Opal',
      'Prism',
      'Quest',
      'Raven',
      'Solar',
      'Terra',
      'Ultra',
      'Vivid',
      'Wheat',
      'Xenon',
      'Yield',
      'Zonal',
    ];
    const symbols = ['@', '#', '!', r'$', '%', '&'];
    final rng = Random.secure();
    final word = adjectives[rng.nextInt(adjectives.length)];
    final num = 100 + rng.nextInt(900);
    final sym = symbols[rng.nextInt(symbols.length)];
    return '$word$num$sym';
  }

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

  // ── Secondary Firebase App ────────────────────────────────────────────────

  Future<FirebaseApp> _createSecondaryApp() async {
    final appName = 'secondary_${DateTime.now().millisecondsSinceEpoch}';
    return Firebase.initializeApp(
      name: appName,
      options: Firebase.app().options,
    );
  }

  Future<({String? uid, String? placeholderEmail, String? error})>
  _createAuthUserSecondary({required String password}) async {
    final placeholderEmail =
        '_${DateTime.now().millisecondsSinceEpoch}@imprenta.internal';
    FirebaseApp? secondaryApp;
    try {
      secondaryApp = await _createSecondaryApp();
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final cred = await secondaryAuth.createUserWithEmailAndPassword(
        email: placeholderEmail,
        password: password,
      );
      final uid = cred.user!.uid;
      await secondaryAuth.signOut();
      return (uid: uid, placeholderEmail: placeholderEmail, error: null);
    } on FirebaseAuthException catch (e) {
      return (
      uid: null,
      placeholderEmail: null,
      error: e.message ?? 'Failed to create auth user.',
      );
    } catch (e) {
      return (
      uid: null,
      placeholderEmail: null,
      error: 'Failed to create auth user: $e',
      );
    } finally {
      await secondaryApp?.delete();
    }
  }

  // ── Register (customer self-registration) ─────────────────────────────────

  Future<({User? user, String? error})> createAccount(
      String email,
      String password,
      String fullName,
      ) async {
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

  Future<String?> finalizeRegistration(
      String uid,
      String email,
      String fullName,
      ) async {
    try {
      final customerId = await generateCustomerId();
      await _firestore.collection('User').doc(uid).set({
        'email': email,
        'full_name': fullName,
        'customer_id': customerId,
        'employee_id': null,
        'user_role': 'customer',
        'must_change_password': false,
        'temp_password': null,
        'date_created': FieldValue.serverTimestamp(),
        'is_deleted': false,
        'is_disabled': false,
      });
      return 'success';
    } catch (e) {
      return 'Failed to complete registration: $e';
    }
  }

  // ── Admin-created accounts ────────────────────────────────────────────────

  Future<({String? password, String? uid, String? employeeId, String? error})>
  createEmployeeAccount() async {
    final tempPassword = generateTemporaryPassword();
    final authResult = await _createAuthUserSecondary(password: tempPassword);
    if (authResult.error != null) {
      return (
      password: null,
      uid: null,
      employeeId: null,
      error: authResult.error,
      );
    }

    final uid = authResult.uid!;
    final placeholderEmail = authResult.placeholderEmail!;

    try {
      final employeeId = await generateEmployeeId();
      await _firestore.collection('AuthIndex').doc(uid).set({
        'placeholder_email': placeholderEmail,
      });
      await _firestore.collection('User').doc(uid).set({
        'email': null,
        'full_name': 'New Employee',
        'customer_id': null,
        'employee_id': employeeId,
        'user_role': 'employee',
        'must_change_password': true,
        'temp_password': tempPassword,
        'date_created': FieldValue.serverTimestamp(),
        'is_deleted': false,
        'is_disabled': false,
      });
      return (
      password: tempPassword,
      uid: uid,
      employeeId: employeeId,
      error: null,
      );
    } catch (e) {
      return (
      password: null,
      uid: null,
      employeeId: null,
      error: 'Account created in Auth but Firestore write failed: $e',
      );
    }
  }

  Future<({String? uid, String? password, String? error})>
  createAdminAccount() async {
    final tempPassword = generateTemporaryPassword();
    final authResult = await _createAuthUserSecondary(password: tempPassword);
    if (authResult.error != null) {
      return (uid: null, password: null, error: authResult.error);
    }

    final uid = authResult.uid!;
    final placeholderEmail = authResult.placeholderEmail!;

    try {
      await _firestore.collection('AuthIndex').doc(uid).set({
        'placeholder_email': placeholderEmail,
      });
      await _firestore.collection('User').doc(uid).set({
        'email': null,
        'full_name': 'New Admin',
        'customer_id': null,
        'employee_id': null,
        'user_role': 'admin',
        'must_change_password': true,
        'temp_password': tempPassword,
        'date_created': FieldValue.serverTimestamp(),
        'is_deleted': false,
        'is_disabled': false,
      });
      return (uid: uid, password: tempPassword, error: null);
    } catch (e) {
      return (
      uid: null,
      password: null,
      error: 'Account created in Auth but Firestore write failed: $e',
      );
    }
  }

  // ── Login ─────────────────────────────────────────────────────────────────

  Future<String?> login(String identifier, String password) async {
    print('DEBUG login() called with identifier="$identifier"');
    try {
      final emailToUse = await _resolveToAuthEmail(identifier);
      print('DEBUG login() resolved email="$emailToUse"');

      if (emailToUse == null) {
        return 'No account found with that ID.';
      }

      final cred = await _auth.signInWithEmailAndPassword(
        email: emailToUse,
        password: password,
      );
      final uid = cred.user!.uid;
      print('DEBUG login() signed in uid="$uid"');

      final doc = await _firestore.collection('User').doc(uid).get();
      print('DEBUG login() User doc exists=${doc.exists}');

      if (!doc.exists) {
        return await _restoreAsCustomer(uid, emailToUse, cred.user);
      }

      final data = doc.data()!;
      print(
        'DEBUG login() role=${data['user_role']} is_disabled=${data['is_disabled']} must_change=${data['must_change_password']}',
      );

      if (data['is_disabled'] == true) {
        await _auth.signOut();
        return 'This account has been disabled. Please contact an administrator.';
      }

      if (data['is_deleted'] == true) {
        bool canRestore = false;
        try {
          final indexDoc = await _firestore
              .collection('email_index')
              .doc(emailToUse)
              .get();
          canRestore = (indexDoc.data()?['status'] as String?) == 'reclaiming';
        } catch (_) {}

        if (canRestore) {
          _firestore
              .collection('email_index')
              .doc(emailToUse)
              .delete()
              .catchError((_) {});
          return await _restoreAsCustomer(
            uid,
            emailToUse,
            cred.user,
            existingDocRef: doc.reference,
          );
        }

        await _auth.signOut();
        return 'This account has been deactivated. Please contact support.';
      }

      if (data['must_change_password'] == true) {
        return 'must_change_password:${data['user_role']}';
      }

      return data['user_role'] as String?;
    } on FirebaseAuthException catch (e) {
      print('DEBUG login() FirebaseAuthException: ${e.code} ${e.message}');
      return e.message;
    } catch (e) {
      print('DEBUG login() unexpected error: $e');
      return 'Login failed';
    }
  }

  // ── Resolve identifier to Firebase Auth email ─────────────────────────────

  Future<String?> _resolveToAuthEmail(String identifier) async {
    print('DEBUG _resolveToAuthEmail: identifier="$identifier"');

    if (identifier.contains('@')) {
      print('DEBUG: plain email branch');
      try {
        final snap = await _firestore
            .collection('User')
            .where('email', isEqualTo: identifier)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) {
          final role = snap.docs.first.data()['user_role'] as String? ?? '';
          if (role == 'employee' || role == 'admin') {
            final uid = snap.docs.first.id;
            final authEmail = await _getPlaceholderEmail(uid);
            print('DEBUG: email → employee/admin authEmail=$authEmail');
            return authEmail ?? identifier;
          }
        }
      } catch (e) {
        print('DEBUG: email branch threw: $e');
      }
      return identifier;
    }

    if (identifier.startsWith('CUS-')) {
      print('DEBUG: CUS branch');
      try {
        final snap = await _firestore
            .collection('User')
            .where('customer_id', isEqualTo: identifier)
            .limit(1)
            .get();
        print('DEBUG: CUS query returned ${snap.docs.length} docs');
        if (snap.docs.isEmpty) return null;
        final email = snap.docs.first.data()['email'] as String?;
        print('DEBUG: CUS email=$email');
        return (email != null && email.isNotEmpty) ? email : null;
      } catch (e) {
        print('DEBUG: CUS branch threw: $e');
        return null;
      }
    }

    if (identifier.startsWith('EMP-')) {
      print('DEBUG: EMP branch');
      try {
        final snap = await _firestore
            .collection('User')
            .where('employee_id', isEqualTo: identifier)
            .limit(1)
            .get();
        print('DEBUG: EMP query returned ${snap.docs.length} docs');
        if (snap.docs.isEmpty) return null;

        final uid = snap.docs.first.id;
        print('DEBUG: EMP uid=$uid');

        final authEmail = await _getPlaceholderEmail(uid);
        print('DEBUG: EMP authEmail from AuthIndex=$authEmail');
        return authEmail;
      } catch (e) {
        print('DEBUG: EMP branch threw: $e');
        return null;
      }
    }

    if (identifier.length >= 20) {
      print('DEBUG: UID branch, length=${identifier.length}');
      try {
        final doc = await _firestore.collection('User').doc(identifier).get();
        print('DEBUG: UID doc exists=${doc.exists}');
        if (!doc.exists) return null;

        final authEmail = await _getPlaceholderEmail(identifier);
        print('DEBUG: UID authEmail from AuthIndex=$authEmail');
        return authEmail;
      } catch (e) {
        print('DEBUG: UID branch threw: $e');
        return null;
      }
    }

    print('DEBUG: no branch matched for "$identifier"');
    return null;
  }

  Future<String?> _getPlaceholderEmail(String uid) async {
    print('DEBUG _getPlaceholderEmail uid=$uid');
    try {
      final doc = await _firestore.collection('AuthIndex').doc(uid).get();
      print(
        'DEBUG _getPlaceholderEmail doc exists=${doc.exists} data=${doc.data()}',
      );
      return doc.data()?['placeholder_email'] as String?;
    } catch (e) {
      print('DEBUG _getPlaceholderEmail threw: $e');
      return null;
    }
  }

  // ── Password management ───────────────────────────────────────────────────

  Future<String?> changePassword(
      String currentPassword,
      String newPassword,
      ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'Not logged in.';
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPassword);
      await _firestore.collection('User').doc(user.uid).update({
        'must_change_password': false,
        'temp_password': null,
      });
      print('DEBUG changePassword() success for uid=${user.uid}');
      return 'success';
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') return 'Current password is incorrect.';
      return e.message ?? 'Failed to change password.';
    } catch (e) {
      return 'Failed to change password: $e';
    }
  }

  /// Sets up email verification for an employee/admin account.
  ///
  /// For placeholder accounts (@imprenta.internal):
  ///   Creates a secondary Firebase Auth account with the real email,
  ///   sends a standard email verification to it, stores the pending
  ///   migration in PendingEmailVerification, and migrates the User doc
  ///   once the employee clicks the link.
  ///   [currentPassword] is required so the new account gets the same
  ///   password — the employee keeps logging in with the same credentials.
  ///
  /// For accounts already on a real email:
  ///   Uses verifyBeforeUpdateEmail (works because the account is verified).
  ///
  /// Returns 'verification_sent' or an error string.
  Future<String?> addEmail(String newEmail, {String? currentPassword}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'Not logged in.';

      // Reject if another Firestore User doc already owns this email.
      final existing = await _firestore
          .collection('User')
          .where('email', isEqualTo: newEmail)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty && existing.docs.first.id != user.uid) {
        return 'That email is already associated with another account.';
      }

      final currentEmail = user.email ?? '';
      final hasPlaceholder = currentEmail.endsWith('@imprenta.internal');

      if (!hasPlaceholder) {
        // Already on a real verified email — standard flow works fine.
        await user.verifyBeforeUpdateEmail(newEmail);
        return 'verification_sent';
      }

      // Placeholder account: create a secondary account with the real email
      // so we can send a proper verification email without the enumeration-
      // protection restriction that blocks verifyBeforeUpdateEmail here.
      FirebaseApp? secondaryApp;
      try {
        secondaryApp = await _createSecondaryApp();
        final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

        // Use the employee's actual password for the new account so they
        // keep logging in with the same credentials after migration.
        final passwordToUse = (currentPassword != null && currentPassword.isNotEmpty)
            ? currentPassword
            : generateTemporaryPassword();

        UserCredential secondaryCred;
        try {
          secondaryCred = await secondaryAuth.createUserWithEmailAndPassword(
            email: newEmail,
            password: passwordToUse,
          );
        } on FirebaseAuthException catch (e) {
          if (e.code == 'email-already-in-use') {
            return 'That email is already registered. Use a different email.';
          }
          rethrow;
        }

        final newUid = secondaryCred.user!.uid;
        await secondaryCred.user!.sendEmailVerification();

        // Store the pending migration record.
        await _firestore
            .collection('PendingEmailVerification')
            .doc(user.uid)
            .set({
          'new_email': newEmail,
          'new_uid': newUid,
          'password': passwordToUse,
          'old_uid': user.uid,
          'created_at': FieldValue.serverTimestamp(),
        });

        await secondaryAuth.signOut();
        return 'migration_sent'; // distinct from verifyBeforeUpdateEmail path
      } finally {
        await secondaryApp?.delete();
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        return 'That email is already registered. Use a different email.';
      }
      return e.message ?? 'Failed to send verification email.';
    } catch (e) {
      return 'Failed to send verification email: $e';
    }
  }

  /// Polls to check if the pending email verification is complete.
  /// If verified, migrates the Firestore User doc to the new uid,
  /// signs the user into the new account, and cleans up.
  /// Returns the verified new email on success, null if not yet done.
  Future<String?> checkAndFinalizeMigration(String oldUid) async {
    try {
      final pendingDoc = await _firestore
          .collection('PendingEmailVerification')
          .doc(oldUid)
          .get();
      if (!pendingDoc.exists) return null;

      final data     = pendingDoc.data()!;
      final newEmail = data['new_email'] as String;
      final newUid   = data['new_uid']   as String;
      final password = data['password']  as String;

      // Check verification status via secondary app.
      FirebaseApp? secondaryApp;
      bool verified = false;
      try {
        secondaryApp = await _createSecondaryApp();
        final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
        final cred = await secondaryAuth.signInWithEmailAndPassword(
          email: newEmail,
          password: password,
        );
        await cred.user!.reload();
        verified = cred.user!.emailVerified;
        await secondaryAuth.signOut();
      } finally {
        await secondaryApp?.delete();
      }

      if (!verified) return null;

      // Read the old User doc BEFORE signing out (we still have old-uid auth).
      final oldDoc = await _firestore.collection('User').doc(oldUid).get();
      Map<String, dynamic>? userData;
      if (oldDoc.exists) {
        userData = Map<String, dynamic>.from(oldDoc.data()!);
        userData['email'] = newEmail;
      }

      // Sign the main app into the NEW account first.
      // Firebase Security Rules require request.auth.uid == newUid to write
      // User/{newUid} and AuthIndex/{newUid}, so we must be authenticated as
      // the new user before those writes — doing it as the old user causes the
      // "permission-denied" error seen in checkAndFinalizeMigration.
      await _auth.signInWithEmailAndPassword(
        email: newEmail,
        password: password,
      );

      // Now authenticated as newUid — all Firestore writes below will succeed.
      if (userData != null) {
        await _firestore.collection('User').doc(newUid).set(userData);
        // AuthIndex for the new account: store the real email so that
        // _resolveToAuthEmail can look it up correctly for future logins.
        await _firestore.collection('AuthIndex').doc(newUid).set({
          'placeholder_email': newEmail,
        });
      }

      // Clean up old docs — these are deletions so the old UID's rules
      // (allow delete: request.auth.uid == oldUid) won't block us because
      // we are now signed in as newUid. Use a batch so it's atomic, and
      // wrap in try/catch so a rule miss on deletion never blocks the user.
      try {
        final batch = _firestore.batch();
        batch.delete(_firestore.collection('User').doc(oldUid));
        batch.delete(_firestore.collection('AuthIndex').doc(oldUid));
        batch.delete(
          _firestore.collection('PendingEmailVerification').doc(oldUid),
        );
        await batch.commit();
      } catch (cleanupErr) {
        // Non-fatal — the new account is fully usable even if old docs linger.
        print('DEBUG checkAndFinalizeMigration cleanup error: $cleanupErr');
      }

      return newEmail;
    } catch (e) {
      print('DEBUG checkAndFinalizeMigration error: $e');
      return null;
    }
  }

  /// Called after the user clicks the verification link.
  /// Updates both User doc and AuthIndex so login-by-ID still works.
  Future<String?> finalizeEmailUpdate(String newEmail) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'Not logged in.';
      await user.reload();
      await _firestore.collection('User').doc(user.uid).update({
        'email': newEmail,
      });
      // Keep AuthIndex in sync — _resolveToAuthEmail reads this to know
      // what email Firebase Auth currently has for this account.
      await _firestore.collection('AuthIndex').doc(user.uid).update({
        'placeholder_email': newEmail,
      });
      return 'success';
    } catch (e) {
      return 'Failed to save email: $e';
    }
  }

  // ── User management (admin) ───────────────────────────────────────────────

  Future<String?> deleteUser(String uid) async {
    try {
      await _firestore.collection('User').doc(uid).update({
        'is_deleted': true,
        'deleted_at': FieldValue.serverTimestamp(),
      });
      return 'success';
    } catch (e) {
      return 'Failed to delete user: $e';
    }
  }

  Future<String?> toggleDisableUser(String uid, bool disable) async {
    try {
      await _firestore.collection('User').doc(uid).update({
        'is_disabled': disable,
      });
      return 'success';
    } catch (e) {
      return 'Failed to ${disable ? 'disable' : 'enable'} user: $e';
    }
  }

  // ── Role management ───────────────────────────────────────────────────────

  Future<String?> promoteToEmployee(String uid) async {
    try {
      final empId = await generateEmployeeId();
      await _firestore.collection('User').doc(uid).update({
        'user_role': 'employee',
        'employee_id': empId,
        'customer_id': null,
      });
      return 'success';
    } catch (_) {
      return 'Failed';
    }
  }

  Future<String?> promoteToAdmin(String uid) async {
    try {
      await _firestore.collection('User').doc(uid).update({
        'user_role': 'admin',
        'customer_id': null,
        'employee_id': null,
      });
      return 'success';
    } catch (_) {
      return 'Failed';
    }
  }

  Future<String?> demoteToCustomer(String uid) async {
    try {
      final customerId = await generateCustomerId();
      await _firestore.collection('User').doc(uid).update({
        'user_role': 'customer',
        'customer_id': customerId,
        'employee_id': null,
      });
      return 'success';
    } catch (_) {
      return 'Failed';
    }
  }

  // ── Sign out ──────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await _auth.signOut();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

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
          try {
            await _auth.sendPasswordResetEmail(email: email);
          } catch (_) {}
          return 'account_reclaim_needed';
        }
      }
    } catch (_) {}
    return 'An account with this email already exists. Please sign in.';
  }

  Future<String> _restoreAsCustomer(
      String uid,
      String email,
      User? firebaseUser, {
        DocumentReference? existingDocRef,
      }) async {
    final customerId = await generateCustomerId();
    final name =
        firebaseUser?.displayName ??
            firebaseUser?.email?.split('@')[0] ??
            'Customer';
    final data = {
      'email': email,
      'full_name': name,
      'customer_id': customerId,
      'employee_id': null,
      'user_role': 'customer',
      'is_deleted': false,
      'is_disabled': false,
      'must_change_password': false,
      'temp_password': null,
      'date_created': FieldValue.serverTimestamp(),
    };
    if (existingDocRef != null) {
      await existingDocRef.set(data);
    } else {
      await _firestore.collection('User').doc(uid).set(data);
    }
    return 'customer';
  }
}