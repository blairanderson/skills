> Source: <https://guides.rubyonrails.org/upgrading_ruby_on_rails.html> (Rails v8.1.2 guide) — extracted verbatim from the official guide.

Upgrading from Rails 6.0 to Rails 6.1
-------------------------------------

For more information on changes made to Rails 6.1 please see the [release notes](https://guides.rubyonrails.org/6_1_release_notes.html).

### `Rails.application.config_for` return value no longer supports access with String keys.

Given a configuration file like this:

```yaml
# config/example.yml
development:
  options:
    key: value
```

```ruby
Rails.application.config_for(:example).options
```

This used to return a hash on which you could access values with String keys. That was deprecated in 6.0, and now doesn't work anymore.

You can call `with_indifferent_access` on the return value of `config_for` if you still want to access values with String keys, e.g.:

```ruby
Rails.application.config_for(:example).with_indifferent_access.dig("options", "key")
```

### Response's Content-Type when using `respond_to#any`

The Content-Type header returned in the response can differ from what Rails 6.0 returned,
more specifically if your application uses `respond_to { |format| format.any }`.
The Content-Type will now be based on the given block rather than the request's format.

Example:

```ruby
def my_action
  respond_to do |format|
    format.any { render(json: { foo: "bar" }) }
  end
end
```

```ruby
get("my_action.csv")
```

Previous behavior was returning a `text/csv` response's Content-Type which is inaccurate since a JSON response is being rendered.
Current behavior correctly returns a `application/json` response's Content-Type.

If your application relies on the previous incorrect behavior, you are encouraged to specify
which formats your action accepts, i.e.

```ruby
format.any(:xml, :json) { render request.format.to_sym => @people }
```

### `ActiveSupport::Callbacks#halted_callback_hook` now receive a second argument

Active Support allows you to override the `halted_callback_hook` whenever a callback
halts the chain. This method now receives a second argument which is the name of the callback being halted.
If you have classes that override this method, make sure it accepts two arguments. Note that this is a breaking
change without a prior deprecation cycle (for performance reasons).

Example:

```ruby
class Book < ApplicationRecord
  before_save { throw(:abort) }
  before_create { throw(:abort) }

  def halted_callback_hook(filter, callback_name) # => This method now accepts 2 arguments instead of 1
    Rails.logger.info("Book couldn't be #{callback_name}d")
  end
end
```

### The `helper` class method in controllers uses `String#constantize`

Conceptually, before Rails 6.1

```ruby
helper "foo/bar"
```

resulted in

```ruby
require_dependency "foo/bar_helper"
module_name = "foo/bar_helper".camelize
module_name.constantize
```

Now it does this instead:

```ruby
prefix = "foo/bar".camelize
"#{prefix}Helper".constantize
```

This change is backwards compatible for the majority of applications, in which case you do not need to do anything.

Technically, however, controllers could configure `helpers_path` to point to a directory in `$LOAD_PATH` that was not in the autoload paths. That use case is no longer supported out of the box. If the helper module is not autoloadable, the application is responsible for loading it before calling `helper`.

### Redirection to HTTPS from HTTP will now use the 308 HTTP status code

The default HTTP status code used in `ActionDispatch::SSL` when redirecting non-GET/HEAD requests from HTTP to HTTPS has been changed to `308` as defined in https://tools.ietf.org/html/rfc7538.

### Active Storage now requires Image Processing

When processing variants in Active Storage, it's now required to have the [image_processing gem](https://github.com/janko/image_processing) bundled instead of directly using `mini_magick`. Image Processing is configured by default to use `mini_magick` behind the scenes, so the easiest way to upgrade is by replacing the `mini_magick` gem for the `image_processing` gem and making sure to remove the explicit usage of `combine_options` since it's no longer needed.

For readability, you may wish to change raw `resize` calls to `image_processing` macros. For example, instead of:

```ruby
video.preview(resize: "100x100")
video.preview(resize: "100x100>")
video.preview(resize: "100x100^")
```

you can respectively do:

```ruby
video.preview(resize_to_fit: [100, 100])
video.preview(resize_to_limit: [100, 100])
video.preview(resize_to_fill: [100, 100])
```

### New `ActiveModel::Error` class

Errors are now instances of a new `ActiveModel::Error` class, with changes to
the API. Some of these changes may throw errors depending on how you manipulate
errors, while others will print deprecation warnings to be fixed for Rails 7.0.

More information about this change and details about the API changes can be
found [in this PR](https://github.com/rails/rails/pull/32313).
