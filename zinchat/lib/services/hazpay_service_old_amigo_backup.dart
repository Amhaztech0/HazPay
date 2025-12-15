import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'paystack_service.dart';

// Data plan model
class DataPlan {
  final String planId;
  final int networkId;
  final String networkName;
  final double capacity; // in GB
  final int validity; // in days
  final double price;
  final double efficiency;
  final String efficiencyLabel;

  DataPlan({
    required this.planId,
    required this.networkId,
    required this.networkName,
    required this.capacity,
    required this.validity,
    required this.price,
    required this.efficiency,
    required this.efficiencyLabel,
  });

  factory DataPlan.fromJson(Map<String, dynamic> json, String networkName, int networkId) {
    return DataPlan(
      planId: json['plan_id'].toString(),
      networkId: networkId,
      networkName: networkName,
      capacity: (json['data_capacity'] ?? 0).toDouble(),
      validity: json['validity'] ?? 30,
      price: (json['price'] ?? 0).toDouble(),
      efficiency: (json['efficiency_percent'] ?? 0).toDouble(),
      efficiencyLabel: json['efficiency_label'] ?? 'Unknown',
    );
  }
}

// Transaction model
class HazPayTransaction {
  final String id;
  final String userId;
  final String type; // 'purchase', 'deposit', 'withdrawal'
  final double amount;
  final String? networkName;
  final String? dataCapacity;
  final String? mobileNumber;
  final String? reference;
  final String status; // 'pending', 'success', 'failed'
  final DateTime createdAt;
  final String? errorMessage;

  HazPayTransaction({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    this.networkName,
    this.dataCapacity,
    this.mobileNumber,
    this.reference,
    required this.status,
    required this.createdAt,
    this.errorMessage,
  });

