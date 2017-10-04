module BillingProjectsHelper
  # return a bootstrap class name for color coding of billing project member roles
  def get_billing_member_class(role)
    role == 'Owner' ? 'primary' : 'default'
  end
end
