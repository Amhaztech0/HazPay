import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:zinchat/services/hazpay_service.dart';
import '../../providers/theme_provider.dart';

class RewardedAdsScreen extends StatefulWidget {
  const RewardedAdsScreen({Key? key}) : super(key: key);

  @override
  State<RewardedAdsScreen> createState() => _RewardedAdsScreenState();
}

class _RewardedAdsScreenState extends State<RewardedAdsScreen> {
  final hazPayService = HazPayService();
  
  RewardedAd? _rewardedAd;
  bool _isAdLoaded = false;
  bool _isWatchingAd = false;
  bool _isRedeeming = false;
  
  int _userPointsInt = 0;
  int _todayAdCount = 0;
  String? _selectedNetwork;
  String? _mobileNumber;
  
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadRewardedAd();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final points = await hazPayService.getUserPoints();
      final todayCount = await hazPayService.getTodayAdCount();

      setState(() {
        _userPointsInt = points;
        _todayAdCount = todayCount;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _loadRewardedAd() {
    try {
      const String testAdUnitId = 'ca-app-pub-3940256099942544/5224354917';
      
      RewardedAd.load(
        adUnitId: testAdUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            debugPrint('✅ Rewarded ad loaded successfully');
            _rewardedAd = ad;
            if (mounted) {
              setState(() => _isAdLoaded = true);
            }
          },
          onAdFailedToLoad: (LoadAdError error) {
            debugPrint('❌ Failed to load rewarded ad: $error');
            if (mounted) {
              setState(() {
                _isAdLoaded = false;
                _rewardedAd = null;
              });
            }
            Future.delayed(const Duration(seconds: 5), _loadRewardedAd);
          },
        ),
      );
    } catch (e) {
      debugPrint('❌ Exception loading ad: $e');
    }
  }

