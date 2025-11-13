import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SecurityService {
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;
  SecurityService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Track access from current IP and notify if it's a new IP
  Future<void> trackAccess() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Get current IP address
      final ipData = await _getCurrentIP();
      final currentIP = ipData['ip'] as String?;

      if (currentIP == null) return;

      // Get user's access log
      final userDoc = _firestore.collection('users').doc(user.uid);
      final accessLog = userDoc.collection('access_log').doc(currentIP);

      final accessSnapshot = await accessLog.get();
      final bool isNewIP = !accessSnapshot.exists;

      // Log this access
      await accessLog.set({
        'ip': currentIP,
        'lastAccess': FieldValue.serverTimestamp(),
        'location': ipData['location'] ?? 'Unknown',
        'userAgent': kIsWeb ? 'Web Browser' : 'Mobile App',
        'accessCount': FieldValue.increment(1),
      }, SetOptions(merge: true));

      // If it's a new IP, create a notification
      if (isNewIP) {
        await _createNewIPNotification(user.uid, currentIP, ipData);
      }

      if (kDebugMode) {
        print('🔒 Access tracked: IP=$currentIP, New=${isNewIP ? "YES" : "NO"}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Security tracking failed: $e');
      }
    }
  }

  /// Get current IP address and location info
  Future<Map<String, dynamic>> _getCurrentIP() async {
    try {
      // Use ipapi.co for IP geolocation (free tier: 1000 requests/day)
      final response = await http.get(
        Uri.parse('https://ipapi.co/json/'),
        headers: {'User-Agent': 'BBetter-App'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'ip': data['ip'],
          'location': '${data['city']}, ${data['country_name']}',
          'latitude': data['latitude'],
          'longitude': data['longitude'],
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ IP lookup failed: $e');
      }
    }

    return {'ip': 'Unknown', 'location': 'Unknown'};
  }

  /// Create a notification for new IP access
  Future<void> _createNewIPNotification(
    String userId,
    String ip,
    Map<String, dynamic> ipData,
  ) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('security_notifications')
          .add({
        'type': 'new_ip_access',
        'ip': ip,
        'location': ipData['location'] ?? 'Unknown',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'message': 'New login from ${ipData['location'] ?? "Unknown location"} (IP: $ip)',
      });

      if (kDebugMode) {
        print('🔔 New IP notification created: $ip');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Failed to create notification: $e');
      }
    }
  }

  /// Get all access logs for current user
  Future<List<Map<String, dynamic>>> getAccessLogs() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('access_log')
          .orderBy('lastAccess', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'ip': doc.id,
          'lastAccess': data['lastAccess'],
          'location': data['location'],
          'accessCount': data['accessCount'],
          'userAgent': data['userAgent'],
        };
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Failed to get access logs: $e');
      }
      return [];
    }
  }

  /// Get unread security notifications
  Stream<List<Map<String, dynamic>>> getSecurityNotifications() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('security_notifications')
        .where('read', isEqualTo: false)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'type': data['type'],
          'message': data['message'],
          'timestamp': data['timestamp'],
          'ip': data['ip'],
          'location': data['location'],
        };
      }).toList();
    });
  }

  /// Mark notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('security_notifications')
          .doc(notificationId)
          .update({'read': true});
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Failed to mark notification as read: $e');
      }
    }
  }

  /// Revoke access from a specific IP (block it)
  Future<void> revokeIPAccess(String ip) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('blocked_ips')
          .doc(ip)
          .set({
        'blockedAt': FieldValue.serverTimestamp(),
        'ip': ip,
      });

      if (kDebugMode) {
        print('🚫 IP blocked: $ip');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Failed to block IP: $e');
      }
    }
  }

  /// Check if current IP is blocked
  Future<bool> isCurrentIPBlocked() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final ipData = await _getCurrentIP();
      final currentIP = ipData['ip'] as String?;

      if (currentIP == null) return false;

      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('blocked_ips')
          .doc(currentIP)
          .get();

      return doc.exists;
    } catch (e) {
      return false;
    }
  }
}
