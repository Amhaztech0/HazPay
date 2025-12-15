import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zinchat/services/hazpay_service.dart';
import '../../providers/theme_provider.dart';
import '../../utils/helpers.dart';

class LoanHistoryScreen extends StatefulWidget {
  const LoanHistoryScreen({Key? key}) : super(key: key);

  @override
  State<LoanHistoryScreen> createState() => _LoanHistoryScreenState();
}

class _LoanHistoryScreenState extends State<LoanHistoryScreen> {
  final hazPayService = HazPayService();
  late Future<List<HazPayLoan>> _loanHistoryFuture;

  @override
  void initState() {
    super.initState();
    _loanHistoryFuture = hazPayService.getLoanHistory(limit: 100);
  }

  String _formatDate(DateTime? d) {
    if (d == null) return '-';
    return '${d.day}/${d.month}/${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> _getStatusConfig(String status, dynamic theme) {
    switch (status) {
      case 'issued':
        return {
          'icon': Icons.check_circle,
          'color': theme.success,
          'label': 'Issued',
        };
      case 'repaid':
        return {
          'icon': Icons.check_circle_outline,
          'color': theme.info,
          'label': 'Repaid',
        };
      case 'failed':
        return {
          'icon': Icons.error,
          'color': theme.error,
          'label': 'Failed',
        };
      case 'pending':
      default:
        return {
          'icon': Icons.hourglass_bottom,
          'color': theme.warning,
          'label': 'Pending',
        };
    }
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
          'Loan History',
          style: TextStyle(
            color: theme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: FutureBuilder<List<HazPayLoan>>(
        future: _loanHistoryFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                color: theme.primaryColor,
                strokeWidth: 2,
              ),
            );
          }

          if (snapshot.hasError) {
            return _buildErrorState(theme, snapshot.error.toString());
          }

          final loans = snapshot.data ?? [];
          if (loans.isEmpty) {
            return _buildEmptyState(theme);
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _loanHistoryFuture = hazPayService.getLoanHistory(limit: 100);
              });
            },
            color: theme.primaryColor,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: loans.length,
              itemBuilder: (context, index) {
                final loan = loans[index];
                return _buildLoanCard(theme, loan);
              },
            ),
          );
        },
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
              'No loan history yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your loan history will appear here',
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

  Widget _buildErrorState(dynamic theme, String error) {
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
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: theme.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _loanHistoryFuture = hazPayService.getLoanHistory(limit: 100);
                });
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

  Widget _buildLoanCard(dynamic theme, HazPayLoan loan) {
    final statusConfig = _getStatusConfig(loan.status, theme);
    final statusColor = statusConfig['color'] as Color;
    final statusIcon = statusConfig['icon'] as IconData;
    final statusLabel = statusConfig['label'] as String;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  statusIcon,
                  color: statusColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatNaira(loan.loanFee),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '1GB Data Loan',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.greyLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                _buildInfoRow(theme, 'Requested', _formatDate(loan.createdAt)),
                if (loan.issuedAt != null) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow(theme, 'Issued', _formatDate(loan.issuedAt)),
                ],
                if (loan.repaidAt != null) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow(theme, 'Repaid', _formatDate(loan.repaidAt)),
                ],
                if (loan.failureReason != null) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow(theme, 'Reason', loan.failureReason!, isError: true),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(dynamic theme, String label, String value, {bool isError = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: theme.textSecondary,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isError ? theme.error : theme.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

