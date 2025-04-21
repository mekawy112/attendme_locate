import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import 'course_service.dart';

class AttendanceService {
  static String get baseUrl => ApiService.baseUrl;

  // Get student attendance summary for all courses
  Future<Map<String, dynamic>> getStudentAttendanceSummary(
    int studentId,
  ) async {
    try {
      // Use the CourseService to get student's enrolled courses
      final courseService = CourseService();
      final coursesResponse = await courseService.getStudentCourses(studentId);

      if (coursesResponse['success'] && coursesResponse['courses'] != null) {
        final courses = List<dynamic>.from(coursesResponse['courses']);

        // Process each course to add attendance data
        List<Map<String, dynamic>> coursesWithAttendance = [];
        int totalLectures = 0;
        int totalAttended = 0;
        int coursesAtRisk = 0;

        for (var course in courses) {
          // For now, we'll generate simulated attendance data for each course
          // In a real implementation, you would fetch this from the server
          final int courseId = course['id'];
          final int totalCourseLectures =
              20 + (courseId % 3) * 5; // Vary by course
          final int attended =
              totalCourseLectures -
              (3 + courseId % 4); // Vary absences by course
          final double attendancePercentage =
              (attended / totalCourseLectures) * 100;
          final int maxAbsences = 5;
          final int remainingAbsences =
              maxAbsences - (totalCourseLectures - attended);

          coursesWithAttendance.add({
            ...Map<String, dynamic>.from(course),
            'total_lectures': totalCourseLectures,
            'attended': attended,
            'attendance_percentage': attendancePercentage,
            'status': _getStatusText(attendancePercentage),
            'max_absences': maxAbsences,
            'remaining_absences': remainingAbsences,
          });

          totalLectures += totalCourseLectures;
          totalAttended += attended;

          if (remainingAbsences <= 0) {
            coursesAtRisk++;
          }
        }

        double overallPercentage =
            totalLectures > 0 ? (totalAttended / totalLectures) * 100 : 0.0;

        return {
          'success': true,
          'courses': coursesWithAttendance,
          'overall_percentage': overallPercentage,
          'total_lectures': totalLectures,
          'total_attended': totalAttended,
          'total_absences': totalLectures - totalAttended,
          'courses_at_risk': coursesAtRisk,
        };
      } else {
        // If we couldn't get the courses, fall back to simulated data
        return _getSimulatedAttendanceData(studentId);
      }
    } catch (e) {
      // If there's an error, fall back to simulated data
      return _getSimulatedAttendanceData(studentId);
    }
  }

  // Helper method to get status text based on percentage
  String _getStatusText(double percentage) {
    if (percentage >= 90) return 'Excellent';
    if (percentage >= 75) return 'Good';
    if (percentage >= 60) return 'Average';
    return 'Poor';
  }

  // Get detailed attendance for a specific course
  Future<Map<String, dynamic>> getCourseAttendanceDetails(
    int studentId,
    int courseId,
  ) async {
    try {
      // Use the CourseService to get course details
      final courseService = CourseService();
      final coursesResponse = await courseService.getStudentCourses(studentId);

      if (coursesResponse['success'] && coursesResponse['courses'] != null) {
        final courses = List<dynamic>.from(coursesResponse['courses']);

        // Find the specific course
        final courseData = courses.firstWhere(
          (course) => course['id'] == courseId,
          orElse: () => null,
        );

        if (courseData != null) {
          // Generate simulated attendance records for this course
          final List<Map<String, dynamic>> records = [];
          final DateTime now = DateTime.now();
          final int totalLectures = 20 + (courseId % 3) * 5; // Vary by course
          final int attended =
              totalLectures - (3 + courseId % 4); // Vary absences by course

          for (int i = 0; i < totalLectures; i++) {
            final date = now.subtract(Duration(days: i * 7)); // Weekly lectures
            final bool wasPresent = i >= (totalLectures - attended);

            records.add({
              'date':
                  '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
              'status': wasPresent ? 'Present' : 'Absent',
              'timestamp':
                  '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}',
              'verification_method': wasPresent ? 'Face and Location' : 'N/A',
            });
          }

          final double attendancePercentage = (attended / totalLectures) * 100;
          final int maxAbsences = 5;
          final int remainingAbsences =
              maxAbsences - (totalLectures - attended);

          return {
            'success': true,
            'course_id': courseId,
            'course_name': courseData['name'],
            'course_code': courseData['code'],
            'attendance_records': records,
            'attendance_percentage': attendancePercentage,
            'total_lectures': totalLectures,
            'attended': attended,
            'absences': totalLectures - attended,
            'remaining_absences': remainingAbsences,
          };
        }
      }

      // If we couldn't get the course data, fall back to simulated data
      return _getSimulatedCourseAttendanceDetails(studentId, courseId);
    } catch (e) {
      // If there's an error, fall back to simulated data
      return _getSimulatedCourseAttendanceDetails(studentId, courseId);
    }
  }

