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

# Display setup reminder.
# Note: We cannot reliably detect the consuming app's framework location from here
# (paths differ between path dependencies and pub.dev dependencies). The actual
# framework resolution happens at compile time via FRAMEWORK_SEARCH_PATHS.
Pod::UI.puts <<-INFO

  [portsip] The PortSIP VoIP SDK is NOT bundled with this plugin.
  [portsip] Ensure PortSIPVoIPSDK.xcframework is placed at ios/Frameworks/
  [portsip] and embedded in Xcode (Embed & Sign). See README for details.

INFO

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

  # NOTE: vendored_frameworks is intentionally removed.
  # The PortSIP VoIP SDK must be provided by the consuming app.
  # Developers must place PortSIPVoIPSDK.xcframework in their app's ios/Frameworks/ directory
  # and embed it in Xcode (Embed & Sign).

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'OTHER_LDFLAGS' => '-ObjC',
    # Allow the plugin to find PortSIPVoIPSDK.xcframework in the app's ios/Frameworks directory.
    # $(PODS_ROOT)/.. resolves to the consuming app's ios/ directory.
    'FRAMEWORK_SEARCH_PATHS' => '$(inherited) "$(PODS_ROOT)/../Frameworks"',
  }

  s.user_target_xcconfig = {
    'OTHER_LDFLAGS' => '-ObjC'
  }

  s.frameworks = 'VideoToolbox', 'AVFoundation', 'AudioToolbox', 'CoreMedia', 'CoreVideo', 'MetalKit', 'CallKit'
  s.libraries = 'resolv', 'c++'
end
