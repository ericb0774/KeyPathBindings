Pod::Spec.new do |s|
  s.name         = "KeyPathBindings"
  s.version      = "0.0.1"
  s.summary      = "Type-safe keyPath bindings in Swift""
  s.description  = <<-DESC
  A lightweight type-safe keyPath binding framework for Swift 4.
                   DESC
  s.homepage     = "https://ericb0774.net/?p=24""
  s.license      = "MIT"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author             = { "Eric Baker" => "ericb0774@gmail.com" }
  s.platform     = :ios, "10.3"
  s.source       = { :git => "https://github.com/ericb0774/KeyPathBindings.git", :tag => "#{s.version}" }
  s.source_files  = "KeyPathBindings", "KeyPathBindings/KeyPathBindings/**/*.swift"
  s.public_header_files = "KeyPathBindings/KeyPathBindings/**/*.h"
  s.requires_arc = true
end

