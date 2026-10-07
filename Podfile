platform :ios, '27.0'

target 'PosesEventDemo' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  pod 'GoogleMLKit/PoseDetection', '8.0.0'
  pod 'GoogleMLKit/PoseDetectionAccurate', '8.0.0'

end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
      config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
      config.build_settings['CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER'] = 'NO'
      config.build_settings['GCC_TREAT_WARNINGS_AS_ERRORS'] = 'NO'
    end
  end
end
