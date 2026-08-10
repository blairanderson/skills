> Source: <https://guides.rubyonrails.org/upgrading_ruby_on_rails.html> (Rails v8.1.2 guide) — extracted verbatim from the official guide.

Upgrading from Rails 6.1 to Rails 7.0
-------------------------------------

For more information on changes made to Rails 7.0 please see the [release notes](https://guides.rubyonrails.org/7_0_release_notes.html).

### `ActionView::Helpers::UrlHelper#button_to` changed behavior

Starting from Rails 7.0 `button_to` renders a `form` tag with `patch` HTTP verb if a persisted Active Record object is used to build button URL.
To keep current behavior consider explicitly passing `method:` option:

```diff
-button_to("Do a POST", [:my_custom_post_action_on_workshop, Workshop.find(1)])
+button_to("Do a POST", [:my_custom_post_action_on_workshop, Workshop.find(1)], method: :post)
```

or using helper to build the URL:

```diff
-button_to("Do a POST", [:my_custom_post_action_on_workshop, Workshop.find(1)])
+button_to("Do a POST", my_custom_post_action_on_workshop_workshop_path(Workshop.find(1)))
```

### Spring

If your application uses Spring, it needs to be upgraded to at least version 3.0.0. Otherwise you'll get

```
undefined method `mechanism=' for ActiveSupport::Dependencies:Module
```

Also, make sure [`config.cache_classes`][] is set to `false` in `config/environments/test.rb`.

[`config.cache_classes`]: https://guides.rubyonrails.org/configuring.html#config-cache-classes

### Sprockets is now an optional dependency

The gem `rails` doesn't depend on `sprockets-rails` anymore. If your application still needs to use Sprockets,
make sure to add `sprockets-rails` to your Gemfile.

```ruby
gem "sprockets-rails"
```

### Applications need to run in `zeitwerk` mode

Applications still running in `classic` mode have to switch to `zeitwerk` mode. Please check the [Classic to Zeitwerk HOWTO](https://guides.rubyonrails.org/v7.0/classic_to_zeitwerk_howto.html) guide for details.

### The setter `config.autoloader=` has been deleted

In Rails 7 there is no configuration point to set the autoloading mode, `config.autoloader=` has been deleted. If you had it set to `:zeitwerk` for whatever reason, just remove it.

### `ActiveSupport::Dependencies` private API has been deleted

The private API of `ActiveSupport::Dependencies` has been deleted. That includes methods like `hook!`, `unhook!`, `depend_on`, `require_or_load`, `mechanism`, and many others.

A few of highlights:

* If you used `ActiveSupport::Dependencies.constantize` or `ActiveSupport::Dependencies.safe_constantize`, just change them to `String#constantize` or `String#safe_constantize`.

  ```ruby
  ActiveSupport::Dependencies.constantize("User") # NO LONGER POSSIBLE
  "User".constantize # 👍
  ```

* Any usage of `ActiveSupport::Dependencies.mechanism`, reader or writer, has to be replaced by accessing `config.cache_classes` accordingly.

* If you want to trace the activity of the autoloader, `ActiveSupport::Dependencies.verbose=` is no longer available, just throw `Rails.autoloaders.log!` in `config/application.rb`.

Auxiliary internal classes or modules are also gone, like `ActiveSupport::Dependencies::Reference`, `ActiveSupport::Dependencies::Blamable`, and others.

### Autoloading during initialization

Applications that autoloaded reloadable constants during initialization outside of `to_prepare` blocks got those constants unloaded and had this warning issued since Rails 6.0:

```
DEPRECATION WARNING: Initialization autoloaded the constant ....

Being able to do this is deprecated. Autoloading during initialization is going
to be an error condition in future versions of Rails.

...
```

If you still get this warning in the logs, please check the section about autoloading when the application boots in the [autoloading guide](https://guides.rubyonrails.org/v7.0/autoloading_and_reloading_constants.html#autoloading-when-the-application-boots). You'd get a `NameError` in Rails 7 otherwise.

Constants managed by the `once` autoloader can be autoloaded during initialization, and they can be used normally, no need for a `to_prepare` block. However, the `once` autoloader is now set up earlier to support that. If the application has custom inflections, and the `once` autoloader should be aware of them, you need to move the code in `config/initializers/inflections.rb` to the body of the application class definition in `config/application.rb`:

```ruby
module MyApp
  class Application < Rails::Application
    # ...

    ActiveSupport::Inflector.inflections(:en) do |inflect|
      inflect.acronym "HTML"
    end
  end
end
```

### Ability to configure `config.autoload_once_paths`

[`config.autoload_once_paths`][] can be set in the body of the application class defined in `config/application.rb` or in the configuration for environments in `config/environments/*`.

Similarly, engines can configure that collection in the class body of the engine class or in the configuration for environments.

After that, the collection is frozen, and you can autoload from those paths. In particular, you can autoload from there during initialization. They are managed by the `Rails.autoloaders.once` autoloader, which does not reload, only autoloads/eager loads.

If you configured this setting after the environments configuration has been processed and are getting `FrozenError`, please just move the code.

[`config.autoload_once_paths`]: https://guides.rubyonrails.org/configuring.html#config-autoload-once-paths

### `ActionDispatch::Request#content_type` now returns Content-Type header as it is.

Previously, `ActionDispatch::Request#content_type` returned value does NOT contain charset part.
This behavior changed to returned Content-Type header containing charset part as it is.

If you want just MIME type, please use `ActionDispatch::Request#media_type` instead.

Before:

```ruby
request = ActionDispatch::Request.new("CONTENT_TYPE" => "text/csv; header=present; charset=utf-16", "REQUEST_METHOD" => "GET")
request.content_type #=> "text/csv"
```

After:

```ruby
request = ActionDispatch::Request.new("Content-Type" => "text/csv; header=present; charset=utf-16", "REQUEST_METHOD" => "GET")
request.content_type #=> "text/csv; header=present; charset=utf-16"
request.media_type   #=> "text/csv"
```

### Key generator digest class change requires a cookie rotator

The default digest class for the key generator is changing from SHA1 to SHA256.
This has consequences in any encrypted message generated by Rails, including
encrypted cookies.

In order to be able to read messages using the old digest class it is necessary
to register a rotator. Failing to do so may result in users having their sessions
invalidated during the upgrade.

The following is an example for rotator for the encrypted and the signed cookies.

```ruby
# config/initializers/cookie_rotator.rb
Rails.application.config.after_initialize do
  Rails.application.config.action_dispatch.cookies_rotations.tap do |cookies|
    authenticated_encrypted_cookie_salt = Rails.application.config.action_dispatch.authenticated_encrypted_cookie_salt
    signed_cookie_salt = Rails.application.config.action_dispatch.signed_cookie_salt

    secret_key_base = Rails.application.secret_key_base

    key_generator = ActiveSupport::KeyGenerator.new(
      secret_key_base, iterations: 1000, hash_digest_class: OpenSSL::Digest::SHA1
    )
    key_len = ActiveSupport::MessageEncryptor.key_len

    old_encrypted_secret = key_generator.generate_key(authenticated_encrypted_cookie_salt, key_len)
    old_signed_secret = key_generator.generate_key(signed_cookie_salt)

    cookies.rotate :encrypted, old_encrypted_secret
    cookies.rotate :signed, old_signed_secret
  end
end
```

### Digest class for ActiveSupport::Digest changing to SHA256

The default digest class for ActiveSupport::Digest is changing from SHA1 to SHA256.
This has consequences for things like Etags that will change and cache keys as well.
Changing these keys can have impact on cache hit rates, so be careful and watch out
for this when upgrading to the new hash.

### New ActiveSupport::Cache serialization format

A faster and more compact serialization format was introduced.

To enable it you must set `config.active_support.cache_format_version = 7.0`:

```ruby
# config/application.rb

config.load_defaults 6.1
config.active_support.cache_format_version = 7.0
```

Or simply:

```ruby
# config/application.rb

config.load_defaults 7.0
```

However Rails 6.1 applications are not able to read this new serialization format,
so to ensure a seamless upgrade you must first deploy your Rails 7.0 upgrade with
`config.active_support.cache_format_version = 6.1`, and then only once all Rails
processes have been updated you can set `config.active_support.cache_format_version = 7.0`.

Rails 7.0 is able to read both formats so the cache won't be invalidated during the
upgrade.

### Active Storage video preview image generation

Video preview image generation now uses FFmpeg's scene change detection to generate
more meaningful preview images. Previously the first frame of the video would be used
and that caused problems if the video faded in from black. This change requires
FFmpeg v3.4+.

### Active Storage default variant processor changed to `:vips`

For new apps, image transformation will use libvips instead of ImageMagick. This will reduce
the time taken to generate variants as well as CPU and memory usage, improving response
times in apps that rely on Active Storage to serve their images.

The `:mini_magick` option is not being deprecated, so it is fine to keep using it.

To migrate an existing app to libvips, set:

```ruby
Rails.application.config.active_storage.variant_processor = :vips
```

You will then need to change existing image transformation code to the
`image_processing` macros, and replace ImageMagick's options with libvips' options.

#### Replace resize with resize_to_limit

```diff
- variant(resize: "100x")
+ variant(resize_to_limit: [100, nil])
```

If you don't do this, when you switch to vips you will see this error: `no implicit conversion to float from string`.

#### Use an array when cropping

```diff
- variant(crop: "1920x1080+0+0")
+ variant(crop: [0, 0, 1920, 1080])
```

If you don't do this when migrating to vips, you will see the following error: `unable to call crop: you supplied 2 arguments, but operation needs 5`.

#### Clamp your crop values:

Vips is more strict than ImageMagick when it comes to cropping:

1. It will not crop if `x` and/or `y` are negative values. e.g.: `[-10, -10, 100, 100]`
2. It will not crop if position (`x` or `y`) plus crop dimension (`width`, `height`) is larger than the image. e.g.: a 125x125 image and a crop of `[50, 50, 100, 100]`

If you don't do this when migrating to vips, you will see the following error: `extract_area: bad extract area`

#### Adjust the background color used for `resize_and_pad`

Vips uses black as the default background color `resize_and_pad`, instead of white like ImageMagick. Fix that by using the `background` option:

```diff
- variant(resize_and_pad: [300, 300])
+ variant(resize_and_pad: [300, 300, background: [255]])
```

#### Remove any EXIF based rotation

Vips will auto rotate images using the EXIF value when processing variants. If you were storing rotation values from user uploaded photos to apply rotation with ImageMagick, you must stop doing that:

```diff
- variant(format: :jpg, rotate: rotation_value)
+ variant(format: :jpg)
```

#### Replace monochrome with colourspace

Vips uses a different option to make monochrome images:

```diff
- variant(monochrome: true)
+ variant(colourspace: "b-w")
```

#### Switch to libvips options for compressing images

JPEG

```diff
- variant(strip: true, quality: 80, interlace: "JPEG", sampling_factor: "4:2:0", colorspace: "sRGB")
+ variant(saver: { strip: true, quality: 80, interlace: true })
```

PNG

```diff
- variant(strip: true, quality: 75)
+ variant(saver: { strip: true, compression: 9 })
```

WEBP

```diff
- variant(strip: true, quality: 75, define: { webp: { lossless: false, alpha_quality: 85, thread_level: 1 } })
+ variant(saver: { strip: true, quality: 75, lossless: false, alpha_q: 85, reduction_effort: 6, smart_subsample: true })
```

GIF

```diff
- variant(layers: "Optimize")
+ variant(saver: { optimize_gif_frames: true, optimize_gif_transparency: true })
```

#### Deploy to production

Active Storage encodes into the url for the image the list of transformations that must be performed.
If your app is caching these urls, your images will break after you deploy the new code to production.
Because of this you must manually invalidate your affected cache keys.

For example, if you have something like this in a view:

```erb
<% @products.each do |product| %>
  <% cache product do %>
    <%= image_tag product.cover_photo.variant(resize: "200x") %>
  <% end %>
<% end %>
```

You can invalidate the cache either by touching the product, or changing the cache key:

```erb
<% @products.each do |product| %>
  <% cache ["v2", product] do %>
    <%= image_tag product.cover_photo.variant(resize_to_limit: [200, nil]) %>
  <% end %>
<% end %>
```

### Rails version is now included in the Active Record schema dump

Rails 7.0 changed some default values for some column types. To avoid that application upgrading from 6.1 to 7.0
load the current schema using the new 7.0 defaults, Rails now includes the version of the framework in the schema dump.

Before loading the schema for the first time in Rails 7.0, make sure to run `bin/rails app:update` to ensure that the
version of the schema is included in the schema dump.

The schema file will look like this:

```ruby
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[6.1].define(version: 2022_01_28_123512) do
  # ...
end
```

NOTE: The first time you dump the schema with Rails 7.0, you will see many changes to that file, including
some column information. Make sure to review the new schema file content and commit it to your repository.
