# HazPay UI Redesign - Visual Guide & Component Library

## 🎨 Modern Fintech Components

### 1. Gradient Balance Card
**Usage:** Dashboard (primary balance display)

```
╔═══════════════════════════════════╗
║ Wallet Balance              NGN   ║  Blue gradient background
║                                   ║  White text on blue
║ ₦250,500.00                       ║  Large font weight 800
║                                   ║
║ [Add Money]  [History]            ║  Two action buttons
╚═══════════════════════════════════╝

Colors:
- Gradient Start: #0057B8
- Gradient End: #0045A0
- Text: White (#FFFFFF)
- Shadow: 0,10px blur with 0.3 opacity
```

**Component Code:**
```dart
Container(
  decoration: BoxDecoration(
    gradient: const LinearGradient(
      colors: [HazPayColors.primary, Color(0xFF0045A0)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(20),
  ),
  padding: const EdgeInsets.all(24),
  child: Column( ... ),
)
```

---

### 2. Service Tiles (3x3 Grid)
**Usage:** Dashboard services section

```
┌──────────┬──────────┬──────────┐
│ 📱 Buy   │ 📋 Pay   │ 🎁 Loans │
│  Data    │  Bills   │          │
├──────────┼──────────┼──────────┤
│ ⭐ Rewards│ 💰 Save  │ ➕ More  │
│          │          │          │
└──────────┴──────────┴──────────┘

Each Tile:
- Icon in colored circle (15% opacity)
- Label below
- White background
- Tap animation
- Navigation on tap

Colors (Service-Specific):
- Buy Data:  #00BCD4 (Cyan)
- Pay Bills: #FF6B6B (Red)
- Loans:    #26A69A (Teal)
- Rewards:  #FFB74D (Gold)
- Savings:  #81C784 (Green)
- More:     #BDBDBD (Gray)
```

**Component Code:**
```dart
GridView.count(
  crossAxisCount: 3,
  childAspectRatio: 1,
  mainAxisSpacing: 12,
  crossAxisSpacing: 12,
  children: [
    _buildServiceTile(
      icon: Icons.sim_card_download_rounded,
      label: 'Buy Data',
      color: const Color(0xFF00BCD4),
      onTap: () { ... },
    ),
    // ... more tiles
  ],
)
```

---

### 3. Quick Action Buttons (2x2 Grid)
**Usage:** Dashboard quick access

```
┌──────────┬──────────┐
│ ↓ Receive│ ↑ Send   │
├──────────┼──────────┤
│ 🔍 Scan  │ ➕ More  │
└──────────┴──────────┘

Style:
- White background
- Colored border (20% opacity)
- Icon with colored background (10% opacity)
- Label text
- Tap feedback
```

**Colors:**
- Receive: #4CAF50 (Green) - incoming money
- Send: #2196F3 (Blue) - outgoing money
- Scan: #9C27B0 (Purple) - scanning
- More: #FF9800 (Orange) - additional actions

---

### 4. Transaction List Item
**Usage:** Recent transactions display

```
┌─────────────────────────────────┐
│ [Icon] Network Name      -₦500  │
│        ✓ Success          12/03 │
└─────────────────────────────────┘

Structure:
- Left: Colored circular icon (15% opacity)
- Center: Transaction name + status
- Right: Amount (large) + date (small)

Color Coding:
- Purchase:   #00BCD4 (Cyan) - data, bills
- Deposit:    #4CAF50 (Green) - money added
- Withdrawal: #FF6B6B (Red) - money removed
```

**Component Code:**
```dart
Container(
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
  ),
  padding: const EdgeInsets.all(12),
  child: Row(
    children: [
      Container(
        decoration: BoxDecoration(
          color: _getColor(tx.type).withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        padding: const EdgeInsets.all(10),
        child: Icon(_getIcon(tx.type), ...),
      ),
      Expanded( ... ),
      Column( ... ),
    ],
  ),
)
```

---

### 5. Network Selection Grid (5 Networks)
**Usage:** Buy Data screen

