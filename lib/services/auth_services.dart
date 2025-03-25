import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // Base URL configuration
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://192.168.1.68:5000';
    }
    return kDebugMode
        ? 'http://192.168.1.68:5000' // Android emulator
        : 'http://192.168.1.68:5000'; // Production
  }

  // Login method
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      print('Making login request to: $baseUrl/login');

      // Make sure we're sending strings for both email and password
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email.toString().trim(),
          'password': password.toString().trim(),
        }),
      );

      print('Login response status: ${response.statusCode}');
      print('Login response body: ${response.body}');

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        // Store user data in SharedPreferences
        final prefs = await SharedPreferences.getInstance();

        // Store token if available
        if (data['token'] != null) {
          await prefs.setString('token', data['token'].toString());
        } else {
          print('Warning: No token received from server');
        }

        // Store user data as JSON string
        if (data['user'] != null) {
          await prefs.setString('user_data', json.encode(data['user']));
          print('Stored user data: ${data['user']}');
        }

        return {
          'success': true,
          'user': data['user'],
          'message': data['message'] ?? 'Login successful',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Login failed',
        };
      }
    } catch (e) {
      print('Login error: $e');
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  // Get current user method
  Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      // First check if we have stored user data
      final prefs = await SharedPreferences.getInstance();
      final userData = prefs.getString('user_data');

      if (userData != null) {
        print('Found stored user data');
        return json.decode(userData);
      }

      // If no stored user data, check for token
      final token = prefs.getString('token');

      if (token == null) {
        print('No token found in SharedPreferences');
        return null;
      }

      print('Token found, fetching user data from server');
      // Get user data from API using the token
      final response = await http.get(
        Uri.parse('$baseUrl/user'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['user'] != null) {
          // Store the user data for future use
          await prefs.setString('user_data', json.encode(data['user']));
          print('Stored user data from API: ${data['user']}');
          return data['user'];
        }
      } else {
        // Token might be invalid, clear it
        await prefs.remove('token');
        await prefs.remove('user_data');
        return null;
      }
    } catch (e) {
      print('Error getting current user: $e');
      return null;
    }
    return null;
  }

  // Logout method
  Future<bool> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('token');
      await prefs.remove('user_data');
      return true;
    } catch (e) {
      print('Logout error: $e');
      return false;
    }
  }

  // Add the missing signUp method
  Future<Map<String, dynamic>> signUp({
    required String email,
    required String password,
    required String studentId,
    required String name,
    required String role,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/signup'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
          'student_id': studentId,
          'name': name,
          'role': role,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 201 && data['success'] == true) {
        return {
          'success': true,
          'message': data['message'] ?? 'Registration successful',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Registration failed',
        };
      }
    } catch (e) {
      print('Signup error: $e');
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }
}
