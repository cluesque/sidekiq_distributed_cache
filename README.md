# SidekiqDistributedCache

Generate and cache objects using sidekiq, with thundering herd prevention and client timeouts.

Say you have a resource that's expensive to calculate (a heavy database query) and would like to use it in a web page.

But you'd rather the web page show an empty value (or a "check back later" placeholder) than take too long to render.

And you'd like to ensure that if there are multiple actions requesting that page at once, that the database only has to fill the query once.  (You want to prevent a [thundering herd problem](https://en.wikipedia.org/wiki/Thundering_herd_problem))

## Usage

Say your `Widget` class has a method `do_a_thing` that is sometimes quite expensive to calculate, but returns a value you'd like to include in a web page, as long as the value can be made available in five seconds.  Once calculated, the value is valid for ten minutes, and all renderings of the page can show that same value.

In the controller:

```ruby
promise = SidekiqDistributedCache::Promise.new(klass: Widget, method: :do_a_thing, expires_in: 10 * 60)
value = promise.execute_and_wait!(5)
```

If no other workers are currently calculating the value, this will queue up a sidekiq job to call `Widget.do_a_thing`.  If other workers are currently calculating, it will not start another, preventing the thundering herd.

Then it will wait as much as 5 seconds for a value to be returned.

If in the end, value is nil, offer a default or "try again" presentation to the user.

Also supported: passing arguments, calling an instance method on an object in the database, and explicitly naming your cache tag.

## Installation
Add this line to your application's Gemfile:

```ruby
gem 'sidekiq_distributed_cache'
```

And then execute:
```bash
$ bundle
```

Or install it yourself as:
```bash
$ gem install sidekiq_distributed_cache
```

Add an initializer:
```ruby
Rails.configuration.to_prepare do
  SidekiqDistributedCache.logger = Rails.logger
  SidekiqDistributedCache.redis_pool = Sidekiq.redis_pool
  SidekiqDistributedCache.cache_prefix = ENV['RAILS_CACHE_ID']
end
```

## Contributing
Contribution directions go here.

## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
