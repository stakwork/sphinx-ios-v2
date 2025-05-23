platform :ios, '15.0'
use_frameworks!
inhibit_all_warnings!

install! 'cocoapods'

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings["EXCLUDED_ARCHS[sdk=iphonesimulator*]"] = "arm64"
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
      config.build_settings['ENABLE_BITCODE'] = 'NO'
      config.build_settings["SWIFT_OPTIMIZATION_LEVEL"] = "-Onone"
      config.build_settings['ONLY_ACTIVE_ARCH'] = 'NO'

      xcconfig_path = config.base_configuration_reference.real_path
      xcconfig = File.read(xcconfig_path)
      xcconfig_mod = xcconfig.gsub(/DT_TOOLCHAIN_DIR/, "TOOLCHAIN_DIR")
      File.open(xcconfig_path, "w") { |file| file << xcconfig_mod }
    end
  end
end

target 'sphinx' do
    pod 'Alamofire', '~> 5.6.4'
    pod 'ReachabilitySwift'
    pod 'SwiftyJSON'
    pod 'SDWebImage', '~> 5.12'
    pod 'SDWebImageFLPlugin'
    pod 'SDWebImageSVGCoder', '~> 1.5.0'
    pod 'SDWebImageSwiftUI'
    pod 'KYDrawerController'
    pod 'SwiftyRSA'
    pod 'RNCryptor', '~> 5.0'
    pod 'SwiftLinkPreview', '~> 3.4.0'
    pod 'JitsiMeetSDK', '~> 11.1.1'
    pod 'PINCache'
    pod 'KeychainAccess'
    pod 'Giphy', '2.2.12'
    pod 'Starscream', '~> 3.1'
    pod 'lottie-ios'
    pod "SwiftyXMLParser", :git => 'https://github.com/yahoojapan/SwiftyXMLParser.git'
    pod "youtube-ios-player-helper", "~> 1.0.3"
    pod 'MarqueeLabel'
    pod 'ObjectMapper'
    pod 'UIView-Shimmer', '~> 1.0'
    pod 'CocoaMQTT', :git => 'https://github.com/emqx/CocoaMQTT.git'
    pod 'MessagePack.swift', '~> 4.0'
    pod 'EPUBKit'
    pod 'MobileVLCKit'
    pod 'Bugsnag'
end

target 'SphinxNotificationExtensionService' do
    pod 'RNCryptor', '~> 5.0'
    pod 'KeychainAccess'
end
