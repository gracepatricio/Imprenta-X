import 'dart:convert';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import 'notification_service.dart';

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

  Future<String> generateAdminId() async {
    final id = await _getNextCounter('admin');
    return 'ADM-${id.toString().padLeft(3, '0')}';
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
  _createAuthUserSecondary({
    required String password,
    required String rolePrefix, // 'adm' or 'emp'
    required String roleId, // e.g. 'ADM-001' or 'EMP-003'
  }) async {
    // Format: adm001@imprenta.sys or emp003@imprenta.sys
    final numericPart = roleId.split('-').last; // '001'
    final localPart = '$rolePrefix${numericPart.toLowerCase()}';
    final placeholderEmail = '$localPart@imprenta.sys';

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
        // Check if admin freed this email — if so, remove the old Firebase
        // Auth account and retry so the user gets a clean fresh account.
        final freed = await _tryFreeEmail(email);
        if (freed) {
          try {
            final cred = await _auth.createUserWithEmailAndPassword(
              email: email,
              password: password,
            );
            await cred.user!.updateDisplayName(fullName);
            await cred.user!.sendEmailVerification();
            return (user: cred.user, error: null);
          } on FirebaseAuthException catch (e2) {
            return (user: null, error: e2.message ?? 'Registration failed.');
          }
        }
        return (
          user: null,
          error: 'An account with this email already exists. Please sign in.',
        );
      }
      return (user: null, error: e.message);
    } catch (e) {
      return (user: null, error: 'Registration failed: $e');
    }
  }

  /// Returns true if the Firebase Auth account for [email] was freed via the
  /// Cloud Function (i.e. the admin had deleted that account).
  Future<bool> _tryFreeEmail(String email) async {
    try {
      final fnRes = await http.post(
        Uri.parse('https://freeemail-xjzzjpgy5a-uc.a.run.app'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );
      return fnRes.statusCode == 200;
    } catch (_) {
      return false;
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

    // Generate the ID first so we can use it in the placeholder email
    final employeeId = await generateEmployeeId();

    final authResult = await _createAuthUserSecondary(
      password: tempPassword,
      rolePrefix: 'emp',
      roleId: employeeId,
    );
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

  Future<({String? uid, String? password, String? adminId, String? error})>
  createAdminAccount() async {
    final tempPassword = generateTemporaryPassword();

    // Generate the ID first so we can use it in the placeholder email
    final adminId = await generateAdminId();

    final authResult = await _createAuthUserSecondary(
      password: tempPassword,
      rolePrefix: 'adm',
      roleId: adminId,
    );
    if (authResult.error != null) {
      return (
        uid: null,
        password: null,
        adminId: null,
        error: authResult.error,
      );
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
        'admin_id': adminId,
        'user_role': 'admin',
        'must_change_password': true,
        'temp_password': tempPassword,
        'date_created': FieldValue.serverTimestamp(),
        'is_deleted': false,
        'is_disabled': false,
      });
      return (uid: uid, password: tempPassword, adminId: adminId, error: null);
    } catch (e) {
      return (
        uid: null,
        password: null,
        adminId: null,
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

      // Legacy soft-deleted accounts (before hard-delete was introduced)
      if (data['is_deleted'] == true) {
        await _auth.signOut();
        return 'This account no longer exists. Please contact support.';
      }

      if (data['is_disabled'] == true) {
        await _auth.signOut();
        return 'This account was disabled by the admin.';
      }

      if (data['must_change_password'] == true) {
        return 'must_change_password:${data['user_role']}';
      }

      // Admin/employee accounts require a verified real email before they
      // can access the app. If email is still null (user bailed out of the
      // AddEmailScreen), block login and send them back to verify.
      final role = data['user_role'] as String? ?? '';
      if (role == 'admin' || role == 'employee') {
        final email = data['email'] as String?;
        if (email == null || email.isEmpty) {
          return 'needs_email_verification:$role';
        }
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

      // ── Placeholder email shortcut ──────────────────────────────────────
      // adm001@imprenta.sys or emp001@imprenta.sys — this IS the Firebase
      // Auth email, so return it directly without any Firestore lookups.
      if (identifier.endsWith('@imprenta.sys')) {
        print('DEBUG: placeholder email — returning as-is');
        return identifier;
      }
      // ───────────────────────────────────────────────────────────────────

      try {
        final indexDoc = await _firestore
            .collection('email_index')
            .doc(identifier)
            .get();
        if (indexDoc.exists) {
          final status = indexDoc.data()?['status'] as String? ?? '';
          if (status != 'active') {
            print(
              'DEBUG: email_index status="$status" for "$identifier" — rejecting',
            );
            return null;
          }
          final uid = indexDoc.data()?['uid'] as String?;
          if (uid != null) {
            final userDoc = await _firestore.collection('User').doc(uid).get();
            final role = userDoc.data()?['user_role'] as String? ?? '';
            if (role == 'employee' || role == 'admin') {
              final authEmail = await _getPlaceholderEmail(uid);
              print('DEBUG: email_index → employee/admin authEmail=$authEmail');
              return authEmail ?? identifier;
            }
            return identifier;
          }
        }
      } catch (e) {
        print('DEBUG: email_index check threw: $e');
      }
      try {
        final snap = await _firestore
            .collection('User')
            .where('email', isEqualTo: identifier)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) {
          final data = snap.docs.first.data();
          final role = data['user_role'] as String? ?? '';
          if (role == 'employee' || role == 'admin') {
            final uid = snap.docs.first.id;
            final authEmail = await _getPlaceholderEmail(uid);
            print('DEBUG: User query → employee/admin authEmail=$authEmail');
            return authEmail ?? identifier;
          }
          print('DEBUG: User query → customer, returning identifier');
          return identifier;
        }
      } catch (e) {
        print('DEBUG: User query threw: $e');
      }
      print('DEBUG: no User doc found for "$identifier" — returning null');
      return null;
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

    if (identifier.startsWith('ADM-')) {
      print('DEBUG: ADM branch');
      try {
        final snap = await _firestore
            .collection('User')
            .where('admin_id', isEqualTo: identifier)
            .limit(1)
            .get();
        print('DEBUG: ADM query returned ${snap.docs.length} docs');
        if (snap.docs.isEmpty) return null;

        final uid = snap.docs.first.id;
        print('DEBUG: ADM uid=$uid');

        final authEmail = await _getPlaceholderEmail(uid);
        print('DEBUG: ADM authEmail from AuthIndex=$authEmail');
        return authEmail;
      } catch (e) {
        print('DEBUG: ADM branch threw: $e');
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

  /// Changes the current user's password.
  ///
  /// For admin/employee accounts on first login, [currentPassword] may be
  /// empty — in that case the temp password is fetched from Firestore and
  /// used to reauthenticate automatically.
  Future<String?> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'Not logged in.';

      // Determine the password to use for reauthentication.
      String reAuthPassword = currentPassword;

      if (reAuthPassword.isEmpty) {
        // No current password provided — fetch the stored temp password
        // from Firestore (set by admin when the account was created).
        final doc = await _firestore.collection('User').doc(user.uid).get();
        final tempPassword = doc.data()?['temp_password'] as String?;
        if (tempPassword == null || tempPassword.isEmpty) {
          return 'Unable to verify your identity. Please sign out and sign back in.';
        }
        reAuthPassword = tempPassword;
      }

      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: reAuthPassword,
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
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        return 'Could not verify your identity. Please sign out and sign back in.';
      }
      return e.message ?? 'Failed to change password.';
    } catch (e) {
      return 'Failed to change password: $e';
    }
  }

  Future<String?> addEmail(String newEmail, {String? currentPassword}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'Not logged in.';

      final existing = await _firestore
          .collection('User')
          .where('email', isEqualTo: newEmail)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty && existing.docs.first.id != user.uid) {
        return 'That email is already associated with another account.';
      }

      final currentEmail = user.email ?? '';
      final hasPlaceholder = currentEmail.endsWith('@imprenta.sys');

      if (!hasPlaceholder) {
        await user.verifyBeforeUpdateEmail(newEmail);
        return 'verification_sent';
      }

      // Check if there is already a pending verification for this exact email.
      // This happens on resend — the Firebase Auth account was already created
      // on the first attempt but the user hasn't clicked the link yet.
      final pendingDoc = await _firestore
          .collection('PendingEmailVerification')
          .doc(user.uid)
          .get();

      if (pendingDoc.exists) {
        final pendingData = pendingDoc.data()!;
        final pendingEmail = pendingData['new_email'] as String?;
        final pendingPassword = pendingData['password'] as String?;
        final pendingNewUid = pendingData['new_uid'] as String?;

        if (pendingEmail == newEmail &&
            pendingPassword != null &&
            pendingNewUid != null) {
          // Reuse the existing Firebase Auth account — just resend the
          // verification email to it without creating a new one.
          FirebaseApp? secondaryApp;
          try {
            secondaryApp = await _createSecondaryApp();
            final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
            final cred = await secondaryAuth.signInWithEmailAndPassword(
              email: newEmail,
              password: pendingPassword,
            );
            await cred.user!.sendEmailVerification();
            await secondaryAuth.signOut();
            return 'migration_sent';
          } finally {
            await secondaryApp?.delete();
          }
        }

        // Different email — delete the old pending account before creating new.
        if (pendingEmail != null &&
            pendingPassword != null &&
            pendingEmail != newEmail) {
          FirebaseApp? cleanupApp;
          try {
            cleanupApp = await _createSecondaryApp();
            final cleanupAuth = FirebaseAuth.instanceFor(app: cleanupApp);
            final cred = await cleanupAuth.signInWithEmailAndPassword(
              email: pendingEmail,
              password: pendingPassword,
            );
            await cred.user!.delete();
            await cleanupAuth.signOut();
          } catch (_) {
            // Best-effort cleanup — proceed regardless.
          } finally {
            await cleanupApp?.delete();
          }
          await _firestore
              .collection('PendingEmailVerification')
              .doc(user.uid)
              .delete();
        }
      }

      FirebaseApp? secondaryApp;
      try {
        secondaryApp = await _createSecondaryApp();
        final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

        final passwordToUse =
            (currentPassword != null && currentPassword.isNotEmpty)
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
        return 'migration_sent';
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

  Future<String?> checkAndFinalizeMigration(String oldUid) async {
    try {
      final pendingDoc = await _firestore
          .collection('PendingEmailVerification')
          .doc(oldUid)
          .get();
      if (!pendingDoc.exists) return null;

      final data = pendingDoc.data()!;
      final newEmail = data['new_email'] as String;
      final newUid = data['new_uid'] as String;
      final password = data['password'] as String;

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

      final oldDoc = await _firestore.collection('User').doc(oldUid).get();
      Map<String, dynamic>? userData;
      if (oldDoc.exists) {
        userData = Map<String, dynamic>.from(oldDoc.data()!);
        userData['email'] = newEmail;
      }

      await _auth.signInWithEmailAndPassword(
        email: newEmail,
        password: password,
      );

      if (userData != null) {
        await _firestore.collection('User').doc(newUid).set(userData);
        await _firestore.collection('AuthIndex').doc(newUid).set({
          'placeholder_email': newEmail,
        });
      }

      try {
        final batch = _firestore.batch();
        batch.delete(_firestore.collection('User').doc(oldUid));
        batch.delete(_firestore.collection('AuthIndex').doc(oldUid));
        batch.delete(
          _firestore.collection('PendingEmailVerification').doc(oldUid),
        );
        await batch.commit();
      } catch (cleanupErr) {
        print('DEBUG checkAndFinalizeMigration cleanup error: $cleanupErr');
      }

      return newEmail;
    } catch (e) {
      print('DEBUG checkAndFinalizeMigration error: $e');
      return null;
    }
  }

  Future<String?> finalizeEmailUpdate(String newEmail) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'Not logged in.';
      await user.reload();
      await _firestore.collection('User').doc(user.uid).update({
        'email': newEmail,
      });
      await _firestore.collection('AuthIndex').doc(user.uid).update({
        'placeholder_email': newEmail,
      });
      return 'success';
    } catch (e) {
      return 'Failed to save email: $e';
    }
  }

  // ── User management (admin) ───────────────────────────────────────────────

  // Deletes a list of document references in Firestore-safe chunks of 400.
  Future<void> _deleteDocsBatch(List<DocumentReference> refs) async {
    const chunkSize = 400;
    for (var i = 0; i < refs.length; i += chunkSize) {
      final end = (i + chunkSize).clamp(0, refs.length);
      final b = _firestore.batch();
      for (final r in refs.sublist(i, end)) {
        b.delete(r);
      }
      await b.commit();
    }
  }

  Future<String?> deleteUser(String uid) async {
    try {
      // ── 1. Read user data ────────────────────────────────────────────────
      final userDoc = await _firestore.collection('User').doc(uid).get();
      final email = userDoc.data()?['email'] as String?;

      // ── 2. Free the email so it can be reused for registration ───────────
      if (email != null && email.isNotEmpty) {
        await _firestore.collection('FreedEmails').doc(email).set({
          'uid': uid,
          'freed_at': FieldValue.serverTimestamp(),
        });
      }

      // ── 3. Delete Firebase Auth account via Cloud Function ───────────────
      // Silently continues if the account doesn't exist (e.g. seed accounts).
      try {
        final idToken = await _auth.currentUser?.getIdToken();
        if (idToken != null) {
          await http.post(
            Uri.parse('https://deleteauthuser-xjzzjpgy5a-uc.a.run.app'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode({'uid': uid}),
          );
        }
      } catch (_) {}

      // ── 4. Separate completed orders from non-completed ──────────────────
      // Completed orders stay in the system with their customer name and
      // contribute to sales totals. Everything else is removed.
      final ordersSnap = await _firestore
          .collection('Orders')
          .where('customer_uid', isEqualTo: uid)
          .get();

      final toDelete = <String>[]; // order IDs to delete
      final toKeep = <String>[]; // completed order IDs

      for (final doc in ordersSnap.docs) {
        final status = doc.data()['status'] as String? ?? '';
        if (status == 'completed') {
          toKeep.add(doc.id);
        } else {
          toDelete.add(doc.id);
        }
      }

      // ── 5. Delete non-completed orders ───────────────────────────────────
      if (toDelete.isNotEmpty) {
        await _deleteDocsBatch(
          toDelete
              .map((id) => _firestore.collection('Orders').doc(id))
              .toList(),
        );
      }

      // ── 6. Delete invoices for non-completed orders ──────────────────────
      // invoice_id is stored directly on each order document.
      final invoiceIdsToDelete = ordersSnap.docs
          .where((d) => toDelete.contains(d.id))
          .map((d) => d.data()['invoice_id'] as String?)
          .where((id) => id != null && id.isNotEmpty)
          .cast<String>()
          .toList();

      if (invoiceIdsToDelete.isNotEmpty) {
        await _deleteDocsBatch(
          invoiceIdsToDelete
              .map((id) => _firestore.collection('Invoices').doc(id))
              .toList(),
        );
      }

      // ── 7. Delete Order_Queue entries for non-completed orders ────────────
      try {
        final queueSnap = await _firestore
            .collection('Order_Queue')
            .where('customer_uid', isEqualTo: uid)
            .get();
        final queueRefs = queueSnap.docs
            .where((d) {
              final orderId = d.data()['order_id'] as String? ?? '';
              return toDelete.contains(orderId);
            })
            .map((d) => d.reference)
            .toList();
        if (queueRefs.isNotEmpty) await _deleteDocsBatch(queueRefs);
      } catch (_) {}

      // ── 8. Delete OrderReviews ───────────────────────────────────────────
      try {
        final reviewsSnap = await _firestore
            .collection('OrderReviews')
            .where('customer_uid', isEqualTo: uid)
            .get();
        if (reviewsSnap.docs.isNotEmpty) {
          await _deleteDocsBatch(
            reviewsSnap.docs.map((d) => d.reference).toList(),
          );
        }
      } catch (_) {}

      // ── 9. Delete Cart ───────────────────────────────────────────────────
      await _firestore.collection('Carts').doc(uid).delete().catchError((_) {});

      // ── 10. Delete Messages thread + subcollection ───────────────────────
      try {
        final chatDocId = 'chat_$uid';
        final msgsSnap = await _firestore
            .collection('Messages')
            .doc(chatDocId)
            .collection('chat')
            .get();
        if (msgsSnap.docs.isNotEmpty) {
          await _deleteDocsBatch(
            msgsSnap.docs.map((d) => d.reference).toList(),
          );
        }
        await _firestore
            .collection('Messages')
            .doc(chatDocId)
            .delete()
            .catchError((_) {});
      } catch (_) {}

      // ── 11. Delete Conversations entry ───────────────────────────────────
      try {
        final convoSnap = await _firestore
            .collection('Conversations')
            .where('customer_id', isEqualTo: uid)
            .get();
        if (convoSnap.docs.isNotEmpty) {
          await _deleteDocsBatch(
            convoSnap.docs.map((d) => d.reference).toList(),
          );
        }
      } catch (_) {}

      // ── 12. Delete core profile documents ────────────────────────────────
      final coreBatch = _firestore.batch();
      coreBatch.delete(_firestore.collection('User').doc(uid));
      coreBatch.delete(_firestore.collection('AuthIndex').doc(uid));
      await coreBatch.commit();

      // ── 13. Cleanup auxiliary collections ────────────────────────────────
      await Future.wait([
        if (email != null && email.isNotEmpty)
          _firestore
              .collection('email_index')
              .doc(email)
              .delete()
              .catchError((_) {}),
        _firestore
            .collection('PendingEmailVerification')
            .doc(uid)
            .delete()
            .catchError((_) {}),
      ]);

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
        'admin_id': null,
      });
      return 'success';
    } catch (_) {
      return 'Failed';
    }
  }

  Future<String?> promoteToAdmin(String uid) async {
    try {
      final adminId = await generateAdminId();
      await _firestore.collection('User').doc(uid).update({
        'user_role': 'admin',
        'admin_id': adminId,
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
        'admin_id': null,
      });
      return 'success';
    } catch (_) {
      return 'Failed';
    }
  }

  // ── Sign out ──────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await NotificationService.clearToken();
    await _auth.signOut();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

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

  // create customers manually code
  Future<({String? uid, String? customerId, String? error})>
  createCustomerAccountManually({
    required String email,
    required String fullName,
    required String password,
  }) async {
    FirebaseApp? secondaryApp;
    try {
      secondaryApp = await _createSecondaryApp();
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      UserCredential cred;
      try {
        cred = await secondaryAuth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          return (
            uid: null,
            customerId: null,
            error: 'That email is already registered.',
          );
        }
        return (
          uid: null,
          customerId: null,
          error: e.message ?? 'Failed to create account.',
        );
      }

      final uid = cred.user!.uid;
      await secondaryAuth.signOut();

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

      return (uid: uid, customerId: customerId, error: null);
    } catch (e) {
      return (uid: null, customerId: null, error: 'Failed: $e');
    } finally {
      await secondaryApp?.delete();
    }
  }
}
