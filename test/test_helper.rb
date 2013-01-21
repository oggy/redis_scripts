ROOT = File.expand_path('..', File.dirname(__FILE__))
Bundler.require(:test)

$:.unshift "#{ROOT}/lib"
require 'redis_scripts'
require 'minitest/spec'
require 'temporaries'

require 'yaml'
config_path = "#{ROOT}/redis.yml"
if File.exist?(config_path)
  REDIS_CONFIG = YAML.load_file(config_path)
else
  REDIS_CONFIG = {url: 'redis://localhost:6379'}
end
