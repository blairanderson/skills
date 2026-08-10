> Source: <https://guides.rubyonrails.org/upgrading_ruby_on_rails.html> (Rails v8.1.2 guide) — extracted verbatim from the official guide.

Upgrading from Rails 8.0 to Rails 8.1
-------------------------------------

For more information on changes made to Rails 8.1 please see the [release notes](https://guides.rubyonrails.org/8_1_release_notes.html).

### The table columns inside `schema.rb` are now sorted alphabetically.

Active Record now alphabetically sorts table columns in `schema.rb` by default, so dumps are consistent across machines and don’t flip-flop with migration order -- meaning fewer noisy diffs. `structure.sql` can still be leveraged to preserve exact column order. [See #53281 for more details on alphabetizing schema changes.](https://github.com/rails/rails/pull/53281)
