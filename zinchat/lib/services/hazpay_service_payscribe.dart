import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'paystack_service.dart';

// ============================================================================
// DATA MODELS
// ============================================================================

// Network Enum
enum DataNetwork {
  mtn(1, 'MTN'),
  glo(2, 'GLO'),
  airtel(3, 'Airtel'),
  nmobile(4, '9Mobile'),
  smile(5, 'SMILE');

  final int id;
  final String name;
  const DataNetwork(this.id, this.name);

  static DataNetwork fromId(int id) {
    return values.firstWhere((e) => e.id == id);
  }
}

// Data Plan Model
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
      capacity: (json['data_size'] ?? '0MB').contains('GB')
          ? double.parse(json['data_size'].replaceAll('GB', '').trim())
          : double.parse(json['data_size'].replaceAll('MB', '').trim()) / 1024,
      validity: 30,
      price: (json['sell_price'] ?? 0).toDouble(),
      efficiency: 100.0,
      efficiencyLabel: 'Custom',
    );
  }
}

// Transaction Model
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

// Loan Model
class HazPayLoan {
  final String id;
  final String userId;
  final int planId;
  final double loanFee;
  final String status;
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

// Wallet Model
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

// Bill Payment Model
class BillPayment {
  final String id;
  final String userId;
  final String billType; // 'electricity', 'cable'
  final String provider; // 'ikedc', 'dstv', etc.
  final String accountNumber;
  final String? customerName;
  final double amount;
  final String? reference;
  final String status;
  final DateTime createdAt;
  final String? errorMessage;

  BillPayment({
    required this.id,
    required this.userId,
    required this.billType,
    required this.provider,
    required this.accountNumber,
    this.customerName,
    required this.amount,
    this.reference,
    required this.status,
    required this.createdAt,
    this.errorMessage,
  });

