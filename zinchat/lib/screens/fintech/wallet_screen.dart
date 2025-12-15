import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:zinchat/services/hazpay_service.dart';
import '../../providers/theme_provider.dart';
import '../../models/app_theme.dart';
import '../../utils/helpers.dart';
import 'transaction_history_screen.dart';
import 'buy_data_screen.dart';
import 'pay_bills_screen.dart';
import 'loan_screen.dart';
import 'rewarded_ads_screen.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({Key? key}) : super(key: key);

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final hazPayService = HazPayService();
  HazPayWallet? _wallet;
  bool _isLoading = true;
  String? _errorMessage;
  bool _balanceVisible = true;

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    try {
      final wallet = await hazPayService.getWallet();
      setState(() {
        _wallet = wallet;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load wallet: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  /// Maps PayScribe bank codes to proper display names
  String _mapBankName(String? bankName) {
    final bankMap = {
      '9PSB': 'PalmPay',
      '9 Payment Service Bank': 'PalmPay',
      'WEMA BANK': 'Wema Bank',
      'PROVIDUS BANK': 'Providus Bank',
      'VFD MICROFINANCE BANK': 'VFD Bank',
      'STERLING BANK': 'Sterling Bank',
    };
    return bankMap[bankName?.toUpperCase()] ?? bankName ?? 'Bank';
  }

  void _showAddBalanceSheet() {
    final theme = context.read<ThemeProvider>().currentTheme;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddBalanceBottomSheet(
        theme: theme,
        onCreateAccount: _createVirtualAccount,
        mapBankName: _mapBankName,
      ),
    );
  }

  Future<Map<String, dynamic>?> _createVirtualAccount(double amount) async {
    try {
      return await hazPayService.depositToWallet(amount);
    } catch (e) {
      debugPrint('💥 Error creating virtual account: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final theme = themeProvider.currentTheme;

    return Scaffold(
      backgroundColor: theme.background,
      body: RefreshIndicator(
        onRefresh: _loadWallet,
        color: theme.primaryColor,
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: theme.primaryColor))
            : _errorMessage != null
                ? _buildErrorWidget(theme)
                : CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      // Custom App Bar with Pull to Refresh text
                      SliverToBoxAdapter(
                        child: SafeArea(
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  'Pull to refresh',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.textSecondary,
                                  ),
                                ),
                              ),
                              _buildHeader(theme),
                            ],
                          ),
                        ),
                      ),
                      // Balance Card
                      SliverToBoxAdapter(
                        child: _buildBalanceCard(theme),
                      ),
                      // Services Section
                      SliverToBoxAdapter(
                        child: _buildServicesSection(theme),
                      ),
                      // Referral Section
                      SliverToBoxAdapter(
                        child: _buildReferralSection(theme),
                      ),
                      // Recent Transactions
                      SliverToBoxAdapter(
                        child: _buildRecentTransactions(theme),
                      ),
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 100),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildHeader(AppTheme theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: theme.primaryColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                'AH',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Name and subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hi, ${_wallet?.id?.substring(0, 8) ?? 'User'}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.textPrimary,
                  ),
                ),
                Text(
                  'HazPay Wallet',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Settings icon
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.settings_outlined, color: theme.textPrimary),
          ),
          // Notifications icon
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.notifications_outlined, color: theme.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(AppTheme theme) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.primaryColor,
            theme.primaryColor.withBlue((theme.primaryColor.blue * 0.7).round()),
            theme.secondaryColor.withOpacity(0.9),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: theme.primaryColor.withOpacity(0.35),
            blurRadius: 25,
            offset: const Offset(0, 12),
            spreadRadius: -5,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative pattern overlay
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
          Positioned(
            left: -20,
            bottom: -40,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          // Main content
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row with wallet icon and visibility toggle
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'HazPay Balance',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _balanceVisible = !_balanceVisible),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _balanceVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Balance amount with animation-ready structure
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    _balanceVisible
                        ? formatNaira(_wallet?.balance ?? 0)
                        : '₦ • • • • • •',
                    key: ValueKey(_balanceVisible),
                    style: const TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -1,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Sub-balances row with glass morphism style
                Row(
                  children: [
                    _buildSubBalanceChip('💰 Cashback', formatNaira(0, decimals: 0)),
                    const SizedBox(width: 12),
                    _buildSubBalanceChip('🎁 Referral', formatNaira(0, decimals: 0)),
                  ],
                ),
                const SizedBox(height: 24),
                // Action buttons row
                Row(
                  children: [
                    _buildCardActionButton(
                      icon: Icons.add_rounded,
                      label: 'Add Money',
                      onTap: _showAddBalanceSheet,
                    ),
                    const SizedBox(width: 12),
                    _buildCardActionButton(
                      icon: Icons.send_rounded,
                      label: 'Transfer',
                      onTap: () {},
                    ),
                    const SizedBox(width: 12),
                    _buildCardActionButton(
                      icon: Icons.history_rounded,
                      label: 'History',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TransactionHistoryScreen())),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubBalanceChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Text(
        '$label $value',
        style: const TextStyle(
          fontSize: 12,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildCardActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubBalance(String label, String value, AppTheme theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.greyLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          fontSize: 12,
          color: theme.textSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required AppTheme theme,
    bool hasBadge = false,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: theme.greyLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: theme.textPrimary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.textPrimary,
                ),
              ),
              if (hasBadge) ...[
                const SizedBox(width: 4),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: theme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServicesSection(AppTheme theme) {
    return Padding(
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
          // First row of services
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardBackground,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: theme.primaryColor.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildServiceItem(
                      Icons.sim_card_download_rounded,
                      'Buy Data',
                      theme.primaryColor,
                      theme,
                      () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BuyDataScreen())),
                    ),
                    _buildServiceItem(
                      Icons.receipt_long_rounded,
                      'Pay Bills',
                      theme.secondaryColor,
                      theme,
                      () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PayBillsScreen())),
                    ),
                    _buildServiceItem(
                      Icons.card_giftcard_rounded,
                      'Data Loan',
                      theme.success,
                      theme,
                      () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoanScreen())),
                    ),
                    _buildServiceItem(
                      Icons.star_rounded,
                      'Rewards',
                      const Color(0xFFFFB300),
                      theme,
                      () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RewardedAdsScreen())),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildServiceItem(
                      Icons.history_rounded,
                      'History',
                      theme.primaryColor.withOpacity(0.8),
                      theme,
                      () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TransactionHistoryScreen())),
                    ),
                    _buildServiceItem(
                      Icons.savings_rounded,
                      'Savings',
                      const Color(0xFF26A69A),
                      theme,
                      () {}, // Coming soon
                    ),
                    _buildServiceItem(
                      Icons.phone_android_rounded,
                      'Airtime',
                      theme.error,
                      theme,
                      () {}, // Coming soon
                    ),
                    _buildServiceItem(
                      Icons.more_horiz_rounded,
                      'More',
                      theme.textSecondary,
                      theme,
                      () {}, // Coming soon
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceItem(IconData icon, String label, Color color, AppTheme theme, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: theme.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferralSection(AppTheme theme) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.primaryColor.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'REFERRAL',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TransactionHistoryScreen()),
                ),
                child: Row(
                  children: [
                    Icon(Icons.receipt_long, size: 16, color: theme.textPrimary),
                    const SizedBox(width: 4),
                    Text(
                      'Transactions',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Invite your friends and earn money anytime they buy data.',
            style: TextStyle(
              fontSize: 13,
              color: theme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.greyLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(Icons.people, size: 16, color: theme.textPrimary),
                    const SizedBox(width: 8),
                    Text(
                      '0 friends',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: theme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.greyLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(Icons.credit_card, size: 16, color: theme.textPrimary),
                    const SizedBox(width: 8),
                    Text(
                      'Code: ${_wallet?.id?.substring(0, 8).toUpperCase() ?? 'HAZPAY'}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: theme.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(
                          text: _wallet?.id?.substring(0, 8).toUpperCase() ?? 'HAZPAY',
                        ));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Referral code copied!')),
                        );
                      },
                      child: Icon(Icons.copy, size: 14, color: theme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactions(AppTheme theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                onTap: () {},
                child: Row(
                  children: [
                    Icon(Icons.tune, size: 16, color: theme.textPrimary),
                    const SizedBox(width: 4),
                    Text(
                      'Filter',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: theme.cardBackground,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.receipt_long_outlined, size: 48, color: theme.textSecondary),
                  const SizedBox(height: 12),
                  Text(
                    'No transactions yet',
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(AppTheme theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: theme.error),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? 'An error occurred',
            style: TextStyle(color: theme.textPrimary),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() => _isLoading = true);
              _loadWallet();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet for adding balance - Amigo-style design
class _AddBalanceBottomSheet extends StatefulWidget {
  final AppTheme theme;
  final Future<Map<String, dynamic>?> Function(double amount) onCreateAccount;
  final String Function(String?) mapBankName;

  const _AddBalanceBottomSheet({
    required this.theme,
    required this.onCreateAccount,
    required this.mapBankName,
  });

  @override
  State<_AddBalanceBottomSheet> createState() => _AddBalanceBottomSheetState();
}

class _AddBalanceBottomSheetState extends State<_AddBalanceBottomSheet> {
  final _amountController = TextEditingController();
  Map<String, dynamic>? _accountDetails;
  bool _isLoading = false;
  String? _error;

  Future<void> _createAccount() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Please enter a valid amount');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await widget.onCreateAccount(amount);

    setState(() {
      _isLoading = false;
      if (result != null) {
        _accountDetails = result;
      } else {
        _error = 'Failed to create account. Please try again.';
      }
    });
  }

  void _copyAccountNumber() {
    final accountNumber = _accountDetails?['account_number'];
    if (accountNumber != null) {
      Clipboard.setData(ClipboardData(text: accountNumber));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Account number copied!'),
          backgroundColor: widget.theme.success,
        ),
      );
    }
  }

  void _shareDetails() {
    final details = _accountDetails;
    if (details == null) return;

    final bankName = widget.mapBankName(details['bank_name']);
    final amount = details['amount'] is num 
        ? formatNaira(details['amount'] as num) 
        : '₦${details['amount']}';
    final message = '''
Bank: $bankName
Account Number: ${details['account_number']}
Account Name: ${details['account_name']}
Amount: $amount

Transfer to this account to fund your HazPay wallet.
''';
    // Copy to clipboard instead
    Clipboard.setData(ClipboardData(text: message));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Account details copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.theme.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: widget.theme.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.arrow_back, color: widget.theme.textPrimary),
                ),
                const SizedBox(width: 16),
                Text(
                  'Add Balance',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: widget.theme.textPrimary,
                  ),
                ),
                const Spacer(),
                if (_accountDetails == null)
                  GestureDetector(
                    onTap: _isLoading ? null : _createAccount,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: widget.theme.primaryColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '+ Create Account',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Content
          if (_accountDetails == null) ...[
            // Amount input
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: widget.theme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Enter amount',
                  hintStyle: TextStyle(color: widget.theme.textSecondary),
                  prefixText: '₦ ',
                  prefixStyle: TextStyle(
                    color: widget.theme.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                  filled: true,
                  fillColor: widget.theme.greyLight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  errorText: _error,
                ),
              ),
            ),
            if (_isLoading)
              Padding(
                padding: const EdgeInsets.all(32),
                child: CircularProgressIndicator(color: widget.theme.primaryColor),
              ),
          ] else ...[
            // Account details - Amigo style
            _buildAccountCard(),
          ],
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 20),
        ],
      ),
    );
  }

  Widget _buildAccountCard() {
    final bankName = widget.mapBankName(_accountDetails?['bank_name']);
    final accountNumber = _accountDetails?['account_number'] ?? '';
    final accountName = _accountDetails?['account_name'] ?? '';
    
    // Format account number with spaces
    final formattedNumber = accountNumber.replaceAllMapped(
      RegExp(r'.{4}'),
      (match) => '${match.group(0)} ',
    ).trim();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: widget.theme.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: widget.theme.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bank header
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: widget.theme.greyLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.account_balance,
                    color: widget.theme.textPrimary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  bankName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: widget.theme.textPrimary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.theme.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Recommended',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: widget.theme.success,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Add money via mobile or internet banking',
              style: TextStyle(
                fontSize: 13,
                color: widget.theme.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            // Account number - large display
            Text(
              formattedNumber,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: widget.theme.textPrimary,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              accountName,
              style: TextStyle(
                fontSize: 13,
                color: widget.theme.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _copyAccountNumber,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: widget.theme.greyLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.copy, size: 18, color: widget.theme.textPrimary),
                          const SizedBox(width: 8),
                          Text(
                            'Copy Number',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: widget.theme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: _shareDetails,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: widget.theme.success,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.share, size: 18, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Share Details',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Info message
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: widget.theme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: widget.theme.primaryColor,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Account expires in 1 hour. Your wallet will be credited automatically.',
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.theme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }
}
