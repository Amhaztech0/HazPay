import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zinchat/services/hazpay_service.dart';
import 'package:zinchat/widgets/receipt_widget.dart';
import '../../providers/theme_provider.dart';
import '../../models/app_theme.dart';
import '../../utils/helpers.dart';

class BuyDataScreen extends StatefulWidget {
  const BuyDataScreen({Key? key}) : super(key: key);

  @override
  State<BuyDataScreen> createState() => _BuyDataScreenState();
}

enum DataPurchaseStep { phoneNumber, networkSelection, planSelection, summary }

class _BuyDataScreenState extends State<BuyDataScreen> {
  final hazPayService = HazPayService();
  final _phoneController = TextEditingController();
  
  DataPurchaseStep _currentStep = DataPurchaseStep.phoneNumber;
  int? _selectedNetwork;
  bool _isPortedNumber = false;
  DataPlan? _selectedPlan;
  bool _isLoading = false;
  bool _isPurchasing = false;
  String? _errorMessage;
  
  List<DataPlan> _filteredPlans = [];
  double? _walletBalance;

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    try {
      final wallet = await hazPayService.getWallet();
      if (mounted) {
        setState(() => _walletBalance = wallet.balance);
      }
    } catch (e) {
      debugPrint('⚠️ Failed to load wallet: $e');
    }
  }

  Future<void> _loadPlansForNetwork(int networkId) async {
    setState(() => _isLoading = true);
    try {
      final allPlansMap = await hazPayService.getDataPlans();
      final networkName = DataNetwork.fromId(networkId).name;
      final networkPlans = allPlansMap[networkName] ?? [];
      
      if (mounted) {
        setState(() {
          _filteredPlans = networkPlans;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load plans: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  void _goToNetworkSelection() {
    if (_phoneController.text.isEmpty) {
      final theme = context.read<ThemeProvider>().currentTheme;
      _showError('Please enter a phone number', theme);
      return;
    }
    setState(() {
      _currentStep = DataPurchaseStep.networkSelection;
      _errorMessage = null;
    });
  }

  void _selectNetwork(int networkId) {
    setState(() => _selectedNetwork = networkId);
    _loadPlansForNetwork(networkId);
    setState(() => _currentStep = DataPurchaseStep.planSelection);
  }

  void _selectPlan(DataPlan plan) {
    setState(() {
      _selectedPlan = plan;
      _currentStep = DataPurchaseStep.summary;
    });
  }

  Future<void> _purchaseData() async {
    final theme = context.read<ThemeProvider>().currentTheme;
    
    if (_phoneController.text.isEmpty || _selectedPlan == null || _selectedNetwork == null) {
      _showError('Missing purchase information', theme);
      return;
    }

    setState(() => _isPurchasing = true);

    try {
      final transaction = await hazPayService.purchaseData(
        mobileNumber: _phoneController.text,
        planId: _selectedPlan!.planId,
        networkId: _selectedNetwork!,
        amount: _selectedPlan!.price,
        isPortedNumber: _isPortedNumber,
        dataCapacity: _formatDataSize(_selectedPlan!.capacity),
      );

      if (mounted) {
        _phoneController.clear();
        setState(() {
          _selectedPlan = null;
          _selectedNetwork = null;
          _isPurchasing = false;
          _currentStep = DataPurchaseStep.phoneNumber;
        });

        _showSuccessDialog(transaction, theme);
        
        final updatedWallet = await hazPayService.getWallet();
        if (mounted) {
          setState(() => _walletBalance = updatedWallet.balance);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPurchasing = false);
        _showError(e.toString(), theme);
      }
    }
  }

  void _showError(String message, AppTheme theme) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: theme.error,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessDialog(HazPayTransaction transaction, AppTheme theme) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ReceiptDialog(
        transaction: transaction,
        theme: theme,
        onClose: () {
          Navigator.pop(context);
          // Optional: Add navigation or additional actions after closing receipt
        },
      ),
    );
  }

  // Using _filteredPlans directly from state

  String _formatDataSize(double capacityGB) {
    if (capacityGB.isInfinite) {
      return 'Unlimited';
    } else if (capacityGB >= 1) {
      return '${capacityGB.toStringAsFixed(1)}GB'.replaceAll(RegExp(r'\.0+$'), '');
    } else {
      final mb = (capacityGB * 1024).toStringAsFixed(0);
      return '${mb}MB';
    }
  }

  // Network colors - these are brand colors, not theme colors
  Color _getNetworkColor(int networkId) {
    switch (networkId) {
      case 1: return const Color(0xFFFFCC00); // MTN Yellow
      case 2: return const Color(0xFF00A651); // GLO Green
      case 3: return const Color(0xFFE40000); // Airtel Red
      case 4: return const Color(0xFF006B54); // 9Mobile Green
      case 5: return const Color(0xFFFF6600); // Smile Orange
      default: return const Color(0xFF666666);
    }
  }

  @override
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
            if (_currentStep != DataPurchaseStep.phoneNumber) {
              setState(() => _currentStep = DataPurchaseStep.phoneNumber);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          '💳 Data',
          style: TextStyle(
            color: theme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
        actions: [
          if (_currentStep != DataPurchaseStep.phoneNumber)
            IconButton(
              icon: Icon(Icons.settings_rounded, color: theme.textPrimary),
              onPressed: () {},
            ),
          if (_currentStep != DataPurchaseStep.phoneNumber)
            IconButton(
              icon: Icon(Icons.history_rounded, color: theme.textPrimary),
              onPressed: () {},
            ),
        ],
      ),
      body: _buildStepContent(theme),
    );
  }

  Widget _buildStepContent(AppTheme theme) {
    switch (_currentStep) {
      case DataPurchaseStep.phoneNumber:
        return _buildPhoneNumberStep(theme);
      case DataPurchaseStep.networkSelection:
        return _buildNetworkSelectionStep(theme);
      case DataPurchaseStep.planSelection:
        return _buildPlanSelectionStep(theme);
      case DataPurchaseStep.summary:
        return _buildSummaryStep(theme);
    }
  }

  Widget _buildPhoneNumberStep(AppTheme theme) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Text(
              '📱 Data',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: theme.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Send to:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: theme.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            // Phone number input
            Container(
              decoration: BoxDecoration(
                color: theme.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.divider),
              ),
              child: TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Phone Number (080***)',
                  hintStyle: TextStyle(color: theme.textSecondary),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Offline toggle
            Container(
              decoration: BoxDecoration(
                color: theme.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.divider),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Offline',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: theme.textPrimary,
                    ),
                  ),
                  Switch(
                    value: _isPortedNumber,
                    onChanged: (value) => setState(() => _isPortedNumber = value),
                    activeColor: theme.primaryColor,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Proceed button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _goToNetworkSelection,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.arrow_forward_rounded, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      'Proceed',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Beneficiaries section
            Text(
              'Beneficiaries',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: theme.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.divider),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, color: theme.textSecondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Search Contacts',
                      style: TextStyle(color: theme.textSecondary, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Recent',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.textPrimary),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: theme.primaryColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Text(
                    'Saved',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'No beneficiaries yet – your recent purchases will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: theme.textSecondary),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkSelectionStep(AppTheme theme) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardBackground,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Network Provider',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: theme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select a network provider',
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ..._buildNetworkOptions(theme),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setState(() => _currentStep = DataPurchaseStep.phoneNumber),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: theme.divider),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: theme.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _selectedNetwork != null ? () => _selectNetwork(_selectedNetwork!) : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Submit',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildNetworkOptions(AppTheme theme) {
    final networks = [
      {'label': 'MTN', 'id': 1},
      {'label': 'Airtel', 'id': 3},
      {'label': 'Glo', 'id': 2},
    ];

    return networks.map((network) {
      final networkId = network['id'] as int;
      final isSelected = _selectedNetwork == networkId;

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: GestureDetector(
          onTap: () => setState(() => _selectedNetwork = networkId),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? theme.primaryColor.withOpacity(0.1) : theme.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? theme.primaryColor : theme.divider,
                width: isSelected ? 2 : 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _getNetworkColor(networkId).withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      (network['label'] as String)[0],
                      style: TextStyle(
                        color: _getNetworkColor(networkId),
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  network['label'] as String,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.textPrimary,
                  ),
                ),
                const Spacer(),
                if (isSelected)
                  Icon(Icons.check_circle_rounded, color: theme.primaryColor),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildPlanSelectionStep(AppTheme theme) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Text(
              'Available Plans',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: theme.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              Center(
                child: CircularProgressIndicator(color: theme.primaryColor),
              )
            else if (_filteredPlans.isEmpty)
              Center(
                child: Text(
                  'No plans available',
                  style: TextStyle(color: theme.textSecondary),
                ),
              )
            else
              GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.9,
                ),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _filteredPlans.length,
                itemBuilder: (context, index) {
                  final plan = _filteredPlans[index];
                  return _buildPlanCard(plan, theme);
                },
              ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _currentStep = DataPurchaseStep.phoneNumber),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: theme.divider),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: theme.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _selectedPlan != null ? () => _selectPlan(_selectedPlan!) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Confirm',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard(DataPlan plan, AppTheme theme) {
    final isSelected = _selectedPlan?.planId == plan.planId;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = plan),
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? theme.primaryColor : theme.divider,
            width: isSelected ? 2 : 1,
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _formatDataSize(plan.capacity),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: theme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              formatNaira(plan.price, decimals: 0),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: theme.background,
                borderRadius: BorderRadius.circular(6),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              child: Text(
                '${plan.validity} days',
                style: TextStyle(fontSize: 10, color: theme.textSecondary, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryStep(AppTheme theme) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            // Summary card
            Container(
              decoration: BoxDecoration(
                color: theme.cardBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: theme.divider),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '📋 Purchase Summary',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: theme.textPrimary,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _currentStep = DataPurchaseStep.planSelection),
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.background,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            Icons.close_rounded,
                            color: theme.textSecondary,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSummaryRow('Phone', _phoneController.text, theme),
                  _buildSummaryRow(
                    'Network',
                    DataNetwork.fromId(_selectedNetwork!).name,
                    theme,
                  ),
                  _buildSummaryRow(
                    'Plan',
                    '${_formatDataSize(_selectedPlan!.capacity)} • ${_selectedPlan!.validity} days',
                    theme,
                  ),
                  _buildSummaryRow(
                    'Plan Price',
                    formatNaira(_selectedPlan!.price, decimals: 0),
                    theme,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(),
                  ),
                  _buildSummaryRow(
                    'Referral Balance',
                    'N0.00',
                    theme,
                    showToggle: true,
                  ),
                  _buildSummaryRow(
                    'Cashback',
                    'N0.00',
                    theme,
                    showToggle: true,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Referral Applied',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: theme.textSecondary,
                        ),
                      ),
                      Text(
                        'N0.00',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Cashback Applied',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: theme.textSecondary,
                        ),
                      ),
                      Text(
                        'N0.00',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total to Pay',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: theme.textPrimary,
                        ),
                      ),
                      Text(
                        formatNaira(_selectedPlan!.price, decimals: 0),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: theme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor.withOpacity(0.1),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.fingerprint_rounded, color: theme.primaryColor),
                        const SizedBox(width: 8),
                        Text(
                          'Biometric',
                          style: TextStyle(
                            color: theme.primaryColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isPurchasing ? null : _purchaseData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isPurchasing
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              strokeWidth: 2,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.lock_rounded, color: Colors.white),
                              const SizedBox(width: 8),
                              Text(
                                'Proceed',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, AppTheme theme, {bool showToggle = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: theme.textSecondary,
            ),
          ),
          if (!showToggle)
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.textPrimary,
              ),
            )
          else
            Row(
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: false,
                  onChanged: (_) {},
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }
}

