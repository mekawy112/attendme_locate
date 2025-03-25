import 'package:flutter/material.dart';

import 'category_card.dart';

class NavBar extends StatelessWidget {
  const NavBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
              currentAccountPicture: CircleAvatar(
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/WhatsApp Image 2025-01-22 at 04.26.49_084e8ce0.jpg',
                    height: 90,
                    width: 90,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              accountName: const Text('Nourhan Magdy'),
              accountEmail: const Text('Nourmagdy@gmail.com')),

          const Divider(),
          const CategoryCard(), // الفئات الأصلية
        ],
      ),
    );
  }
}
