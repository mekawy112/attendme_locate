import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class AuthService {
  // Base URL configuration
  static String get baseUrl => ApiService.baseUrl;

  // Login method
  Future<Map<String, dynamic>?> login(String email, String password) async {
    try {
      var response = await http.post(
        Uri.parse('${ApiService.baseUrl}/user/login'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        try {
          Map<String, dynamic> responseJson = json.decode(response.body);
          if (!responseJson.containsKey('token') || !responseJson.containsKey('user')) {
            throw Exception('Invalid server response format');
          }
          
          String token = responseJson['token'];
          Map<String, dynamic> userData = responseJson['user'];

          // Save auth data to SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('token', token);
          await prefs.setString('user_data', json.encode(userData));
          
          
          return userData;
        } catch (e) {
          throw Exception('Error processing server response: ${e.toString()}');
        }
      } else {
        Map<String, dynamic> errorResponse = {};
        try {
          errorResponse = json.decode(response.body);
        } catch (e) {
          // Ignore decode error and use default messages
        }
        
        if (response.statusCode == 401) {
          throw Exception(errorResponse['message'] ?? 'Invalid email or password');
        } else if (response.statusCode == 400) {
          throw Exception(errorResponse['message'] ?? 'Invalid request data');
        } else {
          throw Exception(errorResponse['message'] ?? 'Server error occurred. Please try again later.');
        }
      }
    } catch (e) {
      throw Exception('Error: $e');
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
      
      // Clear token
      await prefs.remove('token');
      
      // Clear user data
      await prefs.remove('user_data');
      
      // Clear any other stored data related to the session
      await prefs.remove('attendance_notifications');
      
      return true;
    } catch (e) {
      print('Error during logout: $e');
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
