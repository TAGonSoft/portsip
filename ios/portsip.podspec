#
# PortSIP Flutter Plugin - iOS Podspec
#
# This podspec defines the iOS native dependencies and configuration for the PortSIP Flutter plugin.
# The plugin integrates the PortSIP VoIP SDK to enable SIP-based voice and video communications.
#
# The SDK is shipped compressed and will be automatically extracted during pod install.
#
# To learn more about Podspec syntax: http://guides.cocoapods.org/syntax/podspec.html
#

# Path to the compressed SDK (shipped with the plugin)
sdk_folder = File.join(__dir__, 'SDK')
sdk_archive_path = File.join(sdk_folder, 'PortSIPVoIPSDK.xcframework.tar.xz')
sdk_extracted_path = File.join(sdk_folder, 'PortSIPVoIPSDK.xcframework')

# Check if compressed SDK exists
unless File.exist?(sdk_archive_path)
  raise <<-ERROR

  ════════════════════════════════════════════════════════════════════════════════
  ERROR: PortSIP SDK archive not found!

  Expected location: #{sdk_archive_path}

  The compressed SDK should be included with the plugin. If you're seeing this
  error, the plugin installation may be incomplete. Try reinstalling the plugin.
  ════════════════════════════════════════════════════════════════════════════════

  ERROR
end

# Extract SDK if not already extracted
unless File.exist?(sdk_extracted_path)
  puts "Extracting PortSIP SDK..."
  system("tar -xJf '#{sdk_archive_path}' -C '#{sdk_folder}'")

  unless File.exist?(sdk_extracted_path)
    raise <<-ERROR

  ════════════════════════════════════════════════════════════════════════════════
  ERROR: Failed to extract PortSIP SDK!

  Could not extract #{sdk_archive_path}

  Please ensure you have 'tar' and 'xz' installed and try again.
  On macOS: brew install xz
  ════════════════════════════════════════════════════════════════════════════════

    ERROR
  end
  puts "PortSIP SDK extracted successfully."
end

Pod::Spec.new do |s|
  s.name             = 'portsip'
  s.version          = '0.0.1'
  s.summary          = 'A Flutter plugin for integrating PortSIP VoIP SDK, enabling SIP-based voice and video communications.'
  s.description      = <<-DESC
                       Portsip is a Flutter plugin that integrates the PortSIP VoIP SDK into your iOS application. It enables SIP-based voice and video communications by exposing PortSIP's robust features to Flutter, allowing developers to build cross-platform mobile apps with secure, reliable, and high-quality VoIP calling capabilities.
                       DESC
  s.homepage         = 'https://pub.dev'
  s.license          = { :type => 'Proprietary' }
  s.author           = { 'TAGonSoft' => 'contact@tagonsoft.ro' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'
  s.swift_version = '5.0'

  # Use the extracted framework (relative path required by CocoaPods)
  s.vendored_frameworks = 'SDK/PortSIPVoIPSDK.xcframework'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'OTHER_LDFLAGS' => '-ObjC'
  }

  s.user_target_xcconfig = {
    'OTHER_LDFLAGS' => '-ObjC'
  }

  s.frameworks = 'VideoToolbox', 'AVFoundation', 'AudioToolbox', 'CoreMedia', 'CoreVideo', 'MetalKit', 'CallKit'
  s.libraries = 'resolv', 'c++'
end