  factory BillPayment.fromJson(Map<String, dynamic> json) {
    return BillPayment(
      id: json['id'],
      userId: json['user_id'],
      billType: json['bill_type'],
      provider: json['provider'],
      accountNumber: json['account_number'],
      customerName: json['customer_name'],
      amount: (json['amount'] ?? 0).toDouble(),
      reference: json['reference'],
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
      errorMessage: json['error_message'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'bill_type': billType,
    'provider': provider,
    'account_number': accountNumber,
    'customer_name': customerName,
    'amount': amount,
    'reference': reference,
    'status': status,
    'created_at': createdAt.toIso8601String(),
    'error_message': errorMessage,
  };
}

// User Points Model
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

// ============================================================================
// HAZPAY SERVICE - PAYSCRIBE INTEGRATION
// ============================================================================

class HazPayService {
  final supabase = Supabase.instance.client;
  
  // Cache for data plans
  static final Map<int, List<DataPlan>> _plansCache = {};

  /// Get data plans from Supabase pricing table
  /// Supports: MTN (1), GLO (2), Airtel (3), 9Mobile (4), SMILE (5)
  Future<Map<String, List<DataPlan>>> getDataPlans() async {
    try {
      debugPrint('🔄 Fetching data plans...');

      final response = await supabase
          .from('pricing')
          .select()
          .order('network_id', ascending: true)
          .order('plan_id', ascending: true);

      if (response.isNotEmpty) {
        debugPrint('✅ Fetched ${response.length} plans');

        final mtnPlans = <DataPlan>[];
        final gloPlans = <DataPlan>[];
        final airtelPlans = <DataPlan>[];
        final nmobilePlans = <DataPlan>[];
        final smilePlans = <DataPlan>[];

        for (var plan in response) {
          final dataPlan = DataPlan.fromJson(
            plan,
            DataNetwork.fromId(plan['network_id'] as int).name,
            plan['network_id'] as int,
          );

          switch (plan['network_id']) {
            case 1:
              mtnPlans.add(dataPlan);
            case 2:
              gloPlans.add(dataPlan);
            case 3:
              airtelPlans.add(dataPlan);
            case 4:
              nmobilePlans.add(dataPlan);
            case 5:
              smilePlans.add(dataPlan);
          }
        }

        _plansCache[1] = mtnPlans;
        _plansCache[2] = gloPlans;
        _plansCache[3] = airtelPlans;
        _plansCache[4] = nmobilePlans;
        _plansCache[5] = smilePlans;

        return {
          'MTN': mtnPlans,
          'GLO': gloPlans,
          'Airtel': airtelPlans,
          '9Mobile': nmobilePlans,
          'SMILE': smilePlans,
        };
      } else {
        debugPrint('⚠️ Pricing table empty, using cached plans');
        return {
          'MTN': _plansCache[1] ?? [],
          'GLO': _plansCache[2] ?? [],
          'Airtel': _plansCache[3] ?? [],
          '9Mobile': _plansCache[4] ?? [],
          'SMILE': _plansCache[5] ?? [],
        };
      }
    } catch (e) {
      debugPrint('❌ Error fetching plans: $e');
      rethrow;
    }
  }

  /// Purchase data via Payscribe Edge Function
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

      // Create transaction record (pending)
      final transactionId = _generateId();
      final transaction = HazPayTransaction(
        id: transactionId,
        userId: userId,
        type: 'purchase',
        amount: amount,
        networkName: DataNetwork.fromId(networkId).name,
        dataCapacity: planId,
        mobileNumber: mobileNumber,
        status: 'pending',
        createdAt: DateTime.now(),
      );

      await supabase.from('hazpay_transactions').insert(transaction.toJson());

      // Call Payscribe Edge Function
      debugPrint('🔐 Calling Payscribe Edge Function...');
      
      final response = await supabase.functions.invoke(
        'buyData',
        body: {
          'network': networkId,
          'mobile_number': mobileNumber,
          'plan': int.parse(planId),
          'Ported_number': isPortedNumber,
          'idempotency_key': transactionId,
          'transaction_id': transactionId,
          'user_id': userId,
        },
      );

      debugPrint('📡 Edge Function Response: $response');

      final responseBody = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : jsonDecode(response.data.toString()) as Map<String, dynamic>;

      if (responseBody['success'] == true) {
        final data = responseBody['data'] as Map<String, dynamic>;
        
        // Update transaction
        await supabase
            .from('hazpay_transactions')
            .update({
              'status': 'success',
              'reference': data['reference'],
            })
            .eq('id', transactionId);

        // Deduct from wallet
        await _deductFromWallet(userId, amount);

        debugPrint('✅ Data purchase successful: ${data['reference']}');
        
        return HazPayTransaction(
          id: transactionId,
          userId: userId,
          type: 'purchase',
          amount: amount,
          networkName: DataNetwork.fromId(networkId).name,
          dataCapacity: planId,
          mobileNumber: mobileNumber,
          reference: data['reference'],
          status: 'success',
          createdAt: DateTime.now(),
        );
      } else {
        final error = responseBody['error'] as Map<String, dynamic>;
        final errorMessage = error['message'] ?? 'Purchase failed';
        
        await supabase
            .from('hazpay_transactions')
            .update({
              'status': 'failed',
              'error_message': errorMessage,
            })
            .eq('id', transactionId);

        throw Exception(errorMessage);
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
        return await _createWallet(userId);
      }
    } catch (e) {
      debugPrint('❌ Error getting wallet: $e');
      rethrow;
    }
  }

  /// Deposit funds via Paystack
  Future<bool> depositToWallet(double amount) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      if (amount <= 0) throw Exception('Amount must be greater than 0');

      final user = supabase.auth.currentUser;
      if (user?.email == null) throw Exception('User email not found');

      debugPrint('💰 Initiating Paystack deposit: ₦$amount');

      final transactionId = _generateId();
      final reference = 'HAZPAY-$transactionId';

      final transaction = HazPayTransaction(
        id: transactionId,
        userId: userId,
        type: 'deposit',
        amount: amount,
        reference: reference,
        status: 'pending',
        createdAt: DateTime.now(),
      );

      await supabase.from('hazpay_transactions').insert(transaction.toJson());

      final amountInNaira = amount.toInt();
      final userEmail = user?.email;
      if (userEmail == null) {
        throw Exception('User email is required');
      }
      
      final paymentSuccessful = await PaystackService.chargeCard(
        email: userEmail,
        amountInNaira: amountInNaira,
        reference: reference,
      );

