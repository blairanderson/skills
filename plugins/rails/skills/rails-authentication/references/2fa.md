# Two-Factor Authentication (TOTP-based 2FA)

Adds TOTP-based 2FA to a Rails 8 app using the built-in authentication generator.

## Gems

```ruby
gem "rotp"    # TOTP code generation/verification
gem "rqrcode" # QR code generation for authenticator setup
```

## Migration

```ruby
class AddTwoFactorToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :otp_secret, :string
    add_column :users, :otp_required, :boolean, default: false, null: false
    add_column :users, :backup_codes, :text # JSON array of bcrypt hashes
  end
end
```

## Model Concern

```ruby
# app/models/concerns/two_factor_authenticatable.rb
module TwoFactorAuthenticatable
  extend ActiveSupport::Concern
  BACKUP_CODE_COUNT = 10

  included do
    generates_token_for :two_factor_challenge, expires_in: 5.minutes
  end

  def otp_provisioning_uri(issuer: Rails.application.class.module_parent_name)
    ROTP::TOTP.new(otp_secret, issuer: issuer).provisioning_uri(email_address)
  end

  def verify_otp(code)
    return verify_backup_code(code) if code.length > 6
    ROTP::TOTP.new(otp_secret).verify(code, drift_behind: 15, drift_ahead: 15).present?
  end

  def generate_otp_secret!  = update!(otp_secret: ROTP::Base32.random)
  def enable_two_factor!    = update!(otp_required: true)
  def disable_two_factor!   = update!(otp_secret: nil, otp_required: false, backup_codes: nil)

  def generate_backup_codes!
    plain_codes = BACKUP_CODE_COUNT.times.map { SecureRandom.hex(4) }
    hashed = plain_codes.map { |code| BCrypt::Password.create(code) }
    update!(backup_codes: hashed.to_json)
    plain_codes # return plain codes to show the user exactly once
  end

  private

  def verify_backup_code(code)
    return false if backup_codes.blank?
    hashed_codes = JSON.parse(backup_codes)
    index = hashed_codes.index { |h| BCrypt::Password.new(h) == code }
    return false unless index
    hashed_codes.delete_at(index)
    update!(backup_codes: hashed_codes.to_json)
    true
  end
end
```

Include in User: `include TwoFactorAuthenticatable`.

## Routes

```ruby
resource :two_factor_setup, only: %i[new create destroy]
resource :two_factor_challenge, only: %i[new create]
```

## 2FA Setup Controller

Generate secret, show QR code, verify first code, then enable and show backup codes.

```ruby
# app/controllers/two_factor_setups_controller.rb
class TwoFactorSetupsController < ApplicationController
  def new
    Current.user.generate_otp_secret! unless Current.user.otp_secret.present?
    @qr_code = RQRCode::QRCode.new(Current.user.otp_provisioning_uri)
  end

  def create
    if Current.user.verify_otp(params[:code])
      Current.user.enable_two_factor!
      @backup_codes = Current.user.generate_backup_codes!
      render :backup_codes
    else
      redirect_to new_two_factor_setup_path, alert: "Invalid code. Try again."
    end
  end

  def destroy
    if Current.user.authenticate(params[:password])
      Current.user.disable_two_factor!
      redirect_to root_path, notice: "Two-factor authentication disabled."
    else
      redirect_to new_two_factor_setup_path, alert: "Incorrect password."
    end
  end
end
```

**Setup view** (`two_factor_setups/new.html.erb`): render QR via `@qr_code.as_svg(module_size: 4, standalone: true).html_safe`, show `Current.user.otp_secret` as manual entry fallback, and a form posting `code` to `two_factor_setup_path`.

**Backup codes view** (`two_factor_setups/backup_codes.html.erb`): list `@backup_codes` with a warning they are shown only once.

## 2FA Challenge on Login

Modify `SessionsController#create` to intercept login when 2FA is enabled. Use `generates_token_for` so the password-verified state survives the redirect without storing the user ID in the session prematurely.

```ruby
# SessionsController#create -- replace the standard sign-in logic:
def create
  user = User.authenticate_by(email_address: params[:email_address], password: params[:password])

  if user&.otp_required?
    token = user.generate_token_for(:two_factor_challenge)
    redirect_to new_two_factor_challenge_path(token: token)
  elsif user
    start_new_session_for user
    redirect_to after_authentication_url
  else
    redirect_to new_session_path, alert: "Invalid email or password."
  end
end
```

```ruby
# app/controllers/two_factor_challenges_controller.rb
class TwoFactorChallengesController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> {
    redirect_to new_session_url, alert: "Too many attempts. Start over."
  }

  def new
    @token = params[:token]
    redirect_to new_session_path unless find_user
  end

  def create
    user = find_user
    unless user
      return redirect_to new_session_path, alert: "Session expired. Sign in again."
    end

    if user.verify_otp(params[:code])
      start_new_session_for user
      redirect_to after_authentication_url
    else
      @token = params[:token]
      flash.now[:alert] = "Invalid code."
      render :new, status: :unprocessable_entity
    end
  end

  private

  def find_user = User.find_by_token_for(:two_factor_challenge, params[:token])
end
```

**Challenge view** (`two_factor_challenges/new.html.erb`): a form with a hidden `token` field and a `code` text field (`autocomplete: "one-time-code"`, `inputmode: "numeric"`), posting to `two_factor_challenge_path`. Label should indicate backup codes are also accepted.

## Recovery Flow

1. **Has backup codes** -- enter a backup code on the 2FA challenge form. It works like a normal code but is consumed on use.
2. **No backup codes** -- no self-service recovery. Require identity verification through a support process. Do not build an automated email-based bypass (it defeats the purpose of 2FA).

## Security Considerations

- **Rate limit 2FA attempts** -- `rate_limit` on the challenge controller prevents brute-forcing 6-digit codes.
- **Don't leak 2FA status** -- the login error is the same whether or not 2FA is enabled. The challenge prompt only appears after a valid password.
- **Token expiry** -- the challenge token expires in 5 minutes, limiting the window after password verification.
- **Backup codes are hashed** -- stored as bcrypt hashes, shown to the user exactly once.
- **TOTP drift tolerance** -- 15 seconds handles minor clock skew without being too permissive.
- **Disabling requires password** -- the `destroy` action authenticates the current password before removing 2FA.
