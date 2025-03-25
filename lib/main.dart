import 'package:attend_me_locate/screens/course_detail_screen.dart';
import 'package:attend_me_locate/screens/splash_screen.dart';
import 'package:attend_me_locate/services/auth_services.dart';
import 'package:attend_me_locate/widgets/category_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // Add this import
import 'package:http/http.dart' as http;
import 'dart:convert';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      minTextAdapt: true,
      designSize: const Size(360, 690), // Set the design size
      builder: (context, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          home: const SplashScreen(),
          routes: {
            // Remove the CourseDetailScreen from routes since it requires parameters
          },
          onGenerateRoute: (settings) {
            if (settings.name == '/courseDetail') {
              final args = settings.arguments as Map<String, dynamic>;
              return MaterialPageRoute(
                builder: (context) => CourseDetailScreen(
                  course: args['course'],
                  studentData: args['studentData'],
                ),
              );
            }
            return null;
          },
        );
      },
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Map<String, dynamic>? _userData;
  final _authService = AuthService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userData = await _authService.getCurrentUser();
      setState(() {
        _userData = userData;
        _isLoading = false;
      });
      print('User data fetched: $_userData');
    } catch (e) {
      print('Error fetching user data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[800],
      appBar: AppBar(
        title: const Text('Attendance'),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue.shade800,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.person,
                      size: 40,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _userData != null ? _userData!['name'] : 'Guest User',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    _userData != null ? _userData!['email'] : 'Please log in',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            // Pass the user data to CategoryCard
            CategoryCard(
              userData: _userData,
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : const Placeholder(), // Replace with AttendanceScreen() after defining or importing it
    );
  }
}

class DataList extends StatefulWidget {
  const DataList({super.key});

  @override
  _DataListState createState() => _DataListState();
}

class _DataListState extends State<DataList> {
  List data = [];

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  fetchData() async {
    final response = await http.get(Uri.parse('http://localhost:5000/data'));
    if (response.statusCode == 200) {
      setState(() {
        data = json.decode(response.body);
      });
    } else {
      throw Exception('Failed to load data');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: data.length,
      itemBuilder: (context, index) {
        return ListTile(
          title: Text(data[index]['columnName']),
        );
      },
    );
  }
}
