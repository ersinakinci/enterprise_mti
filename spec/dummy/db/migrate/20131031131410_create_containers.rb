class CreateContainers < ActiveRecord::Migration
  def change
    create_table :containers do |t|
      t.text :content

      t.timestamps
    end
  end
end
