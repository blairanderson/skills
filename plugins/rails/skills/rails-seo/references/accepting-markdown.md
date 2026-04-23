# Accepting Markdown in Rails

Source: https://acceptmarkdown.com/recipes/rails

Rails 8+ has built-in markdown support via a registered MIME type, dedicated renderer, and automatic `Vary: Accept` headers. Earlier versions need manual wiring.

## 1. Define `to_markdown` on the model

```ruby
class Post < ApplicationRecord
  def to_markdown
    body_markdown  # stored column, computed conversion, or cached field
  end
end
```

For Action Text bodies, convert via `reverse_markdown`:

```ruby
def to_markdown
  ReverseMarkdown.convert(body.to_s, github_flavored: true)
end
```

## 2. Respond to markdown in the controller

```ruby
class PostsController < ApplicationController
  def show
    @post = Post.find_by!(slug: params[:slug])

    respond_to do |format|
      format.html
      format.md { render markdown: @post }
    end
  end
end
```

`render markdown:` calls `to_markdown` and sends `Content-Type: text/markdown; charset=utf-8`.

## 3. Fix the `*/*` wildcard tie-breaking issue

When `Accept: */*` is sent, HTML wins ties due to MIME registration order. Add this concern so markdown wins when it is the client's explicit top preference:

```ruby
class ApplicationController < ActionController::Base
  before_action :prioritize_markdown_format

  private

  def prioritize_markdown_format
    return unless request.accepts.first&.to_s == 'text/markdown'
    request.formats = [:md, :html]
  end
end
```

## 4. Verify

```bash
curl -sI -H "Accept: text/markdown" https://yoursite.com/posts/hello
# Expect: Content-Type: text/markdown; charset=utf-8
# Expect: Vary: Accept
```

## Markdown source options

| Source | Notes |
|---|---|
| Dedicated column | Author-maintained; cleanest |
| Action Text | Use `ReverseMarkdown.convert(body.to_s, github_flavored: true)` |
| Cached field | Regenerated `after_save`; good for computed conversions |

`Vary: Accept` is set automatically by Rails 8+; no manual configuration needed.
