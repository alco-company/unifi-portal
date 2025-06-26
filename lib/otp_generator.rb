module OtpGenerator
  def self.generate_otp
    SecureRandom.random_number(10**6).to_s.rjust(6, "0")
  end
end
