require_relative 'test_helper'

describe RedisScripts do
  use_temporary_directory "#{ROOT}/test/tmp"

  let(:redis) { Redis.new(REDIS_CONFIG) }
  let(:scripts) { redis.scripts }

  before do
    redis.flushall
    redis.script 'flush'
  end

  after do
    redis.quit
  end

  describe "#initialize" do
    it "defaults the load path to the global one, if available" do
      RedisScripts.load_path = ['global']
      scripts.load_path.must_equal ['global']
    end

    it "finds scripts in all load path directories" do
      write_file "#{tmp}/1/a.lua", "return 'a'"
      write_file "#{tmp}/2/b.lua", "return 'b'"
      scripts.load_path = ["#{tmp}/1", "#{tmp}/2"]
      scripts.script('a').name.must_equal 'a'
      scripts.script('b').name.must_equal 'b'
    end

    it "finds scripts in nested directories" do
      write_file "#{tmp}/a/b.lua", "return 'a/b'"
      scripts.load_path = [tmp]
      scripts.script('a/b').name.must_equal 'a/b'
    end

    it "favors scripts that come earlier in the load path" do
      write_file "#{tmp}/1/a.lua", "return 'a'"
      write_file "#{tmp}/2/a.lua", "return 'b'"
      scripts.load_path = ["#{tmp}/1", "#{tmp}/2"]
      scripts.eval('a', [], []).must_equal 'a'
    end
  end

  describe "#script" do
    it "returns the named script if it exists" do
      write_file "#{tmp}/a.lua", "return 'a'"
      scripts.load_path = [tmp]
      scripts.script('a').must_be_instance_of(RedisScripts::Script)
    end

    it "raises an ArgumentError if no such script exists" do
      scripts.load_path = [tmp]
      -> { scripts.script('a') }.must_raise(ArgumentError)
    end

    it "supports a Symbol argument" do
      write_file "#{tmp}/a.lua", "return 'a'"
      scripts.load_path = [tmp]
      scripts.script(:a).must_be_instance_of(RedisScripts::Script)
    end
  end

  describe "#load" do
    it "loads the named script into the script cache" do
      write_file "#{tmp}/a.lua", "return 'a'"
      scripts.load_path = [tmp]
      scripts.load 'a'
      redis.script('exists', Digest::SHA1.hexdigest("return 'a'")).must_equal true
    end

    it "raises ArgumentError if there is no such script" do
      scripts.load_path = [tmp]
      -> { scripts.load('a', [], []) }.must_raise(ArgumentError)
    end
  end

  describe "#load_all" do
    it "loads all scripts into the script cache" do
      write_file "#{tmp}/a.lua", "return 'a'"
      write_file "#{tmp}/b.lua", "return 'b'"
      scripts.load_path = [tmp]
      scripts.load_all
      redis.script('exists', Digest::SHA1.hexdigest("return 'a'")).must_equal true
      redis.script('exists', Digest::SHA1.hexdigest("return 'b'")).must_equal true
    end
  end

  describe "#exists" do
    it "runs SCRIPT EXISTS for the named script" do
      write_file "#{tmp}/a.lua", "return 'a'"
      write_file "#{tmp}/b.lua", "return 'b'"
      scripts.load_path = [tmp]
      scripts.load 'a'
      scripts.exists('a').must_equal true
      scripts.exists('b').must_equal false
    end

    it "raises ArgumentError if there is no such script" do
      scripts.load_path = [tmp]
      -> { scripts.exists('a', [], []) }.must_raise(ArgumentError)
    end
  end

  describe "#evalsha" do
    it "runs EVALSHA for the named script" do
      write_file "#{tmp}/a.lua", "return 'a'"
      write_file "#{tmp}/b.lua", "return 'b'"
      scripts.load_path = [tmp]
      scripts.load 'a'
      scripts.evalsha('a', [], []).must_equal 'a'
      -> { scripts.evalsha('b', [], []) }.must_raise(Redis::CommandError)
    end

    it "raises ArgumentError if there is no such script" do
      scripts.load_path = [tmp]
      -> { scripts.evalsha('a', [], []) }.must_raise(ArgumentError)
    end
  end

  describe "#run" do
    it "evaluates the named script" do
      write_file "#{tmp}/a.lua", "return 'a'"
      scripts.load_path = [tmp]
      scripts.run('a', [], []).must_equal 'a'
      scripts.run('a', [], []).must_equal 'a'  # cached case
    end

    it "loads the script into cache for fast subsequent execution" do
      write_file "#{tmp}/a.lua", "return 'a'"
      scripts.load_path = [tmp]
      scripts.run('a', [], [])
      redis.script('exists', Digest::SHA1.hexdigest("return 'a'")).must_equal true
    end

    it "raises ArgumentError if there is no such script" do
      scripts.load_path = [tmp]
      -> { scripts.run('a', [], []) }.must_raise(ArgumentError)
    end
  end

  def write_file(path, content)
    FileUtils.mkdir_p File.dirname(path)
    open(path, 'w') { |f| f.print content }
  end
end
