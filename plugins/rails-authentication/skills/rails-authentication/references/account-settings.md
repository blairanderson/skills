# Account Settings

Patterns for letting users manage their own account: password changes, email changes, profile updates, and account deletion. All sensitive changes require current password confirmation via `authenticate_by`.

## Controller Structure

Use separate controllers per concern. A single `AccountSettingsController` grows unwieldy fast.

```ruby
# config/routes.rb
resource :password_update, only: [:edit, :update]
resource :email_update, only: [:edit, :update]
resource :email_confirmation, only: [:show], param: :token
resource :profile, only: [:edit, :update]
resource :account_deletion, only: [:new, :create]
```

All sit behind `require_authentication` (the default from the `Authentication` concern).

## Password Change

Require current password, validate the new one, terminate all other sessions. No migration needed — `password_digest` exists from the auth generator.

```ruby
class PasswordUpdatesController < ApplicationController
  rate_limit to: 5, within: 1.hour, only: :update

  def edit; end

  def update
    user = Current.user.authenticate_by(
      email_address: Current.user.email_address,
      password: params[:current_password]
    )
    if user.nil?
      redirect_to edit_password_update_path, alert: "Current password is incorrect."
    elsif user.update(params.require(:user).permit(:password, :password_confirmation))
      Current.user.sessions.where.not(id: Current.session.id).delete_all
      redirect_to edit_password_update_path, notice: "Password updated."
    else
      redirect_to edit_password_update_path, alert: user.errors.full_messages.to_sentence
    end
  end
end
```

`authenticate_by` is timing-safe. Never use `user.authenticate(password)` for credential checks — it leaks timing information about email existence.

## Email Change

Do NOT update `email_address` immediately. Send a verification link to the new address first. Use an `unconfirmed_email` column (simpler) or a `PendingEmailChange` model (if you need change history). The column approach works for most apps.

```ruby
add_column :users, :unconfirmed_email, :string # Migration

# User model — add token generation for email change verification
generates_token_for :email_change, expires_in: 24.hours do
  unconfirmed_email
end
```

```ruby
class EmailUpdatesController < ApplicationController
  rate_limit to: 5, within: 1.hour, only: :update

  def edit; end

  def update
    user = Current.user.authenticate_by(
      email_address: Current.user.email_address,
      password: params[:current_password]
    )
    if user.nil?
      redirect_to edit_email_update_path, alert: "Current password is incorrect."
    elsif User.exists?(email_address: params[:new_email])
      redirect_to edit_email_update_path, alert: "That email is already taken."
    else
      user.update!(unconfirmed_email: params[:new_email])
      UserMailer.email_change_confirmation(user).deliver_later
      redirect_to edit_email_update_path, notice: "Check your new email for a confirmation link."
    end
  end
end
```

```ruby
class EmailConfirmationsController < ApplicationController
  allow_unauthenticated_access only: [:show]

  def show
    user = User.find_by_token_for(:email_change, params[:token])
    if user && user.unconfirmed_email.present?
      user.update!(email_address: user.unconfirmed_email, unconfirmed_email: nil)
      user.sessions.delete_all
      redirect_to new_session_path, notice: "Email updated. Please sign in again."
    else
      redirect_to new_session_path, alert: "Invalid or expired confirmation link."
    end
  end
end
```

## Profile Updates

Name, avatar, and other non-sensitive fields. No current password required.

```ruby
class ProfilesController < ApplicationController
  def edit
    @user = Current.user
  end

  def update
    @user = Current.user
    if @user.update(params.require(:user).permit(:name, :avatar))
      redirect_to edit_profile_path, notice: "Profile updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end
end
```

For avatar uploads, add `has_one_attached :avatar` to the User model (Active Storage).

## Account Deletion

Requires confirmation step, a grace period before permanent deletion, and careful data handling.

```ruby
# Migration
add_column :users, :deletion_requested_at, :datetime
```

```ruby
class AccountDeletionsController < ApplicationController
  def new; end

  def create
    user = Current.user.authenticate_by(
      email_address: Current.user.email_address,
      password: params[:current_password]
    )
    if user.nil?
      redirect_to new_account_deletion_path, alert: "Incorrect password."
    else
      user.update!(deletion_requested_at: Time.current)
      UserMailer.deletion_scheduled(user).deliver_later
      user.sessions.delete_all
      redirect_to new_session_path, notice: "Account scheduled for deletion in 14 days."
    end
  end
end
```

### Purge Job

Run daily with Solid Queue. Anonymize records you must keep, delete everything else.

```ruby
class PurgeDeletedAccountsJob < ApplicationJob
  def perform
    User.where("deletion_requested_at <= ?", 14.days.ago).find_each do |user|
      user.invoices.update_all(user_email: "deleted@example.com", user_name: "Deleted User")
      user.sessions.delete_all
      user.avatar.purge if user.avatar.attached?
      user.destroy!
    end
  end
end

# config/recurring.yml — schedule: every day at 3am
```

### Cancelling Deletion

Let users cancel during the grace period by signing in. In `SessionsController#create`, after successful authentication:

```ruby
if user.deletion_requested_at.present?
  user.update!(deletion_requested_at: nil)
  flash[:notice] = "Welcome back! Account deletion has been cancelled."
end
```

### GDPR / CCPA

- **Right to erasure**: The grace period + purge job covers this. Log when deletion was requested and completed.
- **Data export**: Offer "Download my data" before deletion — a background job that zips their data as JSON/CSV and emails a link.
- **Anonymize, don't delete** records required for legal/financial compliance. Replace PII with placeholders.
- **Third-party cleanup**: Queue jobs to remove data from external services (Stripe, mailing lists, analytics).

## Security Summary

- Every sensitive change (password, email, deletion) must go through `authenticate_by` with the current password.
- After password or email changes, revoke other sessions. After deletion, revoke all sessions.
- Rate-limit all update endpoints — users hit them infrequently, so tight limits (5/hour) are fine.
- "That email is already taken" is acceptable in the email change flow because the user is already authenticated.
