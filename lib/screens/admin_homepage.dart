import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'app_navbar.dart';
import 'admin_account_dashboard.dart';

class AdminHomepage extends StatelessWidget {
  const AdminHomepage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: AppTheme.backgroundDecoration,
        child: Column(
          children: [
            AppNavBar(
              activeItem: "Home",
              onTap: (item) {
                if (item == "Account") {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AdminAccountDashboard(),
                    ),
                  );
                }
                // Wire other nav items here
              },
            ),
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "IMPRENTA INC.",
                      style: TextStyle(
                        fontSize: 46,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.gold,
                        letterSpacing: 4,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      "Specializes in manufacturing of customized product printing.",
                      style: TextStyle(fontSize: 15, color: Colors.white60),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
