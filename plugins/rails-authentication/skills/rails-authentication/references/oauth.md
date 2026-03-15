# OAuth / Social Login in Rails 8

## Gem Setup

```ruby
# Gemfile
gem "omniauth"
gem "omniauth-rails_csrf_protection"  # Required — enforces POST-only and state verification
gem "omniauth-google-oauth2"          # Add per provider
gem "omniauth-github"
```

Run `bundle install` after adding gems.

## ConnectedAccount Model

```bash
bin/rails generate model ConnectedAccount \
  user:references provider:string uid:string \
  access_token:string refresh_token:string expires_at:datetime
```

Add a unique index on `[provider, uid]` in the migration:

```ruby
add_index :connected_accounts, [:provider, :uid], unique: true
```

In the model, encrypt tokens at rest:

```ruby
class ConnectedAccount < ApplicationRecord
  belongs_to :user

  encrypts :access_token, :refresh_token

  validates :provider, :uid, presence: true
  validates :uid, uniqueness: { scope: :provider }

  def expired?
    expires_at.present? && expires_at < Time.current
  end
end
```

On User:

```ruby
class User < ApplicationRecord
  has_many :connected_accounts, dependent: :destroy
end
```

## OmniAuth Initializer

```ruby
# config/initializers/omniauth.rb
Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2,
    Rails.application.credentials.dig(:google, :client_id),
    Rails.application.credentials.dig(:google, :client_secret),
    scope: "email,profile"

  provider :github,
    Rails.application.credentials.dig(:github, :client_id),
    Rails.application.credentials.dig(:github, :client_secret),
    scope: "user:email"
end

OmniAuth.config.allowed_request_methods = [:post]
```

## Routes

```ruby
# config/routes.rb
post "/auth/:provider/callback", to: "oauth_callbacks#create"
get  "/auth/:provider/callback", to: "oauth_callbacks#create"  # Some providers redirect via GET
get  "/auth/failure",            to: "oauth_callbacks#failure"
```

## Callback Controller

```ruby
class OauthCallbacksController < ApplicationController
  allow_unauthenticated_access only: [:create, :failure]

  def create
    auth = request.env["omniauth.auth"]
    connected = ConnectedAccount.find_by(provider: auth.provider, uid: auth.uid)

    if authenticated?
      # Flow 3: Connect OAuth to existing signed-in user
      link_to_current_user(auth)
    elsif connected
      # Flow 2: Sign in with existing OAuth connection
      sign_in_with(connected)
    else
      # Flow 1: Sign up with OAuth (or link to existing email match)
      sign_up_or_link(auth)
    end
  end

  def failure
    redirect_to new_session_path, alert: "Authentication failed: #{params[:message].humanize}"
  end

  private

  def link_to_current_user(auth)
    existing = ConnectedAccount.find_by(provider: auth.provider, uid: auth.uid)

    if existing && existing.user_id != Current.user.id
      redirect_to settings_path, alert: "That account is linked to a different user."
      return
    end

    Current.user.connected_accounts.find_or_create_by!(provider: auth.provider, uid: auth.uid) do |ca|
      ca.access_token = auth.credentials.token
      ca.refresh_token = auth.credentials.refresh_token
      ca.expires_at = auth.credentials.expires_at ? Time.at(auth.credentials.expires_at) : nil
    end

    redirect_to settings_path, notice: "#{auth.provider.titleize} account connected."
  end

  def sign_in_with(connected)
    connected.update!(
      access_token: request.env["omniauth.auth"].credentials.token,
      refresh_token: request.env["omniauth.auth"].credentials.refresh_token || connected.refresh_token,
      expires_at: request.env["omniauth.auth"].credentials.expires_at&.then { Time.at(_1) }
    )
    start_new_session_for connected.user
    redirect_to after_authentication_url, notice: "Signed in with #{connected.provider.titleize}."
  end

  def sign_up_or_link(auth)
    email = auth.info.email
    existing_user = User.find_by(email_address: email)

    if existing_user
      handle_email_collision(existing_user, auth)
    else
      create_user_from_oauth(auth)
    end
  end

  def handle_email_collision(user, auth)
    # Store OAuth data in session, require the user to sign in first to link
    session[:pending_oauth] = {
      provider: auth.provider,
      uid: auth.uid,
      email: auth.info.email,
      token: auth.credentials.token,
      refresh_token: auth.credentials.refresh_token,
      expires_at: auth.credentials.expires_at
    }
    redirect_to new_session_path,
      notice: "An account with #{auth.info.email} already exists. Sign in to link your #{auth.provider.titleize} account."
  end

  def create_user_from_oauth(auth)
    user = User.create!(
      email_address: auth.info.email,
      password: SecureRandom.base58(24),  # Random password — user can set one later
      email_verified_at: Time.current      # Trust the OAuth provider's verified email
    )

    user.connected_accounts.create!(
      provider: auth.provider,
      uid: auth.uid,
      access_token: auth.credentials.token,
      refresh_token: auth.credentials.refresh_token,
      expires_at: auth.credentials.expires_at ? Time.at(auth.credentials.expires_at) : nil
    )

    start_new_session_for user
    redirect_to after_authentication_url, notice: "Welcome! Account created via #{auth.provider.titleize}."
  end
end
```

