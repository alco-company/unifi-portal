module MailersendApiStubs
  def stub_mailersend_api
    # Stub the Mailersend API calls here
    stub_request(:post, "https://api.mailersend.com/v1/email").
    # with(
    #   body: body,
    #   headers: {
    #   'Accept'=>'*/*',
    #   'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
    #   'Authorization'=>'Bearer',
    #   'Content-Type'=>'application/json',
    #   'User-Agent'=>'Ruby',
    #   'X-Requested-With'=>'XMLHttpRequest'
    #   }).
    to_return(status: 200)    
  end

  private
    def body
    end
end
