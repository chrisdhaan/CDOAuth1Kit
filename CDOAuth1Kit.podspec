#
# Be sure to run `pod lib lint CDOAuth1Kit.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'CDOAuth1Kit'
  s.version          = '0.9.11'
  s.summary          = 'An extensive Objective C OAuth 1.0a library for AFNetworking.'
  s.description      = <<-DESC
This Objective C wrapper provides the functionality to request and refresh access tokens for APIs requiring OAuth 1.0 authentication.
                       DESC
  s.homepage         = 'https://github.com/chrisdhaan/CDOAuth1Kit'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Christopher de Haan' => 'contact@christopherdehaan.me' }
  s.source           = { :git => 'https://github.com/chrisdhaan/CDOAuth1Kit.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/dehaan_solo'

  s.ios.deployment_target = '8.0'
  s.requires_arc = true

  s.source_files = 'CDOAuth1Kit/Classes/Core/{Categories,Headers,**}/**/*'
  s.dependency 'AFNetworking', '~> 3.0'
end
