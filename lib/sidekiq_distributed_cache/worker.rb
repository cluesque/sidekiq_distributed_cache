require 'sidekiq'

module SidekiqDistributedCache
  class Worker
    include Sidekiq::Worker
    def perform(klass, instance_id, method, args, cache_tag, expires_in, interlock_key)
      all_args = [method]
      if args.is_a?(Array)
        all_args += args
      elsif args
        all_args << args
      end
      subject = Object.const_get(klass)
      subject = subject.find(instance_id) if instance_id
      result = subject.send(*all_args)
      SidekiqDistributedCache.redis.set(cache_tag, result)
      SidekiqDistributedCache.redis.expire(cache_tag, expires_in)
      SidekiqDistributedCache.redis.send_done_message(cache_tag)
    ensure
      # remove the interlock key
      SidekiqDistributedCache.redis.del(interlock_key) # WIP - consider something centralizing interlock_key construction
    end
  end
end
