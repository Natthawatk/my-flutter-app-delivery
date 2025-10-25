import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screen/welcome_screen.dart';
import 'screen/login_screen.dart';
import 'screen/register_user.dart';
import 'screen/user_dashboard.dart';
import 'screen/rider_dashboard.dart';
import 'screen/rider_jobs.dart';

import 'screen/profile.dart';
import 'screen/new_delivery.dart';
import 'screen/deliveries.dart';
import 'screen/track_package.dart';
import 'screen/addresses.dart';
import 'screen/select_location_map.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    print('Warning: Could not load .env file: $e');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DeliverEase',
      home: const WelcomePage(),
      routes: {
        '/welcome': (context) => const WelcomePage(),
        '/auth': (context) => const LoginPage(),
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterUser(),
        '/user_dashboard': (context) => const UserDashboard(),
        '/rider_dashboard': (context) => const RiderDashboardScreen(),
        '/rider_jobs': (context) => const RiderJobsScreen(),
        '/user': (context) => const UserDashboard(),
        '/rider': (context) => const RiderDashboardScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/delivery/new': (context) => const NewDelivery(),
        '/deliveries': (context) => const DeliveriesScreen(),
        '/track': (context) => const TrackPackageScreen(),
        '/addresses': (context) => const AddressesScreen(),
        '/select_location': (context) => const SelectLocationMapScreen(),
      },
    );
  }
}