  // Get recent attendance records for a student
  Future<Map<String, dynamic>> getRecentAttendance(
    int studentId, {
    int limit = 5,
  }) async {
    try {
      // Use the CourseService to get student's enrolled courses
      final courseService = CourseService();
      final coursesResponse = await courseService.getStudentCourses(studentId);

      if (coursesResponse['success'] && coursesResponse['courses'] != null) {
        final courses = List<dynamic>.from(coursesResponse['courses']);

        // Generate recent attendance records based on actual courses
        final List<Map<String, dynamic>> records = [];
        final DateTime now = DateTime.now();

        // Use up to 'limit' courses, or repeat courses if needed
        for (int i = 0; i < limit; i++) {
          final course = courses[i % courses.length];
          final date = now.subtract(Duration(days: i));
          final bool wasPresent = i != 1; // Make one absence for demo

          records.add({
            'course_id': course['id'],
            'course_name': course['name'],
            'date':
                '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
            'status': wasPresent ? 'Present' : 'Absent',
            'timestamp':
                '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}',
          });
        }

        return {'success': true, 'records': records};
      } else {
        // If we couldn't get the courses, fall back to simulated data
        return _getSimulatedRecentAttendance(studentId, limit);
      }
    } catch (e) {
      // If there's an error, fall back to simulated data
      return _getSimulatedRecentAttendance(studentId, limit);
    }
  }

  // Simulate attendance data for development purposes
  Map<String, dynamic> _getSimulatedAttendanceData(int studentId) {
    // Generate some sample courses with attendance data
    final List<Map<String, dynamic>> courses = [
      {
        'id': 1,
        'name': 'Mathematics 101',
        'code': 'MATH101',
        'total_lectures': 24,
        'attended': 20,
        'attendance_percentage': 83.3,
        'status': 'Good',
        'max_absences': 6,
        'remaining_absences': 2,
      },
      {
        'id': 2,
        'name': 'Computer Science Fundamentals',
        'code': 'CS101',
        'total_lectures': 30,
        'attended': 28,
        'attendance_percentage': 93.3,
        'status': 'Excellent',
        'max_absences': 7,
        'remaining_absences': 5,
      },
      {
        'id': 3,
        'name': 'Physics',
        'code': 'PHYS101',
        'total_lectures': 20,
        'attended': 15,
        'attendance_percentage': 75.0,
        'status': 'Average',
        'max_absences': 5,
        'remaining_absences': 0,
      },
    ];

    // Calculate overall statistics
    int totalLectures = 0;
    int totalAttended = 0;
    int coursesAtRisk = 0;

    for (var course in courses) {
      totalLectures += course['total_lectures'] as int;
      totalAttended += course['attended'] as int;
      if (course['remaining_absences'] == 0) {
        coursesAtRisk++;
      }
    }

    double overallPercentage =
        totalLectures > 0 ? (totalAttended / totalLectures) * 100 : 0.0;

    return {
      'success': true,
      'courses': courses,
      'overall_percentage': overallPercentage,
      'total_lectures': totalLectures,
      'total_attended': totalAttended,
      'total_absences': totalLectures - totalAttended,
      'courses_at_risk': coursesAtRisk,
    };
  }

  // Simulate course attendance details for development purposes
  Map<String, dynamic> _getSimulatedCourseAttendanceDetails(
    int studentId,
    int courseId,
  ) {
    // Sample course names based on courseId
    final courseNames = {
      1: 'Mathematics 101',
      2: 'Computer Science Fundamentals',
      3: 'Physics',
    };

    // Generate sample attendance records
    final List<Map<String, dynamic>> records = [];
    final DateTime now = DateTime.now();
    final int totalLectures = 20 + (courseId % 3) * 5; // Vary by course
    final int attended =
        totalLectures - (3 + courseId % 4); // Vary absences by course

    for (int i = 0; i < totalLectures; i++) {
      final date = now.subtract(Duration(days: i * 7)); // Weekly lectures
      final bool wasPresent = i >= (totalLectures - attended);

      records.add({
        'date':
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        'status': wasPresent ? 'Present' : 'Absent',
        'timestamp':
            '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}',
        'verification_method': wasPresent ? 'Face and Location' : 'N/A',
      });
    }

    return {
      'success': true,
      'course_id': courseId,
      'course_name': courseNames[courseId] ?? 'Unknown Course',
      'attendance_records': records,
      'attendance_percentage': (attended / totalLectures) * 100,
      'total_lectures': totalLectures,
      'attended': attended,
      'absences': totalLectures - attended,
      'remaining_absences':
          5 - (totalLectures - attended), // Assuming max absences is 5
    };
  }

  // Simulate recent attendance records for development purposes
  Map<String, dynamic> _getSimulatedRecentAttendance(int studentId, int limit) {
    final List<Map<String, dynamic>> records = [];
    final DateTime now = DateTime.now();
    final courseNames = [
      'Mathematics 101',
      'Computer Science Fundamentals',
      'Physics',
    ];

    for (int i = 0; i < limit; i++) {
      final date = now.subtract(Duration(days: i));
      final bool wasPresent = i != 1; // Make one absence for demo
      final String courseName = courseNames[i % courseNames.length];

      records.add({
        'course_id': (i % courseNames.length) + 1,
        'course_name': courseName,
        'date':
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        'status': wasPresent ? 'Present' : 'Absent',
        'timestamp':
            '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}',
      });
    }

    return {'success': true, 'records': records};
  }
}
