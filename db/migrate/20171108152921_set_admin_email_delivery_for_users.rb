# set profile option for admin email delivery (opt-in/out for getting emails from administrators)
class SetAdminEmailDeliveryForUsers < Mongoid::Migration
  def self.up
    User.update_all(admin_email_delivery: true)
  end

  def self.down
    User.all.unset(:admin_email_delivery)
  end
end