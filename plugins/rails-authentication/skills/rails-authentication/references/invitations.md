# Invitations

Invitation flow for adding users to accounts/organizations in a Rails 8 app. Assumes `User`, `Account`, and `Membership` models exist (see SKILL.md Phase 5).

## Invitation Model

```bash
bin/rails generate model Invitation email:string account:references role:string invited_by:references accepted_at:datetime expires_at:datetime
```

```ruby
class Invitation < ApplicationRecord
  belongs_to :account
  belongs_to :invited_by, class_name: "User"

  normalizes :email, with: ->(email) { email.strip.downcase }

  generates_token_for :invite, expires_in: 7.days do
    email
  end

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role, presence: true, inclusion: { in: Membership::ROLES }
  validates :email, uniqueness: { scope: :account_id, conditions: -> { pending },
                                  message: "already has a pending invitation" }

  scope :pending, -> { where(accepted_at: nil).where("expires_at > ?", Time.current) }
  scope :accepted, -> { where.not(accepted_at: nil) }

  before_create { self.expires_at ||= 7.days.from_now }

  def pending? = accepted_at.nil? && expires_at > Time.current

  def accept!(user)
    transaction do
      update!(accepted_at: Time.current)
      account.memberships.create!(user: user, role: role)
    end
  end
end
```

Add a partial unique index to prevent duplicate pending invitations:

```ruby
add_index :invitations, [:account_id, :email], unique: true,
          where: "accepted_at IS NULL", name: "index_invitations_pending_unique"
```

## Routes

```ruby
resources :accounts do
  resources :invitations, only: [:index, :create, :destroy] do
    member { post :resend }
  end
end
get "invitations/accept", to: "invitation_acceptances#show"
```

## Sending Invitations (Admin)

```ruby
class InvitationsController < ApplicationController
  before_action :set_account
  before_action :require_admin

  def index
    @pending = @account.invitations.pending.order(created_at: :desc)
    @accepted = @account.invitations.accepted.order(accepted_at: :desc).limit(20)
  end

  def create
    @invitation = @account.invitations.new(invitation_params)
    @invitation.invited_by = Current.user

    if @account.memberships.exists?(user: User.find_by(email_address: @invitation.email))
      return redirect_to account_invitations_path(@account), alert: "Already a member."
    end

    if @invitation.save
      InvitationMailer.invite(@invitation).deliver_later
      redirect_to account_invitations_path(@account), notice: "Invitation sent."
    else
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    @account.invitations.pending.find(params[:id]).destroy
    redirect_to account_invitations_path(@account), notice: "Invitation revoked."
  end

  def resend
    invitation = @account.invitations.pending.find(params[:id])
    InvitationMailer.invite(invitation).deliver_later
    redirect_to account_invitations_path(@account), notice: "Invitation resent."
  end

  private

  def set_account = @account = Current.user.accounts.find(params[:account_id])

  def require_admin
    membership = @account.memberships.find_by(user: Current.user)
    redirect_to @account, alert: "Not authorized." unless membership&.role.in?(%w[owner admin])
  end

  def invitation_params = params.require(:invitation).permit(:email, :role)
end
```

## Mailer

```ruby
class InvitationMailer < ApplicationMailer
  def invite(invitation)
    @invitation = invitation
    @token = invitation.generate_token_for(:invite)
    @accept_url = invitations_accept_url(token: @token)
    mail(to: invitation.email, subject: "You've been invited to #{invitation.account.name}")
  end
end
```

## Accepting Invitations

Two paths: existing user gets a membership immediately; new user is sent to sign-up.

```ruby
class InvitationAcceptancesController < ApplicationController
  allow_unauthenticated_access

  def show
    invitation = Invitation.find_by_token_for(:invite, params[:token])

    unless invitation&.pending?
      return redirect_to new_session_path, alert: "Invalid or expired invitation link."
    end

    existing_user = User.find_by(email_address: invitation.email)

    if existing_user
      invitation.accept!(existing_user)
      redirect_to new_session_path, notice: "You've joined #{invitation.account.name}. Sign in to continue."
    else
      redirect_to new_registration_path(invitation_token: params[:token])
    end
  end
end
```

Handle the invitation token during registration:

```ruby
# In RegistrationsController#create, after @user.save:
def accept_invitation_if_present(user)
  return if params[:invitation_token].blank?
  invitation = Invitation.find_by_token_for(:invite, params[:invitation_token])
  invitation.accept!(user) if invitation&.pending?
end
```

Pass the token through the sign-up form with a hidden field:

```erb
<%= hidden_field_tag :invitation_token, params[:invitation_token] %>
```

## Duplicate Handling

- **Already a member**: Controller checks `account.memberships` before creating the invitation.
- **Pending invitation exists**: Model validation with `conditions: -> { pending }` plus the partial unique index rejects duplicates. Use the resend action instead.

## Token Security

- `generates_token_for` produces signed, tamper-proof tokens via `MessageVerifier`.
- Tokens expire in 7 days. The `expires_at` column enables query-side filtering.
- One-time use: `accept!` sets `accepted_at`; `pending?` prevents re-acceptance.
- The token digest includes `email`, so changing the invitation email invalidates outstanding tokens.
- Always use `find_by_token_for` to verify tokens. Never store raw tokens in the DB.

## Edge Cases

- **Email case sensitivity**: `normalizes` lowercases invitation emails. Ensure `User` normalizes `email_address` the same way so lookups match.
- **Email changed after invite**: Token encodes the original email. If a user changes their email, `find_by_token_for` returns nil. Admin should revoke and re-invite.
- **Expired cleanup**: `Invitation.where(accepted_at: nil).where("expires_at < ?", 30.days.ago).delete_all` in a recurring job.
- **Race condition on accept**: The transaction in `accept!` plus a unique index on `memberships [:account_id, :user_id]` prevents double membership creation.
