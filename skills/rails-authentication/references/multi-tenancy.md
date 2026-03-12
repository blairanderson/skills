# Multi-Tenancy Scoping in Rails 8

Multi-tenancy means data belongs to an account (or organization/team) and users should only see data for the account they're currently working in. This reference covers how to scope queries, set the current account, and avoid the most common pitfalls.

## Current Attributes Setup

Rails 8's `Current` singleton is the backbone of tenant scoping. The authentication generator gives you `Current.session` and `Current.user`. Extend it with `Current.account`:

```ruby
# app/models/current.rb
class Current < ActiveSupport::CurrentAttributes
  attribute :session
  attribute :user
  attribute :account
end
```

`Current.account` is available everywhere: controllers, models, views, mailers, jobs. It resets automatically at the end of each request.

## Setting Current.account

Resolve the account in a `before_action`. There are three common strategies — subdomain, path prefix, and session-based. All converge on the same pattern:

```ruby
class ApplicationController < ActionController::Base
  before_action :set_current_account, if: :authenticated?

  private

  def set_current_account
    Current.account = Current.user.accounts.find(session[:account_id])
  rescue ActiveRecord::RecordNotFound
    Current.account = Current.user.accounts.first
    session[:account_id] = Current.account&.id
  end
end
```

This guarantees the user actually belongs to the account. If the stored `account_id` is stale or tampered with, it falls back to their first account.

### Eager-Load the Membership

Avoid N+1 queries when loading the account. If you need the user's role in the current account (you almost always do), eager-load the membership:

```ruby
def set_current_account
  membership = Current.user.memberships.includes(:account).find_by!(account_id: session[:account_id])
  Current.account = membership.account
  Current.membership = membership # add this attribute to Current if you need role checks
rescue ActiveRecord::RecordNotFound
  membership = Current.user.memberships.includes(:account).first
  Current.account = membership&.account
  Current.membership = membership
  session[:account_id] = Current.account&.id
end
```

## Never Use default_scope for Tenant Scoping

This is the single most important rule in multi-tenant Rails apps. Do not do this:

```ruby
# DO NOT DO THIS
class Project < ApplicationRecord
  default_scope { where(account_id: Current.account&.id) }
end
```

It looks convenient. It is a trap. Here is why:

### 1. It leaks across associations

```ruby
account = Account.find(1)
account.users.first.projects
# The .projects query applies Project's default_scope using Current.account,
# NOT account (id: 1). If Current.account is different, you get the wrong data.
# If Current.account is nil, you get WHERE account_id IS NULL — zero results.
```

### 2. It breaks unscoped queries and joins

```ruby
# Admin dashboard that needs to see all projects across accounts?
Project.unscoped # removes ALL scopes, including any you actually wanted
Project.unscoped.where(status: "active") # now you have no tenant scoping AND no other scopes

# Joins silently filter:
Account.joins(:projects) # only joins projects matching the default_scope
```

### 3. It is invisible

Six months from now, a developer writes `Project.count` in a rake task. They get the wrong number because `Current.account` is nil in a rake context. There is no indication in the calling code that a scope is being applied. They will spend hours debugging this.

### 4. It is hard to remove

Once `default_scope` is in your codebase and code depends on it, removing it means auditing every single query for that model. The longer it stays, the worse it gets.

## Use Explicit Scoping Instead

Scope all queries through the association on `Current.account`:

```ruby
# Good — explicit, clear, auditable
Current.account.projects
Current.account.projects.active
Current.account.projects.find(params[:id])

# Bad — implicit, fragile
Project.where(account_id: Current.account.id)
Project.find(params[:id])
```

Using the association (`Current.account.projects`) is better than `where(account_id:)` because:
- It reads as intent: "this account's projects"
- It automatically sets `account_id` on new records: `Current.account.projects.create!(name: "X")`
- It cannot accidentally pass a nil account_id

### Controller Pattern

```ruby
class ProjectsController < ApplicationController
  before_action :set_project, only: [:show, :edit, :update, :destroy]

  def index
    @projects = Current.account.projects
  end

  def create
    @project = Current.account.projects.build(project_params)
    if @project.save
      redirect_to @project
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_project
    @project = Current.account.projects.find(params[:id])
  end
end
```

Every `find` goes through `Current.account.projects`. If a user tries to access a project from another account, they get a 404 — not a 403, not a data leak.

## Account Switching

When a user belongs to multiple accounts, provide a way to switch:

