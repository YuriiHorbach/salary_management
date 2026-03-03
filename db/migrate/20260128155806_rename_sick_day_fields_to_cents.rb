class RenameSickDayFieldsToCents < ActiveRecord::Migration[8.0]
  def change
    rename_column :sick_days, :pfu_amount, :pfu_amount_cents
    rename_column :sick_days, :enterprise_amount, :enterprise_amount_cents

    change_column :sick_days, :pfu_amount_cents, :integer, default: 0
    change_column :sick_days, :enterprise_amount_cents, :integer, default: 0
  end
end
