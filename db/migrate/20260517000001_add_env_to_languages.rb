class AddEnvToLanguages < ActiveRecord::Migration[5.2]
  def change
    add_column :languages, :env, :text
  end
end
