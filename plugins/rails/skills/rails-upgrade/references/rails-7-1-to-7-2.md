> Source: <https://guides.rubyonrails.org/upgrading_ruby_on_rails.html> (Rails v8.1.2 guide) — extracted verbatim from the official guide.

Upgrading from Rails 7.1 to Rails 7.2
-------------------------------------

For more information on changes made to Rails 7.2 please see the [release notes](https://guides.rubyonrails.org/7_2_release_notes.html).

### All tests now respect the `active_job.queue_adapter` config

If you have set `config.active_job.queue_adapter` in your `config/application.rb` or `config/environments/test.rb` file,
the adapter you selected was previously not used consistently across all tests. In some tests your adapter would be
used, but other tests would use the `TestAdapter`.

In Rails 7.2, all tests will respect the `queue_adapter` config if provided. This may cause test errors, if you had
set the `queue_adapter` config to something other than `:test`, but written tests in a way that was dependent on the `TestAdapter`.

If no config is provided, the `TestAdapter` will continue to be used.

### `alias_attribute` now bypasses custom methods on the original attribute

In Rails 7.2, `alias_attribute` now bypasses custom methods defined on the original attribute and directly accesses the underlying database value. This change was announced via deprecation warnings in Rails 7.1.

**Before (Rails 7.1):**

```ruby
class User < ActiveRecord::Base
  def email
    "custom_#{super}"
  end

  alias_attribute :username, :email
end

user = User.create!(email: "test@example.com")
user.username
# => "custom_test@example.com"
```

**After (Rails 7.2):**

```ruby
user = User.create!(email: "test@example.com")
user.username
# => "test@example.com"  # Raw database value
```

If you received the deprecation warning "Since Rails 7.2 `#{method_name}` will not be calling `#{target_name}` anymore", you should manually define the alias method:

```ruby
class User < ActiveRecord::Base
  def email
    "custom_#{super}"
  end

  def username
    email  # This will call the custom email method
  end
end
```

Alternatively, you can use `alias_method`:

```ruby
class User < ActiveRecord::Base
  def email
    "custom_#{super}"
  end

  alias_method :username, :email
end
```
