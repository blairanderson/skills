> Source: <https://guides.rubyonrails.org/upgrading_ruby_on_rails.html> (Rails v8.1.2 guide) — extracted verbatim from the official guide.

General Advice
--------------

Before attempting to upgrade an existing application, you should be sure you have a good reason to upgrade. You need to balance several factors: the need for new features, the increasing difficulty of finding support for old code, and your available time and skills, to name a few.

### Test Coverage

The best way to be sure that your application still works after upgrading is to have good test coverage before you start the process. If you don't have automated tests that exercise the bulk of your application, you'll need to spend time manually exercising all the parts that have changed. In the case of a Rails upgrade, that will mean every single piece of functionality in the application. Do yourself a favor and make sure your test coverage is good _before_ you start an upgrade.

### Ruby Versions

Rails generally stays close to the latest released Ruby version when it's released:

* Rails 8.0 and 8.1 require Ruby 3.2.0 or newer.
* Rails 7.2 requires Ruby 3.1.0 or newer.
* Rails 7.0 and 7.1 require Ruby 2.7.0 or newer.
* Rails 6 requires Ruby 2.5.0 or newer.
* Rails 5 requires Ruby 2.2.2 or newer.

It's a good idea to upgrade Ruby and Rails separately. Upgrade to the latest Ruby you can first, and then upgrade Rails.

### The Upgrade Process

When changing Rails versions, it's best to move slowly, one minor version at a time, in order to make good use of the deprecation warnings. Rails version numbers are in the form Major.Minor.Patch. Major and Minor versions are allowed to make changes to the public API, so this may cause errors in your application. Patch versions only include bug fixes, and don't change any public API.

The process should go as follows:

1. Write tests and make sure they pass.
2. Move to the latest patch version after your current version.
3. Fix tests and deprecated features.
4. Move to the latest patch version of the next minor version.

Repeat this process until you reach your target Rails version.

#### Moving between versions

To move between versions:

1. Change the Rails version number in the `Gemfile` and run `bundle update rails`.
2. Change the versions for Rails JavaScript packages in `package.json` and run `bin/rails javascript:install` if running jsbundling-rails.
3. Run the [Update task](#the-update-task).
4. Run your tests.

You can find a list of all released Rails gems [here](https://rubygems.org/gems/rails/versions).

### The Update Task

Rails provides the `bin/rails app:update` command. After updating the Rails version
in the `Gemfile`, run this command.
This will help you with the creation of new files and changes of old files in an
interactive session.

```bash
$ bin/rails app:update
       exist  config
    conflict  config/application.rb
Overwrite /myapp/config/application.rb? (enter "h" for help) [Ynaqdh]
       force  config/application.rb
      create  config/initializers/new_framework_defaults_8_0.rb
...
```

Don't forget to review the difference, to see if there were any unexpected changes, and note that the diff and merge tools used during this process can be defined using the `THOR_DIFF` and `THOR_MERGE` environment variables.

### Configure Framework Defaults

The new Rails version might have different configuration defaults than the previous version. However, after following the steps described above, your application would still run with configuration defaults from the *previous* Rails version. That's because the value for `config.load_defaults` in `config/application.rb` has not been changed yet.

To allow you to upgrade to new defaults one by one, the update task has created a file `config/initializers/new_framework_defaults_X_Y.rb` (with the desired Rails version in the filename). You should enable the new configuration defaults by uncommenting them in the file; this can be done gradually over several deployments. Once your application is ready to run with new defaults, you can remove this file and flip the `config.load_defaults` value.
