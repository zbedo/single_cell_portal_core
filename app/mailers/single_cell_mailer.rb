class SingleCellMailer < ApplicationMailer
  default from: 'no-reply@broadinstitute.org'

  def notify_user_parse_complete(email, title, message)
    @message = message
    mail(to: email, subject: title)
  end

  def notify_user_parse_fail(email, title, error)
    @error = error
    mail(to: email, subject: title)
  end
end