  factory HazPayTransaction.fromJson(Map<String, dynamic> json) {
    return HazPayTransaction(
      id: json['id'],
      userId: json['user_id'],
      type: json['type'],
      amount: (json['amount'] ?? 0).toDouble(),
      networkName: json['network_name'],
      dataCapacity: json['data_capacity'],
      mobileNumber: json['mobile_number'],
      reference: json['reference'],
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
      errorMessage: json['error_message'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'type': type,
    'amount': amount,
    'network_name': networkName,
    'data_capacity': dataCapacity,
    'mobile_number': mobileNumber,
    'reference': reference,
    'status': status,
    'created_at': createdAt.toIso8601String(),
    'error_message': errorMessage,
  };
}

// Loan model
class HazPayLoan {
  final String id;
  final String userId;
  final int planId;
  final double loanFee;
  final String status; // 'pending', 'issued', 'repaid', 'failed'
  final DateTime createdAt;
  final DateTime? issuedAt;
  final DateTime? repaidAt;
  final String? failureReason;

  HazPayLoan({
    required this.id,
    required this.userId,
    required this.planId,
    required this.loanFee,
    required this.status,
    required this.createdAt,
    this.issuedAt,
    this.repaidAt,
    this.failureReason,
  });

  factory HazPayLoan.fromJson(Map<String, dynamic> json) {
    return HazPayLoan(
      id: json['id'],
      userId: json['user_id'],
      planId: json['plan_id'],
      loanFee: (json['loan_fee'] as num).toDouble(),
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
      issuedAt: json['issued_at'] != null ? DateTime.parse(json['issued_at']) : null,
      repaidAt: json['repaid_at'] != null ? DateTime.parse(json['repaid_at']) : null,
      failureReason: json['failure_reason'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'plan_id': planId,
    'loan_fee': loanFee,
    'status': status,
    'created_at': createdAt.toIso8601String(),
    'issued_at': issuedAt?.toIso8601String(),
    'repaid_at': repaidAt?.toIso8601String(),
    'failure_reason': failureReason,
  };
}

// Wallet model
class HazPayWallet {
  final String id;
  final String userId;
  final double balance;
  final int totalTransactions;
  final DateTime createdAt;
  final DateTime updatedAt;

  HazPayWallet({
    required this.id,
    required this.userId,
    required this.balance,
    required this.totalTransactions,
    required this.createdAt,
    required this.updatedAt,
  });

  factory HazPayWallet.fromJson(Map<String, dynamic> json) {
    return HazPayWallet(
      id: json['id'],
      userId: json['user_id'],
      balance: (json['balance'] ?? 0).toDouble(),
      totalTransactions: json['total_transactions'] ?? 0,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}

// User Points model (for Rewarded Ads)
class UserPoints {
  final String id;
  final String userId;
  final int points;
  final int totalPointsEarned;
  final int totalRedemptions;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserPoints({
    required this.id,
    required this.userId,
    required this.points,
    required this.totalPointsEarned,
    required this.totalRedemptions,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserPoints.fromJson(Map<String, dynamic> json) {
    return UserPoints(
      id: json['id'],
      userId: json['user_id'],
      points: json['points'] ?? 0,
      totalPointsEarned: json['total_points_earned'] ?? 0,
      totalRedemptions: json['total_redemptions'] ?? 0,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}

// Daily Ad Limit model
class DailyAdLimit {
  final String id;
  final String userId;
  final int adsWatchedToday;
  final DateTime createdAt;
  final DateTime updatedAt;

  DailyAdLimit({
    required this.id,
    required this.userId,
    required this.adsWatchedToday,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DailyAdLimit.fromJson(Map<String, dynamic> json) {
    return DailyAdLimit(
      id: json['id'],
      userId: json['user_id'],
      adsWatchedToday: json['ads_watched_today'] ?? 0,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}

class HazPayService {
  final supabase = Supabase.instance.client;
  
  // Cache for data plans
  static final Map<int, List<DataPlan>> _plansCache = {};

  /// Get data plans with custom pricing from Supabase pricing table
  /// This ensures prices are always controlled by you, not Amigo's default prices
  Future<Map<String, List<DataPlan>>> getDataPlans() async {
    try {
      debugPrint('🔄 Fetching data plans with custom pricing...');

      // Fetch from Supabase pricing table
      final response = await supabase
          .from('pricing')
          .select()
          .order('network_id', ascending: true)
          .order('plan_id', ascending: true);

      if (response.isNotEmpty) {
        debugPrint('✅ Fetched ${response.length} plans from Supabase pricing table');

        final mtnPlans = <DataPlan>[];
        final gloPlans = <DataPlan>[];

        for (var plan in response) {
          final dataPlan = DataPlan(
            planId: plan['plan_id'].toString(),
            networkId: plan['network_id'] as int,
            networkName: plan['plan_name'] as String,
            capacity: _parseCapacity(plan['data_size'] as String),
            validity: 30,
            price: (plan['sell_price'] as num).toDouble(), // Use your custom sell_price
            efficiency: 100.0, // Not used with custom pricing
            efficiencyLabel: 'Custom',
          );

          if (plan['network_id'] == 1) {
            mtnPlans.add(dataPlan);
          } else if (plan['network_id'] == 2) {
            gloPlans.add(dataPlan);
          }
        }

        // Cache for offline support
        _plansCache[1] = mtnPlans;
        _plansCache[2] = gloPlans;

        debugPrint('✅ Loaded ${mtnPlans.length} MTN and ${gloPlans.length} Glo plans from pricing table');

        return {
          'MTN': mtnPlans,
          'GLO': gloPlans,
        };
      } else {
        debugPrint('⚠️ Pricing table empty, using cached plans');
        return {
          'MTN': _plansCache[1] ?? [],
          'GLO': _plansCache[2] ?? [],
        };
      }
    } catch (e) {
      debugPrint('❌ Error fetching pricing: $e. Using cached plans.');
      // Return cached plans on error
      return {
        'MTN': _plansCache[1] ?? [],
        'GLO': _plansCache[2] ?? [],
      };
    }
  }

  /// Helper to parse data size string (e.g., "500MB" → 0.5, "1GB" → 1.0)
  double _parseCapacity(String dataSize) {
    if (dataSize.contains('MB')) {
      final value = double.tryParse(dataSize.replaceAll('MB', '').trim()) ?? 0;
      return value / 1024;
    } else if (dataSize.contains('GB')) {
      return double.tryParse(dataSize.replaceAll('GB', '').trim()) ?? 0;
    }
    return 0;
  }

  /// Purchase data for a mobile number via Supabase Edge Function
  Future<HazPayTransaction> purchaseData({
    required String mobileNumber,
    required String planId,
    required int networkId,
    required double amount,
    required bool isPortedNumber,
  }) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      debugPrint('💳 Purchasing data: $planId for $mobileNumber');

      // Create transaction record first (pending)
      final transactionId = _generateId();
      final transaction = HazPayTransaction(
        id: transactionId,
        userId: userId,
        type: 'purchase',
        amount: amount,
        networkName: networkId == 1 ? 'MTN' : 'GLO',
        dataCapacity: planId,
        mobileNumber: mobileNumber,
        status: 'pending',
        createdAt: DateTime.now(),
      );

      // Save transaction to Supabase
      await supabase.from('hazpay_transactions').insert(transaction.toJson());

      // Call Supabase Edge Function (API key is secure on server-side)
      debugPrint('🔐 Calling Supabase Edge Function for secure purchase...');
      
      final response = await supabase.functions.invoke(
        'buyData',
        body: {
          'network': networkId,
          'mobile_number': mobileNumber,
          'plan': int.parse(planId),
          'Ported_number': isPortedNumber,
          'idempotency_key': transactionId, // Prevent duplicate charges
          'transaction_id': transactionId, // For tracking pricing info
          'user_id': userId, // For audit trail
        },
      );

      debugPrint('📡 Edge Function Response: $response');

      // Parse response - FunctionResponse.data contains the JSON response body
      final responseBody = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : jsonDecode(response.data.toString()) as Map<String, dynamic>;

      debugPrint('📋 Parsed response: $responseBody');

      if (responseBody['success'] == true) {
        final data = responseBody['data'] as Map<String, dynamic>;
        
        // Extract pricing info from Edge Function response
        final sellPrice = data['sell_price'] as num?;
        final costPrice = data['cost_price'] as num?;
        final profit = data['profit'] as num?;
        
        // Update transaction with pricing and success status
        await supabase
            .from('hazpay_transactions')
            .update({
              'status': 'success',
              'reference': data['reference'],
              'sell_price': sellPrice,
              'cost_price': costPrice,
              'profit': profit,
            })
            .eq('id', transactionId);

        // Deduct from wallet (use sell_price - what user paid)
        await _deductFromWallet(userId, sellPrice != null ? sellPrice.toDouble() : amount);

        debugPrint('✅ Data purchase successful: ${data['reference']} (Profit: ₦${profit ?? 0})');
        
        return HazPayTransaction(
          id: transactionId,
          userId: userId,
          type: 'purchase',
          amount: sellPrice != null ? sellPrice.toDouble() : amount,
          networkName: networkId == 1 ? 'MTN' : 'GLO',
          dataCapacity: planId,
          mobileNumber: mobileNumber,
          reference: data['reference'],
          status: 'success',
          createdAt: DateTime.now(),
        );
      } else {
        final error = responseBody['error'] as Map<String, dynamic>;
        final errorMessage = error['message'] ?? 'Purchase failed';
        final errorCode = error['code'] ?? 'UNKNOWN_ERROR';
        
        // Update transaction as failed
        await supabase
            .from('hazpay_transactions')
            .update({
              'status': 'failed',
              'error_message': '$errorCode: $errorMessage',
            })
            .eq('id', transactionId);

        throw Exception('$errorCode: $errorMessage');
      }
    } catch (e) {
      debugPrint('❌ Error purchasing data: $e');
      rethrow;
    }
  }

  /// Get user's wallet
  Future<HazPayWallet> getWallet() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await supabase
          .from('hazpay_wallets')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null) {
        return HazPayWallet.fromJson(response);
      } else {
        // Create wallet if doesn't exist
        return await _createWallet(userId);
      }
    } catch (e) {
      debugPrint('❌ Error getting wallet: $e');
      rethrow;
    }
  }

  /// Add funds to wallet via Paystack payment
  /// Initiates a Paystack payment and adds funds upon successful completion
  Future<bool> depositToWallet(double amount) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      if (amount <= 0) throw Exception('Amount must be greater than 0');

      final user = supabase.auth.currentUser;
      if (user?.email == null) throw Exception('User email not found');

      debugPrint('💰 Initiating Paystack deposit: ₦$amount');

      // Generate unique reference for this transaction
      final transactionId = _generateId();
      final reference = 'HAZPAY-$transactionId';

      // Create pending deposit transaction
      final transaction = HazPayTransaction(
        id: transactionId,
        userId: userId,
        type: 'deposit',
        amount: amount,
        reference: reference,
        status: 'pending',
        createdAt: DateTime.now(),
      );

      // Save pending transaction
      await supabase.from('hazpay_transactions').insert(transaction.toJson());

      // Initiate Paystack payment
      final amountInNaira = amount.toInt();
      final userEmail = user?.email;
      if (userEmail == null) {
        throw Exception('User email is required for payment');
      }
      
      final paymentSuccessful = await PaystackService.chargeCard(
        email: userEmail,
        amountInNaira: amountInNaira,
        reference: reference,
      );

      if (paymentSuccessful) {
        // Payment successful - add funds to wallet
        await _addToWallet(userId, amount);

        // Update transaction as completed
        await supabase
            .from('hazpay_transactions')
            .update({
              'status': 'success',
            })
            .eq('id', transactionId);

        // Save deposit record
        await supabase.from('hazpay_deposits').insert({
          'id': _generateId(),
          'user_id': userId,
          'amount': amount,
          'reference': reference,
          'status': 'completed',
          'created_at': DateTime.now().toIso8601String(),
        });

        debugPrint('✅ Deposit successful: ₦$amount added to wallet');

        // Check if user has active loan and auto-repay if balance is sufficient
        await _checkAndRepayLoan(userId);

        return true;
      } else {
        // Payment failed - mark transaction as failed
        await supabase
            .from('hazpay_transactions')
            .update({
              'status': 'failed',
              'error_message': 'Payment cancelled or failed',
            })
            .eq('id', transactionId);

        debugPrint('❌ Payment failed or cancelled');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error depositing: $e');
      rethrow;
    }
  }

  /// Get transaction history
  Future<List<HazPayTransaction>> getTransactionHistory({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await supabase
          .from('hazpay_transactions')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List)
          .map((t) => HazPayTransaction.fromJson(t))
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting transaction history: $e');
      rethrow;
    }
  }

  /// Get loan history for the current user
  Future<List<HazPayLoan>> getLoanHistory({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await supabase
          .from('loans')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List).map((l) => HazPayLoan.fromJson(l)).toList();
    } catch (e) {
      debugPrint('❌ Error getting loan history: $e');
      rethrow;
    }
  }

  /// Get wallet balance stream for real-time updates
  Stream<double> watchWalletBalance() {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      return Stream.error('User not authenticated');
    }

    return supabase
        .from('hazpay_wallets')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((list) {
          if (list.isNotEmpty) {
            return (list.first['balance'] as num).toDouble();
          }
          return 0.0;
        });
  }

  // Private helper methods

  Future<HazPayWallet> _createWallet(String userId) async {
    final walletId = _generateId();
    await supabase.from('hazpay_wallets').insert({
      'id': walletId,
      'user_id': userId,
      'balance': 0.0,
      'total_transactions': 0,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });

    return HazPayWallet(
      id: walletId,
      userId: userId,
      balance: 0.0,
      totalTransactions: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Future<void> _addToWallet(String userId, double amount) async {
    try {
      // Get current wallet
      final wallet = await getWallet();
      final newBalance = wallet.balance + amount;
      
      // Direct update (RLS ensures user can only update their own wallet)
      await supabase
          .from('hazpay_wallets')
          .update({
            'balance': newBalance,
            'total_transactions': wallet.totalTransactions + 1,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId);
      
      debugPrint('✅ Added ₦$amount to wallet. New balance: ₦$newBalance');
    } catch (e) {
      debugPrint('❌ Error adding to wallet: $e');
      rethrow;
    }
  }

  Future<void> _deductFromWallet(String userId, double amount) async {
    try {
      // Get current wallet
      final wallet = await getWallet();
      
      if (wallet.balance < amount) {
        throw Exception('Insufficient wallet balance (have ₦${wallet.balance}, need ₦$amount)');
      }

      final newBalance = wallet.balance - amount;
      
      // Direct update (RLS ensures user can only update their own wallet)
      await supabase
          .from('hazpay_wallets')
          .update({
            'balance': newBalance,
            'total_transactions': wallet.totalTransactions + 1,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId);
      
      debugPrint('✅ Deducted ₦$amount from wallet. New balance: ₦$newBalance');
    } catch (e) {
      debugPrint('❌ Error deducting from wallet: $e');
      rethrow;
    }
  }

  /// Check if user is eligible for a loan
  Future<Map<String, dynamic>> checkLoanEligibility() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      debugPrint('🔍 Checking loan eligibility for user: $userId');

      // Get total transaction volume
      final transactions = await supabase
          .from('hazpay_transactions')
          .select()
          .eq('user_id', userId)
          .eq('type', 'purchase')
          .eq('status', 'success');

      final totalSpent = (transactions as List)
          .fold<double>(0, (sum, t) => sum + (t['sell_price'] as num).toDouble());

      // Check for active loan
      final activeLoans = await supabase
          .from('loans')
          .select()
          .eq('user_id', userId)
          .inFilter('status', ['pending', 'issued']);

      final hasActiveLoan = (activeLoans as List).isNotEmpty;
      final eligible = totalSpent >= 10000 && !hasActiveLoan;

      debugPrint('📊 Loan eligibility: eligible=$eligible, totalSpent=₦$totalSpent, hasActiveLoan=$hasActiveLoan');

      return {
        'eligible': eligible,
        'totalSpent': totalSpent,
        'hasActiveLoan': hasActiveLoan,
        'requiredAmount': 10000.0,
        'remainingAmount': (10000 - totalSpent).clamp(0, 10000),
      };
    } catch (e) {
      debugPrint('❌ Error checking loan eligibility: $e');
      rethrow;
    }
  }

  /// Request a 1GB loan
  Future<Map<String, dynamic>> requestLoan({String? mobileNumber, int? networkId}) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      debugPrint('💰 Requesting 1GB loan for user: $userId');

      // Call Edge Function
      final Map<String, dynamic> body = {
        'user_id': userId,
      };
      if (mobileNumber != null) body['mobile_number'] = mobileNumber;
      if (networkId != null) body['network'] = networkId;

      final response = await supabase.functions.invoke(
        'requestLoan',
        body: body,
      );

      debugPrint('📡 Loan request response: $response');

      final responseBody = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : jsonDecode(response.data.toString()) as Map<String, dynamic>;

      if (responseBody['success'] == true) {
        final data = responseBody['data'] as Map<String, dynamic>;
        debugPrint('✅ Loan request successful: ${data['loan_id']}');
        return {
          'success': true,
          'loan_id': data['loan_id'],
          'status': data['status'],
          'message': data['message'],
        };
      } else {
        final error = responseBody['error'] as Map<String, dynamic>;
        debugPrint('❌ Loan request failed: ${error['message']}');
        throw Exception('${error['code']}: ${error['message']}');
      }
    } catch (e) {
      debugPrint('❌ Error requesting loan: $e');
      rethrow;
    }
  }

  /// Get active loan for user
  Future<HazPayLoan?> getActiveLoan() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final loans = await supabase
          .from('loans')
          .select()
          .eq('user_id', userId)
          .inFilter('status', ['pending', 'issued'])
          .order('created_at', ascending: false);

      if ((loans as List).isEmpty) {
        return null;
      }

      return HazPayLoan.fromJson(loans[0]);
    } catch (e) {
      debugPrint('❌ Error getting active loan: $e');
      return null;
    }
  }

  /// Check for auto-repayment of active loan
  Future<void> _checkAndRepayLoan(String userId) async {
    try {
      // Get active loan
      final loans = await supabase
          .from('loans')
          .select()
          .eq('user_id', userId)
          .eq('status', 'issued');

      if ((loans as List).isEmpty) {
        return;
      }

      final loan = loans[0];
      final loanFee = (loan['loan_fee'] as num).toDouble();

      // Get wallet balance
      final wallet = await getWallet();

      if (wallet.balance >= loanFee) {
        debugPrint('💳 Auto-repaying loan: ₦$loanFee (wallet balance: ₦${wallet.balance})');

        // Deduct from wallet
        await _deductFromWallet(userId, loanFee);

        // Mark loan as repaid
        await supabase
            .from('loans')
            .update({
              'status': 'repaid',
              'repaid_at': DateTime.now().toIso8601String(),
            })
            .eq('id', loan['id']);

        debugPrint('✅ Loan repaid automatically');
      }
    } catch (e) {
      debugPrint('⚠️ Error checking auto-repayment: $e');
      // Don't rethrow - this is a background operation
    }
  }

  // ============= REWARDED ADS SYSTEM =============

  /// Get user's current points
  Future<UserPoints?> getUserPoints() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await supabase
          .from('user_points')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null) {
        return UserPoints.fromJson(response);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting user points: $e');
      return null;
    }
  }

  /// Get today's ad watch count
  Future<int> getTodayAdCount() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Get today's date in UTC (format: YYYY-MM-DD)
      final todayDate = DateTime.now().toUtc().toString().split(' ')[0];
      
      debugPrint('🔍 Checking ad count for userId=$userId, date=$todayDate');

      final response = await supabase
          .from('daily_ad_limits')
          .select()
          .eq('user_id', userId)
          .eq('limit_date', todayDate)
          .maybeSingle();

      final count = (response?['ads_watched_today'] as int?) ?? 0;
      debugPrint('✅ Today ad count: $count');
      return count;
    } catch (e) {
      debugPrint('⚠️ Error getting today ad count: $e');
      return 0;
    }
  }

  /// Check if user can watch more ads (max 10 per day)
  Future<bool> canWatchMoreAds() async {
    final todayCount = await getTodayAdCount();
    return todayCount < 10;
  }

  /// Record ad watched and add 1 point
  Future<bool> recordAdWatched(String adUnitId) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Check daily limit
      final canWatch = await canWatchMoreAds();
      if (!canWatch) {
        debugPrint('⚠️ User reached daily ad limit (10 ads)');
        return false;
      }

      debugPrint('🎬 Recording ad watched and adding 1 point...');

      // 0. Ensure user_points record exists
      try {
        final existingPoints = await supabase
            .from('user_points')
            .select()
            .eq('user_id', userId)
            .maybeSingle();
        
        if (existingPoints == null) {
          debugPrint('📋 Creating user_points record...');
          await supabase.from('user_points').insert({
            'user_id': userId,
            'points': 0,
            'total_points_earned': 0,
            'total_redemptions': 0,
          });
        }
      } catch (e) {
        debugPrint('⚠️ Note: user_points init: $e (may already exist)');
      }

      // 1. Insert into reward_ads_watched
      final adWatchResult = await supabase.from('reward_ads_watched').insert({
        'user_id': userId,
        'ad_unit_id': adUnitId,
        'points_earned': 1,
        'watched_at': DateTime.now().toIso8601String(),
      }).then((_) => true).catchError((e) {
        debugPrint('❌ Failed to insert ad watch record: $e');
        throw Exception('Failed to record ad watch: $e');
      });

      if (!adWatchResult) {
        throw Exception('Failed to insert ad watch record');
      }

      debugPrint('✅ Ad watch recorded in database');

      // 2. Increment points in user_points via RPC
      try {
        final pointsResult = await supabase.rpc('add_points', params: {
          'p_user_id': userId,
          'p_points': 1,
        });
        debugPrint('✅ Points incremented via RPC: $pointsResult');
      } catch (e) {
        debugPrint('❌ Failed to add points via RPC: $e');
        throw Exception('Failed to add points: $e');
      }

      // 3. Increment daily ad count via RPC
      try {
        final adCountResult = await supabase.rpc('increment_daily_ad_count', params: {
          'p_user_id': userId,
        });
        debugPrint('✅ Daily ad count incremented: $adCountResult');
      } catch (e) {
        debugPrint('❌ Failed to increment daily ad count: $e');
        throw Exception('Failed to increment daily ad count: $e');
      }

      // 4. Verify points were actually added (sanity check)
      try {
        final verifyPoints = await getUserPoints();
        if (verifyPoints != null) {
          debugPrint('✅ Verification - Current points: ${verifyPoints.points}');
        }
      } catch (e) {
        debugPrint('⚠️ Could not verify points: $e');
      }

      debugPrint('✅ Ad recorded successfully: +1 point');
      return true;
    } catch (e) {
      debugPrint('❌ Error recording ad: $e');
      return false;
    }
  }

  /// Diagnostic helper - fetch recent ad watch records for current user
  Future<List<Map<String, dynamic>>> getRecentAdWatches({int limit = 10}) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await supabase
          .from('reward_ads_watched')
          .select()
          .eq('user_id', userId)
          .order('watched_at', ascending: false)
          .limit(limit);

      final rows = response as List<dynamic>?;
      if (rows == null) return [];
      return rows.map<Map<String, dynamic>>((r) => Map<String, dynamic>.from(r as Map)).toList();
    } catch (e) {
      debugPrint('⚠️ Error fetching recent ad watches: $e');
      return [];
    }
  }

  /// Redeem 100 points for 500MB data (free)
  Future<Map<String, dynamic>> redeemPointsForData({
    required int networkId, // 1 for MTN, 2 for GLO
    required String mobileNumber,
  }) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final userPoints = await getUserPoints();
      if (userPoints == null || userPoints.points < 100) {
        debugPrint('❌ Insufficient points: ${userPoints?.points ?? 0}/100');
        throw Exception('You need at least 100 points to redeem.');
      }

      debugPrint('💰 Redeeming 100 points for 500MB ${networkId == 1 ? 'MTN' : 'GLO'}...');

      // 1. Create redemption record (pending)
      // Note: `id` column is a UUID in the DB. Do NOT insert a non-UUID
      // string (like our local hazpay_... id). Let the DB generate the UUID
      // and read it back. We can still use an idempotency key string for
      // the external API call.
      final idempotencyKey = _generateId(); // safe string for external calls
      final inserted = await supabase
          .from('reward_redemptions')
          .insert({
            'user_id': userId,
            'points_spent': 100,
            'data_amount': '500MB',
            'network_id': networkId,
            'status': 'pending',
          })
          .select()
          .maybeSingle();

      final redemptionId = inserted != null ? (inserted['id'] as String) : null;

      // 2. Deduct points using RPC
      await supabase.rpc('redeem_points', params: {
        'p_user_id': userId,
        'p_points': 100,
      });

      // 3. Call buyData Edge Function to issue 500MB
      // Plan ID for 500MB: check your pricing table
      const plan500MBId = 1; // Adjust based on your pricing table
      
      final purchaseResponse = await supabase.functions.invoke(
        'buyData',
        body: {
          'network': networkId,
          'mobile_number': mobileNumber,
          'plan': plan500MBId,
          'Ported_number': false,
          'idempotency_key': idempotencyKey,
          'is_reward': true, // Mark as free reward
          'user_id': userId,
        },
      );

      final responseBody = purchaseResponse.data is Map<String, dynamic>
          ? purchaseResponse.data as Map<String, dynamic>
          : jsonDecode(purchaseResponse.data.toString()) as Map<String, dynamic>;

      if (responseBody['success'] == true) {
        // 4. Update redemption to issued
        if (redemptionId != null) {
          await supabase
              .from('reward_redemptions')
              .update({
                'status': 'issued',
                'redeemed_at': DateTime.now().toIso8601String(),
                'transaction_id': responseBody['data']?['reference'],
              })
              .eq('id', redemptionId);
        } else {
          // Fallback: update by user + recent pending record (best-effort)
          await supabase
              .from('reward_redemptions')
              .update({
                'status': 'issued',
                'redeemed_at': DateTime.now().toIso8601String(),
                'transaction_id': responseBody['data']?['reference'],
              })
              .eq('user_id', userId)
              .eq('status', 'pending')
              .order('created_at', ascending: false)
              .limit(1);
        }

        debugPrint('✅ Redeemed 100 points for 500MB!');
        return {
          'success': true,
          'message': '500MB credited to your account!',
          'redemption_id': redemptionId,
        };
      } else {
        final error = responseBody['error'] as Map<String, dynamic>;
        // Refund points on failure
        await supabase.rpc('add_points', params: {
          'p_user_id': userId,
          'p_points': 100,
        });

        // Update redemption to failed
        if (redemptionId != null) {
          await supabase
              .from('reward_redemptions')
              .update({
                'status': 'failed',
                'failure_reason': error['message'] ?? 'Unknown error',
              })
              .eq('id', redemptionId);
        } else {
          await supabase
              .from('reward_redemptions')
              .update({
                'status': 'failed',
                'failure_reason': error['message'] ?? 'Unknown error',
              })
              .eq('user_id', userId)
              .eq('status', 'pending')
              .order('created_at', ascending: false)
              .limit(1);
        }

        throw Exception('${error['code']}: ${error['message']}');
      }
    } catch (e) {
      debugPrint('❌ Error redeeming points: $e');
      rethrow;
    }
  }

  /// Get redemption history
  Future<List<Map<String, dynamic>>> getRedemptionHistory({
    int limit = 20,
  }) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await supabase
          .from('reward_redemptions')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('❌ Error getting redemption history: $e');
      return [];
    }
  }

  String _generateId() {
    return 'hazpay_${DateTime.now().millisecondsSinceEpoch}_${(DateTime.now().microsecond % 1000).toString().padLeft(3, '0')}';
  }
}
