import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AttendanceDetailsScreen extends StatelessWidget {
  final int courseId;

  const AttendanceDetailsScreen({Key? key, required this.courseId}) : super(key: key);

  Future<List<Map<String, dynamic>>> _fetchAttendanceDetails() async {
    final response = await http.get(Uri.parse('http://your-backend-url/courses/$courseId/students'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['students']);
    } else {
      throw Exception('Failed to load attendance details');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Details'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchAttendanceDetails(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No attendance records found'));
          } else {
            final students = snapshot.data!;
            return ListView.builder(
              itemCount: students.length,
              itemBuilder: (context, index) {
                final student = students[index];
                return ListTile(
                  title: Text(student['name']),
                  subtitle: Text('ID: ${student['student_id']}'),
                );
              },
            );
          }
        },
      ),
    );
  }
}