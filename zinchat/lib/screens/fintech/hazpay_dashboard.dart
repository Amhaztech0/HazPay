import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:zinchat/services/hazpay_service.dart';
import '../../providers/theme_provider.dart';
import '../../models/app_theme.dart';
import '../../utils/helpers.dart';
import 'buy_data_screen.dart';
import 'wallet_screen.dart';
import 'transaction_history_screen.dart';
import 'loan_screen.dart';
import 'rewarded_ads_screen.dart';
import 'pay_bills_screen.dart';

class HazPayDashboard extends StatefulWidget {
  const HazPayDashboard({super.key});

  @override
  State<HazPayDashboard> createState() => _HazPayDashboardState();
}

class _HazPayDashboardState extends State<HazPayDashboard> {
  final hazPayService = HazPayService();
  bool _balanceVisible = true;

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final theme = themeProvider.currentTheme;

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.cardBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: theme.textPrimary),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
        ),
        title: Text(
          'HazPay Wallet',
          style: TextStyle(
            color: theme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_outlined, color: theme.textPrimary),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Wallet Card
            Padding(
              padding: const EdgeInsets.all(16),
              child: _buildModernBalanceCard(theme),
            ),

            // Quick Actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildQuickActionsGrid(context, theme),
            ),
            const SizedBox(height: 24),

            // Services Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SERVICES',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildServicesGrid(context, theme),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Transactions Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'RECENT TRANSACTIONS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TransactionHistoryScreen(),
                        ),
                      );
                    },
                    child: Text(
                      'View All',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildRecentTransactions(theme),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildModernBalanceCard(AppTheme theme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.primaryColor, theme.secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.primaryColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Wallet Balance',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: const Text(
                  'NGN',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: StreamBuilder<double>(
                  stream: hazPayService.watchWalletBalance(),
                  builder: (context, snapshot) {
                    final balance = snapshot.data ?? 0.0;
                    return Text(
                      _balanceVisible
                          ? formatNaira(balance)
                          : '₦****.**',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    );
                  },
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _balanceVisible = !_balanceVisible),
                child: Icon(
                  _balanceVisible ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white.withOpacity(0.8),
                  size: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const WalletScreen()),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Add Money',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TransactionHistoryScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    'History',
                    style: TextStyle(
                      color: theme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid(BuildContext context, AppTheme theme) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.8,
      children: [
        _buildQuickActionButton(
          icon: Icons.arrow_downward_rounded,
          label: 'Receive',
          color: theme.success,
          theme: theme,
          onTap: () {},
        ),
        _buildQuickActionButton(
          icon: Icons.arrow_upward_rounded,
          label: 'Send',
          color: theme.secondaryColor,
          theme: theme,
          onTap: () {},
        ),
        _buildQuickActionButton(
          icon: Icons.qr_code_rounded,
          label: 'Scan',
          color: theme.primaryColor,
          theme: theme,
          onTap: () {},
        ),
        _buildQuickActionButton(
          icon: Icons.more_horiz_rounded,
          label: 'More',
          color: theme.textSecondary,
          theme: theme,
          onTap: () {},
        ),
      ],
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required AppTheme theme,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(12),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServicesGrid(BuildContext context, AppTheme theme) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1,
      children: [
        _buildServiceTile(
          icon: Icons.sim_card_download_rounded,
          label: 'Buy Data',
          color: theme.primaryColor,
          theme: theme,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BuyDataScreen()),
            );
          },
        ),
        _buildServiceTile(
          icon: Icons.receipt_long_rounded,
          label: 'Pay Bills',
          color: theme.secondaryColor,
          theme: theme,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PayBillsScreen()),
            );
          },
        ),
        _buildServiceTile(
          icon: Icons.card_giftcard_rounded,
          label: 'Loans',
          color: theme.success,
          theme: theme,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LoanScreen()),
            );
          },
        ),
        _buildServiceTile(
          icon: Icons.star_rounded,
          label: 'Rewards',
          color: theme.primaryColor,
          theme: theme,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RewardedAdsScreen()),
            );
          },
        ),
        _buildServiceTile(
          icon: Icons.savings_rounded,
          label: 'Savings',
          color: theme.secondaryColor,
          theme: theme,
          onTap: () {},
        ),
        _buildServiceTile(
          icon: Icons.more_horiz_rounded,
          label: 'More',
          color: theme.textSecondary,
          theme: theme,
          onTap: () {},
        ),
      ],
    );
  }

  Widget _buildServiceTile({
    required IconData icon,
    required String label,
    required Color color,
    required AppTheme theme,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardBackground,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(14),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTransactions(AppTheme theme) {
    return FutureBuilder<List<HazPayTransaction>>(
      future: hazPayService.getTransactionHistory(limit: 5),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator(color: theme.primaryColor)),
          );
        }

        final transactions = snapshot.data ?? [];

        if (transactions.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: theme.cardBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 48, color: theme.textSecondary),
                    const SizedBox(height: 12),
                    Text(
                      'No transactions yet',
                      style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final tx = transactions[index];
              return Container(
                decoration: BoxDecoration(
                  color: theme.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: _getTransactionColor(tx.type, theme).withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(10),
                      child: Icon(
                        _getTransactionIcon(tx.type),
                        color: _getTransactionColor(tx.type, theme),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tx.networkName ?? tx.type,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: theme.textPrimary,
                            ),
                          ),
                          Text(
                            '${tx.status[0].toUpperCase()}${tx.status.substring(1)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '-${formatNaira(tx.amount, decimals: 0)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: theme.textPrimary,
                          ),
                        ),
                        Text(
                          '${tx.createdAt.day}/${tx.createdAt.month}',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  IconData _getTransactionIcon(String type) {
    switch (type) {
      case 'purchase':
        return Icons.sim_card_download_rounded;
      case 'deposit':
        return Icons.arrow_downward_rounded;
      case 'withdrawal':
        return Icons.arrow_upward_rounded;
      default:
        return Icons.swap_horiz_rounded;
    }
  }

  Color _getTransactionColor(String type, AppTheme theme) {
    switch (type) {
      case 'purchase':
        return theme.primaryColor;
      case 'deposit':
        return theme.success;
      case 'withdrawal':
        return theme.secondaryColor;
      default:
        return theme.textSecondary;
    }
  }
}


