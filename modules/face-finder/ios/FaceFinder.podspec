Pod::Spec.new do |s|
  s.name           = 'FaceFinder'
  s.version        = '0.1.0'
  s.summary        = 'Face recognition native module for Mentra Face Finder'
  s.description    = 'Provides face detection, embedding generation, and photo library scanning'
  s.homepage       = 'https://github.com/Mentra-Community/MentraOS'
  s.license        = 'MIT'
  s.author         = 'Mentra'
  s.platform       = :ios, '15.0'
  s.source         = { git: '' }
  s.swift_version  = '5.9'

  s.source_files   = '**/*.swift'
  s.frameworks     = 'Vision', 'CoreML', 'Photos', 'Accelerate', 'CoreImage'

  s.dependency 'ExpoModulesCore'
  s.dependency 'GRDB.swift', '~> 6.24'
end
