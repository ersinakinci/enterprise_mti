class CreateSuperthings < ActiveRecord::Migration
  def change
    create_table :superthings do |t|
      t.text :content

      t.timestamps
    end
  end
end
