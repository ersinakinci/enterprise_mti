class CreateSubthingTwos < ActiveRecord::Migration
  def change
    create_table :subthing_twos do |t|
      t.text :content

      t.timestamps
    end
  end
end
