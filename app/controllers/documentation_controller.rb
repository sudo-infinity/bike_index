class DocumentationController < ApplicationController
  layout 'documentation'
  caches_page :api_v1
  
  def index
    redirect_to controller: :documentation, action: :api_v1
  end

  def api_v1
    @root = ENV['BASE_URL']
  end

  def api_v2
    if current_user.present?
      @applications = current_user.oauth_applications
    else
      cookies[:return_to] = api_v2_documentation_index_url
    end
    render layout: false
  end

  def o2c
    render layout: false
  end

end