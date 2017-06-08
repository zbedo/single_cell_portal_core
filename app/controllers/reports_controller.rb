class ReportsController < ApplicationController

  before_filter do
    authenticate_user!
    authenticate_reporter
  end

  def index
    
  end

end
