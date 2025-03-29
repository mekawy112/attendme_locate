import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
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
          'message': data['message'] ?? 'Failed to load doctor courses',
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
          'message': data['message'] ?? 'Failed to load student courses',
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
    required dynamic doctorId,
    required dynamic location, // Add location parameter
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/courses'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'code': code,
          'name': name,
          'description': description,
          'doctor_id': doctorId,
          'day': day,
          'time': time,
          'location': location, // Include location
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 201) {
        return {
          'success': true,
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
          'student_id': studentIdStr,
          'enrollment_code': enrollmentCode,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': data['message'] ?? 'Enrolled successfully',
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
          'message': data['message'] ?? 'Unenrolled successfully',
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
}
