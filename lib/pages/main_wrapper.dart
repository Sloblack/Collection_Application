import 'package:flutter/material.dart';
import 'package:recollection_application/pages/history_screen.dart';
import 'package:recollection_application/pages/main_map_screen.dart';
import 'package:recollection_application/pages/profile_screen.dart';
import 'package:recollection_application/pages/scanner_screen.dart';

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {

  int _currentIndex = 0;

  final List<Widget> _pages = [
    MainMapScreen(),
    ScannerScreen(),
    HistoryScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        showUnselectedLabels: true,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        selectedLabelStyle: TextStyle(fontSize: 18),
        unselectedItemColor: Theme.of(context).colorScheme.onSurface,
        unselectedLabelStyle: TextStyle(fontSize: 14),
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label:  'Mapa',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner),
            label: 'Escáner',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Historial',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ]
      ),
    );
  }
}
