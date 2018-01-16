
SendWelcomeEmailsJob = Struct.new(:id) do
  def perform
    Group.find(id).send_welcome_emails
  end  
end