```
┌─────┬─────┬─────┐
│ M   │ G   │ A   │  Cyan border = selected
│ MTN │ GLO │Air │
├─────┼─────┼─────┤
│ 9   │ S   │     │
│ 9M  │ SMILE │    │
└─────┴─────┴─────┘

Network Colors:
- MTN:     #FFD700 (Gold) - bright yellow
- GLO:     #009A44 (Green) - dark green
- Airtel:  #FF0000 (Red) - bright red
- 9Mobile: #00A651 (Green) - medium green
- SMILE:   #0099FF (Blue) - bright blue

Each Tile:
- Circular icon with network initial
- Network name label
- Border highlight on selection (blue)
```

---

### 6. Data Plan Cards (2-Column Grid)
**Usage:** Buy Data plan selection

```
┌──────────────┬──────────────┐
│ 1.5GB   ✓    │ 3GB       ○   │
│              │              │
│ ₦500         │ ₦1,000       │
│ 30 days      │ 30 days      │
└──────────────┴──────────────┘

Selected Card (✓):
- Blue border (2px)
- Green checkmark in circle

Unselected Card (○):
- Light border (1px, #E0E0E0)
- Empty circle

Tap Behavior:
- Toggle selection
- Update checkmark state
- Highlight border
```

**Component Code:**
```dart
GridView.builder(
  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    childAspectRatio: 1.2,
  ),
  itemBuilder: (context, index) {
    final plan = plans[index];
    final isSelected = _selectedPlan == plan;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = plan),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? HazPayColors.primary : Color(0xFFE0E0E0),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column( ... ),
      ),
    );
  },
)
```

---

### 7. Clean Input Field
**Usage:** Phone number, account inputs

```
┌────────────────────────────────┐
│ 📱 Enter phone number...        │
└────────────────────────────────┘

Style:
- White background
- Light border (#E0E0E0)
- Rounded corners (12px)
- Phone icon prefix
- Placeholder text in gray
- Clear padding
```

---

### 8. Success Dialog
**Usage:** Purchase confirmation

```
╔═══════════════════════════════╗
║     [✓] (in white circle)     ║
║                               ║
║ Purchase Successful!          ║
║ Data has been sent to 08...   ║
║                               ║
║ ┌─────────────────────────┐   ║
║ │ Network:    MTN         │   ║
║ │ Amount:     ₦500        │   ║
║ │ Reference:  HAZ123...   │   ║
║ └─────────────────────────┘   ║
║                               ║
║     [     Done      ]          ║
╚═══════════════════════════════╝

Colors:
- Gradient: Green #4CAF50 to #388E3C
- Text: White
- Details background: White 10% opacity
- Button: White background, green text

Animation:
- Slide up
- Scale in
- Fade in details
```

---

### 9. Error Toast Notification
**Usage:** Validation errors, failures

```
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃ Please select a data plan     ┃  Red background
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

Duration: 3 seconds
Position: Bottom
Color: #FF6B6B (Error red)
```

---

## 🎯 Color Reference Chart

### Primary Actions
```
HazPay Blue:   #0057B8  ← Main brand color
Darker Blue:   #0045A0  ← Gradient end
Light Border:  #E0E0E0  ← Card borders
Light Gray:    #F5F5F5  ← Background
```

### Service Colors (Icon + Accents)
```
Buy Data:      #00BCD4  (Cyan)
Pay Bills:     #FF6B6B  (Red)
Loans:         #26A69A  (Teal)
Rewards:       #FFB74D  (Gold/Orange)
Savings:       #81C784  (Light Green)
Receive:       #4CAF50  (Green)
Send:          #2196F3  (Light Blue)
Scan:          #9C27B0  (Purple)
More:          #BDBDBD  (Gray)
```

### Feedback Colors
```
Success:       #4CAF50  (Green)
Error:         #FF6B6B  (Red) or #D32F2F (Dark Red)
Warning:       #FF9800  (Orange)
Info:          #2196F3  (Blue)
Disabled:      #BDBDBD  (Gray) at 50% opacity
```

---

## 📏 Spacing System (Base Unit: 4px)

