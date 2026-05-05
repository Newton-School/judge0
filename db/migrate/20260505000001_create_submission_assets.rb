class CreateSubmissionAssets < ActiveRecord::Migration[5.2]
  def change
    create_table :submission_assets do |t|
      t.references :submission,
                   foreign_key: { on_delete: :cascade },
                   null: false
      t.string :logical_name,    null: false
      t.string :source_filename
      t.text :data
      t.integer :size_bytes,     null: false
      t.string :error
      t.text :error_detail
      t.timestamps
    end

    add_index :submission_assets, [:submission_id, :logical_name]
  end
end
