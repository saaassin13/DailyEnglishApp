import 'package:flutter/material.dart';
import 'wordbook_selection_screen.dart';
import 'check_in_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;
  
  const MainScreen({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _selectedIndex;
  
  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  final List<Widget> _screens = [
    const WordbookSelectionScreen(),
    const CheckInScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.book),
            label: '词库',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: '签到',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: '个人中心',
          ),
        ],
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}

