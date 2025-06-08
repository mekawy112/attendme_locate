import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../core/theming/colors.dart';
import '../widgets/application_app_bar.dart';
import '../services/auth_services.dart';
import 'edit_profile_screen.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const SettingsScreen({Key? key, required this.userData}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _darkMode = false;
  bool _notificationsEnabled = true;
  String _selectedLanguage = 'English';
  bool _isLoggingOut = false;

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
  void _handleLogout() async {
    // Show confirmation dialog
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to sign out? You will need to sign in again to access your account.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (shouldLogout == true) {
      setState(() {
        _isLoggingOut = true;
      });
      
      try {
        // Call logout method from AuthService
        final authService = AuthService();
        final success = await authService.logout();
        
        if (success) {
          // Navigate to login screen and clear navigation stack
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        } else {
          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to sign out. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _isLoggingOut = false;
          });
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoggingOut = false;
        });
      }
    }
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
              
              // UI Customization
              _buildSectionHeader('UI Customization'),
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
                title: 'Font Size',
                subtitle: 'Adjust the application font size',
                trailing: Icon(Icons.arrow_forward_ios, size: 16.sp),
                onTap: () {
                  // Show font size options
                },
              ),
              _buildSettingCard(
                title: 'Course Display Order',
                subtitle: 'Change how courses are ordered',
                trailing: Icon(Icons.arrow_forward_ios, size: 16.sp),
                onTap: () {
                  // Show sorting options
                },
              ),
              
              // Notification Settings
              _buildSectionHeader('Notification Settings'),
              _buildSettingCard(
                title: 'Attendance Notifications',
                subtitle: 'Enable or disable attendance updates',
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
              _buildSettingCard(
                title: 'Lecture Reminders',
                subtitle: 'Get reminders before your lectures',
                trailing: Icon(Icons.arrow_forward_ios, size: 16.sp),
                onTap: () {
                  // Show reminder options
                },
              ),
              
              // Privacy & Security
              _buildSectionHeader('Privacy & Security'),
              _buildSettingCard(
                title: 'Change Password',
                subtitle: 'Update your account password',
                trailing: Icon(Icons.arrow_forward_ios, size: 16.sp),
                onTap: () {
                  // Show password change dialog
                },
              ),
              _buildSettingCard(
                title: 'Face Recognition Data',
                subtitle: 'Manage your saved face data',
                trailing: Icon(Icons.arrow_forward_ios, size: 16.sp),
                onTap: () {
                  // Show face data management
                },
              ),
              _buildSettingCard(
                title: 'Location Settings',
                subtitle: 'Manage GPS and location privacy',
                trailing: Icon(Icons.arrow_forward_ios, size: 16.sp),
                onTap: () {
                  // Show location settings
                },
              ),
              
              // Data & Statistics
              _buildSectionHeader('Data & Statistics'),
              _buildSettingCard(
                title: 'Attendance Statistics',
                subtitle: 'View attendance metrics for courses',
                trailing: Icon(Icons.bar_chart, size: 22.sp),
                onTap: () {
                  // Show statistics screen
                },
              ),
              _buildSettingCard(
                title: 'Export Records',
                subtitle: 'Export attendance to PDF or Excel',
                trailing: Icon(Icons.download, size: 22.sp),
                onTap: () {
                  // Show export options
                },
              ),
              _buildSettingCard(
                title: 'Clear Notification History',
                subtitle: 'Remove old notification records',
                trailing: Icon(Icons.delete_outline, size: 22.sp),
                onTap: () {
                  // Show confirmation dialog
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
                title: 'Mobile Data Usage',
                subtitle: 'Allow downloads using cellular data',
                trailing: Icon(Icons.arrow_forward_ios, size: 16.sp),
                onTap: () {
                  // Show data usage settings
                },
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
              _buildSettingCard(
                title: 'Contact Support',
                subtitle: 'Get help from our support team',
                trailing: Icon(Icons.support_agent, size: 22.sp),
                onTap: () {
                  // Show support contact info
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
              
              SizedBox(height: 30.h),
              
              // App version info
              Center(
                child: Text(
                  'Version 1.0.0',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12.sp,
                  ),
                ),
              ),
              SizedBox(height: 10.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ColorsManager.blueColor.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30.r,
            backgroundColor: Colors.white,
            child: Text(
              widget.userData['name']?[0] ?? 'U',
              style: TextStyle(
                fontSize: 24.sp,
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
                  widget.userData['name'] ?? 'User',
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
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(left: 8.w, top: 24.h, bottom: 8.h),
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

  Widget _buildSettingCard({
    required String title,
    required String subtitle,
    required Widget trailing,
    VoidCallback? onTap,
    Color? color,
  }) {
    return Card(
      margin: EdgeInsets.only(bottom: 8.h),
      elevation: 0,
      color: color ?? Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            fontSize: 13.sp,
            color: Colors.grey[600],
          ),
        ),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}
