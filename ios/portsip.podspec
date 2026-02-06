#
# PortSIP Flutter Plugin - iOS Podspec
#
# This podspec defines the iOS native dependencies and configuration for the PortSIP Flutter plugin.
# The plugin integrates the PortSIP VoIP SDK to enable SIP-based voice and video communications.
#
# IMPORTANT: The PortSIP VoIP SDK is NOT bundled with this plugin.
# You must download and place it manually. See the README for instructions.
#
# To learn more about Podspec syntax: http://guides.cocoapods.org/syntax/podspec.html
#

# The developer places the xcframework at their app's ios/Frameworks/ directory.
# CocoaPods needs vendored_frameworks to properly handle xcframeworks (architecture
# selection, module maps, embedding). We create a symlink from SDK/ to the app's
# Frameworks/ directory so vendored_frameworks can find it.

sdk_dir = File.join(__dir__, 'SDK')
sdk_framework = File.join(sdk_dir, 'PortSIPVoIPSDK.xcframework')

unless File.exist?(sdk_framework)
  # During pod install, Dir.pwd is the directory containing the Podfile (app's ios/ directory)
  app_framework = File.join(Dir.pwd, 'Frameworks', 'PortSIPVoIPSDK.xcframework')

  if File.exist?(app_framework)
    Dir.mkdir(sdk_dir) unless Dir.exist?(sdk_dir)
    source_abs = File.expand_path(app_framework)
    File.symlink(source_abs, sdk_framework)
    Pod::UI.puts "[portsip] Linked PortSIP SDK from: #{source_abs}"
  else
    Pod::UI.warn <<-WARNING

  ════════════════════════════════════════════════════════════════════════════════
  WARNING: PortSIP VoIP SDK framework not found!

  The portsip plugin requires the PortSIP VoIP SDK to be placed at:

    ios/Frameworks/PortSIPVoIPSDK.xcframework

  Download the SDK from:
    https://www.portsip.com/download-portsip-voip-sdk/

  Then extract and copy PortSIPVoIPSDK.xcframework to your app's
  ios/Frameworks/ directory.

  The build will FAIL if the framework is not present.
  ════════════════════════════════════════════════════════════════════════════════

    WARNING
  end
end

Pod::Spec.new do |s|
  s.name             = 'portsip'
  s.version          = '0.0.2'
  s.summary          = 'A Flutter plugin for integrating PortSIP VoIP SDK, enabling SIP-based voice and video communications.'
  s.description      = <<-DESC
                       Portsip is a Flutter plugin that integrates the PortSIP VoIP SDK into your iOS application.
                       It enables SIP-based voice and video communications by exposing PortSIP's robust features
                       to Flutter, allowing developers to build cross-platform mobile apps with secure, reliable,
                       and high-quality VoIP calling capabilities.

                       IMPORTANT: The PortSIP VoIP SDK is not bundled with this plugin.
                       You must download the SDK from PortSIP and place the xcframework in your app's
                       ios/Frameworks/ directory. See the README for detailed setup instructions.
                       DESC
  s.homepage         = 'https://pub.dev'
  s.license          = { :type => 'Proprietary' }
  s.author           = { 'TAGonSoft' => 'contact@tagonsoft.ro' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'
  s.swift_version = '5.0'

  # The xcframework is symlinked from the app's ios/Frameworks/ directory during pod install.
  # vendored_frameworks is required for CocoaPods to properly handle xcframeworks
  # (architecture selection, module maps, and embedding into the app bundle).
  s.vendored_frameworks = 'SDK/PortSIPVoIPSDK.xcframework'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'OTHER_LDFLAGS' => '-ObjC',
  }

  s.user_target_xcconfig = {
    'OTHER_LDFLAGS' => '-ObjC'
  }

  s.frameworks = 'VideoToolbox', 'AVFoundation', 'AudioToolbox', 'CoreMedia', 'CoreVideo', 'MetalKit', 'CallKit', 'Network'
  s.libraries = 'resolv', 'c++'
end
