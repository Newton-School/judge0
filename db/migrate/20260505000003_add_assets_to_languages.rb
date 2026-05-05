class AddAssetsToLanguages < ActiveRecord::Migration[5.2]
  def change
    add_column :languages, :assets, :text
  end
end
