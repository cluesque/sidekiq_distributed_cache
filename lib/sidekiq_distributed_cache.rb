require "sidekiq_distributed_cache/worker"
require "sidekiq_distributed_cache/promise"
require "sidekiq_distributed_cache/redis"

module SidekiqDistributedCache
  class TimeoutError < StandardError; end

  class << self
    attr_accessor :cache_prefix, :redis_pool, :logger
  end

  def self.redis
    @redis ||= Redis.new(redis_pool)
  end
end
