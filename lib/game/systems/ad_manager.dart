import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Types of rewards that can be earned by watching ads.
enum AdRewardType {
  continueAfterDeath,
  doubleGold,
  doubleSpirit,
}

/// Singleton manager for Google AdMob ads.
///
/// Handles rewarded video ads (optional, player-initiated) and
/// interstitial ads (shown every 5th death).
class AdManager {
  AdManager._();
  static final AdManager instance = AdManager._();

  // ═══════════════════════════════════════════════════════════════════════════
  // Ad Unit IDs
  // ═══════════════════════════════════════════════════════════════════════════

  // Android production ad unit IDs
  static const String _androidRewardedAdUnitId = 'ca-app-pub-7133882009437292/4562177719';
  static const String _androidInterstitialAdUnitId = 'ca-app-pub-7133882009437292/1936014370';

  // iOS production ad unit IDs
  static const String _iosRewardedAdUnitId = 'ca-app-pub-7133882009437292/4814931335';
  static const String _iosInterstitialAdUnitId = 'ca-app-pub-7133882009437292/5011837495';

  static String get _rewardedAdUnitId =>
      Platform.isIOS ? _iosRewardedAdUnitId : _androidRewardedAdUnitId;

  static String get _interstitialAdUnitId =>
      Platform.isIOS ? _iosInterstitialAdUnitId : _androidInterstitialAdUnitId;

  // ═══════════════════════════════════════════════════════════════════════════
  // State
  // ═══════════════════════════════════════════════════════════════════════════

  bool _initialized = false;
  bool get isInitialized => _initialized;

  RewardedAd? _rewardedAd;
  InterstitialAd? _interstitialAd;

  bool _isRewardedAdLoading = false;
  bool _isInterstitialAdLoading = false;

  /// Whether a rewarded ad is ready to show.
  bool get isRewardedAdReady => _rewardedAd != null;

  /// Whether an interstitial ad is ready to show.
  bool get isInterstitialAdReady => _interstitialAd != null;

  /// Persistent death count for interstitial frequency.
  int _deathCount = 0;
  int get deathCount => _deathCount;

  /// Whether an ad-continue has already been used this run.
  bool _adContinueUsedThisRun = false;
  bool get adContinueUsedThisRun => _adContinueUsedThisRun;

  /// Whether the double-gold ad was used this wave break.
  bool _doubleGoldUsedThisBreak = false;
  bool get doubleGoldUsedThisBreak => _doubleGoldUsedThisBreak;

  static const String _deathCountKey = 'ad_death_count';

  // ═══════════════════════════════════════════════════════════════════════════
  // Initialization
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await MobileAds.instance.initialize();
      _initialized = true;
      debugPrint('[AdManager] MobileAds initialized');

      // Load persistent death count
      final prefs = await SharedPreferences.getInstance();
      _deathCount = prefs.getInt(_deathCountKey) ?? 0;

      // Pre-load ads
      _loadRewardedAd();
      _loadInterstitialAd();
    } catch (e) {
      debugPrint('[AdManager] Failed to initialize MobileAds: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Run lifecycle
  // ═══════════════════════════════════════════════════════════════════════════

  /// Call at the start of each new game run.
  void resetRunState() {
    _adContinueUsedThisRun = false;
    _doubleGoldUsedThisBreak = false;
  }

  /// Call at the start of each wave break.
  void resetWaveBreakState() {
    _doubleGoldUsedThisBreak = false;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Rewarded Ads
  // ═══════════════════════════════════════════════════════════════════════════

  void _loadRewardedAd() {
    if (_rewardedAd != null || _isRewardedAdLoading) return;
    _isRewardedAdLoading = true;

    RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedAdLoading = false;
          debugPrint('[AdManager] Rewarded ad loaded');
        },
        onAdFailedToLoad: (error) {
          _isRewardedAdLoading = false;
          debugPrint('[AdManager] Rewarded ad failed to load: ${error.message}');
          // Retry after a delay
          Future.delayed(const Duration(seconds: 30), _loadRewardedAd);
        },
      ),
    );
  }

  /// Show a rewarded ad. Calls [onRewarded] with the reward type if the user
  /// watches the entire ad. Calls [onFailed] if the ad cannot be shown.
  void showRewardedAd({
    required AdRewardType rewardType,
    required VoidCallback onRewarded,
    VoidCallback? onFailed,
  }) {
    final ad = _rewardedAd;
    if (ad == null) {
      debugPrint('[AdManager] No rewarded ad available');
      onFailed?.call();
      return;
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        _loadRewardedAd(); // Pre-load next ad
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('[AdManager] Rewarded ad failed to show: ${error.message}');
        ad.dispose();
        _rewardedAd = null;
        _loadRewardedAd();
        onFailed?.call();
      },
    );

    ad.show(onUserEarnedReward: (ad, reward) {
      debugPrint('[AdManager] Reward earned: ${rewardType.name} (${reward.amount} ${reward.type})');
      switch (rewardType) {
        case AdRewardType.continueAfterDeath:
          _adContinueUsedThisRun = true;
          break;
        case AdRewardType.doubleGold:
          _doubleGoldUsedThisBreak = true;
          break;
        case AdRewardType.doubleSpirit:
          // No per-goal tracking needed; the reward is applied immediately
          break;
      }
      onRewarded();
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Interstitial Ads (every 5th death)
  // ═══════════════════════════════════════════════════════════════════════════

  void _loadInterstitialAd() {
    if (_interstitialAd != null || _isInterstitialAdLoading) return;
    _isInterstitialAdLoading = true;

    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialAdLoading = false;
          debugPrint('[AdManager] Interstitial ad loaded');
        },
        onAdFailedToLoad: (error) {
          _isInterstitialAdLoading = false;
          debugPrint('[AdManager] Interstitial ad failed to load: ${error.message}');
          Future.delayed(const Duration(seconds: 30), _loadInterstitialAd);
        },
      ),
    );
  }

  /// Record a death and show interstitial if it's every 5th death.
  /// Calls [onComplete] when the ad is dismissed (or immediately if no ad shown).
  Future<void> recordDeathAndShowInterstitial({VoidCallback? onComplete}) async {
    _deathCount++;
    // Persist death count
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_deathCountKey, _deathCount);
    } catch (e) {
      debugPrint('[AdManager] Failed to persist death count: $e');
    }

    if (_deathCount % 5 == 0 && _interstitialAd != null) {
      debugPrint('[AdManager] Showing interstitial (death #$_deathCount)');
      final ad = _interstitialAd!;
      _interstitialAd = null;

      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _loadInterstitialAd(); // Pre-load next
          onComplete?.call();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          debugPrint('[AdManager] Interstitial failed to show: ${error.message}');
          ad.dispose();
          _loadInterstitialAd();
          onComplete?.call();
        },
      );
      ad.show();
    } else {
      onComplete?.call();
    }
  }
}
