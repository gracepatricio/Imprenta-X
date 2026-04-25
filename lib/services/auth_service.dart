import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 🔥 SAFE COUNTER INIT
  Future<int> _getNextCounter(String type) async {
    DocumentReference counterRef = _firestore.collection('Counters').doc(type);
    return _firestore.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(counterRef);
      int lastId = 0;
      if (snapshot.exists && snapshot.data() != null) {
        lastId = (snapshot['last_id'] ?? 0) as int;
      } else {
        transaction.set(counterRef, {'last_id': 0});
      }
      int newId = lastId + 1;
      transaction.set(counterRef, {'last_id': newId});
      return newId;
    });
  }

  // 🔥 CUSTOMER ID
  Future<String> generateCustomerId() async {
    int newId = await _getNextCounter('customer');
    String formatted = newId.toString().padLeft(3, '0');
    return "CUS-$formatted";
  }

  // 🔥 EMPLOYEE ID
  Future<String> generateEmployeeId() async {
    int newId = await _getNextCounter('employee');
    String formatted = newId.toString().padLeft(3, '0');
    return "EMP-$formatted";
  }

  // 🔥 REGISTER USER (default: customer)
  Future<String?> register(
    String email,
    String password,
    String fullName,
  ) async {
    try {
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);
      String uid = userCredential.user!.uid;
      String customerId = await generateCustomerId();
      await _firestore.collection('User').doc(uid).set({
        'user_id': uid,
        'customer_id': customerId,
        'employee_id': null,
        'full_name': fullName,
        'email': email,
        'user_role': 'customer',
        'date_created': FieldValue.serverTimestamp(),
      });
      return "success";
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return "Registration failed: $e";
    }
  }

  // 🔥 LOGIN
  Future<String?> login(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      String uid = userCredential.user!.uid;
      DocumentSnapshot userDoc = await _firestore
          .collection('User')
          .doc(uid)
          .get();
      if (!userDoc.exists) {
        return "User record not found";
      }
      return userDoc['user_role'];
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return "Login failed";
    }
  }

  // 🔥 PROMOTE TO EMPLOYEE
  // Generates a new employee_id, nulls out customer_id
  Future<String?> promoteToEmployee(String uid) async {
    try {
      String empId = await generateEmployeeId();
      await _firestore.collection('User').doc(uid).update({
        'user_role': 'employee',
        'employee_id': empId,
        'customer_id': null,
      });
      return "success";
    } catch (e) {
      print("promoteToEmployee failed: $e");
      return "Failed";
    }
  }

  // 🔥 PROMOTE TO ADMIN
  // No admin_id in ERD — both customer_id and employee_id become null
  Future<String?> promoteToAdmin(String uid) async {
    try {
      await _firestore.collection('User').doc(uid).update({
        'user_role': 'admin',
        'customer_id': null,
        'employee_id': null,
      });
      return "success";
    } catch (e) {
      print("promoteToAdmin failed: $e");
      return "Failed";
    }
  }

  // 🔥 DEMOTE TO CUSTOMER
  // Generates a new customer_id, nulls out employee_id
  Future<String?> demoteToCustomer(String uid) async {
    try {
      String customerId = await generateCustomerId();
      await _firestore.collection('User').doc(uid).update({
        'user_role': 'customer',
        'customer_id': customerId,
        'employee_id': null,
      });
      return "success";
    } catch (e) {
      print("demoteToCustomer failed: $e");
      return "Failed";
    }
  }
}
