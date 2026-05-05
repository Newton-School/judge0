class AddSkipAssetsToSubmissions < ActiveRecord::Migration[5.2]
  def change
    add_column :submissions, :skip_assets, :boolean, default: false, null: false
  end
end
