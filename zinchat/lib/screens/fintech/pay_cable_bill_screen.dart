import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zinchat/services/hazpay_service.dart';
import 'package:zinchat/widgets/receipt_widget.dart';
import '../../providers/theme_provider.dart';
import '../../utils/helpers.dart';

class PayCableBillScreen extends StatefulWidget {
  const PayCableBillScreen({Key? key}) : super(key: key);

  @override
  State<PayCableBillScreen> createState() => _PayCableBillScreenState();
}

class _PayCableBillScreenState extends State<PayCableBillScreen> {
  final hazPayService = HazPayService();
  final _smartcardController = TextEditingController();
  final _amountController = TextEditingController();

  // Cable Providers with brand colors
  final List<Map<String, dynamic>> _providers = [
    {
      'code': 'dstv',
      'name': 'DStv',
      'color': const Color(0xFF003876),
      'icon': Icons.tv,
    },
    {
      'code': 'gotv',
      'name': 'GOtv',
      'color': const Color(0xFF009444),
      'icon': Icons.live_tv,
    },
    {
      'code': 'startimes',
      'name': 'StarTimes',
      'color': const Color(0xFFE31837),
      'icon': Icons.star,
    },
    {
      'code': 'showmax',
      'name': 'Showmax',
      'color': const Color(0xFFE31837),
      'icon': Icons.play_circle,
    },
  ];

  // Cable Plans
  final Map<String, List<Map<String, String>>> _cablePlans = {
    'dstv': [
      {'id': 'ng_dstv_padi24', 'name': 'DStv Padi', 'price': '4400'},
      {'id': 'ng_dstv_yanga65', 'name': 'DStv Yanga', 'price': '8400'},
      {'id': 'ng_dstv_confam36', 'name': 'DStv Confam', 'price': '12500'},
      {'id': 'ng_dstv_compact30', 'name': 'DStv Compact', 'price': '15700'},
      {'id': 'ng_dstv_hdprme36', 'name': 'DStv Premium', 'price': '24500'},
    ],
    'gotv': [
      {'id': 'ng_gotv_lite20', 'name': 'GOtv Smallie', 'price': '1575'},
      {'id': 'ng_gotv_jinja30', 'name': 'GOtv Jinja', 'price': '3300'},
      {'id': 'ng_gotv_jolli40', 'name': 'GOtv Jolli', 'price': '4850'},
      {'id': 'ng_gotv_max60', 'name': 'GOtv Max', 'price': '7200'},
      {'id': 'ng_gotv_supa70', 'name': 'GOtv Supa', 'price': '9600'},
    ],
    'startimes': [
      {'id': 'ng_startimes_nova20', 'name': 'Nova', 'price': '1200'},
      {'id': 'ng_startimes_basic30', 'name': 'Basic', 'price': '2100'},
      {'id': 'ng_startimes_smart40', 'name': 'Smart', 'price': '2800'},
      {'id': 'ng_startimes_classic50', 'name': 'Classic', 'price': '3500'},
      {'id': 'ng_startimes_super60', 'name': 'Super', 'price': '5500'},
    ],
    'showmax': [
      {'id': 'ng_showmax_mobile14', 'name': 'Mobile', 'price': '1200'},
      {'id': 'ng_showmax_standard49', 'name': 'Standard', 'price': '2900'},
      {'id': 'ng_showmax_pro86', 'name': 'Pro', 'price': '6300'},
    ],
  };

