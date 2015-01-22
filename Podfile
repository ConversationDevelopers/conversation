# Uncomment this line to define a global platform for your project
# platform :ios, '6.0'

source 'https://github.com/CocoaPods/Specs.git'

target 'conversation' do
	pod 'PHFComposeBarView', '~> 2.0.1'
	pod 'DLImageLoader', :git => 'https://github.com/AndreyLunevich/DLImageLoader-iOS.git'
	pod 'YLGIFImage', :git => 'https://github.com/liyong03/YLGIFImage.git'
	pod 'UIActionSheet+Blocks'
	pod 'ImgurAnonymousAPIClient', :git => 'https://github.com/nolanw/ImgurAnonymousAPIClient.git', :tag => 'v0.2'
	pod 'SHTransitionBlocks' 
	pod 'SHNavigationControllerBlocks'
	pod 'MCNotificationManager'
	pod 'InAppSettingsKit'
	pod 'FCModel'
	pod 'MenuPopOverView'
end

post_install do |installer_representation|
	`sh "update-acknowledgements.sh"`
end
