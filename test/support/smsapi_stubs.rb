# test/support/smsapi_stubs.rb
module SmsapiStubs
  def stub_smsapi(code="123456")
    stub_request(:post, "https://api.smsapi.com/sms.do").
      with(body: "to=%2B4512345678&message=Din%20engangskode%20er%3A%20#{code}&from=Mortimer&format=json").
      with(headers: { 
        "Accept"=>"*/*", 
        "Accept-Encoding"=>"gzip;q=1.0,deflate;q=0.6,identity;q=0.3", 
        "Authorization"=>"Bearer", 
        "User-Agent"=>"Ruby" 
      }).
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
              "number":"4512345678",           #//recipient number with country prefix
              "date_sent":1460969712,           #//send date
              "submitted_number":"4512345678", #//phone number in request
              "status":"QUEUE"                  #//message status
          }
        ]
      }
      JSON
      str.strip
    end
end