  void _showRewardedAd() async {
    final theme = context.read<ThemeProvider>().currentTheme;
    
    if (!_isAdLoaded || _rewardedAd == null) {
      _showSnackBar('⏳ Ad is still loading... Please try again in a moment.', theme.primaryColor);
      return;
    }

    setState(() => _isWatchingAd = true);

    try {
      _rewardedAd?.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (ad) {
          debugPrint('🎬 Ad shown - watching started');
        },
        onAdDismissedFullScreenContent: (ad) {
          debugPrint('📱 Ad dismissed');
          try {
            ad.dispose();
          } catch (e) {
            debugPrint('⚠️ Error disposing ad: $e');
          }
          if (mounted) {
            setState(() => _isWatchingAd = false);
          }
          _loadRewardedAd();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          debugPrint('❌ Ad failed to show: $error');
          ad.dispose();
          if (mounted) {
            setState(() => _isWatchingAd = false);
          }
        },
      );

      await _rewardedAd!.show(
        onUserEarnedReward: (ad, reward) async {
          debugPrint('✅ REWARD CALLBACK FIRED: User earned ${reward.amount} ${reward.type}');
          
          await hazPayService.recordAdWatched();
          
          if (mounted) {
            _showSnackBar('🎉 +1 Point! Keep watching to earn more!', theme.success);
            _loadUserData();
          }

          try {
            ad.dispose();
          } catch (e) {
            debugPrint('⚠️ Error disposing ad after reward: $e');
          }
          if (mounted) {
            setState(() => _isWatchingAd = false);
          }
          _loadRewardedAd();
        },
      );
    } catch (e) {
      debugPrint('❌ Error showing ad: $e');
      if (mounted) {
        setState(() => _isWatchingAd = false);
        _showSnackBar('Error: $e', theme.error);
      }
    }
  }

  Future<void> _redeemPoints() async {
    final theme = context.read<ThemeProvider>().currentTheme;
    
    if (_selectedNetwork == null || _mobileNumber == null || _mobileNumber!.isEmpty) {
      _showSnackBar('Please select network and enter mobile number', theme.error);
      return;
    }

    setState(() => _isRedeeming = true);

    try {
      final networkId = _selectedNetwork == 'MTN' ? 1 : 2;
      final planId = '${_selectedNetwork}_basic_plan';
      final success = await hazPayService.redeemPointsForData(
        points: 100,
        networkId: networkId,
        planId: planId,
      );

      if (mounted) {
        _showSnackBar(
          success ? 'Redemption successful!' : 'Redemption failed',
          success ? theme.success : theme.error,
        );
        if (success) {
          _mobileNumber = '';
          _selectedNetwork = null;
          _loadUserData();
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error: $e', theme.error);
      }
    } finally {
      setState(() => _isRedeeming = false);
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
          'Earn Points',
          style: TextStyle(
            color: theme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: theme.textPrimary),
            onPressed: _loadUserData,
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
              onRefresh: _loadUserData,
              color: theme.primaryColor,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    if (_error != null) _buildErrorCard(theme),
                    if (_error == null) ...[
                      _buildPointsCard(theme),
                      const SizedBox(height: 20),
                      _buildWatchAdCard(theme),
                      const SizedBox(height: 20),
                      _buildRedemptionCard(theme),
                      const SizedBox(height: 20),
                      _buildHowItWorksCard(theme),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildErrorCard(dynamic theme) {
    return Container(
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

  Widget _buildPointsCard(dynamic theme) {
    final points = _userPointsInt;
    final canRedeem = points >= 100;
    final progress = (points / 100).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
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
        children: [
          const Text(
            'Your Points',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '$points',
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            canRedeem ? '✅ You can redeem now!' : '${100 - points} more points to redeem',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(
                canRedeem ? Colors.greenAccent : Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                '0',
                style: TextStyle(color: Colors.white60, fontSize: 11),
              ),
              Text(
                '100 points',
                style: TextStyle(color: Colors.white60, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWatchAdCard(dynamic theme) {
    final canWatch = _todayAdCount < 10;
    final adsLeft = 10 - _todayAdCount;

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
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.videocam,
                  color: theme.primaryColor,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Watch Ad',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.textPrimary,
                      ),
                    ),
                    Text(
                      'Earn 1 point per ad',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: (canWatch ? theme.success : theme.error).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  canWatch ? '$adsLeft/10' : 'Limit',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: canWatch ? theme.success : theme.error,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (!canWatch)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: theme.warning, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Daily limit reached. Try again tomorrow!',
                      style: TextStyle(
                        color: theme.warning,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: (_isAdLoaded && !_isWatchingAd) ? _showRewardedAd : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  disabledBackgroundColor: theme.grey.withOpacity(0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isWatchingAd
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
                          Icon(Icons.play_arrow, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Watch Ad Now',
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
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (_isAdLoaded ? theme.success : theme.warning).withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: (_isAdLoaded ? theme.success : theme.warning).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isAdLoaded ? Icons.check_circle : Icons.hourglass_top,
                    color: _isAdLoaded ? theme.success : theme.warning,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _isAdLoaded ? 'Ad ready to watch' : 'Loading ad... Please wait',
                    style: TextStyle(
                      color: _isAdLoaded ? theme.success : theme.warning,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRedemptionCard(dynamic theme) {
    final canRedeem = _userPointsInt >= 100;

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
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.secondaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.card_giftcard,
                  color: theme.secondaryColor,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Redeem 100 Points',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.textPrimary,
                      ),
                    ),
                    Text(
                      'Get 500MB Free Data',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: (canRedeem ? theme.secondaryColor : theme.grey).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  canRedeem ? '✅' : '🔒',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (!canRedeem)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.greyLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Watch ${100 - _userPointsInt} more ads to unlock redemption',
                style: TextStyle(
                  color: theme.textSecondary,
                  fontSize: 13,
                ),
              ),
            )
          else ...[
            Text(
              'Select Network',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildNetworkButton(theme, 'MTN', const Color(0xFFFFC107)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildNetworkButton(theme, 'GLO', const Color(0xFF4CAF50)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: theme.greyLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.divider),
              ),
              child: TextField(
                onChanged: (value) => _mobileNumber = value,
                style: TextStyle(color: theme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Enter mobile number',
                  hintStyle: TextStyle(color: theme.textSecondary.withOpacity(0.7)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  prefixIcon: Icon(Icons.phone, color: theme.textSecondary),
                ),
                keyboardType: TextInputType.phone,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: (_isRedeeming || _selectedNetwork == null || (_mobileNumber?.isEmpty ?? true))
                    ? null
                    : _redeemPoints,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.secondaryColor,
                  disabledBackgroundColor: theme.grey.withOpacity(0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isRedeeming
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Redeem Now',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNetworkButton(dynamic theme, String network, Color color) {
    final isSelected = _selectedNetwork == network;

    return GestureDetector(
      onTap: () => setState(() => _selectedNetwork = isSelected ? null : network),
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
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  network[0],
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              network,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? color : theme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHowItWorksCard(dynamic theme) {
    final steps = [
      {'icon': Icons.videocam, 'text': 'Watch a rewarded ad to earn 1 point'},
      {'icon': Icons.trending_up, 'text': 'Accumulate points in your account'},
      {'icon': Icons.card_giftcard, 'text': 'Redeem 100 points for 500MB data'},
      {'icon': Icons.access_time, 'text': 'Max 10 ads per day (resets at midnight)'},
      {'icon': Icons.flash_on, 'text': 'Data is added instantly to your account'},
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

  @override
  void dispose() {
    try {
      _rewardedAd?.dispose();
    } catch (e) {
      debugPrint('⚠️ Error disposing rewarded ad: $e');
    }
    super.dispose();
  }
}


