module BillingProjectsHelper
  # return a bootstrap class name for color coding of billing project member roles
  def get_billing_member_class(role)
    role == 'Owner' ? 'primary' : 'default'
  end

  # return a formatted label corresponding to a billing project creation status
  def get_project_status_label(status)
    case status
      when 'Creating'
        label_class = 'warning'
      when 'Created'
        label_class = 'success'
      when 'Error'
        label_class = 'danger'
      else
        label_class = 'default'
    end
    "<big><span class='label label-#{label_class}'>#{status}</span></big>".html_safe
  end
end
