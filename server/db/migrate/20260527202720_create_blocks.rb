class CreateBlocks < ActiveRecord::Migration[8.1]
  def change
    create_table :blocks do |t|
      t.references :user, null: false, foreign_key: true
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.string :quadrant, null: false
      t.text :note, null: false, default: ""
      t.boolean :auto, null: false, default: false
      t.string :external_id

      t.timestamps
    end

    add_index :blocks, [:user_id, :starts_at]
    add_index :blocks, [:user_id, :external_id], unique: true
  end
end