  String? _selectedProvider;
  String? _selectedPlan;
  double? _walletBalance;
  bool _isLoading = false;
  bool _isPaying = false;

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    setState(() => _isLoading = true);
    try {
      final wallet = await hazPayService.getWallet();
      if (mounted) {
        setState(() {
          _walletBalance = wallet.balance;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      debugPrint('Failed to load wallet: $e');
    }
  }

  Future<void> _payBill() async {
    final theme = context.read<ThemeProvider>().currentTheme;

    // Validation
    if (_selectedProvider == null || _selectedProvider!.isEmpty) {
      _showSnackBar('Please select a cable provider', theme.error);
      return;
    }

    if (_selectedPlan == null || _selectedPlan!.isEmpty) {
      _showSnackBar('Please select a plan', theme.error);
      return;
    }

    if (_smartcardController.text.isEmpty) {
      _showSnackBar('Please enter smartcard number', theme.error);
      return;
    }

    if (_amountController.text.isEmpty) {
      _showSnackBar('Please enter amount', theme.error);
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      _showSnackBar('Invalid amount', theme.error);
      return;
    }

    if (_walletBalance != null && amount > _walletBalance!) {
      _showSnackBar('Insufficient wallet balance', theme.error);
      return;
    }

    setState(() => _isPaying = true);

    try {
      final payment = await hazPayService.payCableBill(
        cableProvider: _selectedProvider!,
        planId: _selectedPlan!,
        amount: amount,
        smartcardNumber: _smartcardController.text.trim(),
      );

      if (mounted) {
        // Reset form
        _smartcardController.clear();
        _amountController.clear();
        setState(() {
          _selectedProvider = null;
          _selectedPlan = null;
          _isPaying = false;
        });

        // Reload wallet
        await _loadWallet();

        // Show success dialog
        _showSuccessDialog(payment);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPaying = false);
        final theme = context.read<ThemeProvider>().currentTheme;
        _showSnackBar('Payment failed: ${e.toString()}', theme.error);
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

  void _showSuccessDialog(BillPayment payment) {
    final theme = context.read<ThemeProvider>().currentTheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReceiptBottomSheet(
        billPayment: payment,
        theme: theme,
      ),
    );
  }

  @override
  void dispose() {
    _smartcardController.dispose();
    _amountController.dispose();
    super.dispose();
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
          'Cable TV Subscription',
          style: TextStyle(
            color: theme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Wallet Balance Card
            _buildBalanceCard(theme),
            const SizedBox(height: 28),

            // Select Provider Section
            Text(
              'Select Provider',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            _buildProviderSelector(theme),
            const SizedBox(height: 24),

            // Select Plan Section
            if (_selectedProvider != null) ...[
              Text(
                'Select Plan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              _buildPlanSelector(theme),
              const SizedBox(height: 24),
            ],

            // Smartcard Number Input
            Text(
              'Smartcard/IUC Number',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            _buildTextField(
              theme: theme,
              controller: _smartcardController,
              hint: 'Enter smartcard number',
              icon: Icons.credit_card,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),

            // Amount Input (Read-only when plan selected)
            Text(
              'Amount',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            _buildTextField(
              theme: theme,
              controller: _amountController,
              hint: 'Enter amount',
              prefix: '₦',
              keyboardType: TextInputType.number,
              readOnly: _selectedPlan != null,
            ),
            const SizedBox(height: 32),

            // Pay Button
            _buildPayButton(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard(dynamic theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.primaryColor.withOpacity(0.1),
            theme.secondaryColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.primaryColor.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.account_balance_wallet,
              color: theme.primaryColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Wallet Balance',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                _isLoading
                    ? SizedBox(
                        width: 80,
                        child: LinearProgressIndicator(
                          color: theme.primaryColor,
                          backgroundColor: theme.greyLight,
                        ),
                      )
                    : Text(
                        _walletBalance != null
                            ? formatNaira(_walletBalance!)
                            : formatNaira(0),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: theme.textPrimary,
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderSelector(dynamic theme) {
    return Row(
      children: _providers.map((provider) {
        final isSelected = _selectedProvider == provider['code'];
        final providerColor = provider['color'] as Color;

        return Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedProvider = provider['code'];
                _selectedPlan = null;
                _amountController.clear();
              });
            },
            child: Container(
              margin: EdgeInsets.only(
                right: provider != _providers.last ? 10 : 0,
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: isSelected
                    ? providerColor.withOpacity(0.15)
                    : theme.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? providerColor : theme.divider,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    provider['icon'] as IconData,
                    color: isSelected ? providerColor : theme.textSecondary,
                    size: 24,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    provider['name'],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? providerColor : theme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPlanSelector(dynamic theme) {
    final plans = _cablePlans[_selectedProvider] ?? [];
    final providerData = _providers.firstWhere(
      (p) => p['code'] == _selectedProvider,
      orElse: () => _providers.first,
    );
    final providerColor = providerData['color'] as Color;

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: plans.length,
      itemBuilder: (context, index) {
        final plan = plans[index];
        final isSelected = _selectedPlan == plan['id'];

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedPlan = plan['id'];
              _amountController.text = plan['price']!;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected
                  ? providerColor.withOpacity(0.1)
                  : theme.cardBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? providerColor : theme.divider,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: providerColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.tv,
                    color: providerColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan['name']!,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: theme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '30 days subscription',
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
                      formatNaira((plan['price'] as num).toDouble(), decimals: 0),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? providerColor : theme.textPrimary,
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        Icons.check_circle,
                        color: providerColor,
                        size: 20,
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextField({
    required dynamic theme,
    required TextEditingController controller,
    required String hint,
    IconData? icon,
    String? prefix,
    TextInputType? keyboardType,
    bool readOnly = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: readOnly ? theme.greyLight : theme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.divider),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        readOnly: readOnly,
        style: TextStyle(
          fontSize: 16,
          color: theme.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: theme.textSecondary.withOpacity(0.7)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          prefixIcon: icon != null
              ? Icon(icon, color: theme.textSecondary)
              : prefix != null
                  ? Padding(
                      padding: const EdgeInsets.only(left: 16, right: 8),
                      child: Text(
                        prefix,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.textPrimary,
                        ),
                      ),
                    )
                  : null,
          prefixIconConstraints: const BoxConstraints(minWidth: 40),
        ),
      ),
    );
  }

  Widget _buildPayButton(dynamic theme) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isPaying ? null : _payBill,
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.primaryColor,
          disabledBackgroundColor: theme.grey.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: _isPaying
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Subscribe Now',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}
