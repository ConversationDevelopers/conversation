# Uncomment this line to define a global platform for your project
# platform :ios, '6.0'

source 'https://github.com/CocoaPods/Specs.git'

target 'conversation' do
	pod 'PHFComposeBarView', '~> 2.0.1'
	pod 'DLImageLoader', '~> 2.0.0'
	pod 'YLGIFImage', :git => 'https://github.com/liyong03/YLGIFImage.git'
	pod 'UIActionSheet+Blocks'
	pod 'ImgurAnonymousAPIClient', :git => 'https://github.com/nolanw/ImgurAnonymousAPIClient.git', :tag => 'v0.2'
	pod 'SHTransitionBlocks' 
	pod 'SHNavigationControllerBlocks'
	pod 'MCNotificationManager'
	pod 'InAppSettingsKit'
	pod 'FCModel'
	pod 'MenuPopOverView'
	pod 'GoogleAnalytics-iOS-SDK'
	pod 'NSDate-Extensions'
end

target 'conversationTests' do
    pod 'PHFComposeBarView', '~> 2.0.1'
    pod 'DLImageLoader', '~> 2.0.0'
    pod 'YLGIFImage', :git => 'https://github.com/liyong03/YLGIFImage.git'
    pod 'UIActionSheet+Blocks'
    pod 'ImgurAnonymousAPIClient', :git => 'https://github.com/nolanw/ImgurAnonymousAPIClient.git', :tag => 'v0.2'
    pod 'SHTransitionBlocks'
    pod 'SHNavigationControllerBlocks'
    pod 'MCNotificationManager'
    pod 'InAppSettingsKit'
    pod 'FCModel'
    pod 'MenuPopOverView'
	pod 'GoogleAnalytics-iOS-SDK'
	pod 'NSDate-Extensions'
end

post_install do |installer_representation|
	`sh "update-acknowledgements.sh"`
end
