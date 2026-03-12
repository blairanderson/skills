# Roles & Permissions in Rails 8

Role-based authorization for Rails apps with organizations. Roles live on the membership (per-org), not on the user.

## Role Hierarchy

Use numeric levels so authorization checks are simple comparisons:

```ruby
class Membership < ApplicationRecord
  ROLE_HIERARCHY = { owner: 40, admin: 30, member: 20, viewer: 10 }.freeze
  ROLES = ROLE_HIERARCHY.keys.map(&:to_s).freeze

  belongs_to :user
  belongs_to :account

  validates :role, inclusion: { in: ROLES }

  def role_level
    ROLE_HIERARCHY[role.to_sym] || 0
  end

  def role_at_least?(minimum_role)
    role_level >= ROLE_HIERARCHY[minimum_role.to_sym]
  end

  def can_manage_role?(target_role)
    role_level > ROLE_HIERARCHY[target_role.to_sym]
  end
end
```

Add a helper on `User` to look up memberships:

```ruby
class User < ApplicationRecord
  has_many :memberships
  has_many :accounts, through: :memberships

  def membership_for(account)
    memberships.find_by(account: account)
  end

  def role_in(account)
    membership_for(account)&.role
  end
end
```

## Authorization Concern

Include this in `ApplicationController`:

```ruby
module Authorization
  extend ActiveSupport::Concern

  private

  def require_role(minimum_role)
    membership = Current.user.membership_for(Current.account)
    unless membership&.role_at_least?(minimum_role)
      redirect_to root_path, alert: "Not authorized."
    end
  end

  def require_owner
    require_role(:owner)
  end
end
```

## Usage in Controllers

Use lambda `before_action` to pass arguments:

```ruby
class ProjectsController < ApplicationController
  before_action -> { require_role(:viewer) }, only: [:index, :show]
  before_action -> { require_role(:member) }, only: [:new, :create]
  before_action -> { require_role(:admin) },  only: [:edit, :update, :destroy]
end

class AccountSettingsController < ApplicationController
  before_action -> { require_role(:admin) }
  before_action :require_owner, only: [:destroy]
end
```

## Role Assignment Rules

Never let a user assign a role at or above their own level. Owners are the exception -- they can assign admin but not owner (that requires an ownership transfer).

```ruby
class MembershipsController < ApplicationController
  before_action -> { require_role(:admin) }

  def update
    membership = Current.account.memberships.find(params[:id])
    new_role = params[:membership][:role]
    current_membership = Current.user.membership_for(Current.account)

    unless current_membership.can_manage_role?(new_role)
      return redirect_to members_path, alert: "You cannot assign a role equal to or above your own."
    end

    if membership.update(role: new_role)
      redirect_to members_path, notice: "Role updated."
    else
      redirect_to members_path, alert: "Failed to update role."
    end
  end
end
```

Strong parameter filtering -- only allow valid roles:

```ruby
def membership_params
  params.require(:membership).permit(:role).tap do |p|
    p[:role] = "member" unless Membership::ROLES.include?(p[:role])
  end
end
```

## Ownership Transfer

Ownership transfer is a destructive action. Use a dedicated flow with confirmation rather than a role dropdown.

```ruby
class OwnershipTransfersController < ApplicationController
  before_action :require_owner

  def create
    new_owner_membership = Current.account.memberships.find(params[:membership_id])
    current_owner_membership = Current.user.membership_for(Current.account)

    ActiveRecord::Base.transaction do
      new_owner_membership.update!(role: "owner")
      current_owner_membership.update!(role: "admin")
    end

    redirect_to account_settings_path, notice: "Ownership transferred."
  end
end
```

Add a confirmation step in the view -- require typing the account name or clicking through a modal. Never transfer ownership from a single button click.

Routes:

```ruby
resource :ownership_transfer, only: [:new, :create]
```

## When to Upgrade to Pundit or Action Policy

The `require_role` approach works when authorization is **role-based**: "admins can edit settings, viewers can only read." It breaks down when permissions depend on the **specific resource**:

- "User X can edit Project Y but not Project Z"
- "Only the creator of a comment can delete it"
- "Members can edit documents they own, admins can edit any document"

If you need resource-level permissions, reach for **Pundit** or **Action Policy**.

### Pundit Quick-Start

```ruby
# Gemfile
gem "pundit"

# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include Pundit::Authorization
  after_action :verify_authorized, except: :index
  after_action :verify_policy_scoped, only: :index
end

# app/policies/application_policy.rb
class ApplicationPolicy
  attr_reader :context, :record

  def initialize(context, record)
    @context = context # context is Current.user + Current.account
    @record = record
  end

  def user       = context.user
  def account    = context.account
  def membership = user.membership_for(account)
end

# app/policies/project_policy.rb
class ProjectPolicy < ApplicationPolicy
  def update?
    membership&.role_at_least?(:admin) || record.creator == user
  end

  def destroy?
    membership&.role_at_least?(:admin)
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(account: account)
    end
  end
end

# In the controller
class ProjectsController < ApplicationController
  def update
    @project = Current.account.projects.find(params[:id])
    authorize @project
    # ...
  end

  def index
    @projects = policy_scope(Project)
  end
end
```

Set up the Pundit user to pass both user and account context:

```ruby
# app/controllers/application_controller.rb
def pundit_user
  OpenStruct.new(user: Current.user, account: Current.account)
end
```

## Testing Roles

### Controller Tests

```ruby
class ProjectsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:default)
    @project = projects(:one)
  end

  test "viewers cannot delete projects" do
    sign_in users(:viewer_user), account: @account
    delete project_url(@project)
    assert_redirected_to root_path
    assert_equal "Not authorized.", flash[:alert]
  end

  test "admins can delete projects" do
    sign_in users(:admin_user), account: @account
    delete project_url(@project)
    assert_redirected_to projects_path
  end
end
```

Add a `sign_in` test helper that sets up the session and current account:

```ruby
# test/test_helper.rb
class ActionDispatch::IntegrationTest
  def sign_in(user, account: nil)
    post session_url, params: {
      email_address: user.email_address,
      password: "password"
    }
    if account
      patch current_account_url, params: { account_id: account.id }
    end
  end
end
```

### System Tests

```ruby
class RoleAuthorizationTest < ApplicationSystemTestCase
  test "member cannot access admin settings" do
    user = users(:member_user)
    sign_in_as(user)

    visit account_settings_path
    assert_text "Not authorized"
    assert_current_path root_path
  end

  test "admin can access admin settings" do
    user = users(:admin_user)
    sign_in_as(user)

    visit account_settings_path
    assert_text "Account Settings"
  end
end
```

### Fixtures

```yaml
# test/fixtures/memberships.yml
viewer_membership:
  user: viewer_user
  account: default
  role: viewer

member_membership:
  user: member_user
  account: default
  role: member

admin_membership:
  user: admin_user
  account: default
  role: admin

owner_membership:
  user: owner_user
  account: default
  role: owner
```

### Model Tests

```ruby
class MembershipTest < ActiveSupport::TestCase
  test "role_at_least? compares hierarchy levels" do
    membership = Membership.new(role: "admin")
    assert membership.role_at_least?(:member)
    assert membership.role_at_least?(:admin)
    refute membership.role_at_least?(:owner)
  end

  test "can_manage_role? prevents assigning equal or higher roles" do
    admin = Membership.new(role: "admin")
    assert admin.can_manage_role?(:member)
    refute admin.can_manage_role?(:admin)
    refute admin.can_manage_role?(:owner)
  end

  test "rejects invalid roles" do
    membership = Membership.new(role: "superadmin")
    refute membership.valid?
  end
end
```
