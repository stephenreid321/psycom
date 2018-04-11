ActivateApp::App.controllers do
    
  post '/groups/:slug/inbound' do    
    group = Group.find_by(slug: params[:slug]) || (halt 406)
		mail = EmailReceiver.receive(request)
    
    (halt 406) unless mail.from
    from = mail.from.first
    
    puts "message from #{from}"            
    (halt 406) if mail.sender == group.email('-noreply') # check this isn't a message sent by the app
                                   
    # skip messages from people that aren't in the group
    account = Account.find_by(email: /^#{::Regexp.escape(from)}$/i)     
    if !account or !account.memberships.find_by(:group => group, :status => 'confirmed', :muted.ne => true)
      begin
        mail = Mail.new(
          :to => from,
          :bcc => ENV['HELP_ADDRESS'],
          :from => "#{group.slug} <#{group.email('-noreply')}>",
          :subject => "Delivery failed: #{mail.subject}",
          :body => ERB.new(File.read(Padrino.root('app/views/emails/delivery_failed.erb'))).result(binding)
        )
        mail.deliver
      rescue => e
        Airbrake.notify(e)
      end
        
      puts "this message was sent by a stranger"
      (halt 406)
    end    
    
    if mail.html_part
      body = mail.html_part.body
      charset = mail.html_part.charset
      nl2br = false
    elsif mail.text_part                
      body = mail.text_part.body
      charset = mail.text_part.charset
      nl2br = true
    else
      body = mail.body
      charset = mail.charset
      nl2br = true
    end                            
              
    html = begin; body.decoded.force_encoding(charset).encode('UTF-8'); rescue; body.to_s; end
    html = html.gsub("\n", "<br>\n") if nl2br
    html = html.gsub(/<o:p>/, '')
    html = html.gsub(/<\/o:p>/, '') 
    
    begin
      html = Premailer.new(html, :with_html_string => true, :adapter => 'nokogiri', :input_encoding => 'UTF-8').to_inline_css
    rescue => e
      Airbrake.notify(e)
    end    

    if (
        (mail.in_reply_to and (conversation = ConversationPostBcc.find_by(message_id: mail.in_reply_to).try(:conversation)) and conversation.group == group) or
          (
          html.match(/Respond\s+by\s+replying\s+above\s+this\s+line/) and
            (conversation_url_match = html.match(/#{ENV['BASE_URI']}\/conversations\/(\d+)/)) and
            conversation = group.conversations.find_by(slug: conversation_url_match[-1])
        )
      )
      new_conversation = false
      puts "part of conversation id #{conversation.id}"
      [/Respond\s+by\s+replying\s+above\s+this\s+line/, /On.+, .+ wrote:/, /<span.*>From:<\/span>/, '___________','<hr id="stopSpelling">'].each { |pattern|
        html = html.split(pattern).first
      }
    else      
      new_conversation = true
      conversation = group.conversations.create :subject => (mail.subject.blank? ? '(no subject)' : mail.subject), :account => account
      (halt 406) if !conversation.persisted? # failed to find/create a valid conversation - probably a dupe
      puts "created new conversation id #{conversation.id}"
    end 
      
    html = Nokogiri::HTML.parse(html)
    html.search('style').remove
    # html.search('.gmail_extra').remove
    html = html.search('body').inner_html
         
    conversation_post = conversation.conversation_posts.create :body => html, :account => account, :message_id => (mail.message_id or "#{SecureRandom.uuid}@#{ENV['DOMAIN']}")
        
    if !conversation_post.persisted? # failed to create the conversation post
      puts "failed to create conversation post, deleting conversation"
      conversation.destroy if new_conversation
      (halt 406)
    end
    puts "created conversation post id #{conversation_post.id}"
    
    begin
      raise 'mail'
    rescue => e
      Airbrake.notify(e, :parameters => {:data => mail.attachments.map { |attachment| [attachment.filename, attachment.cid] } })
    end      
    
    mail.attachments.each do |attachment|
      file = Tempfile.new(attachment.filename)
      begin
        file.binmode
        file.write(attachment.body)
        file.original_filename = attachment.filename
        conversation_post.attachments.create :file => file, :file_name => attachment.filename, :cid => attachment.cid
      ensure
        file.close
        file.unlink
      end      
    end         
    puts "sending notifications"
    conversation_post.send_notifications!

  end 
  
end