      if (paymentSuccessful) {
        await _addToWallet(userId, amount);

        await supabase
            .from('hazpay_transactions')
            .update({'status': 'success'})
            .eq('id', transactionId);

        await supabase.from('hazpay_deposits').insert({
          'id': _generateId(),
          'user_id': userId,
          'amount': amount,
          'reference': reference,
          'status': 'completed',
          'created_at': DateTime.now().toIso8601String(),
        });

        debugPrint('✅ Deposit successful: ₦$amount');

        await _checkAndRepayLoan(userId);

        return true;
      } else {
        await supabase
            .from('hazpay_transactions')
            .update({'status': 'failed', 'error_message': 'Payment cancelled'})
            .eq('id', transactionId);

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

  /// Check loan eligibility
  Future<Map<String, dynamic>> checkLoanEligibility() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final transactions = await supabase
          .from('hazpay_transactions')
          .select()
          .eq('user_id', userId)
          .eq('type', 'purchase')
          .eq('status', 'success');

      final totalSpent = (transactions as List)
          .fold<double>(0, (sum, t) => sum + (t['amount'] as num).toDouble());

      final activeLoans = await supabase
          .from('loans')
          .select()
          .eq('user_id', userId)
          .inFilter('status', ['pending', 'issued']);

      final hasActiveLoan = (activeLoans as List).isNotEmpty;
      final eligible = totalSpent >= 10000 && !hasActiveLoan;

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

  /// Request 1GB loan
  Future<Map<String, dynamic>> requestLoan({String? mobileNumber, int? networkId}) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      debugPrint('💰 Requesting 1GB loan');

      final body = {'user_id': userId} as Map<String, dynamic>;
      if (mobileNumber != null) body['mobile_number'] = mobileNumber;
      if (networkId != null) body['network'] = networkId;

      final response = await supabase.functions.invoke('requestLoan', body: body);

      final responseBody = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : jsonDecode(response.data.toString()) as Map<String, dynamic>;

      if (responseBody['success'] == true) {
        final data = responseBody['data'] as Map<String, dynamic>;
        return {
          'success': true,
          'loan_id': data['loan_id'],
          'status': data['status'],
          'message': data['message'],
        };
      } else {
        final error = responseBody['error'] as Map<String, dynamic>;
        throw Exception('${error['message']}');
      }
    } catch (e) {
      debugPrint('❌ Error requesting loan: $e');
      rethrow;
    }
  }

  /// Get active loan
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

  // ============================================================================
  // BILLS PAYMENT - NEW FEATURES
  // ============================================================================

  /// Pay electricity bill
  Future<BillPayment> payElectricityBill({
    required String discoCode, // e.g., 'ikedc', 'ekedc'
    required String meterNumber,
    required double amount,
    String? meterType, // 'prepaid' or 'postpaid', defaults to 'prepaid'
    String? customerName,
  }) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      debugPrint('⚡ Paying electricity bill: $discoCode, meter=$meterNumber, amount=₦$amount');

      final billId = _generateId();

      final bill = BillPayment(
        id: billId,
        userId: userId,
        billType: 'electricity',
        provider: discoCode,
        accountNumber: meterNumber,
        customerName: customerName,
        amount: amount,
        status: 'pending',
        createdAt: DateTime.now(),
      );

      await supabase.from('bills_payments').insert(bill.toJson());

      // Call Payscribe Edge Function
      debugPrint('🔐 Calling Payscribe Edge Function for electricity...');

      final response = await supabase.functions.invoke(
        'payBill',
        body: {
          'bill_type': 'electricity',
          'provider': discoCode,
          'account_number': meterNumber,
          'customer_name': customerName,
          'amount': amount,
          'ref': billId,
          'user_id': userId,
        },
      );

      final responseBody = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : jsonDecode(response.data.toString()) as Map<String, dynamic>;

