> Source: <https://guides.rubyonrails.org/upgrading_ruby_on_rails.html> (Rails v8.1.2 guide) — extracted verbatim from the official guide.

Upgrading from Rails 7.0 to Rails 7.1
-------------------------------------

For more information on changes made to Rails 7.1 please see the [release notes](https://guides.rubyonrails.org/7_1_release_notes.html).

### Development and test environments secret_key_base file changed

In development and test environments, the file from which Rails reads the `secret_key_base` has been renamed from `tmp/development_secret.txt` to `tmp/local_secret.txt`.

You can simply rename the previous file to `local_secret.txt` to continue using the same secret, or copy the key from the previous file to the new one.

Failure to do so will cause Rails to generate a new secret key in the new file `tmp/local_secret.txt` when the app loads.

This will invalidate all existing sessions/cookies in development and test environments, and also cause other signatures derived from `secret_key_base` to break, such as Active Storage/Action Text attachments.

Production and other environments are not affected.

### New ActiveSupport::Cache serialization format

A new 7.1 cache format is available which includes an optimization for bare string values such as view fragments.

The 7.1 cache format is used by default for new apps, and existing apps can enable the format by setting `config.load_defaults 7.1` or by setting `config.active_support.cache_format_version = 7.1` in `config/application.rb` or a `config/environments/*.rb` file.

Cache entries written using the 6.1 or 7.0 cache formats can be read when using the 7.1 format. To perform a rolling deploy of a Rails 7.1 upgrade, wherein servers that have not yet been upgraded must be able to read caches from upgraded servers, leave the cache format unchanged on the first deploy, then enable the 7.1 cache format on a subsequent deploy.

### Autoloaded paths are no longer in $LOAD_PATH

Starting from Rails 7.1, the directories managed by the autoloaders are no
longer added to `$LOAD_PATH`. This means it won't be possible to load their
files with a manual `require` call, which shouldn't be done anyway.

Reducing the size of `$LOAD_PATH` speeds up `require` calls for apps not using
`bootsnap`, and reduces the size of the `bootsnap` cache for the others.

If you'd like to have these paths still in `$LOAD_PATH`, you can opt-in:

```ruby
config.add_autoload_paths_to_load_path = true
```

but we discourage doing so, classes and modules in the autoload paths are meant
to be autoloaded. That is, just reference them.

The `lib` directory is not affected by this flag, it is added to `$LOAD_PATH`
always.

### config.autoload_lib and config.autoload_lib_once

If your application does not have `lib` in the autoload or autoload once paths,
please skip this section. You can find that out by inspecting the output of

```bash
# Print autoload paths.
$ bin/rails runner 'pp Rails.autoloaders.main.dirs'

# Print autoload once paths.
$ bin/rails runner 'pp Rails.autoloaders.once.dirs'
```

If your application already has `lib` in the autoload paths, normally there is
configuration in `config/application.rb` that looks something like

```ruby
# Autoload lib, but do not eager load it (maybe overlooked).
config.autoload_paths << config.root.join("lib")
```

or

```ruby
# Autoload and also eager load lib.
config.autoload_paths << config.root.join("lib")
config.eager_load_paths << config.root.join("lib")
```

or

```ruby
# Same, because all eager load paths become autoload paths too.
config.eager_load_paths << config.root.join("lib")
```

That still works, but it is recommended to replace those lines with the more
concise

```ruby
config.autoload_lib(ignore: %w(assets tasks))
```

Please, add to the `ignore` list any other `lib` subdirectories that do not
contain `.rb` files, or that should not be reloaded or eager loaded. For
example, if your application has `lib/templates`, `lib/generators`, or
`lib/middleware`, you'd add their name relative to `lib`:

```ruby
config.autoload_lib(ignore: %w(assets tasks templates generators middleware))
```

With that one-liner, the (non-ignored) code in `lib` will be also eager loaded
if `config.eager_load` is `true` (the default in `production` mode). This is
normally what you want, but if `lib` was not added to the eager load paths
before and you still want it that way, please opt-out:

```ruby
Rails.autoloaders.main.do_not_eager_load(config.root.join("lib"))
```

The method `config.autoload_lib_once` is the analogous one if the application
had `lib` in `config.autoload_once_paths`.

### `ActiveStorage::BaseController` no longer includes the streaming concern

Application controllers that inherit from `ActiveStorage::BaseController` and use streaming to implement custom file serving logic must now explicitly include the `ActiveStorage::Streaming` module.

### `MemCacheStore` and `RedisCacheStore` now use connection pooling by default

The `connection_pool` gem has been added as a dependency of the `activesupport` gem,
and the `MemCacheStore` and `RedisCacheStore` now use connection pooling by default.

If you don't want to use connection pooling, set `:pool` option to `false` when
configuring your cache store:

```ruby
config.cache_store = :mem_cache_store, "cache.example.com", { pool: false }
```

See the [caching with Rails](https://guides.rubyonrails.org/v7.1/caching_with_rails.html#connection-pool-options) guide for more information.

### `SQLite3Adapter` now configured to be used in a strict strings mode

The use of a strict strings mode disables double-quoted string literals.

SQLite has some quirks around double-quoted string literals.
It first tries to consider double-quoted strings as identifier names, but if they don't exist
it then considers them as string literals. Because of this, typos can silently go unnoticed.
For example, it is possible to create an index for a non existing column.
See [SQLite documentation](https://www.sqlite.org/quirks.html#double_quoted_string_literals_are_accepted) for more details.

If you don't want to use `SQLite3Adapter` in a strict mode, you can disable this behavior:

```ruby
# config/application.rb
config.active_record.sqlite3_adapter_strict_strings_by_default = false
```

### Support multiple preview paths for `ActionMailer::Preview`

Option `config.action_mailer.preview_path` is deprecated in favor of `config.action_mailer.preview_paths`. Appending paths to this configuration option will cause those paths to be used in the search for mailer previews.

```ruby
config.action_mailer.preview_paths << "#{Rails.root}/lib/mailer_previews"
```

### `config.i18n.raise_on_missing_translations = true` now raises on any missing translation.

Previously it would only raise when called in a view or controller. Now it will raise anytime `I18n.t` is provided an unrecognized key.

```ruby
# with config.i18n.raise_on_missing_translations = true

# in a view or controller:
t("missing.key") # raises in 7.0, raises in 7.1
I18n.t("missing.key") # didn't raise in 7.0, raises in 7.1

# anywhere:
I18n.t("missing.key") # didn't raise in 7.0, raises in 7.1
```

If you don't want this behavior, you can set `config.i18n.raise_on_missing_translations = false`:

```ruby
# with config.i18n.raise_on_missing_translations = false

# in a view or controller:
t("missing.key") # didn't raise in 7.0, doesn't raise in 7.1
I18n.t("missing.key") # didn't raise in 7.0, doesn't raise in 7.1

# anywhere:
I18n.t("missing.key") # didn't raise in 7.0, doesn't raise in 7.1
```

Alternatively, you can customize the `I18n.exception_handler`.
See the [i18n guide](https://guides.rubyonrails.org/v7.1/i18n.html#using-different-exception-handlers) for more information.

`AbstractController::Translation.raise_on_missing_translations` has been removed. This was a private API, if you were
relying on it you should migrate to `config.i18n.raise_on_missing_translations` or to a custom exception handler.

### `bin/rails test` now runs `test:prepare` task

When running tests via `bin/rails test`, the `rake test:prepare` task will run before tests run. If you've enhanced
the `test:prepare` task, your enhancements will run before your tests. `tailwindcss-rails`, `jsbundling-rails`, and `cssbundling-rails`
enhance this task, as do other third party gems.

See the [Testing Rails Applications](https://guides.rubyonrails.org/testing.html#running-tests-in-continuous-integration-ci) guide for more information.

If you run a single file's tests (`bin/rails test test/models/user_test.rb`), `test:prepare` will not run before it.

### Import syntax from `@rails/ujs` is modified

Starting from Rails 7.1, the syntax for importing modules from `@rails/ujs` is modified. Rails no longer supports the
direct import of a module from `@rails/ujs`.

For example, attempting to import a function from the library will fail:

```javascript
import { fileInputSelector } from "@rails/ujs"
// ERROR: export 'fileInputSelector' (imported as 'fileInputSelector') was not found in '@rails/ujs' (possible exports: default)
```

In Rails 7.1, users should first import the Rails object directly from `@rails/ujs`.
Users can then import specific modules from the Rails object.

An example of imports in Rails 7.1 is shown below:

```javascript
import Rails from "@rails/ujs"
// Alias the method
const fileInputSelector = Rails.fileInputSelector
// Alternatively, reference it from the Rails object where it is used
Rails.fileInputSelector(...)
```

### `Rails.logger` now returns an `ActiveSupport::BroadcastLogger` instance

The `ActiveSupport::BroadcastLogger` class is a new logger that allows to broadcast logs to different sinks (STDOUT, a log file...) in an easy way.

The API to broadcast logs (using the `ActiveSupport::Logger.broadcast` method) was removed and was previously private.
If your application or library was relying on this API, you need to make the following changes:

```ruby
logger = Logger.new("some_file.log")

# Before

Rails.logger.extend(ActiveSupport::Logger.broadcast(logger))

# After

Rails.logger.broadcast_to(logger)
```

If your application had configured a custom logger, `Rails.logger` will wrap and proxy all methods to it. No changes on your side are required to make it work.

If you need to access your custom logger instance, you can do so using the `broadcasts` method:

```ruby
# config/application.rb
config.logger = MyLogger.new

# Anywhere in your application
puts Rails.logger.class #=> BroadcastLogger
puts Rails.logger.broadcasts #=> [MyLogger]
```

[assert_match]: https://docs.seattlerb.org/minitest/Minitest/Assertions.html#method-i-assert_match


### Active Record Encryption algorithm changes

Active Record Encryption now uses SHA-256 as its hash digest algorithm. If you have data encrypted with previous Rails
versions, there are two scenarios to consider:

1. If you have `config.active_support.key_generator_hash_digest_class` configured as SHA-1 (the default
   before Rails 7.0), you need to configure SHA-1 for Active Record Encryption too:

    ```ruby
    config.active_record.encryption.hash_digest_class = OpenSSL::Digest::SHA1
    ```

    If all of your data was encrypted non-deterministicly (the default unless `encrypts` is passed `deterministic: true`, you can instead configure SHA-256 for Active Record Encryption as in scenario 2 below and also allow columns previously encrypted with SHA-1 to be decrypted by setting:

    ```ruby
    config.active_record.encryption.support_sha1_for_non_deterministic_encryption = true
    ```

2. If you have `config.active_support.key_generator_hash_digest_class` configured as SHA-256 (the new default
   in 7.0), then you need to configure SHA-256 for Active Record Encryption:

    ```ruby
    config.active_record.encryption.hash_digest_class = OpenSSL::Digest::SHA256
    ```

See the [Configuring Rails Applications](https://guides.rubyonrails.org/configuring.html#config-active-record-encryption-hash-digest-class)
guide for more information on `config.active_record.encryption.hash_digest_class`.

In addition, a new configuration [`config.active_record.encryption.support_sha1_for_non_deterministic_encryption`](https://guides.rubyonrails.org/configuring.html#config-active-record-encryption-support-sha1-for-non-deterministic-encryption)
was introduced to resolve [a bug](https://github.com/rails/rails/issues/42922) that caused some attributes to be
encrypted using SHA-1 even when SHA-256 was configured via the aforementioned `hash_digest_class` configuration.

By default, `config.active_record.encryption.support_sha1_for_non_deterministic_encryption` is disabled in
Rails 7.1. If you have data encrypted in a version of Rails < 7.1 that you believe may be affected
by the aforementioned bug, this configuration should be enabled:

```ruby
config.active_record.encryption.support_sha1_for_non_deterministic_encryption = true
```

**If you are working with encrypted data, please carefully review the above.**

### New ways to handle exceptions in Controller Tests, Integration Tests, and System Tests

The `config.action_dispatch.show_exceptions` configuration controls how Action Pack handles exceptions raised while responding to requests.

Prior to Rails 7.1, setting `config.action_dispatch.show_exceptions = true` configured Action Pack to rescue exceptions and render appropriate HTML error pages, like rendering `public/404.html` with a `404 Not found` status code instead of raising an `ActiveRecord::RecordNotFound` exception. Setting `config.action_dispatch.show_exceptions = false` configured Action Pack to not rescue the exception. Prior to Rails 7.1, new applications were generated with a line in `config/environments/test.rb` that set `config.action_dispatch.show_exceptions = false`.

Rails 7.1 changes the acceptable values from `true` and `false` to `:all`, `:rescuable`, and `:none`.

* `:all` - render HTML error pages for all exceptions (equivalent to `true`)
* `:rescuable` - render HTML error pages for exceptions declared by [`config.action_dispatch.rescue_responses`](https://guides.rubyonrails.org/configuring.html#config-action-dispatch-rescue-responses)
* `:none` (equivalent to `false`) - do not rescue from any exceptions

Applications generated by Rails 7.1 or later set `config.action_dispatch.show_exceptions = :rescuable` in their `config/environments/test.rb`. When upgrading, existing applications can change `config.action_dispatch.show_exceptions = :rescuable` to utilize the new behavior, or replace the old values with the corresponding new ones (`:all` replaces `true`, `:none` replaces `false`).
