import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../core/theming/colors.dart';
import '../services/attendance_service.dart';
import '../widgets/application_app_bar.dart';
import 'course_attendance_details_screen.dart';

class StudentAttendanceScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const StudentAttendanceScreen({Key? key, required this.userData})
    : super(key: key);

  @override
  _StudentAttendanceScreenState createState() =>
      _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState extends State<StudentAttendanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  List<Map<String, dynamic>> _courses = [];
  Map<String, dynamic> _attendanceStats = {};
  List<Map<String, dynamic>> _recentAttendance = [];
  final AttendanceService _attendanceService = AttendanceService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAttendanceData();
  }

  Future<void> _loadAttendanceData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get student ID from user data
      final studentId = widget.userData['id'];

      // Load attendance summary
      final summaryResponse = await _attendanceService
          .getStudentAttendanceSummary(studentId);

      if (summaryResponse['success']) {
        setState(() {
          _courses = List<Map<String, dynamic>>.from(
            summaryResponse['courses'],
          );
          _attendanceStats = {
            'overall_percentage': summaryResponse['overall_percentage'],
            'total_lectures': summaryResponse['total_lectures'],
            'total_attended': summaryResponse['total_attended'],
            'total_absences': summaryResponse['total_absences'],
            'courses_at_risk': summaryResponse['courses_at_risk'],
          };
        });
      }

      // Load recent attendance
      final recentResponse = await _attendanceService.getRecentAttendance(
        studentId,
      );

      if (recentResponse['success']) {
        setState(() {
          _recentAttendance = List<Map<String, dynamic>>.from(
            recentResponse['records'],
          );
        });
      }
    } catch (e) {
      print('Error loading attendance data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading attendance data: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildApplicationAppBar(title: 'My Attendance'),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  // Tab bar
                  Container(
                    color: ColorsManager.darkBlueColor1,
                    child: TabBar(
                      controller: _tabController,
                      indicatorColor: Colors.white,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white70,
                      tabs: const [
                        Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
                        Tab(text: 'Courses', icon: Icon(Icons.school)),
                        Tab(text: 'Calendar', icon: Icon(Icons.calendar_today)),
                      ],
                    ),
                  ),
                  // Tab content
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildOverviewTab(),
                        _buildCoursesTab(),
                        _buildCalendarTab(),
                      ],
                    ),
                  ),
                ],
              ),
    );
  }

  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: _loadAttendanceData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overall attendance card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'Overall Attendance',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: ColorsManager.darkBlueColor1,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Circular progress indicator for attendance percentage
                    SizedBox(
                      height: 150,
                      width: 150,
                      child: Stack(
                        children: [
                          Center(
                            child: SizedBox(
                              height: 150,
                              width: 150,
                              child: CircularProgressIndicator(
                                value:
                                    _attendanceStats['overall_percentage'] /
                                    100,
                                strokeWidth: 12,
                                backgroundColor: Colors.grey[300],
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _getStatusColor(
                                    _attendanceStats['overall_percentage'],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${_attendanceStats['overall_percentage'].toStringAsFixed(1)}%',
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: ColorsManager.darkBlueColor1,
                                  ),
                                ),
                                Text(
                                  _getStatusText(
                                    _attendanceStats['overall_percentage'],
                                  ),
                                  style: TextStyle(
                                    color: _getStatusColor(
                                      _attendanceStats['overall_percentage'],
                                    ),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Attendance statistics
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(
                          'Total Classes',
                          _attendanceStats['total_lectures'].toString(),
                          Icons.class_,
                        ),
                        _buildStatItem(
                          'Present',
                          _attendanceStats['total_attended'].toString(),
                          Icons.check_circle,
                          color: Colors.green,
                        ),
                        _buildStatItem(
                          'Absent',
                          _attendanceStats['total_absences'].toString(),
                          Icons.cancel,
                          color: Colors.red,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Courses at risk
            if (_attendanceStats['courses_at_risk'] > 0) ...[
              const Text(
                'Courses at Risk',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: ColorsManager.darkBlueColor1,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                color: Colors.red[50],
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning, color: Colors.red[700]),
                          const SizedBox(width: 8),
                          Text(
                            'You have ${_attendanceStats['courses_at_risk']} course(s) at risk',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Your attendance in some courses is below the required threshold. Please ensure you attend the upcoming classes.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Recent attendance
            const Text(
              'Recent Attendance',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: ColorsManager.darkBlueColor1,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child:
                  _recentAttendance.isEmpty
                      ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: Text('No recent attendance records found'),
                        ),
                      )
                      : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _recentAttendance.length,
                        separatorBuilder: (context, index) => const Divider(),
                        itemBuilder: (context, index) {
                          final record = _recentAttendance[index];
                          final bool wasPresent = record['status'] == 'Present';

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  wasPresent ? Colors.green : Colors.red,
                              child: Icon(
                                wasPresent ? Icons.check : Icons.close,
                                color: Colors.white,
                              ),
                            ),
                            title: Text(record['course_name']),
                            subtitle: Text(record['date']),
                            trailing: Text(
                              wasPresent ? 'Present' : 'Absent',
                              style: TextStyle(
                                color: wasPresent ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoursesTab() {
    return RefreshIndicator(
      onRefresh: _loadAttendanceData,
      child:
          _courses.isEmpty
              ? const Center(child: Text('No courses found'))
              : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _courses.length,
                itemBuilder: (context, index) {
                  final course = _courses[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    color: Colors.white,
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => CourseAttendanceDetailsScreen(
                                  userData: widget.userData,
                                  courseId: course['id'],
                                  courseName: course['name'],
                                ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              course['name'],
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: ColorsManager.darkBlueColor1,
                              ),
                            ),
                            Text(
                              'Course Code: ${course['code']}',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 16),
                            LinearProgressIndicator(
                              value: course['attendance_percentage'] / 100,
                              backgroundColor: Colors.grey[300],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _getStatusColor(
                                  course['attendance_percentage'],
                                ),
                              ),
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${course['attendance_percentage'].toStringAsFixed(1)}%',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  course['status'],
                                  style: TextStyle(
                                    color: _getStatusColor(
                                      course['attendance_percentage'],
                                    ),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildCourseStatItem(
                                  'Total',
                                  course['total_lectures'].toString(),
                                ),
                                _buildCourseStatItem(
                                  'Present',
                                  course['attended'].toString(),
                                  color: Colors.green,
                                ),
                                _buildCourseStatItem(
                                  'Absent',
                                  (course['total_lectures'] -
                                          course['attended'])
                                      .toString(),
                                  color: Colors.red,
                                ),
                                _buildCourseStatItem(
                                  'Remaining',
                                  course['remaining_absences'].toString(),
                                  color: Colors.orange,
                                ),
                              ],
                            ),
                            if (course['remaining_absences'] == 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.red[50],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.warning,
                                        color: Colors.red[700],
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'You have reached the maximum allowed absences for this course!',
                                          style: TextStyle(
                                            color: Colors.red[700],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
    );
  }

  Widget _buildCalendarTab() {
    // This would be implemented with a calendar widget showing attendance
    // For now, just a placeholder
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.calendar_today, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Calendar view will be implemented here\nshowing attendance by date',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Calendar view coming soon!')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ColorsManager.darkBlueColor1,
            ),
            child: const Text(
              'View Calendar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon, {
    Color? color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ],
    );
  }

  Widget _buildCourseStatItem(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: color,
          ),
        ),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ],
    );
  }

  Color _getStatusColor(double percentage) {
    if (percentage >= 90) return Colors.green;
    if (percentage >= 75) return Colors.blue;
    if (percentage >= 60) return Colors.orange;
    return Colors.red;
  }

  String _getStatusText(double percentage) {
    if (percentage >= 90) return 'Excellent';
    if (percentage >= 75) return 'Good';
    if (percentage >= 60) return 'Average';
    return 'Poor';
  }
}
