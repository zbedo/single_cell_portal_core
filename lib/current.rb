# module to access Devise current_user object outside of ActionControllers
module Current
  thread_mattr_accessor :user
end