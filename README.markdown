## Redis Scripts

Elegant redis scripting for ruby.

## Show me

    require 'redis_scripts'

    # Grab a redis handle.
    redis = Redis.new

    # Configure the scripts location. Can also be done globally via
    # RedisScripts.load_path.
    redis.scripts.load_path = '/path/to/scripts'

    # Run the script at /path/to/scripts/foo.lua .
    redis.scripts.run :foo, keys, values

The call to `run` intuitively translates to a call to `EVALSHA`. If the SHA is
not in the redis script cache, it will be loaded (with `SCRIPT LOAD`), and then
re-executed via `EVALSHA`, ensuring future calls are optimal.

## Priming the cache

You can load all scripts into cache ahead of time like this:

    redis.scripts.load_all

You could do this, for example, each time you deploy updates to your
application.

## Emptying the cache

Redis does not offer a way to list or delete individual scripts. To clear out
the script cache, you'll need to call `redis.script 'flush'` to empty the cache
entirely. You can then call `load_all` to reload your scripts, or just let
subsequent calls to `run` restore them as needed.

## Contributing

 * [Bug reports](https://github.com/oggy/redis_scripts/issues)
 * [Source](https://github.com/oggy/redis_scripts)
 * Patches: Fork on Github, send pull request.
   * Include tests where practical.
   * Leave the version alone, or bump it in a separate commit.

## Copyright

Copyright (c) George Ogata. See LICENSE for details.
