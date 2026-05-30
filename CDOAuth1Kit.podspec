Pod::Spec.new do |s|
  s.name = 'CDOAuth1Kit'
  s.version = '2.0.0'
  s.cocoapods_version = '>= 1.13.0'
  s.license = { :type => 'MIT', :file => 'LICENSE' }
  s.summary = 'A Swift OAuth 1.0a library for iOS and macOS.'
  s.description = <<-DESC
    This Swift library provides the functionality to request and refresh access tokens
    for APIs requiring OAuth 1.0a authentication, with no external dependencies.
  DESC
  s.homepage = 'https://github.com/chrisdhaan/CDOAuth1Kit'
  s.author = { 'Christopher de Haan' => 'contact@christopherdehaan.me' }
  s.source = { :git => 'https://github.com/chrisdhaan/CDOAuth1Kit.git', :tag => s.version.to_s }
  s.documentation_url = 'https://chrisdhaan.github.io/CDOAuth1Kit/'

  s.ios.deployment_target = '13.0'
  s.osx.deployment_target = '10.15'

  s.swift_versions = ['5']

  s.source_files = 'Source/*.swift'
  s.resource_bundles = { 'CDOAuth1Kit' => ['Source/PrivacyInfo.xcprivacy'] }

  s.framework = 'Foundation'
  s.framework = 'Security'
  s.framework = 'CryptoKit'
end
