class EmailReceiver < Incoming::Strategies::Mailgun
	setup :api_key => Config['MAILGUN_API_KEY']
  def receive(mail)  	            
    return mail
  end
end