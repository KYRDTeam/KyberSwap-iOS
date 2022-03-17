//
//  FeatureFlagManager.swift
//  KyberNetwork
//
//  Created by Com1 on 28/02/2022.
//

import LaunchDarkly

public struct FeatureFlagKeys {
  public static let bifinityIntegration = "bifinity-integration"
  public static let promotionCodeIntegration = "promotion-code"
}

class FeatureFlagManager {
  static let shared = FeatureFlagManager()

  func configClient(session: KNSession) {
    let currentAddress = session.wallet.address.description.lowercased()

    var config = LDConfig(mobileKey: KNEnvironment.default.mobileKey)
    config.backgroundFlagPollingInterval = 60
    let user = LDUser(key: currentAddress)
    if let client = LDClient.get() {
      client.identify(user: user)
    }
    LDClient.start(config: config, user: user) {
      KNNotificationUtil.postNotification(for: kUpdateFeatureFlag)
    }
  }

  func showFeature(forKey flagKey: String) -> Bool {
    let client = LDClient.get()!
    return client.variation(forKey: flagKey, defaultValue: false)
  }
}
