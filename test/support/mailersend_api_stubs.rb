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
    to_return(status: 200, body: "", headers: {})    
  end

  private
    def body
      {
        "from": {"email": "info@mortimer.pro", "name": null},
        "to": [{"email": "alice@example.com"}],
        "subject": "Din OTP-kode til adgang til netværket",
        "html": "\\u003c!DOCTYPE html\\u003e\\r\\n\\u003chtml\\u003e\\r\\n  \\u003chead\\u003e\\r\\n    \\u003cmeta http-equiv=\\\"Content-Type\\\" content=\\\"text/html; charset=utf-8\\\"\\u003e\\r\\n    \\u003cstyle\\u003e\\r\\n      /* Email styles need to be inline */\\r\\n    \\u003c/style\\u003e\\r\\n  \\u003c/head\\u003e\\r\\n\\r\\n  \\u003cbody\\u003e\\r\\n    \\u003c!DOCTYPE html\\u003e\\r\\n\\u003chtml\\u003e\\r\\n  \\u003cbody style=\\\"font-family: sans-serif; background-color: #f9fafb; padding: 2rem;\\\"\\u003e\\r\\n    \\u003cdiv style=\\\"max-width: 600px; margin: auto; background-color: white; padding: 2rem; border-radius: 0.5rem; box-shadow: 0 0 10px rgba(0,0,0,0.05);\\\"\\u003e\\r\\n      \\u003ch1 style=\\\"font-size: 1.5rem; font-weight: bold; color: #111827; margin-bottom: 1rem;\\\"\\u003e\\r\\n        Din OTP-kode til adgang til netværket\\r\\n      \\u003c/h1\\u003e\\r\\n      \\u003cp style=\\\"font-size: 1rem; color: #374151; margin-bottom: 1rem;\\\"\\u003e\\r\\n        Brug følgende kode til at fuldføre dit login:\\r\\n      \\u003c/p\\u003e\\r\\n      \\u003cp style=\\\"font-size: 2rem; font-weight: bold; color: #1f2937; letter-spacing: 0.05em; margin: 1rem 0;\\\"\\u003e\\r\\n        752850\\r\\n      \\u003c/p\\u003e\\r\\n      \\u003cp style=\\\"font-size: 0.875rem; color: #6b7280;\\\"\\u003e\\r\\n        Denne kode udløber snart. Del den venligst ikke med nogen.\\r\\n      \\u003c/p\\u003e\\r\\n    \\u003c/div\\u003e\\r\\n  \\u003c/body\\u003e\\r\\n\\u003c/html\\u003e\\r\\n  \\u003c/body\\u003e\\r\\n\\u003c/html\\u003e\\r\\n",
        "text": "Your OTP is: 752850\\r\\n\\r\\nThis code is valid for the next few minutes. Do not share it with anyone.\\r\\n"
      }
    end
end
