
BccSingleJob = Struct.new(:id) do  
  def perform
    ConversationPost.find(id).bcc_single
  end
end

SendWelcomeEmailsJob = Struct.new(:id) do
  def perform
    Group.find(id).send_welcome_emails
  end  
end

