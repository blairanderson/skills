---
name: rails-authentication
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - AskUserQuestion
description: |
  End-to-end Rails authentication setup using Rails 8's built-in authentication generator (`bin/rails generate authentication`). MUST trigger when user mentions authentication, login, sign-up, user accounts, sessions, password reset, or authorization in a Rails context. Also trigger when the user mentions organizations, teams, roles, multi-tenancy, or account structures in a Rails app — these are natural extensions of authentication. Even simple requests like "add login" or "set up users" should trigger this skill.
---

# Rails Authentication — End to End

This skill walks through setting up authentication in a Rails app using Rails 8's built-in generator, then extends it with sign-up, email verification, accounts/organizations, roles, and beyond. The goal is to get the user from zero to a fully working auth system — not just the generator output, but everything around it that makes auth actually usable.

## Before You Start

Confirm the app is Rails 8+ by checking the Gemfile. If it's older, let the user know the built-in generator requires Rails 8 and discuss alternatives (Devise, hand-rolled `has_secure_password`).

## Phase 1: Discover Requirements and Ask the User Clarifying Questions

Before running any generators or writing code, present what you've learned and ask targeted questions. Only ask what the code doesn't already answer:

- Core Auth / **Sign-up flow**: Do users self-register, or are they invited?
- Core Auth / **Email verification**: Required before access? (Recommended for most apps — prevents fake accounts and ensures password reset works)
- Core Auth / **Password requirements**: Any specific rules beyond Rails defaults? (Rails enforces max 72 bytes but no minimum — you'll likely want a minimum length)
- Core Auth / **Remember me**: Should sessions persist across browser closes?
- Extended Features / **Accounts / Organizations / Teams**: Does the app have a concept of a group that users belong to? (e.g., a company, a workspace, a team). This is extremely common in B2B SaaS.
- Extended Features / **Roles & Permissions**: Do different users have different access levels? (e.g., admin, member, viewer). Even simple apps often need at least an admin role. See `references/roles-and-permissions.md` for implementation patterns.
- Extended Features / **Invitations**: Can existing users invite new ones? This often goes hand-in-hand with organizations. See `references/invitations.md` for the full flow.
- Extended Features / **OAuth / Social Login**: Need "Sign in with Google/GitHub/etc."? See `references/oauth.md`.
- Extended Features / **Multi-tenancy**: Should data be scoped to organizations? (If they said yes to organizations, this is usually yes too). See `references/multi-tenancy.md` for scoping patterns.

**Save to memory:** app profile (what it does, who it's for, platform, core features, paywall status, sign-in preference).

### Advanced Features (mention these — they may not need them now, but it's good to plant the seed)

- **Two-Factor Authentication (2FA/MFA)**: Required for SOC2, expected by enterprise customers. See `references/2fa.md`.
- **API Token Authentication**: Does the app need programmatic access (webhooks, integrations, CLI tools, mobile apps)? See `references/api-tokens.md`.
- **Session Management**: Should users be able to see and revoke active sessions? See `references/session-management.md`.
- **Rate Limiting**: Rails 8 has built-in `rate_limit` — should we apply it to auth endpoints? (Usually yes.) See `references/rate-limiting.md`.

Summarize what you heard back to the user and confirm before proceeding.

## Phase 2: Run the Generator

```bash
bin/rails generate authentication
```

This creates:

- **Models**: `User` (with `has_secure_password`), `Session`
- **Controllers**: `SessionsController`, `PasswordsController`
- **Concern**: `Authentication` (included in `ApplicationController`)
- **Migrations**: `users` table (email_address, password_digest), `sessions` table
- **Mailer**: Password reset emails
- **Views**: Sign-in form, password reset forms

Then run migrations:

```bash
bin/rails db:migrate
```

Review the generated code with the user. Point out:

1. The `Authentication` concern — this is the heart of it. It provides `authenticated?`, `require_authentication`, and session management helpers.
2. `authenticate_by` in the sessions controller — this is Rails' timing-safe credential check.
3. Password reset tokens are valid for 15 minutes by default.

**Important**: The generator does NOT create sign-up. That's Phase 3.

### Verify Phase 2

```bash
bin/rails routes | grep session
bin/rails routes | grep password
```

Confirm you see routes for sessions#new, sessions#create, sessions#destroy, and passwords#new, passwords#create, passwords#edit, passwords#update.

## Phase 3: Add Sign-Up

The generator deliberately omits registration. Build it:

1. Create `RegistrationsController` with `new` and `create` actions
2. Add the sign-up form view
3. Add routes: `resource :registration, only: [:new, :create]`
4. After successful registration, sign the user in immediately (`start_new_session_for user`)
5. Add a link from the sign-in page to sign-up and vice versa

Add password validations to the User model that the generator doesn't include:

```ruby
validates :password, length: { minimum: 10 }, allow_nil: true
```

The `allow_nil: true` is intentional — `has_secure_password` already validates presence on create, and `nil` means the user isn't changing their password on update.

### Verify Phase 3

```bash
bin/rails routes | grep registration
```

Then test in the Rails console:

```ruby
User.create!(email_address: "test@example.com", password: "securepassword", password_confirmation: "securepassword")
User.authenticate_by(email_address: "test@example.com", password: "securepassword")
```

## Phase 4: Email Verification (if requested)

Most SaaS apps should verify email addresses. Without this, you get fake accounts, unreliable password reset, and no way to confirm you're communicating with the right person.

### Implementation

1. Add `email_verified_at` column to users:

```ruby
add_column :users, :email_verified_at, :datetime
```

2. Generate a verification token using Rails' `generates_token_for`:

```ruby
class User < ApplicationRecord
  generates_token_for :email_verification, expires_in: 24.hours do
    email_address
  end

  def email_verified?
    email_verified_at.present?
  end

  def verify_email!
    update!(email_verified_at: Time.current)
  end
end
```

3. Create `EmailVerificationsController`:

```ruby
class EmailVerificationsController < ApplicationController
  allow_unauthenticated_access only: [:show]

  def show
    user = User.find_by_token_for(:email_verification, params[:token])
    if user
      user.verify_email!
      redirect_to new_session_path, notice: "Email verified! Please sign in."
    else
      redirect_to new_session_path, alert: "Invalid or expired verification link."
    end
  end

  def create
    # Resend verification email
    UserMailer.email_verification(Current.user).deliver_later
    redirect_to root_path, notice: "Verification email sent."
  end
end
```

4. Create `UserMailer#email_verification` that sends the token link.

5. Send verification email after sign-up in `RegistrationsController#create`.

6. **Gate access** — decide whether unverified users can use the app:
   - **Strict**: Add a before_action that redirects unverified users to a "check your email" page
   - **Lenient**: Let them use the app but show a banner and restrict certain actions

### Verify Phase 4

```bash
bin/rails routes | grep email_verification
```

Test the full flow: sign up → receive email → click link → `email_verified_at` is set.

## Phase 5: Accounts / Organizations (if requested)

This is where auth becomes useful for real apps. If the user wants organizations/teams/accounts:

### Data Model

```
Account (or Organization/Team — match the user's language)
├── has_many :memberships
├── has_many :users, through: :memberships
│
Membership
├── belongs_to :account
├── belongs_to :user
├── role: string (e.g., "owner", "admin", "member")
│
User
├── has_many :memberships
├── has_many :accounts, through: :memberships
```

### Key decisions to discuss:

- **Can a user belong to multiple organizations?** (Usually yes for B2B SaaS)
- **What's the default role?** (Usually "member")
- **Who can create organizations?** (Usually any user)
- **Account creation on sign-up**: Auto-create a personal account? Or require joining/creating one after sign-up?

### Multi-tenancy scoping

If data should be scoped to accounts, read `references/multi-tenancy.md` for the full implementation. The short version: set up `Current.account` via a before_action, scope all queries through it, and **never use default_scope for tenant scoping** (it leaks across associations and breaks unscoped queries).

### Switching between accounts

If users can belong to multiple accounts, you need account switching. Store the current account ID in the session or use a subdomain/path prefix pattern.

### Verify Phase 5

```ruby
# In Rails console
user = User.first
account = Account.create!(name: "Test Org")
Membership.create!(user: user, account: account, role: "owner")
user.accounts # should return the account
```

## Phase 6: Roles & Permissions (if requested)

Start simple. Don't reach for a gem unless the requirements are complex.

Role stored on the `Membership` (not the `User` — roles are per-organization):

```ruby
class Membership < ApplicationRecord
  ROLES = %w[owner admin member viewer].freeze
  validates :role, inclusion: { in: ROLES }
end
```

For the full implementation — role hierarchy, authorization concern, and when to upgrade to Pundit or Action Policy — read `references/roles-and-permissions.md`.

### Verify Phase 6

```ruby
membership = Membership.first
membership.update!(role: "admin")
# Test whatever authorization helpers you built
```

## Phase 7: Invitations (if requested)

If the user wants invite flows, read `references/invitations.md` for the complete implementation covering:

- Invitation model with signed tokens and expiration
- Handling existing vs. new users
- Admin invitation management
- Duplicate and revocation handling

The basic flow:

1. Admin creates invitation (email, account, role)
2. Invitee receives email with signed link
3. If existing user → add membership, redirect to sign-in
4. If new user → redirect to sign-up with invitation token, create membership after registration

## Phase 8: OAuth / Social Login (if requested)

If the user wants "Sign in with Google/GitHub/etc.", read `references/oauth.md` for the complete implementation. Key points:

- Uses the `omniauth` gem with provider-specific strategy gems
- `ConnectedAccount` model links OAuth providers to users
- Handles both "sign up with OAuth" and "connect OAuth to existing account"
- Addresses email collision (user signs up with email, then tries OAuth with same email)

## Security Checklist

Before wrapping up, verify these are in place:

- [ ] `require_authentication` is the default (opt-out, not opt-in) — add `allow_unauthenticated_access` only to specific actions
- [ ] Password minimum length validation exists (recommend 10+ characters)
- [ ] Rate limiting on sign-in, sign-up, and password reset endpoints — see `references/rate-limiting.md`
- [ ] CSRF protection is enabled (Rails default, but verify `protect_from_forgery`)
- [ ] Session is reset on sign-in (`start_new_session_for` handles this)
- [ ] Password reset tokens expire (15 min default)
- [ ] Sensitive pages (password change, email change) require current password confirmation — see `references/account-settings.md`
- [ ] Session management: users can view and revoke active sessions — see `references/session-management.md`
- [ ] Email verification is in place (if applicable)

## How to Use This Skill

Work through the phases in order, but skip what doesn't apply. The user might only need Phases 1-3, or they might need all 8 plus reference docs. Let the requirements conversation in Phase 1 guide you.

After each phase, run the verification steps to confirm everything works before moving on. Don't stack up a bunch of generated code without verifying along the way.

When writing code, follow the conventions already in the app. Check for existing patterns (how other controllers look, whether they use Tailwind or Bootstrap, etc.) before generating new files.

For advanced features (2FA, API tokens, account settings, session management, rate limiting), point the user to the appropriate reference doc and follow the implementation guidance there.
