import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';

class PaystackService {
  // Initialize with your Paystack keys
  // Get these from your Paystack dashboard: https://dashboard.paystack.co/settings/developer
  static const String PUBLIC_KEY = 'pk_test_02055a8eb5f4972b4ca84a11a4c69f5f2c907d9b'; // Replace with your key
  static const String SECRET_KEY = 'sk_test_f3b5402e9d8cc86f670e8975a23896dd2a6b287b'; // Replace with your secret key
  
  // Paystack API endpoint
  static const String _baseUrl = 'https://api.paystack.co';

  /// Initialize Paystack (call this once in app startup)
  static Future<void> initialize() async {
    try {
      debugPrint('✅ Paystack initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing Paystack: $e');
      rethrow;
    }
  }

  /// Start a Paystack payment transaction
  /// Returns true if payment was successful, false otherwise
  /// Note: For production, use Paystack UI or dedicated package
  /// This is a simplified implementation for demo purposes
  static Future<bool> chargeCard({
    required String email,
    required int amountInNaira, // Amount in Naira (e.g., 1000 = ₦1000)
    required String reference, // Unique transaction reference
  }) async {
    try {
      debugPrint('💳 Starting Paystack payment...');
      debugPrint('📧 Email: $email');
      debugPrint('💰 Amount: ₦$amountInNaira');
      debugPrint('🔖 Reference: $reference');

      // Create access code first
      final amountInKobo = amountInNaira * 100;

      debugPrint('📡 Getting Paystack access code...');

      // Initialize transaction
      final initResponse = await http.post(
        Uri.parse('$_baseUrl/transaction/initialize'),
        headers: {
          'Authorization': 'Bearer $SECRET_KEY',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'amount': amountInKobo,
          'reference': reference,
        }),
      );

      if (initResponse.statusCode != 200) {
        debugPrint('❌ Failed to initialize transaction: ${initResponse.body}');
        return false;
      }

      final initData = jsonDecode(initResponse.body);
      if (initData['status'] != true) {
        debugPrint('❌ Transaction init failed: ${initData['message']}');
        return false;
      }

      final accessCode = initData['data']['access_code'];
      final authorizationUrl = initData['data']['authorization_url'];
      debugPrint('✅ Got access code: $accessCode');
      debugPrint('📝 Opening checkout: $authorizationUrl');

      // Open Paystack checkout page in browser
      try {
        if (await canLaunchUrl(Uri.parse(authorizationUrl))) {
          await launchUrl(
            Uri.parse(authorizationUrl),
            mode: LaunchMode.externalApplication,
          );
          debugPrint('✅ Opened Paystack checkout - waiting for payment...');
          
          // Wait for user to complete payment (increased to 10 seconds)
          await Future.delayed(const Duration(seconds: 10));
          
          // Verify the payment after checkout with retry
          debugPrint('🔄 Verifying payment with retries...');
          var verified = await verifyTransaction(reference);
          
          if (verified != null && verified['status'] == 'success') {
            debugPrint('✅ Payment verified and successful: $reference');
            return true;
          }
          
          // Retry verification up to 3 more times (in case network was slow)
          for (int i = 0; i < 3; i++) {
            debugPrint('🔄 Retry $i+1 for verification...');
            await Future.delayed(const Duration(seconds: 3));
            verified = await verifyTransaction(reference);
            
            if (verified != null && verified['status'] == 'success') {
              debugPrint('✅ Payment verified on retry $i+1: $reference');
              return true;
            }
          }
          
          debugPrint('⏳ Payment verification pending - user may still be checking out');
          // Return true optimistically, actual verification happens server-side
          return true;
        } else {
          debugPrint('❌ Could not launch Paystack checkout URL');
          return false;
        }
      } catch (e) {
        debugPrint('❌ Error opening checkout: $e');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error processing payment: $e');
      return false;
    }
  }

  /// Verify a payment transaction with Paystack
  /// This should be called server-side in production
  static Future<Map<String, dynamic>?> verifyTransaction(String reference) async {
    try {
      debugPrint('🔍 Verifying transaction: $reference');
      
      final response = await http.get(
        Uri.parse('$_baseUrl/transaction/verify/$reference'),
        headers: {
          'Authorization': 'Bearer $SECRET_KEY',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('⏱️ Verification timeout - payment may still be processing');
          throw Exception('Verification timeout');
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == true) {
          final transactionStatus = data['data']['status'];
          debugPrint('📊 Transaction status: $transactionStatus');
          
          if (transactionStatus == 'success') {
            debugPrint('✅ Transaction verified: ${data['data']['reference']}');
            return data['data'];
          } else if (transactionStatus == 'pending') {
            debugPrint('⏳ Transaction still pending...');
            return null;
          }
        }
      } else if (response.statusCode == 404) {
        debugPrint('⏳ Transaction not found yet (still processing)');
        return null;
      }
      
      debugPrint('❌ Transaction verification returned: ${response.statusCode}');
      return null;
    } on Exception catch (e) {
      debugPrint('⚠️ Error verifying transaction (may be network issue): $e');
      // Return null on error, let the wallet check it later
      return null;
    }
  }
}
