module ApplicationHelper
  def query_param
    session[:query] || @query || ""
  end
end
