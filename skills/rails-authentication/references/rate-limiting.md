# Rate Limiting Auth Endpoints

Rails 8 has a built-in `rate_limit` controller DSL backed by `Rails.cache`. No gems needed. Apply it to every auth endpoint that accepts credentials or sends emails.

## The `rate_limit` DSL

```ruby
class SessionsController < ApplicationController
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> {
    redirect_to new_session_path, alert: "Too many sign-in attempts. Please wait a few minutes."
  }
end
```

Key options:
- `to:` -- max requests allowed
- `within:` -- time window
- `only:` / `except:` -- scope to specific actions
- `by:` -- lambda returning the rate limit key (defaults to `request.remote_ip`)
- `with:` -- lambda called when limit is exceeded (default raises `ActionController::RateLimited`)

## Recommended Limits by Endpoint

```ruby
# app/controllers/sessions_controller.rb
class SessionsController < ApplicationController
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> {
    redirect_to new_session_path, alert: "Too many sign-in attempts. Please wait a few minutes."
  }
end

# app/controllers/registrations_controller.rb
class RegistrationsController < ApplicationController
  rate_limit to: 5, within: 1.hour, only: :create, with: -> {
    redirect_to new_registration_path, alert: "Too many sign-up attempts. Try again later."
  }
end

# app/controllers/passwords_controller.rb
class PasswordsController < ApplicationController
  rate_limit to: 5, within: 1.hour, only: :create, with: -> {
    redirect_to new_password_path, alert: "Too many password reset requests. Try again later."
  }
end

# app/controllers/email_verifications_controller.rb
class EmailVerificationsController < ApplicationController
  rate_limit to: 3, within: 1.hour, only: :create, with: -> {
    redirect_to root_path, alert: "Too many verification emails requested."
  }
end

# app/controllers/two_factor_challenges_controller.rb
class TwoFactorChallengesController < ApplicationController
  rate_limit to: 5, within: 10.minutes, only: :create, with: -> {
    redirect_to new_session_path, alert: "Too many attempts. Please sign in again."
  }
end
```

## Per-Email Rate Limiting

The default `rate_limit` keys by IP. Attackers can try one password per IP across a botnet. For login, add a per-email limit using the `by:` option:

```ruby
class SessionsController < ApplicationController
  # Per-IP limit
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> {
    redirect_to new_session_path, alert: "Too many attempts. Please wait."
  }

  # Per-email limit (stacks with the IP limit)
  rate_limit to: 5, within: 3.minutes, only: :create,
    by: -> { "session-email:#{params[:email_address].to_s.downcase.strip}" },
    with: -> { redirect_to new_session_path, alert: "Too many attempts for this email." }
end
```

Both limits apply independently -- a request is blocked if either limit is exceeded.

## Custom Cache-Based Limiting

For cases where `rate_limit` doesn't fit (e.g., counting only failed attempts), use `Rails.cache` directly:

```ruby
class SessionsController < ApplicationController
  def create
    user = User.authenticate_by(email_address: params[:email_address], password: params[:password])

    if user
      clear_failed_attempts(params[:email_address])
      start_new_session_for user
      redirect_to after_authentication_url
    else
      record_failed_attempt(params[:email_address])
      redirect_to new_session_path, alert: "Invalid email or password."
    end
  end

  private

  def record_failed_attempt(email)
    key = "login_failures:#{email.to_s.downcase.strip}"
    count = Rails.cache.increment(key, 1, expires_in: 30.minutes) || 1
    lock_account(email) if count >= 10
  end

  def clear_failed_attempts(email)
    Rails.cache.delete("login_failures:#{email.to_s.downcase.strip}")
  end

  def lock_account(email)
    user = User.find_by(email_address: email)
    user&.lock_access!
  end
end
```

## Account Lockout

Temporary lockout after repeated failures. Add to the User model:

```ruby
# Migration: add_column :users, :locked_at, :datetime

class User < ApplicationRecord
  LOCK_DURATION = 30.minutes

  def lock_access!
    update_column(:locked_at, Time.current)
    UserMailer.account_locked(self).deliver_later
  end

  def unlock_access!
    update_column(:locked_at, nil)
  end

  def locked?
    return false if locked_at.nil?
    if locked_at > LOCK_DURATION.ago
      true
    else
      unlock_access!
      false
    end
  end
end
```

Check the lock in `SessionsController#create` before authenticating:

```ruby
def create
  user = User.find_by(email_address: params[:email_address])

  if user&.locked?
    redirect_to new_session_path, alert: "Account temporarily locked. Try again later."
    return
  end

  user = User.authenticate_by(email_address: params[:email_address], password: params[:password])
  # ... rest of sign-in logic
end
```

## API Token Rate Limiting

Use the `by:` option to rate limit per token instead of per IP:

```ruby
class Api::BaseController < ApplicationController
  before_action :require_api_token

  rate_limit to: 100, within: 1.minute,
    by: -> { Current.api_token&.id },
    with: -> { render json: { error: "Rate limit exceeded" }, status: :too_many_requests }
end
```

## Cache Store Requirements

`rate_limit` requires a cache store that supports `increment`. In production, use Redis or Memcached:

```ruby
# config/environments/production.rb
config.cache_store = :solid_cache_store  # Rails 8 default, works with rate_limit
# or
config.cache_store = :redis_cache_store, { url: ENV["REDIS_URL"] }
```

For development, the default `MemoryStore` works fine. `FileStore` also supports `increment`.