      if (responseBody['success'] == true) {
        final data = responseBody['data'] as Map<String, dynamic>;

        await supabase
            .from('bills_payments')
            .update({
              'status': 'success',
              'reference': data['reference'],
            })
            .eq('id', billId);

        await _deductFromWallet(userId, amount);

        debugPrint('✅ Electricity bill paid: ${data['reference']}');

        return BillPayment(
          id: billId,
          userId: userId,
          billType: 'electricity',
          provider: discoCode,
          accountNumber: meterNumber,
          customerName: customerName,
          amount: amount,
          reference: data['reference'],
          status: 'success',
          createdAt: DateTime.now(),
        );
      } else {
        final error = responseBody['error'] as Map<String, dynamic>;
        final errorMessage = error['message'] ?? 'Bill payment failed';

        await supabase
            .from('bills_payments')
            .update({'status': 'failed', 'error_message': errorMessage})
            .eq('id', billId);

        throw Exception(errorMessage);
      }
    } catch (e) {
      debugPrint('❌ Error paying electricity bill: $e');
      rethrow;
    }
  }

  /// Pay cable subscription bill
  Future<BillPayment> payCableBill({
    required String cableProvider, // 'dstv', 'gotv', 'startimes'
    required String planId, // e.g., 'ng_dstv_hdprme36'
    required double amount,
    String? smartcardNumber,
  }) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      debugPrint('📺 Paying cable bill: $cableProvider, plan=$planId, amount=₦$amount');

      final billId = _generateId();

      final bill = BillPayment(
        id: billId,
        userId: userId,
        billType: 'cable',
        provider: cableProvider,
        accountNumber: planId,
        customerName: smartcardNumber,
        amount: amount,
        status: 'pending',
        createdAt: DateTime.now(),
      );

      await supabase.from('bills_payments').insert(bill.toJson());

      // Call Payscribe Edge Function
      final response = await supabase.functions.invoke(
        'payBill',
        body: {
          'bill_type': 'cable',
          'provider': cableProvider,
          'account_number': planId,
          'customer_name': smartcardNumber,
          'amount': amount,
          'ref': billId,
          'user_id': userId,
        },
      );

      final responseBody = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : jsonDecode(response.data.toString()) as Map<String, dynamic>;

      if (responseBody['success'] == true) {
        final data = responseBody['data'] as Map<String, dynamic>;

        await supabase
            .from('bills_payments')
            .update({
              'status': 'success',
              'reference': data['reference'],
            })
            .eq('id', billId);

        await _deductFromWallet(userId, amount);

        debugPrint('✅ Cable bill paid: ${data['reference']}');

        return BillPayment(
          id: billId,
          userId: userId,
          billType: 'cable',
          provider: cableProvider,
          accountNumber: planId,
          customerName: smartcardNumber,
          amount: amount,
          reference: data['reference'],
          status: 'success',
          createdAt: DateTime.now(),
        );
      } else {
        final error = responseBody['error'] as Map<String, dynamic>;
        final errorMessage = error['message'] ?? 'Bill payment failed';

        await supabase
            .from('bills_payments')
            .update({'status': 'failed', 'error_message': errorMessage})
            .eq('id', billId);

        throw Exception(errorMessage);
      }
    } catch (e) {
      debugPrint('❌ Error paying cable bill: $e');
      rethrow;
    }
  }

  /// Get bill payment history
  Future<List<BillPayment>> getBillPaymentHistory({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await supabase
          .from('bills_payments')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List)
          .map((b) => BillPayment.fromJson(b))
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting bill history: $e');
      rethrow;
    }
  }

  // ============================================================================
  // PRIVATE HELPERS
  // ============================================================================

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
      final wallet = await getWallet();
      final newBalance = wallet.balance + amount;
      
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
      final wallet = await getWallet();
      
      if (wallet.balance < amount) {
        throw Exception('Insufficient wallet balance (have ₦${wallet.balance}, need ₦$amount)');
      }

      final newBalance = wallet.balance - amount;
      
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

  Future<void> _checkAndRepayLoan(String userId) async {
    try {
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

      final wallet = await getWallet();

      if (wallet.balance >= loanFee) {
        debugPrint('💳 Auto-repaying loan: ₦$loanFee');

        await _deductFromWallet(userId, loanFee);

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
    }
  }

  String _generateId() {
    return 'hazpay_${DateTime.now().millisecondsSinceEpoch}_${(DateTime.now().microsecond % 1000).toString().padLeft(3, '0')}';
  }
}
