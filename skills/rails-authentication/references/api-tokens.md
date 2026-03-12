# API Token Authentication

API tokens are for programmatic access: CI/CD, CLI tools, webhooks, mobile apps, third-party integrations. Use session auth for browsers, tokens for everything else.

## Data Model

```ruby
# bin/rails generate model ApiToken user:references name:string token_digest:string
#   scopes:text last_used_at:datetime expires_at:datetime

class CreateApiTokens < ActiveRecord::Migration[8.0]
  def change
    create_table :api_tokens do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :token_digest, null: false
      t.string :token_prefix, null: false, limit: 8
      t.text :scopes, default: "[]"
      t.datetime :last_used_at
      t.datetime :expires_at
      t.timestamps
    end

    add_index :api_tokens, :token_prefix
    add_index :api_tokens, :token_digest, unique: true
  end
end
```

## ApiToken Model

Never store plaintext tokens. Store a bcrypt digest and a short prefix for lookup.

```ruby
class ApiToken < ApplicationRecord
  belongs_to :user
  # belongs_to :account, optional: true  # add if using multi-tenancy

  VALID_SCOPES = %w[read write admin].freeze

  serialize :scopes, coder: JSON

  validates :name, presence: true
  validates :token_digest, presence: true, uniqueness: true
  validates :token_prefix, presence: true
  validate :scopes_are_valid

  scope :active, -> { where("expires_at IS NULL OR expires_at > ?", Time.current) }

  # Generate a new token. Returns the plaintext token — show it ONCE.
  def self.generate_token_for(user, name:, scopes: ["read"], expires_at: nil)
    plaintext = SecureRandom.hex(32) # 64-char hex string
    token = user.api_tokens.create!(
      name: name,
      token_prefix: plaintext[0..7],
      token_digest: BCrypt::Password.create(plaintext),
      scopes: scopes,
      expires_at: expires_at
    )
    [token, plaintext]
  end

  # Look up by prefix, then verify the full token with bcrypt.
  def self.authenticate(plaintext)
    return nil if plaintext.blank?

    prefix = plaintext[0..7]
    candidates = active.where(token_prefix: prefix)
    candidates.find { |t| BCrypt::Password.new(t.token_digest) == plaintext }
  end

  def expired?
    expires_at? && expires_at < Time.current
  end

  def touch_last_used
    update_column(:last_used_at, Time.current)
  end

  def has_scope?(scope)
    scopes.include?(scope.to_s)
  end

  private

  def scopes_are_valid
    return if scopes.blank?
    invalid = scopes - VALID_SCOPES
    errors.add(:scopes, "contain invalid values: #{invalid.join(', ')}") if invalid.any?
  end
end
```

Why the prefix approach: bcrypt is intentionally slow. Iterating all tokens to find a match does not scale. The 8-char prefix narrows candidates to (almost always) one row, then bcrypt verifies it.

## Controller Concern

```ruby
# app/controllers/concerns/api_authentication.rb
module ApiAuthentication
  extend ActiveSupport::Concern

  private

  def authenticate_api_token
    authenticate_with_http_token do |plaintext, _options|
      api_token = ApiToken.authenticate(plaintext)
      if api_token
        api_token.touch_last_used
        Current.user = api_token.user
        Current.api_token = api_token
        api_token
      end
    end
  end

  def require_api_token
    unless authenticate_api_token
      render json: { error: "Invalid or expired API token" }, status: :unauthorized
    end
  end

  def require_scope(scope)
    unless Current.api_token&.has_scope?(scope)
      render json: { error: "Token missing required scope: #{scope}" }, status: :forbidden
    end
  end
end
```

Add `api_token` to your `Current` model:

```ruby
class Current < ActiveSupport::CurrentAttributes
  attribute :session, :user, :api_token
end
```

## Using in API Controllers

```ruby
class Api::BaseController < ApplicationController
  include ApiAuthentication

  skip_before_action :verify_authenticity_token
  before_action :require_api_token

  rate_limit to: 100, within: 1.minute, by: -> { Current.api_token&.id }, with: -> {
    render json: { error: "Rate limit exceeded" }, status: :too_many_requests
  }
end

class Api::ProjectsController < Api::BaseController
  before_action -> { require_scope("read") }, only: [:index, :show]
  before_action -> { require_scope("write") }, only: [:create, :update, :destroy]

  def index
    projects = Current.user.projects
    render json: projects
  end

  def create
    project = Current.user.projects.create!(project_params)
    render json: project, status: :created
  end
end
```

Clients send the token as a Bearer header:

```
Authorization: Bearer <token>
```

## Token Management UI

```ruby
class ApiTokensController < ApplicationController
  before_action :resume_session  # browser session auth, not token auth

  def index
    @api_tokens = Current.user.api_tokens.order(created_at: :desc)
  end

  def create
    @api_token, @plaintext = ApiToken.generate_token_for(
      Current.user,
      name: params[:api_token][:name],
      scopes: params[:api_token][:scopes] || ["read"],
      expires_at: params[:api_token][:expires_at]
    )
    # Show the plaintext token ONCE — it cannot be retrieved again
    flash[:token] = @plaintext
    redirect_to api_tokens_path, notice: "Token created. Copy it now — you won't see it again."
  end

  def destroy
    token = Current.user.api_tokens.find(params[:id])
    token.destroy
    redirect_to api_tokens_path, notice: "Token revoked."
  end
end
```

## Token Rotation

Create new, migrate integrations, then revoke old. Never revoke-then-create — that causes downtime.

```ruby
# In a rake task, console, or controller action:
new_token, plaintext = ApiToken.generate_token_for(user, name: "Production v2", scopes: ["read", "write"])
# Deploy plaintext to the integration
# Verify the integration works with the new token
# Then revoke the old one:
old_token.destroy
```

## When to Use API Tokens vs Sessions

| Concern | Session Auth | API Tokens |
|---------|-------------|------------|
| Used by | Browsers | Scripts, CI, mobile, integrations |
| Storage | Cookie (encrypted) | Client stores the token |
| CSRF | Required | Not needed (no cookies) |
| Expiry | Tied to session lifetime | Explicit `expires_at` |
| Revocation | Delete session record | Delete token record |
| Scoping | Full user access | Can limit to specific scopes |

Both set `Current.user`, so downstream code works the same regardless of auth method. The difference is at the gate.
