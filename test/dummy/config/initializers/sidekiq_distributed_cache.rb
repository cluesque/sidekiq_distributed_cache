Rails.configuration.to_prepare do
  SidekiqDistributedCache.logger = Rails.logger
  SidekiqDistributedCache.redis_pool = Sidekiq.redis_pool
  SidekiqDistributedCache.cache_prefix = ENV['RAILS_CACHE_ID']
end
