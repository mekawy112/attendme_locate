import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/theming/colors.dart';
import '../widgets/application_app_bar.dart';
import '../services/auth_services.dart';
import '../services/api_service.dart';
import 'edit_profile_screen.dart';
import 'login_screen.dart';

class DoctorSettingsScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const DoctorSettingsScreen({Key? key, required this.userData}) : super(key: key);

  @override
  _DoctorSettingsScreenState createState() => _DoctorSettingsScreenState();
}

class _DoctorSettingsScreenState extends State<DoctorSettingsScreen> {
  bool _darkMode = false;
  bool _notificationsEnabled = true;
  String _selectedLanguage = 'English';
  bool _isLoggingOut = false;
  bool _autoCloseAttendance = true;
  bool _requireFaceVerification = true;
  bool _requireLocationVerification = true;
  double _attendanceRadius = 100.0; // Default radius in meters

  // Method to handle editing profile
  void _navigateToEditProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(userData: widget.userData),
      ),
    );
    
    // If userData was updated, refresh settings screen
    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        // Update the user data
      });
    }
  }

  // Method to handle logout
  Future<void> _handleLogout() async {
    setState(() {
      _isLoggingOut = true;
    });
    
    try {
      final authService = AuthService();
      await authService.logout();
      
      // Navigate to login screen
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error logging out: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoggingOut = false;
        });
      }
    }
  }

  // Helper method to build section headers
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(top: 24.h, bottom: 8.h),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18.sp,
          fontWeight: FontWeight.bold,
          color: ColorsManager.darkBlueColor1,
        ),
      ),
    );
  }

  // Helper method to build setting cards
  Widget _buildSettingCard({
    required String title,
    required String subtitle,
    required Widget trailing,
    VoidCallback? onTap,
    Color? color,
  }) {
    return Card(
      margin: EdgeInsets.only(bottom: 8.h),
      color: color,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 14.sp,
            color: Colors.grey[600],
          ),
        ),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }

  // Helper method to build profile card
  Widget _buildProfileCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
      ),
      color: ColorsManager.darkBlueColor1,
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Row(
          children: [
            CircleAvatar(
              radius: 40.r,
              backgroundColor: Colors.white,
              child: Text(
                widget.userData['name']?.substring(0, 1).toUpperCase() ?? 'D',
                style: TextStyle(
                  fontSize: 30.sp,
                  fontWeight: FontWeight.bold,
                  color: ColorsManager.darkBlueColor1,
                ),
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.userData['name'] ?? 'Doctor',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    widget.userData['email'] ?? 'email@example.com',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    widget.userData['id']?.toString() ?? 'ID: -',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.edit, color: Colors.white),
              onPressed: _navigateToEditProfile,
            ),
          ],
        ),
      ),
    );
  }

  // Method to show course location change dialog
  void _showCourseLocationChangeDialog() {
    final _courseController = TextEditingController();
    final _locationController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Course Location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Select Course',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'course1', child: Text('Course 1')),
                DropdownMenuItem(value: 'course2', child: Text('Course 2')),
                // This would be populated from actual courses
              ],
              onChanged: (value) {
                _courseController.text = value ?? '';
              },
            ),
            SizedBox(height: 16.h),
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'New Location',
                border: OutlineInputBorder(),
                hintText: 'Enter new location (e.g., Room 101, Building A)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Implement location change logic
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Course location updated successfully')),
              );
            },
            child: const Text('Update Location'),
          ),
        ],
      ),
    );
  }

  // Method to show fraudulent attendance management dialog
  void _showFraudulentAttendanceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manage Fraudulent Attendance'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const TextField(
              decoration: InputDecoration(
                labelText: 'Student ID',
                border: OutlineInputBorder(),
                hintText: 'Enter student ID',
              ),
            ),
            SizedBox(height: 16.h),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Course',
                border: OutlineInputBorder(),
                hintText: 'Enter course name or ID',
              ),
            ),
            SizedBox(height: 16.h),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Date',
                border: OutlineInputBorder(),
                hintText: 'Enter date (YYYY-MM-DD)',
              ),
            ),
            SizedBox(height: 16.h),
            const TextField(
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Reason',
                border: OutlineInputBorder(),
                hintText: 'Enter reason for marking as fraudulent',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              // Implement fraudulent attendance handling logic
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Attendance marked as fraudulent')),
              );
            },
            child: const Text('Mark as Fraudulent'),
          ),
        ],
      ),
    );
  }

  // Method to show course archiving dialog
  void _showArchiveCourseDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive Courses'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select courses to archive after term completion:'),
            SizedBox(height: 16.h),
            // This would be a list of checkboxes for each course
            CheckboxListTile(
              title: const Text('Course 1'),
              subtitle: const Text('Spring 2023'),
              value: true,
              onChanged: (value) {},
            ),
            CheckboxListTile(
              title: const Text('Course 2'),
              subtitle: const Text('Spring 2023'),
              value: false,
              onChanged: (value) {},
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Implement course archiving logic
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Selected courses archived successfully')),
              );
            },
            child: const Text('Archive Selected'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildApplicationAppBar(title: 'Settings'),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User profile card
              _buildProfileCard(),
              SizedBox(height: 24.h),
              
              // Course Management
              _buildSectionHeader('Course Management'),
              _buildSettingCard(
                title: 'Change Course Location',
                subtitle: 'Update lecture location if changed',
                trailing: Icon(Icons.location_on, size: 22.sp),
                onTap: _showCourseLocationChangeDialog,
              ),
              _buildSettingCard(
                title: 'Manage Fraudulent Attendance',
                subtitle: 'Handle cases of attendance fraud',
                trailing: Icon(Icons.warning, size: 22.sp, color: Colors.orange),
                onTap: _showFraudulentAttendanceDialog,
              ),
              _buildSettingCard(
                title: 'Archive Courses',
                subtitle: 'Archive or remove courses after term completion',
                trailing: Icon(Icons.archive, size: 22.sp),
                onTap: _showArchiveCourseDialog,
              ),
              
              // Attendance Settings
              _buildSectionHeader('Attendance Settings'),
              _buildSettingCard(
                title: 'Face Verification',
                subtitle: 'Require face verification for attendance',
                trailing: Switch(
                  value: _requireFaceVerification,
                  onChanged: (value) {
                    setState(() {
                      _requireFaceVerification = value;
                    });
                  },
                  activeColor: ColorsManager.blueColor,
                ),
              ),
              _buildSettingCard(
                title: 'Location Verification',
                subtitle: 'Require location verification for attendance',
                trailing: Switch(
                  value: _requireLocationVerification,
                  onChanged: (value) {
                    setState(() {
                      _requireLocationVerification = value;
                    });
                  },
                  activeColor: ColorsManager.blueColor,
                ),
              ),
              _buildSettingCard(
                title: 'Attendance Radius',
                subtitle: 'Set maximum distance for location verification',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${_attendanceRadius.toInt()}m', 
                      style: TextStyle(fontSize: 14.sp)),
                    SizedBox(width: 8.w),
                    Icon(Icons.edit, size: 18.sp),
                  ],
                ),
                onTap: () {
                  // Show radius setting dialog
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Set Attendance Radius'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Current radius: ${_attendanceRadius.toInt()} meters'),
                          Slider(
                            value: _attendanceRadius,
                            min: 10,
                            max: 500,
                            divisions: 49,
                            label: '${_attendanceRadius.toInt()} m',
                            onChanged: (value) {
                              setState(() {
                                _attendanceRadius = value;
                              });
                            },
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            // Save the new radius
                            Navigator.pop(context);
                          },
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  );
                },
              ),
              _buildSettingCard(
                title: 'Auto-Close Attendance',
                subtitle: 'Automatically close attendance after lecture time',
                trailing: Switch(
                  value: _autoCloseAttendance,
                  onChanged: (value) {
                    setState(() {
                      _autoCloseAttendance = value;
                    });
                  },
                  activeColor: ColorsManager.blueColor,
                ),
              ),
              
              // Data & Statistics
              _buildSectionHeader('Data & Statistics'),
              _buildSettingCard(
                title: 'Attendance Reports',
                subtitle: 'View detailed attendance reports',
                trailing: Icon(Icons.bar_chart, size: 22.sp),
                onTap: () {
                  // Show statistics screen
                },
              ),
              _buildSettingCard(
                title: 'Export Data',
                subtitle: 'Export attendance to PDF or Excel',
                trailing: Icon(Icons.download, size: 22.sp),
                onTap: () {
                  // Show export options
                },
              ),
              
              // General Preferences
              _buildSectionHeader('General Preferences'),
              _buildSettingCard(
                title: 'Language',
                subtitle: 'Set application language',
                trailing: DropdownButton<String>(
                  value: _selectedLanguage,
                  icon: Icon(Icons.arrow_drop_down, size: 24.sp),
                  elevation: 16,
                  style: TextStyle(color: ColorsManager.darkBlueColor1),
                  underline: Container(
                    height: 0,
                  ),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedLanguage = newValue!;
                    });
                  },
                  items: <String>['English', 'Arabic']
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                ),
              ),
              _buildSettingCard(
                title: 'Dark Mode',
                subtitle: 'Switch between light and dark theme',
                trailing: Switch(
                  value: _darkMode,
                  onChanged: (value) {
                    setState(() {
                      _darkMode = value;
                    });
                  },
                  activeColor: ColorsManager.blueColor,
                ),
              ),
              _buildSettingCard(
                title: 'Notifications',
                subtitle: 'Enable or disable app notifications',
                trailing: Switch(
                  value: _notificationsEnabled,
                  onChanged: (value) {
                    setState(() {
                      _notificationsEnabled = value;
                    });
                  },
                  activeColor: ColorsManager.blueColor,
                ),
              ),
              
              // Help & Support
              _buildSectionHeader('Help & Support'),
              _buildSettingCard(
                title: 'User Guide',
                subtitle: 'How to use the application',
                trailing: Icon(Icons.menu_book, size: 22.sp),
                onTap: () {
                  // Show user guide
                },
              ),
              _buildSettingCard(
                title: 'FAQ',
                subtitle: 'Frequently asked questions',
                trailing: Icon(Icons.question_answer, size: 22.sp),
                onTap: () {
                  // Show FAQ
                },
              ),
              _buildSettingCard(
                title: 'Report a Problem',
                subtitle: 'Let us know if something is not working',
                trailing: Icon(Icons.bug_report, size: 22.sp),
                onTap: () {
                  // Show problem reporting form
                },
              ),
              
              // Account Actions
              _buildSectionHeader('Account'),
              _buildSettingCard(
                title: 'Edit Profile',
                subtitle: 'Update your personal information',
                trailing: Icon(Icons.edit, size: 22.sp),
                onTap: _navigateToEditProfile,
              ),
              _buildSettingCard(
                title: 'Log Out',
                subtitle: 'Sign out from your account',
                trailing: _isLoggingOut 
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.red,
                        )
                      )
                    : Icon(Icons.logout, size: 22.sp, color: Colors.red),
                onTap: _isLoggingOut ? null : _handleLogout,
                color: Colors.red[50],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
