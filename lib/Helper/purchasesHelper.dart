import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Helper class for managing RevenueCat purchases and subscriptions
class PurchasesHelper {
  // iOS Subscription IDs
  static const String iOSMonthlySubID = 'MonthlySub';
  static const String iOSYearlySubID = 'YearlySub';
  static const String iOSMonthlySubWithSSID = 'SSMonthlyWithSiteSharing';
  static const String iOSYearlySubWithSSID = 'SSYearlyWithSiteSharing';
  
  // Android Subscription IDs
  static const String AndMonthlySubID = 'ssmoothly:ssmonthly';
  static const String AndYearlySubID = 'ssyearly:ssyearly';
  static const String AndMonthlySubWithSSID = 'monthlywithsitesharing:mwithwss';
  static const String AndYearlySubWithSSID = 'yearlywithsitesharing:ywss';
  
  /// Gets available offerings from RevenueCat
  static getOfferings() async {
    return await Purchases.getOfferings();
  }
  
  /// Gets the current subscription ID for the user
  static getCurrentSubscriptionID() async {
    // Get the type
    CustomerInfo info = await Purchases.getCustomerInfo();
    if (kDebugMode) print("*************");
    if (kDebugMode) info.entitlements.active.entries.forEach((element) => print(element));
    // Get the price string
  }
  
  /// Checks if site sharing feature is enabled for the current user
  static Future<bool> isSiteSharingEnabled() async {
    CustomerInfo info = await Purchases.getCustomerInfo();
    if (kDebugMode) print ('::::::::::::::::::::::::');
    if (kDebugMode) print (info.activeSubscriptions);
    
    return Platform.isIOS
        ? info.activeSubscriptions.contains(iOSMonthlySubWithSSID) || 
          info.activeSubscriptions.contains(iOSYearlySubWithSSID)
        : info.activeSubscriptions.contains(AndMonthlySubWithSSID) || 
          info.activeSubscriptions.contains(AndYearlySubWithSSID);
  }
  
  /// Checks if the user has a pro subscription
  static isUserPro() async {
    CustomerInfo info = await Purchases.getCustomerInfo();
    if (kDebugMode) print ('::::::::::::::::::::::::');
    if (kDebugMode) print (info.activeSubscriptions);
    
    return Platform.isIOS
        ? info.activeSubscriptions.contains(iOSMonthlySubWithSSID) || 
          info.activeSubscriptions.contains(iOSYearlySubWithSSID) ||
          info.activeSubscriptions.contains(iOSMonthlySubID) || 
          info.activeSubscriptions.contains(iOSYearlySubID)
        : info.activeSubscriptions.contains(AndMonthlySubWithSSID) || 
          info.activeSubscriptions.contains(AndYearlySubWithSSID) ||
          info.activeSubscriptions.contains(AndMonthlySubID) || 
          info.activeSubscriptions.contains(AndYearlySubID);
  }
  
  /// Configures RevenueCat purchases with the appropriate API keys
  static configurePurchases() async {
    late PurchasesConfiguration configuration;
    
    // Updated API keys as requested
    configuration = PurchasesConfiguration(
      Platform.isAndroid 
          ? "goog_HZFLgHLqCPXcwsaFvWdZWdbYxPn"  // Updated Google API key
          : "appl_QMwLhcamwHcoXWDOsAszWiYHHVO"  // Updated Apple API key
    )..appUserID = FirebaseAuth.instance.currentUser!.uid;
    
    await Purchases.configure(configuration);
  }
  
  /// Purchases a given package
  static purchaseGivenPackage(Package p) async {
    await Purchases.purchasePackage(p);
  }
}