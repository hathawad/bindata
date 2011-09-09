$:.push File.expand_path("../lib", __FILE__)
require 'bindata'

Gem::Specification.new do |s|
  s.name = 'bindata'
  s.version = BinData::VERSION
  s.platform = Gem::Platform::RUBY
  s.summary = 'A declarative way to read and write binary file formats'
  s.author = 'Dion Mendel'
  s.email = 'dion@lostrealm.com'
  s.homepage = 'http://bindata.rubyforge.org'
  s.rubyforge_project = 'bindata'

  s.require_path = 'lib'
  s.autorequire = 'bindata'

  s.has_rdoc = true
  s.rdoc_options = %w[README lib/bindata -m README]


  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {examples,spec,lib/tasks}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
end
