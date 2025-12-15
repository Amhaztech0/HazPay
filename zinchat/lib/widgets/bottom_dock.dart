import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../utils/constants.dart';
import '../providers/theme_provider.dart';

enum DockItem { messages, server, compose, hazpay }

class BottomDock extends StatefulWidget {
  final DockItem selectedItem;
  final Function(DockItem) onItemSelected;

  const BottomDock({
    super.key,
    required this.selectedItem,
    required this.onItemSelected,
  });

  @override
  State<BottomDock> createState() => _BottomDockState();
}

class _BottomDockState extends State<BottomDock>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppAnimations.standard,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onItemTap(DockItem item) {
    // Haptic feedback
    HapticFeedback.mediumImpact();
    
    // Animate
    _controller.forward().then((_) => _controller.reverse());
    
    widget.onItemSelected(item);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        final theme = themeProvider.currentTheme;
        return _buildDock(context, theme);
      },
    );
  }

  Widget _buildDock(BuildContext context, dynamic theme) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Positioned(
      left: AppSpacing.md,
      right: AppSpacing.md,
      bottom: bottomPadding + AppSpacing.lg,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              constraints: BoxConstraints(maxWidth: screenWidth - AppSpacing.md * 2),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md + 8,
                vertical: AppSpacing.md + 2,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.cardBackground.withOpacity(0.7),
                    theme.cardBackground.withOpacity(0.8),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                boxShadow: [
                  BoxShadow(
                    color: theme.primaryColor.withOpacity(0.25),
                    blurRadius: 28,
                    offset: const Offset(0, 8),
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
                border: Border.all(
                  color: theme.primaryColor.withOpacity(0.4),
                  width: 1.5,
                ),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _DockButton(
                      icon: Icons.chat_bubble_rounded,
                      label: 'Messages',
                      isSelected: widget.selectedItem == DockItem.messages,
                      onTap: () => _onItemTap(DockItem.messages),
                    ),
                    const SizedBox(width: 12),
                    _DockButton(
                      icon: Icons.dns_rounded,
                      label: 'Server',
                      isSelected: widget.selectedItem == DockItem.server,
                      onTap: () => _onItemTap(DockItem.server),
                    ),
                    const SizedBox(width: 12),
                    _DockButton(
                      icon: Icons.add_circle_rounded,
                      label: 'Contacts',
                      isSelected: widget.selectedItem == DockItem.compose,
                      isPrimary: true,
                      onTap: () => _onItemTap(DockItem.compose),
                    ),
                    const SizedBox(width: 12),
                    _DockButton(
                      icon: Icons.wallet_rounded,
                      label: 'HazPay',
                      isSelected: widget.selectedItem == DockItem.hazpay,
                      onTap: () => _onItemTap(DockItem.hazpay),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DockButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isPrimary;
  final VoidCallback onTap;

  const _DockButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    this.isPrimary = false,
    required this.onTap,
  });

  @override
  State<_DockButton> createState() => _DockButtonState();
}

class _DockButtonState extends State<_DockButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: AppAnimations.fast,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _scaleController, curve: AppAnimations.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        final theme = themeProvider.currentTheme;
        return _buildButton(context, theme);
      },
    );
  }

  Widget _buildButton(BuildContext context, dynamic theme) {
    final Color iconColor = widget.isSelected
        ? theme.primaryColor
        : theme.textSecondary;
    
    final Color bgColor = widget.isPrimary
        ? theme.primaryColor
        : (widget.isSelected ? theme.greyLight : Colors.transparent);

    return GestureDetector(
      onTapDown: (_) {
        _scaleController.forward();
      },
      onTapUp: (_) {
        _scaleController.reverse();
        widget.onTap();
      },
      onTapCancel: () {
        _scaleController.reverse();
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: AnimatedContainer(
              duration: AppAnimations.fast,
              curve: AppAnimations.easeInOut,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(AppRadius.large),
                boxShadow: widget.isPrimary
                    ? [
                        BoxShadow(
                          color: theme.primaryColor.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.icon,
                    color: widget.isPrimary ? theme.cardBackground : iconColor,
                    size: widget.isPrimary ? 28 : 22,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    widget.label,
                    style: AppTextStyles.caption.copyWith(
                      color: widget.isPrimary ? theme.cardBackground : iconColor,
                      fontWeight:
                          widget.isSelected ? FontWeight.w600 : FontWeight.w400,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
