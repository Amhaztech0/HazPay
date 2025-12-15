import 'package:flutter/material.dart';
import 'package:zinchat/services/hazpay_service.dart';
import 'package:zinchat/models/app_theme.dart';
import 'package:zinchat/utils/helpers.dart';

/// A beautiful receipt widget that displays transaction details
/// Can be used in dialogs, modal sheets, or transaction history
/// Supports both HazPayTransaction and BillPayment models
class ReceiptWidget extends StatelessWidget {
  final HazPayTransaction? transaction;
  final BillPayment? billPayment;
  final AppTheme theme;
  final bool isCompact;
  final bool showCloseButton;
  final VoidCallback? onClose;

  const ReceiptWidget({
    Key? key,
    this.transaction,
    this.billPayment,
    required this.theme,
    this.isCompact = false,
    this.showCloseButton = false,
    this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: isCompact ? _buildCompactReceipt() : _buildFullReceipt(context),
    );
  }

  /// Full receipt with all details
  Widget _buildFullReceipt(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header with status and close button
        Container(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          decoration: BoxDecoration(
            color: _getStatusBackgroundColor(),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Close button (if needed)
              if (showCloseButton)
                Align(
                  alignment: Alignment.topRight,
                  child: GestureDetector(
                    onTap: onClose ?? () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.cardBackground.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        color: theme.cardBackground,
                        size: 20,
                      ),
                    ),
                  ),
                )
              else
                const SizedBox.shrink(),

              const SizedBox(height: 12),

              // Status icon and badge
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: theme.cardBackground.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    _getStatusIcon(),
                    size: 40,
                    color: theme.cardBackground,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Status text
              Container(
                decoration: BoxDecoration(
                  color: theme.cardBackground.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  _getStatusText(),
                  style: TextStyle(
                    color: theme.cardBackground,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Amount
              Text(
                formatNaira(_getAmount()),
                style: TextStyle(
                  color: theme.cardBackground,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),

              const SizedBox(height: 8),

              // Transaction type
              Text(
                _getTransactionTypeLabel(),
                style: TextStyle(
                  color: theme.cardBackground.withOpacity(0.8),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        // Divider
        Container(
          height: 1,
          color: theme.divider.withOpacity(0.3),
        ),

        // Receipt details
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              _buildReceiptRow(
                'Date & Time',
                transaction != null ? _formatDateTime(transaction!.createdAt) : _formatDateTime(billPayment!.createdAt),
                theme,
              ),
              const SizedBox(height: 16),
              _buildReceiptRow(
                'Transaction ID',
                transaction?.id ?? billPayment!.id,
                theme,
                isCopyable: true,
              ),
              const SizedBox(height: 16),

              // Network (if applicable - for transactions)
              if (transaction?.networkName != null) ...[
                _buildReceiptRow('Network', transaction!.networkName!, theme),
                const SizedBox(height: 16),
              ],

              // Provider (if applicable - for bill payments)
              if (billPayment != null) ...[
                _buildReceiptRow('Provider', billPayment!.provider, theme),
                const SizedBox(height: 16),
              ],

              // Data capacity (if applicable)
              if (transaction?.dataCapacity != null) ...[
                _buildReceiptRow('Data Plan', transaction!.dataCapacity!, theme),
                const SizedBox(height: 16),
              ],

              // Mobile number (if applicable - for transactions)
              if (transaction?.mobileNumber != null) ...[
                _buildReceiptRow('Phone Number', transaction!.mobileNumber!, theme),
                const SizedBox(height: 16),
              ],

              // Account number (if applicable - for bill payments)
              if (billPayment?.accountNumber != null) ...[
                _buildReceiptRow('Account Number', billPayment!.accountNumber, theme),
                const SizedBox(height: 16),
              ],

              // Reference (if available)
              if (transaction?.reference != null) ...[
                _buildReceiptRow('Reference', transaction!.reference!, theme),
                const SizedBox(height: 16),
              ],

              // Error message (if failed)
              if (_getStatus() == 'failed' && _getErrorMessage() != null) ...[
                Container(
                  decoration: BoxDecoration(
                    color: theme.error.withOpacity(0.1),
                    border: Border.all(
                      color: theme.error.withOpacity(0.3),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        color: theme.error,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _getErrorMessage()!,
                          style: TextStyle(
                            color: theme.error,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Bottom divider
              Container(
                height: 1,
                color: theme.divider.withOpacity(0.2),
                margin: const EdgeInsets.symmetric(vertical: 8),
              ),

              // Footer message
              Text(
                _getFooterMessage(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.textSecondary,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Compact receipt for transaction history
  Widget _buildCompactReceipt() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Compact header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          decoration: BoxDecoration(
            color: _getStatusBackgroundColor().withOpacity(0.1),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            border: Border(
              bottom: BorderSide(
                color: _getStatusBackgroundColor().withOpacity(0.2),
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getTransactionTypeLabel(),
                      style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatNaira(_getAmount()),
                      style: TextStyle(
                        color: theme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _getStatusBackgroundColor().withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        _getStatusIcon(),
                        size: 24,
                        color: _getStatusBackgroundColor(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getStatusBackgroundColor().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _getStatusText(),
                      style: TextStyle(
                        color: _getStatusBackgroundColor(),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Compact details
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildCompactReceiptRow(
                'Date',
                transaction != null ? _formatDateOnly(transaction!.createdAt) : _formatDateOnly(billPayment!.createdAt),
                theme,
              ),
              const SizedBox(height: 12),
              _buildCompactReceiptRow('Transaction ID', transaction?.id ?? billPayment!.id, theme, showTruncation: true),

              if (transaction?.networkName != null) ...[
                const SizedBox(height: 12),
                _buildCompactReceiptRow('Network', transaction!.networkName!, theme),
              ],

              if (billPayment != null) ...[
                const SizedBox(height: 12),
                _buildCompactReceiptRow('Provider', billPayment!.provider, theme),
              ],

              if (transaction?.mobileNumber != null) ...[
                const SizedBox(height: 12),
                _buildCompactReceiptRow('Phone', transaction!.mobileNumber!, theme),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Receipt row for full receipt
  static Widget _buildReceiptRow(
    String label,
    String value,
    AppTheme theme, {
    bool isCopyable = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: theme.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: GestureDetector(
                onTap: isCopyable ? () => _copyToClipboard(value) : null,
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    decoration: isCopyable ? TextDecoration.underline : null,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Compact receipt row for transaction history
  static Widget _buildCompactReceiptRow(
    String label,
    String value,
    AppTheme theme, {
    bool showTruncation = false,
  }) {
    String displayValue = value;
    if (showTruncation && value.length > 20) {
      displayValue = '${value.substring(0, 10)}...${value.substring(value.length - 6)}';
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: theme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          displayValue,
          style: TextStyle(
            color: theme.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  static void _copyToClipboard(String value) {
    // TODO: Implement clipboard functionality when needed
    // For now, this is a placeholder
  }

  // Helper methods
  String _getStatus() => transaction?.status ?? billPayment?.status ?? 'pending';

  double _getAmount() => transaction?.amount ?? billPayment?.amount ?? 0;

  String? _getErrorMessage() => transaction?.errorMessage ?? billPayment?.errorMessage;

  String _getStatusText() {
    final status = _getStatus();
    switch (status) {
      case 'success':
        return 'SUCCESSFUL';
      case 'pending':
        return 'PENDING';
      case 'failed':
        return 'FAILED';
      default:
        return status.toUpperCase();
    }
  }

  IconData _getStatusIcon() {
    final status = _getStatus();
    switch (status) {
      case 'success':
        return Icons.check_circle_rounded;
      case 'pending':
        return Icons.schedule_rounded;
      case 'failed':
        return Icons.cancel_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  Color _getStatusBackgroundColor() {
    final status = _getStatus();
    switch (status) {
      case 'success':
        return theme.success;
      case 'pending':
        return theme.warning;
      case 'failed':
        return theme.error;
      default:
        return theme.info;
    }
  }

  String _getTransactionTypeLabel() {
    if (transaction != null) {
      switch (transaction!.type) {
        case 'purchase':
          return 'Data Purchase';
        case 'deposit':
          return 'Wallet Deposit';
        case 'withdrawal':
          return 'Wallet Withdrawal';
        case 'bill_payment':
          return 'Bill Payment';
        default:
          return transaction!.type;
      }
    } else if (billPayment != null) {
      return 'Bill Payment - ${billPayment!.provider}';
    }
    return 'Payment';
  }

  String _getFooterMessage() {
    final status = _getStatus();
    switch (status) {
      case 'success':
        return 'Transaction completed successfully';
      case 'pending':
        return 'Your transaction is being processed. Please wait...';
      case 'failed':
        return 'Transaction failed. Please try again or contact support.';
      default:
        return 'Thank you for using HazPay';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final txDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    String dateStr;
    if (txDate == today) {
      dateStr = 'Today';
    } else if (txDate == yesterday) {
      dateStr = 'Yesterday';
    } else {
      dateStr = '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }

    final timeStr = '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    return '$dateStr at $timeStr';
  }

  String _formatDateOnly(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
  }
}

/// Dialog version of receipt (for immediate payment success)
class ReceiptDialog extends StatelessWidget {
  final HazPayTransaction? transaction;
  final BillPayment? billPayment;
  final AppTheme theme;
  final VoidCallback? onClose;

  const ReceiptDialog({
    Key? key,
    this.transaction,
    this.billPayment,
    required this.theme,
    this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.transparent,
      child: ReceiptWidget(
        transaction: transaction,
        billPayment: billPayment,
        theme: theme,
        showCloseButton: true,
        onClose: onClose ?? () => Navigator.pop(context),
      ),
    );
  }
}

/// Bottom sheet version of receipt (for transaction history)
class ReceiptBottomSheet extends StatelessWidget {
  final HazPayTransaction? transaction;
  final BillPayment? billPayment;
  final AppTheme theme;

  const ReceiptBottomSheet({
    Key? key,
    this.transaction,
    this.billPayment,
    required this.theme,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardBackground,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 48,
            height: 4,
            decoration: BoxDecoration(
              color: theme.textSecondary.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Receipt content
          Expanded(
            child: SingleChildScrollView(
              child: ReceiptWidget(
                transaction: transaction,
                billPayment: billPayment,
                theme: theme,
                isCompact: false,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

