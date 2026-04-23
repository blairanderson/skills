# Conductor Rails Templates

These are the reference templates from the Conductor Rails quickstart.
When applying these to a project, always read existing files first and merge intelligently — don't blindly overwrite working configurations.

## conductor.json

Create at project root if it doesn't exist.

```json
{
  "scripts": {
    "setup": "bin/conductor-setup",
    "server": "script/server"
  }
}
```

## bin/conductor-setup

This script runs automatically when Conductor creates a new workspace. It symlinks shared files (`.env`, storage, credentials) from the root repo so every workspace shares the same config.

```bash
#!/bin/sh
#/ Usage: bin/conductor-setup
#/
#/ Setup files that are not tracked in git for Conductor workspaces.
#/ This is run automatically when a new workspace is created.

set -e
cd $(dirname "$0")/..

# Symlink .env from the root repo so all workspaces share the same config.
# Set up your .env once at $CONDUCTOR_ROOT_PATH/.env and all workspaces use it.
if [ -n "$CONDUCTOR_ROOT_PATH" ]; then
  if [ -f "$CONDUCTOR_ROOT_PATH/.env" ]; then
    echo "Symlinking .env from $CONDUCTOR_ROOT_PATH/.env..."
    ln -sf "$CONDUCTOR_ROOT_PATH/.env" .env
  else
    echo "Warning: $CONDUCTOR_ROOT_PATH/.env not found."
    echo "Create it from .env.example: cp .env.example $CONDUCTOR_ROOT_PATH/.env"
  fi

  # Copy database.yml and credential keys from repo root
  if [ -f "$CONDUCTOR_ROOT_PATH/config/database.yml" ]; then
    echo "Copying database.yml from repo root..."
    cp "$CONDUCTOR_ROOT_PATH/config/database.yml" config/database.yml
  fi

  if [ -f "$CONDUCTOR_ROOT_PATH/config/credentials/development.key" ]; then
    echo "Copying development.key from repo root..."
    cp "$CONDUCTOR_ROOT_PATH/config/credentials/development.key" config/credentials/development.key
  fi

  if [ -f "$CONDUCTOR_ROOT_PATH/config/credentials/test.key" ]; then
    echo "Copying test.key from repo root..."
    cp "$CONDUCTOR_ROOT_PATH/config/credentials/test.key" config/credentials/test.key
  fi

  # Symlink storage directory for Active Storage
  if [ -d "$CONDUCTOR_ROOT_PATH/storage" ]; then
    echo "Symlinking storage from $CONDUCTOR_ROOT_PATH/storage..."
    ln -sf "$CONDUCTOR_ROOT_PATH/storage" storage
  else
    echo "Creating storage directory at $CONDUCTOR_ROOT_PATH/storage..."
    mkdir -p "$CONDUCTOR_ROOT_PATH/storage"
    ln -sf "$CONDUCTOR_ROOT_PATH/storage" storage
  fi

  # Symlink ngrok.yml from repo root if it exists
  if [ -f "$CONDUCTOR_ROOT_PATH/ngrok.yml" ]; then
    echo "Symlinking ngrok.yml from $CONDUCTOR_ROOT_PATH/ngrok.yml..."
    ln -sf "$CONDUCTOR_ROOT_PATH/ngrok.yml" ngrok.yml
  fi

  # Symlink .bundle for private gem credentials
  if [ -d "$CONDUCTOR_ROOT_PATH/.bundle" ]; then
    if [ -e .bundle ] && [ ! -L .bundle ]; then
      echo "Error: .bundle exists and is not a symlink. Remove it manually first."
      exit 1
    fi
    echo "Symlinking .bundle from $CONDUCTOR_ROOT_PATH/.bundle..."
    ln -sf "$CONDUCTOR_ROOT_PATH/.bundle" .bundle
  fi
else
  # Fallback for running outside Conductor
  if [ ! -f .env ]; then
    echo "Creating .env from .env.example..."
    cp .env.example .env
  else
    echo ".env already exists, skipping..."
  fi
fi

# Run full setup (dependencies, database, fixtures)
script/bootstrap

echo "Conductor setup complete!"
```

## script/server

This replaces or wraps the existing server start script. The key behavior: it reads `CONDUCTOR_PORT` so each workspace gets a unique port.

```bash
#!/bin/sh
#/ Usage: script/server
#/
#/ Run all the processes necessary for the app.

set -e
cd $(dirname "$0")/..

[ "$1" = "--help" -o "$1" = "-h" -o "$1" = "help" ] && {
    grep '^#/' <"$0"| cut -c4-
    exit 0
}

# Use CONDUCTOR_PORT if set, otherwise PORT, defaulting to 3000
export PORT=${CONDUCTOR_PORT:-${PORT:-3000}}

bundle exec foreman start -p ${PORT} -f Procfile.dev
```

## config/initializers/default_host.rb

This ensures URL generation, mailer links, and asset hosts all use the correct port — critical when Conductor assigns dynamic ports.

```ruby
canonical_host = ENV["CANONICAL_HOST"]

CANONICAL_HOST = if canonical_host
  canonical_host
elsif Rails.env.development?
  "localhost:#{ENV.fetch("PORT", 3000)}"
elsif Rails.env.test?
  "www.example.com"
else
  "#{ENV["HEROKU_APP_NAME"]}.herokuapp.com"
end

scheme = Rails.configuration.force_ssl ? "https" : "http"
APP_URL = "#{scheme}://#{CANONICAL_HOST}"

Rails.application.routes.default_url_options[:host] = CANONICAL_HOST
Rails.application.config.action_mailer.default_url_options = { host: CANONICAL_HOST }
Rails.application.config.asset_host = CANONICAL_HOST

if canonical_host
  Rails.application.middleware.use Rack::CanonicalHost, canonical_host
end
```

## config/puma.rb

The key Conductor-specific parts are: reading `PORT` from env, and the `on_booted` block that prints the URL. Merge these into the existing puma.rb rather than replacing it.

```ruby
workers_count = Integer(ENV['WEB_CONCURRENCY'] || 1)
max_threads_count = Integer(ENV['RAILS_MAX_THREADS'] || 2)
min_threads_count = Integer(ENV['RAILS_MIN_THREADS'] || max_threads_count)
threads min_threads_count, max_threads_count

port        ENV['PORT']     || 3000
environment ENV['RACK_ENV'] || ENV['RAILS_ENV'] || 'development'

enable_keep_alives false

if workers_count > 1
  preload_app!
  workers workers_count

  before_fork do
    if defined?(::ActiveRecord) && defined?(::ActiveRecord::Base)
      ApplicationRecord.connection_pool.disconnect!
    end
  end

  on_worker_boot do
    if defined?(::ActiveRecord) && defined?(::ActiveRecord::Base)
      ApplicationRecord.establish_connection
    end
  end
end

if ENV['RACK_ENV'] == 'development' || ENV['RAILS_ENV'] == 'development' || (ENV['RACK_ENV'].nil? && ENV['RAILS_ENV'].nil?)
  on_booted do
    port = ENV['PORT'] || 3000
    url = "http://localhost:#{port}"
    puts
    puts "  App running at #{url}"
    puts
  end
end

plugin :tmp_restart
```
