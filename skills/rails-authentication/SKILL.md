---
name: rails-authentication
description: End-to-end Rails authentication setup using Rails 8's built-in authentication generator (`bin/rails generate authentication`). MUST trigger when user mentions authentication, login, sign-up, user accounts, sessions, password reset, or authorization in a Rails context. Also trigger when the user mentions organizations, teams, roles, multi-tenancy, or account structures in a Rails app — these are natural extensions of authentication. Even simple requests like "add login" or "set up users" should trigger this skill.
---

# Rails Authentication — End to End

This skill walks through setting up authentication in a Rails app using Rails 8's built-in generator, then extends it with sign-up, accounts/organizations, roles, and beyond. The goal is to get the user from zero to a fully working auth system — not just the generator output, but everything around it that makes auth actually usable.

## Before You Start

Confirm the app is Rails 8+ by checking the Gemfile. If it's older, let the user know the built-in generator requires Rails 8 and discuss alternatives (Devise, hand-rolled `has_secure_password`).

## Phase 1: Discover Requirements

Before running any generators or writing code, have a short conversation with the user. You need to understand what they're building so you can set up auth correctly the first time.

Ask about these in a natural way (not as a checklist dump — read the room and skip what's obvious from context):

### Core Auth
- **Sign-up flow**: Do users self-register, or are they invited? Or both?
- **Email verification**: Required before access? (Recommended for most apps)
- **Password requirements**: Any specific rules beyond Rails defaults? (Rails enforces max 72 bytes but no minimum — you'll likely want a minimum length)
- **Remember me**: Should sessions persist across browser closes?

### Extended Features (ask about these — they're common and better to set up early)
- **Accounts / Organizations / Teams**: Does the app have a concept of a group that users belong to? (e.g., a company, a workspace, a team). This is extremely common in B2B SaaS.
- **Roles & Permissions**: Do different users have different access levels? (e.g., admin, member, viewer). Even simple apps often need at least an admin role.
- **Invitations**: Can existing users invite new ones? This often goes hand-in-hand with organizations.
- **OAuth / Social Login**: Need "Sign in with Google/GitHub/etc."?
- **Multi-tenancy**: Should data be scoped to organizations? (If they said yes to organizations, this is usually yes too)

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

## Phase 4: Accounts / Organizations (if requested)

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
If data should be scoped to accounts, set up a `Current` object:
```ruby
class Current < ActiveSupport::CurrentAttributes
  attribute :session
  attribute :user
  attribute :account
end
```

Add a `set_current_account` method that runs on each request. Then scope queries through `Current.account`.

### Switching between accounts
If users can belong to multiple accounts, you need account switching. Store the current account ID in the session or use a subdomain/path prefix pattern.

## Phase 5: Roles & Permissions (if requested)

Start simple. Don't reach for a gem unless the requirements are complex.

### Simple approach (recommended for most apps):
Role stored on the `Membership` (not the `User` — roles are per-organization):

```ruby
class Membership < ApplicationRecord
  ROLES = %w[owner admin member viewer].freeze
  validates :role, inclusion: { in: ROLES }

  def admin_or_above?
    role.in?(%w[owner admin])
  end
end
```

### Controller authorization pattern:
```ruby
before_action :require_admin, only: [:destroy, :update]

private

def require_admin
  unless Current.user.membership_for(Current.account).admin_or_above?
    redirect_to root_path, alert: "Not authorized."
  end
end
```

### When to suggest a gem:
If the user needs fine-grained resource-level permissions (e.g., "user X can edit project Y but not project Z"), suggest **Pundit** or **Action Policy**. The simple role check above breaks down when permissions depend on the specific resource, not just the user's role.

## Phase 6: Invitations (if requested)

If the user wants invite flows:
1. Create an `Invitation` model (email, account, role, token, accepted_at)
2. Invited users receive a link with a signed token
3. If they already have an account → add membership, redirect to sign-in
4. If they're new → redirect to sign-up with the invitation token, create membership after registration

## Phase 7: OAuth / Social Login (if requested)

If the user wants "Sign in with Google/GitHub/etc.":
- Recommend the `omniauth` gem with the appropriate strategy gem
- Create a `ConnectedAccount` or `Identity` model to link OAuth providers to users
- Support both "sign up with OAuth" and "connect OAuth to existing account"

## Security Checklist

Before wrapping up, verify these are in place:

- [ ] `require_authentication` is the default (opt-out, not opt-in) — add `allow_unauthenticated_access` only to specific actions
- [ ] Password minimum length validation exists
- [ ] Rate limiting on sign-in attempts (Rails 8 has `rate_limit` built in)
- [ ] CSRF protection is enabled (Rails default, but verify `protect_from_forgery`)
- [ ] Session is reset on sign-in (`start_new_session_for` handles this)
- [ ] Password reset tokens expire (15 min default)
- [ ] Sensitive pages (password change, email change) require current password confirmation

## How to Use This Skill

Work through the phases in order, but skip what doesn't apply. The user might only need Phases 1-3, or they might need all 7. Let the requirements conversation in Phase 1 guide you.

After each phase, make sure the code works — run migrations, check routes (`bin/rails routes`), and suggest the user test in a browser. Don't stack up a bunch of generated code without verifying along the way.

When writing code, follow the conventions already in the app. Check for existing patterns (how other controllers look, whether they use Tailwind or Bootstrap, etc.) before generating new files.
