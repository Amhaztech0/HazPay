import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zinchat/services/hazpay_service.dart';
import 'pay_electricity_bill_screen.dart';
import 'pay_cable_bill_screen.dart';
import '../../providers/theme_provider.dart';
import '../../utils/helpers.dart';

class PayBillsScreen extends StatefulWidget {
  const PayBillsScreen({Key? key}) : super(key: key);

  @override
  State<PayBillsScreen> createState() => _PayBillsScreenState();
}

class _PayBillsScreenState extends State<PayBillsScreen> {
  final hazPayService = HazPayService();
  List<BillPayment> _recentBills = [];
  bool _isLoading = true;
  double? _walletBalance;
  bool _balanceVisible = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final bills = await hazPayService.getBillPaymentHistory(limit: 10);
      final wallet = await hazPayService.getWallet();

      setState(() {
        _recentBills = bills;
        _walletBalance = wallet.balance;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Error loading data: $e');
    }
  }

  void _refreshData() {
    setState(() => _isLoading = true);
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>().currentTheme;

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: theme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Pay Bills',
          style: TextStyle(
            color: theme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.history, color: theme.textPrimary),
            onPressed: () {
              // Navigate to full history
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refreshData(),
        color: theme.primaryColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Balance Card
                _buildBalanceCard(theme),
                const SizedBox(height: 28),

                // Services Section
                Text(
                  'What would you like to pay?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                _buildServicesGrid(theme),
                const SizedBox(height: 28),

                // Recent Payments Section
                _buildRecentPaymentsSection(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceCard(dynamic theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.primaryColor,
            theme.secondaryColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.primaryColor.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Available Balance',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _balanceVisible = !_balanceVisible),
                child: Icon(
                  _balanceVisible ? Icons.visibility : Icons.visibility_off,
                  color: Colors.white70,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _balanceVisible
                ? (_walletBalance != null
                    ? formatNaira(_walletBalance!)
                    : 'Loading...')
                : '₦••••••',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bolt, color: Colors.white, size: 16),
                SizedBox(width: 4),
                Text(
                  'Bills & Utilities',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesGrid(dynamic theme) {
    return Row(
      children: [
        Expanded(
          child: _buildServiceCard(
            theme: theme,
            icon: Icons.flash_on,
            iconColor: theme.warning,
            title: 'Electricity',
            subtitle: '9 Power Discos',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PayElectricityBillScreen(),
                ),
              ).then((_) => _refreshData());
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildServiceCard(
            theme: theme,
            icon: Icons.tv,
            iconColor: theme.info,
            title: 'Cable TV',
            subtitle: '4 Providers',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PayCableBillScreen(),
                ),
              ).then((_) => _refreshData());
            },
          ),
        ),
      ],
    );
  }

  Widget _buildServiceCard({
    required dynamic theme,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.divider,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: theme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentPaymentsSection(dynamic theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Payments',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.textPrimary,
              ),
            ),
            TextButton(
              onPressed: () {
                // Navigate to full history
              },
              child: Text(
                'See All',
                style: TextStyle(
                  color: theme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoading)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: CircularProgressIndicator(
                color: theme.primaryColor,
                strokeWidth: 2,
              ),
            ),
          )
        else if (_recentBills.isEmpty)
          _buildEmptyState(theme)
        else
          ..._recentBills.take(5).map((bill) => _buildPaymentItem(theme, bill)),
      ],
    );
  }

  Widget _buildEmptyState(dynamic theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: theme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.divider),
      ),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: theme.greyLight,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.receipt_long_outlined,
              size: 32,
              color: theme.grey,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No bill payments yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your bill payment history will appear here',
            style: TextStyle(
              fontSize: 14,
              color: theme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentItem(dynamic theme, BillPayment bill) {
    final isSuccess = bill.status == 'success';
    final isElectricity = bill.billType == 'electricity';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.divider),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: (isSuccess ? theme.success : theme.error).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isElectricity ? Icons.flash_on : Icons.tv,
              color: isSuccess ? theme.success : theme.error,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bill.billType[0].toUpperCase() + bill.billType.substring(1),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: theme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${bill.provider.toUpperCase()} • ${_formatDate(bill.createdAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Amount & Status
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatNaira(bill.amount),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: theme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: (isSuccess ? theme.success : theme.error).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isSuccess ? 'Success' : 'Failed',
                  style: TextStyle(
                    fontSize: 11,
                    color: isSuccess ? theme.success : theme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return 'Today';
    } else if (dateOnly == yesterday) {
      return 'Yesterday';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
