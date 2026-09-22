Pod::Spec.new do |s|
  s.name             = 'UTEBluetoothRYApi'
  s.version          = '1.3.1'
  s.summary          = 'UTE Bluetooth RY Api Framework for KALKAN SPORT'
  s.description      = 'Native iOS SDK for UTE / JieLi Bluetooth Smart Watches.'
  s.homepage         = 'https://github.com/heroku134/barys-biotracker'
  s.license          = { :type => 'Commercial', :text => 'Commercial' }
  s.author           = { 'UTE' => 'support@ute.com' }
  s.source           = { :path => '.' }
  s.platform         = :ios, '13.0'
  s.vendored_frameworks = 'Frameworks/UTEBluetoothRYApi.framework'
  s.source_files     = 'Classes/**/*.{h,m,c}'
  s.resources        = 'Frameworks/UTEBluetoothRYApi.framework/UTEBluetoothRYApi.bundle'
  s.libraries        = 'c++'
  s.frameworks       = 'CoreBluetooth', 'UIKit', 'Foundation'
  s.dependency 'SSZipArchive'
  s.dependency 'MJExtension'
  s.dependency 'iOSOTAJL'
  s.dependency 'SocketRocket'
  s.pod_target_xcconfig = {
    'OTHER_LDFLAGS' => '-ObjC',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386 arm64'
  }
end
