import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zinchat/services/hazpay_service.dart';
import 'package:zinchat/widgets/receipt_widget.dart';
import '../../providers/theme_provider.dart';
import '../../utils/helpers.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({Key? key}) : super(key: key);

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  final hazPayService = HazPayService();
  List<HazPayTransaction> _transactions = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    try {
      final transactions = await hazPayService.getTransactionHistory();
      setState(() {
        _transactions = transactions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load transactions: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  List<HazPayTransaction> _getFilteredTransactions() {
    if (_selectedFilter == 'all') {
      return _transactions;
    }
    return _transactions.where((t) => t.type == _selectedFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>().currentTheme;
    final filteredTransactions = _getFilteredTransactions();

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
          'Transaction History',
          style: TextStyle(
            color: theme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: theme.textPrimary),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadTransactions();
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
          : _errorMessage != null
              ? _buildErrorWidget(theme)
              : Column(
                  children: [
                    _buildFilterBar(theme),
                    Expanded(
                      child: filteredTransactions.isEmpty
                          ? _buildEmptyState(theme)
                          : RefreshIndicator(
                              onRefresh: () async {
                                setState(() => _isLoading = true);
                                await _loadTransactions();
                              },
                              color: theme.primaryColor,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: filteredTransactions.length,
                                itemBuilder: (context, index) {
                                  final transaction = filteredTransactions[index];
                                  return _buildTransactionTile(theme, transaction);
                                },
                              ),
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildErrorWidget(dynamic theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 40,
                color: theme.error,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'An error occurred',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: theme.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() => _isLoading = true);
                _loadTransactions();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar(dynamic theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _buildFilterChip(
            theme: theme,
            label: 'All',
            count: _transactions.length,
            isSelected: _selectedFilter == 'all',
            onTap: () => setState(() => _selectedFilter = 'all'),
          ),
          const SizedBox(width: 10),
          _buildFilterChip(
            theme: theme,
            label: 'Purchases',
            isSelected: _selectedFilter == 'purchase',
            onTap: () => setState(() => _selectedFilter = 'purchase'),
          ),
          const SizedBox(width: 10),
          _buildFilterChip(
            theme: theme,
            label: 'Deposits',
            isSelected: _selectedFilter == 'deposit',
            onTap: () => setState(() => _selectedFilter = 'deposit'),
          ),
          const SizedBox(width: 10),
          _buildFilterChip(
            theme: theme,
            label: 'Withdrawals',
            isSelected: _selectedFilter == 'withdrawal',
            onTap: () => setState(() => _selectedFilter = 'withdrawal'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required dynamic theme,
    required String label,
    int? count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? theme.primaryColor : theme.cardBackground,
          borderRadius: BorderRadius.circular(24),
          border: isSelected ? null : Border.all(color: theme.divider),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: Text(
          count != null ? '$label ($count)' : label,
          style: TextStyle(
            color: isSelected ? Colors.white : theme.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(dynamic theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.greyLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.history,
                size: 40,
                color: theme.grey,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No transactions yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your ${_selectedFilter == 'all' ? 'transaction' : _selectedFilter} history will appear here',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: theme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionTile(dynamic theme, HazPayTransaction transaction) {
    final txDisplay = _getTransactionDisplay(transaction, theme);
    final icon = txDisplay['icon'] as IconData;
    final color = txDisplay['color'] as Color;
    final displayLabel = txDisplay['label'] as String;
    final isSuccess = transaction.status == 'success';

    return GestureDetector(
      onTap: () => _showTransactionDetails(theme, transaction),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSuccess ? theme.divider : theme.error.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayLabel,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: theme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        _formatDate(transaction.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textSecondary,
                        ),
                      ),
                      if (transaction.mobileNumber != null) ...[
                        Text(
                          ' • ',
                          style: TextStyle(color: theme.textSecondary),
                        ),
                        Text(
                          transaction.mobileNumber!,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Amount & Status
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${_getAmountSign(transaction)}${formatNaira(transaction.amount)}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _getAmountColor(theme, transaction),
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
                    transaction.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isSuccess ? theme.success : theme.error,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _getTransactionDisplay(HazPayTransaction transaction, dynamic theme) {
    switch (transaction.type) {
      case 'deposit':
        return {
          'icon': Icons.arrow_downward,
          'color': theme.success,
          'label': 'Deposit',
        };
      case 'withdrawal':
        return {
          'icon': Icons.arrow_upward,
          'color': theme.warning,
          'label': 'Withdrawal',
        };
      case 'purchase':
        return {
          'icon': Icons.shopping_cart,
          'color': theme.info,
          'label': transaction.networkName ?? 'Purchase',
        };
      case 'data':
        return {
          'icon': Icons.signal_cellular_alt,
          'color': theme.secondaryColor,
          'label': 'Data Purchase',
        };
      case 'electricity':
        return {
          'icon': Icons.flash_on,
          'color': theme.warning,
          'label': 'Electricity',
        };
      case 'cable':
        return {
          'icon': Icons.tv,
          'color': theme.primaryColor,
          'label': 'Cable TV',
        };
      default:
        return {
          'icon': Icons.receipt_long,
          'color': theme.grey,
          'label': transaction.type,
        };
    }
  }

  String _getAmountSign(HazPayTransaction transaction) {
    if (transaction.type == 'deposit') {
      return '+';
    }
    return '-';
  }

  Color _getAmountColor(dynamic theme, HazPayTransaction transaction) {
    if (transaction.status != 'success') {
      return theme.error;
    }
    if (transaction.type == 'deposit') {
      return theme.success;
    }
    return theme.textPrimary;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    String timeStr = '${date.hour}:${date.minute.toString().padLeft(2, '0')}';

    if (dateOnly == today) {
      return 'Today, $timeStr';
    } else if (dateOnly == yesterday) {
      return 'Yesterday, $timeStr';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _showTransactionDetails(dynamic theme, HazPayTransaction transaction) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReceiptBottomSheet(
        transaction: transaction,
        theme: theme,
      ),
    );
  }
}
