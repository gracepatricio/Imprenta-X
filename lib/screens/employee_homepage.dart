import 'package:flutter/material.dart';

class EmployeeHomepage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Employee Homepage')),
      body: Center(
        child: Text('Welcome, Employee!', style: TextStyle(fontSize: 18)),
      ),
    );
  }
}
