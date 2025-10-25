import 'package:flutter/material.dart';

class RiderBottomNav extends StatelessWidget {
  final int currentIndex;
  final bool hasActiveJob;
  
  const RiderBottomNav({
    Key? key,
    required this.currentIndex,
    this.hasActiveJob = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) {
          if (hasActiveJob && index != 0) {
            // Show message if trying to navigate away from dashboard with active job
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please complete your current job first')),
            );
            return;
          }
          
          switch (index) {
            case 0:
              if (currentIndex != 0) {
                Navigator.pushReplacementNamed(context, '/rider_dashboard');
              }
              break;
            case 1:
              if (currentIndex != 1) {
                Navigator.pushReplacementNamed(context, '/rider_jobs');
              }
              break;
            case 2:
              if (currentIndex != 2) {
                Navigator.pushReplacementNamed(context, '/profile');
              }
              break;
          }
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey[600],
        selectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.normal,
        ),
        elevation: 0,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.work_outline),
            activeIcon: Icon(Icons.work),
            label: 'Jobs',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}