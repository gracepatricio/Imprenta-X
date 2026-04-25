import 'package:flutter/material.dart';

class CustomerHomepage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Customer Homepage')),
      body: Center(
        child: Text('Welcome, Customer!', style: TextStyle(fontSize: 18)),
      ),
    );
  }
}
