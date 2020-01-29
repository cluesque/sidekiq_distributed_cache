class CreateDoohickeys < ActiveRecord::Migration[5.2]
  def change
    create_table :doohickeys do |t|
      t.string :name
      t.integer :number

      t.timestamps
    end
  end
end
