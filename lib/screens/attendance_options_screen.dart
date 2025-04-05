import 'package:attend_me_locate/core/theming/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';
import 'face_rec_screen/RecognitionScreen.dart';
import 'location_screen.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AttendanceOptionsScreen extends StatefulWidget {
  final Map<String, dynamic> courseData;
  final Map<String, dynamic> studentData;

  const AttendanceOptionsScreen(
      {Key? key, required this.courseData, required this.studentData})
      : super(key: key);

  @override
  _AttendanceOptionsScreenState createState() => _AttendanceOptionsScreenState();
}

class _AttendanceOptionsScreenState extends State<AttendanceOptionsScreen> {
  // حالات التحقق مبدئياً false
  bool isFaceVerified = false;
  bool isLocationVerified = false;
  bool isLoading = false;
  bool isAttendanceConfirmed = false;

  @override
  void initState() {
    super.initState();
    // إعادة ضبط الحالات عند بدء الشاشة
    _resetVerificationStatus();
  }

  // دالة لإعادة ضبط حالات التحقق
  void _resetVerificationStatus() {
    setState(() {
      isFaceVerified = false;
      isLocationVerified = false;
      isAttendanceConfirmed = false;
      isLoading = false;
    });
  }

  // دالة للانتقال إلى شاشة التحقق من الموقع
  Future<bool> _navigateToLocationScreen(BuildContext context) async {
    setState(() {
      isLoading = true;
    });

    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LocationScreen(
            courseData: widget.courseData,
            studentData: widget.studentData,
          ),
        ),
      );

      setState(() {
        isLoading = false;
      });

      if (result == true) {
        setState(() {
          isLocationVerified = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location verified successfully'),
            backgroundColor: Colors.green,
          ),
        );
        return true;
      } else {
        setState(() {
          isLocationVerified = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location verification failed'),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        isLocationVerified = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error verifying location'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
  }

  // دالة للتحقق من حضور الطالب
  Future<void> _verifyAttendance(BuildContext context) async {
    if (!isFaceVerified || !isLocationVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please verify both face and location first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final studentId = widget.studentData['id'];
      final courseId = widget.courseData['id'];
      
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/attendance/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'student_id': studentId,
          'course_id': courseId,
          'face_verified': true,
          'location_verified': true,
        }),
      );

      setState(() {
        isLoading = false;
      });

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['success']) {
          setState(() {
            isAttendanceConfirmed = true;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Attendance registered successfully'),
              backgroundColor: Colors.green,
            ),
          );

          final confirmResponse = await http.post(
            Uri.parse('${ApiService.baseUrl}/attendance/confirm'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'student_id': studentId,
              'course_id': courseId,
            }),
          );

          if (confirmResponse.statusCode == 200) {
            final doctorResponse = await http.post(
              Uri.parse('${ApiService.baseUrl}/attendance/send-to-doctor'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'course_id': courseId,
                'student_id': studentId,
                'timestamp': DateTime.now().toIso8601String(),
                'face_verified': true,
                'location_verified': true,
              }),
            );

            if (doctorResponse.statusCode == 200) {
              final doctorResult = jsonDecode(doctorResponse.body);
              if (doctorResult['success']) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Attendance sent to doctor successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Error sending attendance to doctor'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Failed to send attendance to doctor. Check network connection.'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to confirm attendance. Check network connection.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } else {
          setState(() {
            isAttendanceConfirmed = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error registering attendance'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        setState(() {
          isAttendanceConfirmed = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error verifying attendance. Code: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        isAttendanceConfirmed = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error confirming attendance'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // دالة للانتقال إلى شاشة التعرف على الوجه
  Future<void> _navigateToFaceRecognition(BuildContext context) async {
    setState(() {
      isLoading = true;
    });

    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RecognitionScreen(
            studentId: widget.studentData['id'].toString(),
            studentData: widget.studentData,
            courseId: widget.courseData['id'].toString(),
          ),
        ),
      );

      setState(() {
        isFaceVerified = result == true;
        isLoading = false;
      });

      if (isFaceVerified) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Face verification successful'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() {
        isFaceVerified = false;
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Face verification failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
            color: Colors.white
        ),
        title: const Text('Attendance Options',style: TextStyle(
          color: Colors.white,
        ),),
        backgroundColor: ColorsManager.darkBlueColor1,
        actions: [
          // زر إعادة ضبط الحالة للاختبار
          IconButton(
            icon: const Icon(Icons.refresh,color: Colors.white,),
            onPressed: _resetVerificationStatus,
            tooltip: 'إعادة ضبط حالات التحقق',
          ),
        ],
      ),
      body: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // عنوان يوضح المطلوب
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'Make sure to verify both the destination and location to register attendance',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                      color: ColorsManager.darkBlueColor1),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // زر التحقق من الوجه مع أيقونة الحالة
                  Card(
                    color: ColorsManager.darkBlueColor1,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: InkWell(
                      onTap: (isLoading || isAttendanceConfirmed)
                          ? null
                          : () => _navigateToFaceRecognition(context),
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Face Recognition',
                              style: TextStyle(fontSize: 16, color: Colors.white),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              decoration: BoxDecoration(
                                color: isFaceVerified ? Colors.green : Colors.transparent,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1),
                              ),
                              padding: const EdgeInsets.all(2),
                              child: Icon(
                                Icons.check_circle,
                                color: isFaceVerified ? Colors.white : Colors.transparent,
                                size: 24,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // زر التحقق من الموقع مع أيقونة الحالة
                  Card(
                    color: ColorsManager.darkBlueColor1,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: InkWell(
                      onTap: (isLoading || isAttendanceConfirmed)
                          ? null
                          : () => _navigateToLocationScreen(context),
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'GPS',
                              style: TextStyle(fontSize: 16, color: Colors.white),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              decoration: BoxDecoration(
                                color: isLocationVerified ? Colors.green : Colors.transparent,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1),
                              ),
                              padding: const EdgeInsets.all(2),
                              child: Icon(
                                Icons.check_circle,
                                color: isLocationVerified ? Colors.white : Colors.transparent,
                                size: 24,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // زر تأكيد الحضور - يظهر فقط إذا لم يتم تأكيد الحضور مسبقًا
                  if (isAttendanceConfirmed)
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green, width: 2),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 40,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Attendance registered and sent to the doctor successfully',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                  // تأكيد الحضور في أسفل الشاشة
                  if (!isAttendanceConfirmed)
                    ElevatedButton(
                      onPressed: (isFaceVerified && isLocationVerified && !isLoading)
                          ? () => _verifyAttendance(context)
                          : null, // تعطيل الزر حتى إتمام عمليتي التحقق
                      style: ElevatedButton.styleFrom(
                        backgroundColor: (isFaceVerified && isLocationVerified)
                            ? Colors.green
                            : Colors.grey[300],
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: Text(
                        'Confirm Attendance',
                        style: TextStyle(
                          color: (isFaceVerified && isLocationVerified)
                              ? Colors.white
                              : Colors.black54,
                          fontSize: 16,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // طبقة التحميل
          if (isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),

          // تأكيد الحضور في أسفل الشاشة
          if (isAttendanceConfirmed)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: const Text(
                  'Attendance confirmed and sent to the doctor.',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
