# Session Management

Rails 8's authentication generator creates a `Session` model that tracks active sessions. This reference extends it so users can view, manage, and revoke their sessions.

## Enrich the Sessions Table

Add device info and activity tracking to the existing `sessions` table:

```ruby
# bin/rails generate migration AddDeviceInfoToSessions user_agent:string ip_address:string last_active_at:datetime
class AddDeviceInfoToSessions < ActiveRecord::Migration[8.0]
  def change
    add_column :sessions, :user_agent, :string
    add_column :sessions, :ip_address, :string
    add_column :sessions, :last_active_at, :datetime
  end
end
```

## Session Model

```ruby
class Session < ApplicationRecord
  belongs_to :user

  validates :ip_address, presence: true
  validates :user_agent, presence: true

  scope :active, -> { order(last_active_at: :desc) }

  def current?(session_id)
    id == session_id
  end

  def browser_name
    case user_agent
    when /Chrome/i then "Chrome"
    when /Firefox/i then "Firefox"
    when /Safari/i then "Safari"
    when /Edge/i then "Edge"
    else "Unknown browser"
    end
  end

  def os_name
    case user_agent
    when /Windows/i then "Windows"
    when /Macintosh/i then "macOS"
    when /Linux/i then "Linux"
    when /iPhone|iPad/i then "iOS"
    when /Android/i then "Android"
    else "Unknown OS"
    end
  end

  def device_label
    "#{browser_name} on #{os_name}"
  end
end
```

For richer parsing, use the `user_agent_parser` gem instead of regex.

## Record Device Info on Sign-In

In the `Authentication` concern, update `start_new_session_for` (or after it is called) to capture request metadata. The generator's `SessionsController#create` calls `start_new_session_for(user)`. Override or wrap it:

```ruby
# app/controllers/sessions_controller.rb
def create
  if user = User.authenticate_by(params.permit(:email_address, :password))
    start_new_session_for user
    Current.session.update!(
      user_agent: request.user_agent,
      ip_address: request.remote_ip,
      last_active_at: Time.current
    )
    notify_if_new_device(user)
    redirect_to after_authentication_url
  else
    redirect_to new_session_path, alert: "Invalid email or password."
  end
end
```

## Track Last Active

Update `last_active_at` on each request using a `before_action` in `ApplicationController`:

```ruby
class ApplicationController < ActionController::Base
  before_action :touch_session

  private

  def touch_session
    return unless Current.session
    Current.session.update_column(:last_active_at, Time.current) if Current.session.last_active_at&.before?(5.minutes.ago)
  end
end
```

The 5-minute throttle avoids a write on every single request.

## Sessions Controller: List and Revoke

```ruby
# config/routes.rb
resources :sessions, only: [:index, :destroy] do
  delete :destroy_all_others, on: :collection
end
```

```ruby
# app/controllers/sessions_controller.rb (add to existing controller)
def index
  @sessions = Current.user.sessions.active
end

def destroy
  session_record = Current.user.sessions.find(params[:id])
  session_record.destroy
  redirect_to sessions_path, notice: "Session revoked."
end

def destroy_all_others
  Current.user.sessions.where.not(id: Current.session.id).destroy_all
  redirect_to sessions_path, notice: "All other sessions have been signed out."
end
```

## View Template

```erb
<%# app/views/sessions/index.html.erb %>
<h1>Active Sessions</h1>

<table>
  <thead>
    <tr>
      <th>Device</th>
      <th>IP Address</th>
      <th>Last Active</th>
      <th></th>
    </tr>
  </thead>
  <tbody>
    <% @sessions.each do |session_record| %>
      <tr>
        <td>
          <%= session_record.device_label %>
          <% if session_record.current?(Current.session.id) %>
            <strong>(current session)</strong>
          <% end %>
        </td>
        <td><%= session_record.ip_address %></td>
        <td><%= time_ago_in_words(session_record.last_active_at) %> ago</td>
        <td>
          <% unless session_record.current?(Current.session.id) %>
            <%= button_to "Revoke", session_path(session_record), method: :delete %>
          <% end %>
        </td>
      </tr>
    <% end %>
  </tbody>
</table>

<%= button_to "Sign out all other sessions", destroy_all_others_sessions_path, method: :delete %>
```

## Automatic Cleanup

Prune stale sessions with a recurring job:

```ruby
# app/jobs/session_cleanup_job.rb
class SessionCleanupJob < ApplicationJob
  def perform
    Session.where(last_active_at: ..30.days.ago).delete_all
  end
end
```

Schedule it with `solid_queue` recurring tasks or invoke from `after_create`:

```ruby
# config/recurring.yml (Solid Queue)
session_cleanup:
  class: SessionCleanupJob
  schedule: every day at 3am
```

## Security: New Device Notification

Notify users when a session is created from an unfamiliar IP or device:

```ruby
# app/controllers/sessions_controller.rb (inside create, after session is saved)
def notify_if_new_device(user)
  known = user.sessions.where.not(id: Current.session.id)
  ip_known = known.exists?(ip_address: request.remote_ip)
  ua_known = known.exists?(user_agent: request.user_agent)

  unless ip_known && ua_known
    SessionMailer.new_sign_in(user, Current.session).deliver_later
  end
end
```

```ruby
# app/mailers/session_mailer.rb
class SessionMailer < ApplicationMailer
  def new_sign_in(user, session)
    @user = user
    @session = session
    mail to: @user.email_address, subject: "New sign-in to your account"
  end
end
```

The email should include the device, IP, and time so the user can recognize whether it was them.
