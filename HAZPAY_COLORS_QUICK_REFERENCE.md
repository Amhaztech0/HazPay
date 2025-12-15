# HazPay Colors - Quick Reference Guide

## 🎨 All Available Colors

### Primary Brand Colors
```dart
HazPayColors.primary          // #0057B8 - HazPay Blue (main brand)
HazPayColors.primaryDark      // #0045A0 - Dark Blue (gradients)
HazPayColors.accent           // #00C49A - HazPay Green (secondary)
```

### Text Colors
```dart
HazPayColors.textPrimary      // #222B45 - Main text (dark)
HazPayColors.textSecondary    // #8F9BB3 - Secondary text (gray)
HazPayColors.textMuted        // #999999 - Muted text
```

### Surface Colors
```dart
HazPayColors.background       // #F5F5F5 - Page background
HazPayColors.card             // #FFFFFF - Card background (white)
HazPayColors.surfaceLight     // #F9F9F9 - Light surface
```

### Service Category Colors
```dart
HazPayColors.buyDataColor     // #00BCD4 - Buy Data (Cyan)
HazPayColors.payBillsColor    // #FF6B6B - Pay Bills (Red)
HazPayColors.loanColor        // #26A69A - Loans (Teal)
HazPayColors.rewardsColor     // #FFB74D - Rewards (Gold)
HazPayColors.savingsColor     // #81C784 - Savings (Green)
HazPayColors.receiveColor     // #4CAF50 - Receive (Green)
HazPayColors.sendColor        // #2196F3 - Send (Blue)
HazPayColors.scanColor        // #9C27B0 - Scan (Purple)
HazPayColors.moreColor        // #BDBDBD - More (Gray)
```

### Network Colors
```dart
HazPayColors.mtnColor         // #FFD700 - MTN (Gold)
HazPayColors.gloColor         // #009A44 - GLO (Green)
HazPayColors.airtelColor      // #FF0000 - Airtel (Red)
HazPayColors.nineNobileColor  // #00A651 - 9Mobile (Green)
HazPayColors.smileColor       // #0099FF - SMILE (Blue)
```

### Semantic Colors
```dart
HazPayColors.success          // #4CAF50 - Success (Green)
HazPayColors.successDark      // #388E3C - Success Dark
HazPayColors.error            // #D32F2F - Error (Red)
HazPayColors.errorDark        // #C62828 - Error Dark
HazPayColors.warning          // #FF9800 - Warning (Orange)
HazPayColors.warningDark      // #F57C00 - Warning Dark
HazPayColors.info             // #2196F3 - Info (Blue)
```

### Text on Primary Background
```dart
HazPayColors.onPrimary        // #FFFFFF - White text on blue
HazPayColors.onPrimaryMuted   // #B3FFFFFF - 70% white on blue
HazPayColors.onPrimaryFaint   // #3DFFFFFF - 24% white on blue
```

### Borders & Dividers
```dart
HazPayColors.border           // #E0E0E0 - Light border
HazPayColors.borderLight      // #F0F0F0 - Lighter border
HazPayColors.divider          // #E4E9F2 - Divider
```

### Shadow & Transparency
```dart
HazPayColors.shadow           // #1A222B45 - Card shadow
HazPayColors.shadowLight      // #0D222B45 - Light shadow
HazPayColors.transparent      // #00000000 - Transparent
```

## 🔧 Utility Functions

### Adjust Opacity
```dart
// Make color 50% transparent
HazPayColors.withOpacity(HazPayColors.primary, 0.5)
HazPayColors.alpha(HazPayColors.primary, 0.3)  // 30% opacity
```

### Lighten/Darken
```dart
// Lighten a color
HazPayColors.lighten(HazPayColors.primary)         // +10%
HazPayColors.lighten(HazPayColors.primary, 0.2)   // +20%

// Darken a color
HazPayColors.darken(HazPayColors.primary)          // -10%
HazPayColors.darken(HazPayColors.primary, 0.15)   // -15%
```

## 📝 Usage Examples

### Simple Color
```dart
Container(
  color: HazPayColors.primary,
  child: Text('Hello'),
)
```

### Gradient
```dart
Container(
  decoration: BoxDecoration(
    gradient: LinearGradient(
      colors: [HazPayColors.primary, HazPayColors.primaryDark],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ),
)
```

### Text Style with Color
```dart
Text(
  'Hello',
  style: TextStyle(color: HazPayColors.textPrimary),
)
```

### Transparent Overlay
```dart
Container(
  color: HazPayColors.withOpacity(HazPayColors.primary, 0.1),
)
```

### Border
```dart
Container(
  decoration: BoxDecoration(
    border: Border.all(
      color: HazPayColors.border,
      width: 1,
    ),
  ),
)
```

### Icon with Service Color
```dart
Icon(
  Icons.download,
  color: HazPayColors.buyDataColor,
)
```

### Error State
```dart
Container(
  color: HazPayColors.error.withValues(alpha: 0.1),
  child: Text(
    'Error message',
    style: TextStyle(color: HazPayColors.error),
  ),
)
```

## 📋 Common Patterns

### Service Tile (3x3 Grid)
```dart
Container(
  decoration: BoxDecoration(
    color: HazPayColors.card,
    borderRadius: BorderRadius.circular(16),
  ),
  child: Column(
    children: [
      Container(
        decoration: BoxDecoration(
          color: HazPayColors.buyDataColor.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        padding: EdgeInsets.all(12),
        child: Icon(Icons.sim_card, color: HazPayColors.buyDataColor),
      ),
      Text('Buy Data'),
    ],
  ),
)
```

### Success Dialog
```dart
Dialog(
  child: Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [HazPayColors.success, HazPayColors.successDark],
      ),
    ),
    child: Column(
      children: [
        Icon(Icons.check, color: HazPayColors.onPrimary),
        Text('Success!', style: TextStyle(color: HazPayColors.onPrimary)),
      ],
    ),
  ),
)
```

### Balance Card (Gradient)
```dart
Container(
  decoration: BoxDecoration(
    gradient: LinearGradient(
      colors: [HazPayColors.primary, HazPayColors.primaryDark],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(20),
  ),
  padding: EdgeInsets.all(24),
  child: Column(
    children: [
      Text('Balance', style: TextStyle(color: HazPayColors.onPrimaryMuted)),
      Text('₦250,000', style: TextStyle(color: HazPayColors.onPrimary)),
    ],
  ),
)
```

## ✅ Checklist for Developers

When creating new UI components:
- [ ] Use HazPayColors instead of hardcoded colors
- [ ] Import from `'../../design/hazpay_colors.dart'`
- [ ] Use semantic colors (error, success, warning, info)
- [ ] Apply consistent spacing and radius
- [ ] Check text contrast (should be ≥ 4.5:1)
- [ ] Test in light mode (dark mode coming soon)
- [ ] Verify on different screen sizes

## 🎯 Design System Rules

1. **Never hardcode colors** - Always use HazPayColors
2. **Use semantic colors** - Use error, success, warning instead of random reds/greens
3. **Consistent spacing** - Use HazPaySpacing values
4. **Consistent borders** - Use HazPayRadius values
5. **Group related colors** - Keep colors logically organized

## 🚀 Ready for Production

✅ All colors centralized and named
✅ No hardcoded color values in UI code
✅ Easy to theme and customize
✅ Professional design system approach
✅ Future-proof for dark mode support

---

**Need to change a color across the entire app?** Edit it in one place: `lib/design/hazpay_colors.dart`
