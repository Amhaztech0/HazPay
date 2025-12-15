import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zinchat/services/hazpay_service.dart';
import 'package:zinchat/widgets/receipt_widget.dart';
import '../../providers/theme_provider.dart';
import '../../utils/helpers.dart';

class PayElectricityBillScreen extends StatefulWidget {
  const PayElectricityBillScreen({Key? key}) : super(key: key);

  @override
  State<PayElectricityBillScreen> createState() => _PayElectricityBillScreenState();
}

class _PayElectricityBillScreenState extends State<PayElectricityBillScreen> {
  final hazPayService = HazPayService();
  final _meterController = TextEditingController();
  final _amountController = TextEditingController();

  // Electricity Discos
  final List<Map<String, String>> _discos = [
    {'code': 'ikedc', 'name': 'Ikeja Electric', 'shortName': 'IKEDC'},
    {'code': 'ekedc', 'name': 'Eko Electricity', 'shortName': 'EKEDC'},
    {'code': 'eedc', 'name': 'Enugu Electric', 'shortName': 'EEDC'},
    {'code': 'phedc', 'name': 'Port Harcourt', 'shortName': 'PHEDC'},
    {'code': 'aedc', 'name': 'Abuja Electric', 'shortName': 'AEDC'},
    {'code': 'ibedc', 'name': 'Ibadan Electric', 'shortName': 'IBEDC'},
    {'code': 'kedco', 'name': 'Kano Electric', 'shortName': 'KEDCO'},
    {'code': 'jed', 'name': 'Jos Electric', 'shortName': 'JED'},
    {'code': 'kaedco', 'name': 'Kaduna Electric', 'shortName': 'KAEDCO'},
  ];

  String? _selectedDisco;
  String _selectedMeterType = 'prepaid';
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
      setState(() {
        _walletBalance = wallet.balance;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Failed to load wallet: $e');
    }
  }

  Future<void> _payBill() async {
    final theme = context.read<ThemeProvider>().currentTheme;

    // Validation
    if (_selectedDisco == null || _selectedDisco!.isEmpty) {
      _showSnackBar('Please select a power disco', theme.error);
      return;
    }

    if (_meterController.text.isEmpty) {
      _showSnackBar('Please enter meter number', theme.error);
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
      final payment = await hazPayService.payElectricityBill(
        discoCode: _selectedDisco!,
        meterNumber: _meterController.text.trim(),
        amount: amount,
        meterType: _selectedMeterType,
      );

      if (mounted) {
        // Reset form
        _meterController.clear();
        _amountController.clear();
        setState(() {
          _selectedDisco = null;
          _selectedMeterType = 'prepaid';
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
    _meterController.dispose();
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
          'Electricity Bill',
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

            // Select Disco Section
            Text(
              'Select Power Disco',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            _buildDiscoGrid(theme),
            const SizedBox(height: 24),

            // Meter Type Section
            Text(
              'Meter Type',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            _buildMeterTypeSelector(theme),
            const SizedBox(height: 24),

            // Meter Number Input
            Text(
              'Meter Number',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            _buildTextField(
              theme: theme,
              controller: _meterController,
              hint: 'Enter meter number',
              icon: Icons.pin,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),

            // Amount Input
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
            ),
            const SizedBox(height: 32),

            // Quick Amounts
            _buildQuickAmounts(theme),
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

  Widget _buildDiscoGrid(dynamic theme) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.1,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _discos.length,
      itemBuilder: (context, index) {
        final disco = _discos[index];
        final isSelected = _selectedDisco == disco['code'];

        return GestureDetector(
          onTap: () => setState(() => _selectedDisco = disco['code']),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.primaryColor.withOpacity(0.1)
                  : theme.cardBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? theme.primaryColor : theme.divider,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: theme.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.flash_on,
                    color: theme.warning,
                    size: 20,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  disco['shortName']!,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected ? theme.primaryColor : theme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMeterTypeSelector(dynamic theme) {
    return Row(
      children: [
        Expanded(
          child: _buildMeterTypeOption(
            theme: theme,
            title: 'Prepaid',
            icon: Icons.bolt,
            isSelected: _selectedMeterType == 'prepaid',
            onTap: () => setState(() => _selectedMeterType = 'prepaid'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMeterTypeOption(
            theme: theme,
            title: 'Postpaid',
            icon: Icons.receipt_long,
            isSelected: _selectedMeterType == 'postpaid',
            onTap: () => setState(() => _selectedMeterType = 'postpaid'),
          ),
        ),
      ],
    );
  }

  Widget _buildMeterTypeOption({
    required dynamic theme,
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.primaryColor.withOpacity(0.1)
              : theme.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? theme.primaryColor : theme.divider,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? theme.primaryColor : theme.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? theme.primaryColor : theme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required dynamic theme,
    required TextEditingController controller,
    required String hint,
    IconData? icon,
    String? prefix,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.divider),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
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

  Widget _buildQuickAmounts(dynamic theme) {
    final amounts = ['500', '1000', '2000', '5000'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Select',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: theme.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: amounts.map((amount) {
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _amountController.text = amount),
                child: Container(
                  margin: EdgeInsets.only(
                    right: amount != amounts.last ? 10 : 0,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: theme.greyLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      '₦$amount',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
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
            ? SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Pay Now',
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
