# test/support/smsapi_stubs.rb
module SmsapiStubs
  def stub_smsapi
    stub_request(:post, "https://api.smsapi.com/sms.do").
      to_return(status: 200, body: reply_body, headers: {})
  end

  private
    def reply_body
      str =<<~JSON
      {
        "count":1,
        "list": [
          {
              "id":"1460969715572091219",       #//message id
              "points":0.16,                    #//price of delivery
              "number":"44123456789",           #//recipient number with country prefix
              "date_sent":1460969712,           #//send date
              "submitted_number":"44123456789", #//phone number in request
              "status":"QUEUE"                  #//message status
          }
        ]
      }
      JSON
      str.strip
    end
end