```ruby
class AccountSwitchesController < ApplicationController
  def create
    account = Current.user.accounts.find(params[:account_id])
    session[:account_id] = account.id
    redirect_to root_path, notice: "Switched to #{account.name}"
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: "Account not found"
  end
end
```

```ruby
# config/routes.rb
resource :account_switch, only: [:create]
```

In the UI, a dropdown or menu listing `Current.user.accounts` with a form that posts to `account_switches#create`.

## Subdomain vs Path Prefix vs Session-Based

| Approach | Example | Pros | Cons |
|---|---|---|---|
| **Subdomain** | `acme.app.com` | Clean URLs, easy to identify tenant | DNS/SSL wildcard setup, harder in dev, breaks on localhost without config |
| **Path prefix** | `app.com/acme/projects` | No DNS config, works on localhost | Pollutes every route, easy to forget the prefix in link helpers |
| **Session-based** | `app.com/projects` | Simplest setup, clean routes | Account not in URL (can't bookmark an account-specific page), need explicit switcher |

### Subdomain Resolution

```ruby
# app/controllers/application_controller.rb
def set_current_account
  if request.subdomain.present? && request.subdomain != "www"
    Current.account = Current.user.accounts.find_by!(subdomain: request.subdomain)
  else
    Current.account = Current.user.accounts.find(session[:account_id])
  end
rescue ActiveRecord::RecordNotFound
  redirect_to account_selector_path
end
```

For development, add entries to `/etc/hosts` or use `lvh.me` (resolves to 127.0.0.1 with subdomain support).

### Path Prefix Resolution

```ruby
# config/routes.rb
scope "/:account_slug" do
  resources :projects
  resources :tasks
end
```

```ruby
def set_current_account
  if params[:account_slug]
    Current.account = Current.user.accounts.find_by!(slug: params[:account_slug])
    session[:account_id] = Current.account.id
  end
end
```

## Background Jobs and Mailers

`Current` attributes reset between requests and are **not automatically available** in background jobs or mailers. This is the most common source of tenant data leaks.

### Jobs: Pass the Account ID Explicitly

```ruby
# Enqueue with the account
TenantReportJob.perform_later(account_id: Current.account.id)

# In the job, set Current.account before doing work
class TenantReportJob < ApplicationJob
  def perform(account_id:)
    Current.account = Account.find(account_id)
    projects = Current.account.projects.active
    # ...
  end
end
```

Do not pass `Current.account` as an argument (ActiveJob serializes it as a GlobalID, which works but obscures the intent). Pass the ID.

### Mailers: Same Rule

```ruby
# Controller
AccountMailer.weekly_summary(Current.account.id).deliver_later

# Mailer
class AccountMailer < ApplicationMailer
  def weekly_summary(account_id)
    @account = Account.find(account_id)
    @projects = @account.projects.active
    mail(to: @account.owner.email_address, subject: "Weekly Summary for #{@account.name}")
  end
end
```

Scope queries through the `@account` local variable — not through `Current.account`, which will be nil when the mailer runs asynchronously.

## Testing Data Isolation

Every multi-tenant app needs tests that verify records from Account A are invisible to Account B:

```ruby
class ProjectScopingTest < ActiveSupport::TestCase
  setup do
    @account_a = Account.create!(name: "Account A")
    @account_b = Account.create!(name: "Account B")
    @project_a = @account_a.projects.create!(name: "Secret Project")
    @project_b = @account_b.projects.create!(name: "Other Project")
  end

  test "projects are scoped to the current account" do
    Current.account = @account_a
    assert_includes Current.account.projects, @project_a
    assert_not_includes Current.account.projects, @project_b
  end

  test "find raises RecordNotFound for other account's records" do
    Current.account = @account_a
    assert_raises(ActiveRecord::RecordNotFound) do
      Current.account.projects.find(@project_b.id)
    end
  end
end
```

### Integration Test for Controller Scoping

```ruby
class ProjectsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_user
    @account_a = create_account_with_member(@user)
    @account_b = create_account_with_member(@user)
    @project_a = @account_a.projects.create!(name: "A's Project")
    @project_b = @account_b.projects.create!(name: "B's Project")
    sign_in_as(@user, account: @account_a)
  end

  test "cannot access another account's project" do
    get project_url(@project_b)
    assert_response :not_found
  end

  test "switching accounts changes visible projects" do
    post account_switch_url, params: { account_id: @account_b.id }
    get projects_url
    assert_select "h2", text: "B's Project"
    assert_select "h2", text: "A's Project", count: 0
  end
end
```

Write these tests early. They catch scoping bugs that are otherwise invisible until a customer reports seeing another customer's data.
