import 'package:flutter/material.dart';
//import 'package:locate_me/screens/face_rec_screen/HomeScreen.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';


import '../screens/doctor_dashboard.dart';
import '../screens/face_rec_screen/RegistrationScreen.dart';
import '../screens/student_courses_screen.dart';
import '../services/auth_services.dart';

class CategoryCard extends StatefulWidget {
  final Map<String, dynamic>? userData;
  
  const CategoryCard({
    super.key,
    this.userData,
  });

  @override
  State<CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<CategoryCard> {
  Map<String, dynamic>? _userData;
  final _authService = AuthService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _userData = widget.userData;
    if (_userData == null) {
      _fetchUserData();
    }
  }

  // Fetch user data if it's not provided
  Future<void> _fetchUserData() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      // First try to get from SharedPreferences directly
      final prefs = await SharedPreferences.getInstance();
      final storedUserData = prefs.getString('user_data');
      
      if (storedUserData != null) {
        setState(() {
          _userData = json.decode(storedUserData);
          _isLoading = false;
        });
        print('Loaded user data from SharedPreferences: $_userData');
        return;
      }
      
      // If not in SharedPreferences, try to get from auth service
      final userData = await _authService.getCurrentUser();
      
      setState(() {
        _userData = userData;
        _isLoading = false;
      });
      
      print('Fetched user data from service: $_userData');
    } catch (e) {
      print('Error fetching user data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if user is a doctor to show appropriate features
    final bool isDoctor = _userData != null && _userData!['role'] == 'doctor';
    
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    return Column(
      children: [
        // عنوان القسم
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Features',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              // User profile button
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Navigate to profile screen
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile coming soon')),
                  );
                },
                child: CircleAvatar(
                  backgroundColor: Colors.blue.shade100,
                  radius: 20,
                  child: Icon(
                    Icons.person,
                    color: Colors.blue.shade900,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // أزرار الميزات - الصف الأول
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // زر GPS
              _buildFeatureButton(
                context,
                icon: Icons.location_on,
                label: 'GPS',
                onTap: () {
                  // التنقل إلى صفحة GPS
                  Navigator.pop(context);
                  // Navigate to GPS scree);
                },
              ),
              
              // زر التعرف على الوجه
              _buildFeatureButton(
                context,
                icon: Icons.face,
                label: 'Face Rec',
                onTap: () {
                  // التنقل إلى صفحة التعرف على الوجه
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const RegistrationScreen()),
                  );
                },
              ),
              
              // زر المقررات الدراسية - مختلف للدكتور والطالب
              _buildFeatureButton(
                context,
                icon: Icons.book,
                label: isDoctor ? 'Manage Courses' : 'My Courses',
                onTap: () {
                  Navigator.pop(context);
                  
                  // Debug print to check userData
                  print('User data in CategoryCard: $_userData');
                  
                  if (_userData == null) {
                    // If still null after trying to fetch, show login prompt
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Please log in to access your courses'),
                        action: SnackBarAction(
                          label: 'Login',
                          onPressed: () {
                            Navigator.pushNamed(context, '/login');
                          },
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  
                  if (isDoctor) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DoctorDashboard(
                          doctorData: _userData!,
                        ),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => StudentCoursesScreen(
                          studentData: _userData!,
                        ),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 15),
        
        // أزرار الميزات - الصف الثاني
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // زر الحضور - مختلف للدكتور والطالب
              _buildFeatureButton(
                context,
                icon: Icons.calendar_today,
                label: isDoctor ? 'Take Attendance' : 'My Attendance',
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Add navigation to attendance screen
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Attendance feature coming soon')),
                  );
                },
              ),
              
              // زر الإشعارات مع مؤشر للإشعارات الجديدة
              Stack(
                children: [
                  _buildFeatureButton(
                    context,
                    icon: Icons.notifications,
                    label: 'Notifications',
                    onTap: () {
                      Navigator.pop(context);
                      // TODO: Add navigation to notifications screen
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Notifications feature coming soon')),
                      );
                    },
                  ),
                  // مؤشر الإشعارات الجديدة
                  Positioned(
                    right: 10,
                    top: 10,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Text(
                        '3',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              // زر المساعدة والدعم
              _buildFeatureButton(
                context,
                icon: Icons.help_outline,
                label: 'Help & Support',
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Add navigation to help screen
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Help & Support feature coming soon')),
                  );
                },
              ),
            ],
          ),
        ),
        
        // صف ثالث للميزات الإضافية (إذا كان المستخدم دكتور)
        if (isDoctor) ...[
          const SizedBox(height: 15),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // زر إدارة الطلاب
                _buildFeatureButton(
                  context,
                  icon: Icons.people,
                  label: 'Manage Students',
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Add navigation to student management screen
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Student Management feature coming soon')),
                    );
                  },
                ),
                
                // زر التقارير
                _buildFeatureButton(
                  context,
                  icon: Icons.bar_chart,
                  label: 'Reports',
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Add navigation to reports screen
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Reports feature coming soon')),
                    );
                  },
                ),
                
                // زر الإعدادات
                _buildFeatureButton(
                  context,
                  icon: Icons.settings,
                  label: 'Settings',
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Add navigation to settings screen
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Settings feature coming soon')),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
  
  Widget _buildFeatureButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool hasNotification = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.blue.shade100,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 30, color: Colors.blue.shade900),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue.shade900,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}