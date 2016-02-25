$:.unshift File.expand_path('lib', File.dirname(__FILE__))
require 'redis_scripts/version'

Gem::Specification.new do |gem|
  gem.name          = 'redis_scripts'
  gem.version       = RedisScripts::VERSION
  gem.authors       = ['George Ogata']
  gem.email         = ['george.ogata@gmail.com']
  gem.description   = "Elegant redis scripting for ruby."
  gem.summary       = "Elegant redis scripting for ruby."
  gem.homepage      = 'https://github.com/oggy/redis_scripts'

  gem.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")

  gem.add_runtime_dependency 'redis', '~> 3.0'
end
