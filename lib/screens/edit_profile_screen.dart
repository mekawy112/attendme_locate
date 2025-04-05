import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../services/api_service.dart';
import '../services/auth_services.dart';
import '../core/theming/colors.dart';
import '../widgets/application_app_bar.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const EditProfileScreen({Key? key, required this.userData}) : super(key: key);

  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Personal Information
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  
  // Academic Information
  late TextEditingController _universityController;
  late TextEditingController _universityEmailController;
  late TextEditingController _studentIdController;
  late TextEditingController _majorController;
  String _academicYear = '1';
  
  bool _isLoading = false;
  String? _errorMessage;
  bool _isSuccess = false;
  
  @override
  void initState() {
    super.initState();
    // Initialize personal info controllers
    _nameController = TextEditingController(text: widget.userData['name']);
    _phoneController = TextEditingController(text: widget.userData['phone'] ?? '');
    
    // Initialize academic info controllers
    _universityController = TextEditingController(text: widget.userData['university'] ?? '');
    _universityEmailController = TextEditingController(text: widget.userData['university_email'] ?? '');
    _studentIdController = TextEditingController(text: widget.userData['student_id'] ?? '');
    _majorController = TextEditingController(text: widget.userData['major'] ?? '');
    _academicYear = widget.userData['academic_year'] ?? '1';
  }
  
  @override
  void dispose() {
    // Dispose personal info controllers
    _nameController.dispose();
    _phoneController.dispose();
    
    // Dispose academic info controllers
    _universityController.dispose();
    _universityEmailController.dispose();
    _studentIdController.dispose();
    _majorController.dispose();
    super.dispose();
  }
  
  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isSuccess = false;
    });

    try {
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/user/update-profile'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': widget.userData['id'],
          'name': _nameController.text,
          'phone': _phoneController.text,
          'university': _universityController.text,
          'university_email': _universityEmailController.text,
          'student_id': _studentIdController.text,
          'major': _majorController.text,
          'academic_year': _academicYear,
        }),
      );

      if (response.statusCode == 200) {
        // Update the user data in shared preferences
        final Map<String, dynamic> updatedUserData = {
          ...widget.userData,
          'name': _nameController.text,
          'phone': _phoneController.text,
          'university': _universityController.text,
          'university_email': _universityEmailController.text,
          'student_id': _studentIdController.text,
          'major': _majorController.text,
          'academic_year': _academicYear,
        };
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_data', jsonEncode(updatedUserData));
        
        setState(() {
          _isSuccess = true;
        });
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Return to the previous screen after a short delay
        Future.delayed(const Duration(seconds: 1), () {
          Navigator.pop(context, updatedUserData);
        });
      } else {
        final errorData = jsonDecode(response.body);
        setState(() {
          _errorMessage = errorData['message'] ?? 'Failed to update profile';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildApplicationAppBar(title: 'Edit Profile'),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Picture
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50.r,
                        backgroundColor: ColorsManager.blueColor,
                        child: Text(
                          _nameController.text.isNotEmpty ? _nameController.text[0] : 'U',
                          style: TextStyle(
                            fontSize: 40.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(height: 12.h),
                      TextButton.icon(
                        onPressed: () {
                          // Photo upload functionality would go here
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Photo upload coming soon'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Change Photo'),
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: 24.h),
                
                // Personal Information Section
                _buildSectionHeader('Personal Information'),
                
                // Name Field
                _buildFormField(
                  label: 'Full Name',
                  controller: _nameController,
                  hint: 'Enter your full name',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                ),
                
                // Phone Field
                _buildFormField(
                  label: 'Phone Number',
                  controller: _phoneController,
                  hint: 'Enter your phone number',
                  keyboardType: TextInputType.phone,
                ),
                
                SizedBox(height: 24.h),
                
                // Academic Information Section
                _buildSectionHeader('Academic Information'),
                
                // University Field
                _buildFormField(
                  label: 'University',
                  controller: _universityController,
                  hint: 'Enter your university name',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your university';
                    }
                    return null;
                  },
                ),
                
                // University Email Field
                _buildFormField(
                  label: 'University Email',
                  controller: _universityEmailController,
                  hint: 'Enter your university email',
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your university email';
                    }
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                
                // Student ID Field
                _buildFormField(
                  label: 'Student ID',
                  controller: _studentIdController,
                  hint: 'Enter your student ID number',
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your student ID';
                    }
                    return null;
                  },
                ),
                
                // Major Field
                _buildFormField(
                  label: 'Major / Department',
                  controller: _majorController,
                  hint: 'Enter your major or department',
                ),
                
                // Academic Year Dropdown
                Padding(
                  padding: EdgeInsets.only(bottom: 16.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Academic Year',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _academicYear,
                            onChanged: (String? newValue) {
                              setState(() {
                                _academicYear = newValue!;
                              });
                            },
                            items: ['1', '2', '3', '4', '5', '6']
                                .map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text('Year $value'),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: 8.h),
                
                // Error message
                if (_errorMessage != null)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12),
                    margin: EdgeInsets.only(bottom: 16.h),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 14.sp,
                      ),
                    ),
                  ),
                
                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 54.h,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _updateProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColorsManager.blueColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            'Save Changes',
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                
                SizedBox(height: 16.h),
                
                // Cancel Button
                SizedBox(
                  width: double.infinity,
                  height: 54.h,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: ColorsManager.blueColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: ColorsManager.blueColor,
                      ),
                    ),
                  ),
                ),
                
                SizedBox(height: 32.h),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  // Helper method to build section headers
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: ColorsManager.darkBlueColor1,
            ),
          ),
          SizedBox(height: 4.h),
          Divider(
            thickness: 1,
            color: Colors.grey.shade300,
          ),
        ],
      ),
    );
  }
  
  // Helper method to build form fields
  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8.h),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              hintText: hint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            validator: validator,
          ),
        ],
      ),
    );
  }
}
