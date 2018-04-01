Pod::Spec.new do |s|
  s.name          = "KeyPathBindings"
  s.version       = "0.0.1"
  s.summary       = "Type-safe keyPath bindings in Swift"
  s.description   = <<-DESC
  A simple way to create property bindings between pure Swift objects that are type-safe.
                    DESC
  s.homepage      = "https://ericb0774.net"
  s.license       = "MIT"
  s.author        = { "Eric Baker" => "ericb0774@gmail.com" }
  s.platform      = :ios, "10.3"
  s.source        = { :git => "https://github.com/ericb0774/KeyPathBindings.git", :tag => "#{s.version}" }
  s.source_files  = "KeyPathBindings/KeyPathBindings/**/*.{h,swift}"
  s.requires_arc  = true
  s.swift_version = "4.0"
end

