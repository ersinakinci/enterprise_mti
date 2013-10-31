class CreateSubthingOnes < ActiveRecord::Migration
  def change
    create_table :subthing_ones do |t|
      t.text :content

      t.timestamps
    end
  end
end
