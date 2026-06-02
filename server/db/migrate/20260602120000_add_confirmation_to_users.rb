class AddConfirmationToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :confirmed_at, :datetime
    add_column :users, :terms_accepted_at, :datetime

    # Grandfather existing users: they already proved inbox ownership through
    # the magic-link sign-in, so treat them as confirmed as of their creation.
    # Without this they'd be locked out the moment confirmation gating lands.
    execute "UPDATE users SET confirmed_at = created_at WHERE confirmed_at IS NULL"
  end

  def down
    remove_column :users, :terms_accepted_at
    remove_column :users, :confirmed_at
  end
end
