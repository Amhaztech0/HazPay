import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zinchat/services/hazpay_service.dart';
import 'package:zinchat/screens/fintech/loan_history_screen.dart';
import '../../providers/theme_provider.dart';
import '../../utils/helpers.dart';

class LoanScreen extends StatefulWidget {
  const LoanScreen({Key? key}) : super(key: key);

  @override
  State<LoanScreen> createState() => _LoanScreenState();
}

class _LoanScreenState extends State<LoanScreen> {
  final hazPayService = HazPayService();
  bool _isLoading = true;
  bool _isRequestingLoan = false;
  
  Map<String, dynamic>? _eligibility;
  HazPayLoan? _activeLoan;
  String? _error;
  final TextEditingController _mobileController = TextEditingController();
  int _selectedNetwork = 1;

  @override
  void initState() {
    super.initState();
    _loadLoanInfo();
  }

  @override
  void dispose() {
    _mobileController.dispose();
    super.dispose();
  }

  Future<void> _loadLoanInfo() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final eligibility = await hazPayService.checkLoanEligibility();
      final activeLoan = await hazPayService.getActiveLoan();

      if (mounted) {
        setState(() {
          _eligibility = eligibility;
          _activeLoan = activeLoan;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _requestLoan() async {
    final theme = context.read<ThemeProvider>().currentTheme;
    
    if (_isRequestingLoan || _eligibility == null || !(_eligibility!['eligible'] as bool)) {
      return;
    }

    final mobile = _mobileController.text.trim();
    if (mobile.isEmpty) {
      _showSnackBar('Please enter your mobile number', theme.error);
      return;
    }

    if (!mounted) return;
    setState(() => _isRequestingLoan = true);

    try {
      final result = await hazPayService.requestLoan(
        mobileNumber: mobile,
        networkId: _selectedNetwork,
      );

      if (mounted) {
        _showSnackBar(
          result['message'] ?? 'Loan requested successfully',
          theme.success,
        );
        _loadLoanInfo();
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error: $e', theme.error);
      }
    } finally {
      if (mounted) {
        setState(() => _isRequestingLoan = false);
      }
    }
  }

  void _showSnackBar(String message, Color bgColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
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
          'Data Loan',
          style: TextStyle(
            color: theme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.history, color: theme.textPrimary),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoanHistoryScreen()),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: theme.primaryColor,
                strokeWidth: 2,
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadLoanInfo,
              color: theme.primaryColor,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_error != null) _buildErrorCard(theme),
                    if (_activeLoan != null)
                      _buildActiveLoanCard(theme)
                    else
                      _buildEligibilityCard(theme),
                    const SizedBox(height: 24),
                    _buildHowItWorksCard(theme),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildErrorCard(dynamic theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.error.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: theme.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(color: theme.error, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveLoanCard(dynamic theme) {
    final loanStatus = _activeLoan!.status;
    final isRepaid = loanStatus == 'repaid';
    final isFailed = loanStatus == 'failed';

    Color statusColor;
    IconData statusIcon;
    if (isRepaid) {
      statusColor = theme.success;
      statusIcon = Icons.check_circle;
    } else if (isFailed) {
      statusColor = theme.error;
      statusIcon = Icons.cancel;
    } else {
      statusColor = theme.warning;
      statusIcon = Icons.pending;
    }

    return Container(
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
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(statusIcon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Active Loan',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        loanStatus.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildLoanDetailRow('Loan Amount', formatNaira(_activeLoan!.loanFee)),
          _buildLoanDetailRow('Requested', _formatDate(_activeLoan!.createdAt)),
          if (_activeLoan!.issuedAt != null)
            _buildLoanDetailRow('Issued', _formatDate(_activeLoan!.issuedAt!)),
          if (_activeLoan!.repaidAt != null)
            _buildLoanDetailRow('Repaid', _formatDate(_activeLoan!.repaidAt!)),
          if (_activeLoan!.failureReason != null)
            _buildLoanDetailRow('Reason', _activeLoan!.failureReason!),
        ],
      ),
    );
  }

  Widget _buildLoanDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEligibilityCard(dynamic theme) {
    if (_eligibility == null) {
      return const SizedBox.shrink();
    }

    final eligible = _eligibility!['eligible'] as bool;
    final totalSpent = (_eligibility!['totalSpent'] as num).toDouble();
    final remaining = (_eligibility!['remainingAmount'] as num).toDouble();
    final progress = (totalSpent / 10000).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.card_giftcard,
                  color: theme.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Text(
                'Loan Eligibility',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Progress Section
          Text(
            'Transaction Volume',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: theme.greyLight,
              valueColor: AlwaysStoppedAnimation<Color>(
                progress >= 1.0 ? theme.success : theme.primaryColor,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formatNaira(totalSpent, decimals: 0),
                style: TextStyle(
                  fontSize: 13,
                  color: theme.textSecondary,
                ),
              ),
              Text(
                formatNaira(10000, decimals: 0),
                style: TextStyle(
                  fontSize: 13,
                  color: theme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Eligibility Status
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: eligible
                  ? theme.success.withOpacity(0.1)
                  : theme.primaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              eligible
                  ? '🎉 You are eligible! You can request a 1GB loan.'
                  : '📊 Spend ${formatNaira(remaining)} more to become eligible.',
              style: TextStyle(
                color: eligible ? theme.success : theme.primaryColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          
          if (eligible) ...[
            const SizedBox(height: 24),
            
            // Mobile Number Input
            Text(
              'Mobile Number',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: theme.greyLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.divider),
              ),
              child: TextField(
                controller: _mobileController,
                keyboardType: TextInputType.phone,
                style: TextStyle(color: theme.textPrimary),
                decoration: InputDecoration(
                  hintText: '0801xxxxxxx',
                  hintStyle: TextStyle(color: theme.textSecondary.withOpacity(0.7)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  prefixIcon: Icon(Icons.phone, color: theme.textSecondary),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Network Selector
            Text(
              'Network',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildNetworkOption(theme, 'MTN', 1, const Color(0xFFFFC107)),
                const SizedBox(width: 12),
                _buildNetworkOption(theme, 'GLO', 2, const Color(0xFF4CAF50)),
              ],
            ),
            const SizedBox(height: 24),
            
            // Request Button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isRequestingLoan ? null : _requestLoan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  disabledBackgroundColor: theme.grey.withOpacity(0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isRequestingLoan
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.card_giftcard, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Request 1GB Loan',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNetworkOption(dynamic theme, String name, int value, Color color) {
    final isSelected = _selectedNetwork == value;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedNetwork = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.15) : theme.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : theme.divider,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? color : theme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHowItWorksCard(dynamic theme) {
    final steps = [
      {'icon': Icons.shopping_cart, 'text': 'Spend ₦10,000 or more to become eligible'},
      {'icon': Icons.card_giftcard, 'text': 'Request a 1GB data loan instantly'},
      {'icon': Icons.flash_on, 'text': 'Data is added to your account immediately'},
      {'icon': Icons.autorenew, 'text': 'Repayment happens automatically when you deposit'},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How It Works',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: theme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ...steps.map((step) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    step['icon'] as IconData,
                    color: theme.primaryColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    step['text'] as String,
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