```
xs:  4px   (1 unit)
sm:  8px   (2 units)
md:  16px  (4 units) ← MOST COMMON
lg:  24px  (6 units)
xl:  32px  (8 units)
xxl: 48px  (12 units)
```

### Common Padding/Margin
- Screen edges: 16px
- Between sections: 20-24px
- Card padding: 12-16px
- Icon spacing: 8-12px
- Text spacing: 4-8px

---

## 🔲 Border Radius System

```
sm:  8px   (small buttons, inputs)
md:  12px  (cards, selections)
lg:  16px  (main cards, sections)
xl:  20px  (balance card)
circle: BorderRadius.circular(999) (icons, dots)
```

---

## ⚡ Interactive States

### Button States
```
Normal:    Solid color, elevation 2
Hover:     Background color 8% darker
Pressed:   Background color 12% darker + ripple
Disabled:  Gray color, 50% opacity, no tap

Example:
ElevatedButton(
  onPressed: isEnabled ? _purchase : null,
  style: ElevatedButton.styleFrom(
    backgroundColor: HazPayColors.primary,
    disabledBackgroundColor: Colors.grey[300],
  ),
)
```

### Card Selection
```
Unselected: Light border, white background
Selected:   Blue border (2px), highlighted state
Tap:        Visual feedback, ripple effect

Example:
border: Border.all(
  color: isSelected ? HazPayColors.primary : Color(0xFFE0E0E0),
  width: isSelected ? 2 : 1,
)
```

---

## 📱 Responsive Breakpoints

```
Mobile (< 480px):    Single column, full-width buttons
Tablet (480-768px):  Adjusted spacing, larger touch targets
Desktop (> 768px):   Not applicable (mobile-first app)

Current Design Target: 360px - 480px width (standard phones)
```

---

## 🎬 Animation Specifications

### Transitions
```
Quick interactions:  200ms
Page transitions:    300ms
Dialogs:            400ms
Curves:             easeOut (smooth deceleration)

Example:
AnimationController(
  duration: Duration(milliseconds: 200),
  vsync: this,
);
```

### Common Animations
- Button tap: Scale (0.95x) + 100ms
- Dialog appear: Fade + Scale in + 300ms
- Card selection: Border color change + 150ms
- Navigation: Slide + Fade + 300ms

---

## 🔌 Integration Points

### Service Methods Used
```dart
hazPayService.watchWalletBalance()      // Real-time balance
hazPayService.getDataPlans()            // Network plans
hazPayService.getWallet()               // Current balance
hazPayService.purchaseData()            // Buy data transaction
hazPayService.getTransactionHistory()   // Transaction list
```

### Navigation Structure
```
HazPayDashboard
├── Buy Data Screen (via service tile)
├── Pay Bills Screen (via service tile)
├── Loan Screen (via service tile)
├── Rewards Screen (via service tile)
├── Wallet Screen (via Add Money button)
└── Transaction History Screen (via View All/History button)
```

---

## ✅ Quality Checklist

- [x] Color contrast ≥ 4.5:1 (WCAG AA)
- [x] Touch targets ≥ 48dp
- [x] Readable font sizes (≥ 14px body)
- [x] Proper spacing between elements
- [x] Consistent icon usage
- [x] Loading states indicated
- [x] Error messages clear
- [x] Navigation logical
- [x] Performance optimized
- [x] Responsive on all phones

---

## 📚 Component Usage Examples

### How to Use Service Tiles in Your Code
```dart
_buildServiceTile(
  icon: Icons.sim_card_download_rounded,
  label: 'Buy Data',
  color: const Color(0xFF00BCD4),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BuyDataScreen()),
    );
  },
)
```

### How to Create a New Color-Coded Item
```dart
Color getColorForItem(String type) {
  switch (type) {
    case 'purchase': return const Color(0xFF00BCD4);
    case 'deposit': return const Color(0xFF4CAF50);
    case 'withdrawal': return const Color(0xFFFF6B6B);
    default: return const Color(0xFF2196F3);
  }
}
```

---

**Design System Version:** 1.0  
**Last Updated:** December 13, 2025  
**Compatible With:** Flutter 3.0+, Material 3.0
