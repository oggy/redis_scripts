require 'digest/sha1'
require 'shellwords'
require 'redis'

# Adapter for elegant Redis scripting.
#
# This is usually accessed as +redis.scripts+, although can also be instantiated
# as +RedisScripts.new(redis)+.
class RedisScripts
  autoload :VERSION, 'redis_scripts/version'

  class << self
    # Global load path for redis scripts.
    #
    # redis.scripts.load_path defaults to this value for all redis clients.
    attr_accessor :load_path
  end

  # Create a RedisScripts adapter for the given +redis+ handle.
  def initialize(redis)
    @redis = redis
    @load_path = RedisScripts.load_path
  end

  # The adapter's redis handle.
  attr_reader :redis

  # Paths to look for Redis scripts.
  #
  # These directories are searched recursively for all .lua files. Defaults to
  # RedisScripts.load_path, which itself has no default, so one of these needs
  # to be set.
  #
  # Like the ruby load path, earlier directories shadow later directories in the
  # event two directories contain scripts with the same name.
  attr_accessor :load_path

  # Run the script named +name+ with the given +args+.
  #
  # +name+ is the path of the script relative to the +load_path+, minus the
  # '.lua' extension. So if the load_path contains 'scripts', and the script is
  # at 'scripts/foo/bar.lua', then +name+ should be 'foo/bar'. +name+ may be a
  # string or symbol.
  #
  # +args+ are passed to Redis#evalsha (see documentation for the Redis gem). If
  # the script is not yet loaded in the redis script cache, it is loaded and
  # called again. Note that this means this should not be called inside a MULTI
  # transaction - this is usually not a problem, since the purpose of scripting
  # is to perform a sequence of atomic operations in a single command.
  #
  # Raises ArgumentError if no such script exists.
  def run(name, *args)
    script = script(name)
    begin
      redis.evalsha script.sha, *args
    rescue Redis::CommandError => error
      error.message.include?('NOSCRIPT') or
        raise
      sha, value = redis.pipelined do
        redis.script 'load', script.content
        redis.evalsha(script.sha, *args)
      end
      sha == script.sha or
        raise SHAMismatch, "SHA mismatch for #{name}: expected #{script.sha}, got #{sha}"
      value
    end
  end

  # Call EVAL for the named script.
  #
  # Raises ArgumentError if no such script exists.
  def eval(name, *args)
    redis.eval script(name).content, *args
  end

  # Call SCRIPT LOAD for the named script.
  #
  # Raises ArgumentError if no such script exists.
  def load(name)
    redis.script 'load', script(name).content
  end

  # Call SCRIPT LOAD for all scripts.
  #
  # This effectively primes the script cache with all your scripts. It does not
  # remove any scripts - use +redis.script('flush')+ to empty the script cache
  # first if that is required.
  def load_all
    scripts.each do |name, script|
      redis.script 'load', script.content
    end
  end

  # Call SCRIPT EXISTS for the named script.
  #
  # Raises ArgumentError if no such script exists.
  def exists(name)
    redis.script 'exists', script(name).sha
  end

  # Call EVALSHA for the named script.
  #
  # Raises ArgumentError if no such script exists.
  def evalsha(name, *args)
    redis.evalsha script(name).sha, *args
  end

  # Return the named script, as a Script object.
  #
  # Raises ArgumentError if no such script exists.
  def script(name)
    scripts[name.to_s] or
      raise ArgumentError, "no such script: #{name}"
  end

  # Represents a script in a lua file under the load path.
  Script = Struct.new(:name, :path) do
    # The SHA1 of the content of the script.
    def sha
      @sha ||= Digest::SHA1.file(path).to_s
    end

    # The content of the script.
    def content
      @content = File.read(path)
    end
  end

  # Raised when Redis returns an unexpected SHA when loading a script into the
  # redis script cache.
  #
  # Should never happen.
  SHAMismatch = Class.new(RuntimeError)

  private

  def scripts
    @scripts ||= find_scripts
  end

  def find_scripts
    scripts = {}
    @load_path.each do |path|
      command = ['find', path, '-name', '*.lua'].shelljoin
      prefix = /^#{Regexp.escape(path)}#{File::SEPARATOR}/
      `#{command} 2> /dev/null`.lines.each do |path|
        path.chomp!
        name = path.sub(prefix, '').sub(/\.lua\z/, '')
        scripts[name] ||= Script.new(name, path)
      end
    end
    scripts
  end

  module Mixin
    # Return a RedisScripts adapter for this redis handle.
    #
    # See RedisScripts for details.
    def scripts
      @scripts ||= RedisScripts.new(self)
    end
  end

  Redis.__send__ :include, Mixin
end
