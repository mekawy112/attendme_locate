import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart'; // Add this import
import 'api_service.dart';

class CourseService {
  // Use the same baseUrl pattern as in AuthService
  static String get baseUrl => ApiService.baseUrl;

  Future<Map<String, dynamic>> getDoctorCourses(dynamic doctorId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/courses/doctor/$doctorId'),
        headers: {'Content-Type': 'application/json'},
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'courses': data['courses'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to load courses',
        };
      }
    } catch (e) {
      print('Error getting doctor courses: $e');
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  Future<Map<String, dynamic>> getStudentCourses(dynamic studentId) async {
    try {
      // Convert studentId to string if it's not already
      final studentIdStr = studentId.toString();

      final response = await http.get(
        Uri.parse('$baseUrl/courses/student/$studentIdStr'),
        headers: {'Content-Type': 'application/json'},
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'courses': data['courses'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to load courses',
        };
      }
    } catch (e) {
      print('Error getting student courses: $e');
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  Future<Map<String, dynamic>> addCourse({
    required String code,
    required String name,
    required String day,
    required String time,
    required String description,
    required String location, // Add this parameter
    required dynamic doctorId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/courses'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'code': code,
          'name': name,
          'day': day,
          'time': time,
          'description': description,
          'location': location, // Include location in the request body
          'doctor_id': doctorId,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 201) {
        return {
          'success': true,
          'message': data['message'] ?? 'Course added successfully',
          'course': data['course'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to add course',
        };
      }
    } catch (e) {
      print('Error adding course: $e');
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  Future<Map<String, dynamic>> enrollInCourse({
    required dynamic studentId, // Change from String to dynamic
    required String enrollmentCode,
  }) async {
    try {
      // Convert studentId to string if it's an integer
      final studentIdStr = studentId.toString();

      final response = await http.post(
        Uri.parse('$baseUrl/courses/enroll'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'student_id': studentIdStr, // Always send as string
          'enrollment_code': enrollmentCode,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': data['message'] ?? 'Successfully enrolled',
          'course': data['course'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to enroll in course',
        };
      }
    } catch (e) {
      print('Error enrolling in course: $e');
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  Future<Map<String, dynamic>> unenrollFromCourse({
    required String studentId,
    required int courseId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/courses/unenroll'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'student_id': studentId,
          'course_id': courseId,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Successfully unenrolled',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to unenroll from course',
        };
      }
    } catch (e) {
      print('Error unenrolling from course: $e');
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  Future<Map<String, dynamic>> updateAttendanceState(
      int courseId, bool isOpen) async {
    try {
      Map<String, dynamic> requestBody = {'isAttendanceOpen': isOpen};
      
      if (isOpen) {
        try {
          final position = await Geolocator.getCurrentPosition();
          requestBody['location'] = '${position.latitude},${position.longitude}';
          print('Updating location to: ${position.latitude},${position.longitude}');
        } catch (e) {
          print('Error getting current location: $e');
        }
      }

      final response = await http.put(
        Uri.parse('$baseUrl/courses/$courseId/attendance'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {
        'success': false,
        'message': 'Error updating attendance state: $e',
      };
    }
  }

  Future<Map<String, dynamic>> getAttendanceRecords(int courseId, {String? date}) async {
    try {
      // استخدام الواجهة الجديدة بطريقة GET بدلاً من POST
      String url = '$baseUrl/doctor/course-attendance?course_id=$courseId';
      
      // إضافة التاريخ إذا كان محدداً
      if (date != null && date.isNotEmpty) {
        url += '&date=$date';
      }
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'students': data['students'] ?? [], // قائمة الطلاب مع حالة الحضور
          'date': data['date'] ?? DateTime.now().toIso8601String().split('T')[0],
          'total_students': data['total_students'] ?? 0,
          'present_students': data['present_students'] ?? 0,
          'absence_students': data['absence_students'] ?? 0,
          'attendance_percentage': data['attendance_percentage'] ?? 0.0,
          'course_name': data['course_name'] ?? "",
        };
      } else {
        final errorMessage = jsonDecode(response.body)['message'] ?? 'Failed to fetch attendance records';
        return {
          'success': false,
          'message': errorMessage,
        };
      }
    } catch (e) {
      print('Error fetching attendance records: $e');
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }
  
  // إضافة وظيفة للبحث عن طالب محدد
  Future<Map<String, dynamic>> searchStudentAttendance(int courseId, String studentId, {String? date}) async {
    try {
      String url = '$baseUrl/doctor/course-attendance?course_id=$courseId&student_id=$studentId';
      
      // إضافة التاريخ إذا كان محدداً
      if (date != null && date.isNotEmpty) {
        url += '&date=$date';
      }
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'students': data['students'] ?? [],
          'date': data['date'] ?? DateTime.now().toIso8601String().split('T')[0],
          'total_students': data['total_students'] ?? 0,
          'present_students': data['present_students'] ?? 0,
          'absence_students': data['absence_students'] ?? 0,
          'attendance_percentage': data['attendance_percentage'] ?? 0.0,
          'course_name': data['course_name'] ?? "",
        };
      } else {
        final errorMessage = jsonDecode(response.body)['message'] ?? 'Failed to fetch student attendance';
        return {
          'success': false,
          'message': errorMessage,
        };
      }
    } catch (e) {
      print('Error searching student attendance: $e');
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  // دالة جديدة للحصول على ملخص الحضور الإجمالي للمقرر
  Future<Map<String, dynamic>> getCourseAttendanceSummary(int courseId) async {
    try {
      String url = '$baseUrl/doctor/course-attendance/summary?course_id=$courseId';
      
      print('Fetching attendance summary from: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );
      
      print('Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true) {
          return {
            'success': true,
            'course_id': data['course_id'],
            'course_name': data['course_name'],
            'course_code': data['course_code'],
            'total_students': data['total_students'],
            'total_lectures': data['total_lectures'],
            'students': data['students'],
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Failed to fetch attendance summary',
          };
        }
      } else {
        final errorMessage = jsonDecode(response.body)['message'] ?? 'Failed to fetch attendance summary';
        return {
          'success': false,
          'message': errorMessage,
        };
      }
    } catch (e) {
      print('Error fetching attendance summary: $e');
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }
}