## Completing Email Collision Linking

After the user signs in with their password, check for pending OAuth data in `SessionsController#create`:

```ruby
# Inside SessionsController#create, after start_new_session_for(user)
if session[:pending_oauth].present?
  oauth = session.delete(:pending_oauth)
  user.connected_accounts.find_or_create_by!(provider: oauth["provider"], uid: oauth["uid"]) do |ca|
    ca.access_token = oauth["token"]
    ca.refresh_token = oauth["refresh_token"]
    ca.expires_at = oauth["expires_at"] ? Time.at(oauth["expires_at"]) : nil
  end
  redirect_to root_path, notice: "#{oauth['provider'].titleize} account linked."
  return
end
```

## OAuth Login Buttons (Views)

```erb
<%# Use POST via button_to — never GET links for OAuth initiation %>
<%= button_to "Sign in with Google", "/auth/google_oauth2", data: { turbo: false } %>
<%= button_to "Sign in with GitHub", "/auth/github", data: { turbo: false } %>
```

`data: { turbo: false }` is required because OmniAuth runs as Rack middleware outside of Turbo.

## Token Refresh Job

If you need ongoing API access (e.g., pulling data from Google), refresh tokens before they expire:

```ruby
class RefreshOauthTokenJob < ApplicationJob
  def perform(connected_account_id)
    account = ConnectedAccount.find(connected_account_id)
    return unless account.expired?

    # Example for Google — each provider has its own refresh flow
    response = Net::HTTP.post_form(URI("https://oauth2.googleapis.com/token"), {
      client_id: Rails.application.credentials.dig(:google, :client_id),
      client_secret: Rails.application.credentials.dig(:google, :client_secret),
      refresh_token: account.refresh_token,
      grant_type: "refresh_token"
    })

    data = JSON.parse(response.body)
    account.update!(
      access_token: data["access_token"],
      expires_at: data["expires_in"].seconds.from_now
    )
  end
end
```

Schedule with `solid_queue` recurring or trigger before each API call:

```ruby
RefreshOauthTokenJob.perform_later(connected_account.id) if connected_account.expired?
```

## Disconnecting a Provider

Only allow disconnecting if the user has another way to sign in:

```ruby
class ConnectedAccountsController < ApplicationController
  def destroy
    account = Current.user.connected_accounts.find(params[:id])

    unless can_disconnect?
      redirect_to settings_path, alert: "Set a password before disconnecting your only login method."
      return
    end

    account.destroy!
    redirect_to settings_path, notice: "#{account.provider.titleize} disconnected."
  end

  private

  def can_disconnect?
    Current.user.password_digest.present? || Current.user.connected_accounts.count > 1
  end
end
```

## Security Notes

- **omniauth-rails_csrf_protection** verifies the `state` parameter and enforces POST-only initiation. Never remove this gem.
- **Always use POST** (`button_to`) to start OAuth flows. GET links are vulnerable to CSRF login attacks.
- **Set `OmniAuth.config.allowed_request_methods = [:post]`** in the initializer.
- **Encrypt tokens at rest** with `encrypts` (Active Record Encryption, Rails 7+).
- **Never log OAuth tokens.** Filter them in `config/initializers/filter_parameter_logging.rb`:

```ruby
Rails.application.config.filter_parameters += [:access_token, :refresh_token]
```
