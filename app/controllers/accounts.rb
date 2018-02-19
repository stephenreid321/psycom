ActivateApp::App.controllers do
  
  get '/sign_up' do
    @account = Account.new
    erb :'accounts/build'
  end  
  
  post '/sign_up' do
    @account = Account.new(params[:account])
    if @account.save
      SignIn.create(account: @account)
      session[:account_id] = @account.id.to_s     
      flash[:notice] = "Welcome to #{Config['SITE_NAME']}!"
      redirect '/me'
    else
      flash.now[:error] = 'Some errors prevented the account from being saved'
      erb :'accounts/build'
    end
  end  
  
  get '/people' do      
    erb :'accounts/people'
  end      
               
  get '/accounts/results' do
    scope = params[:scope]
    scope_id = params[:scope_id]
    @o = (params[:o] ? params[:o] : 'date').to_sym
    @name = params[:name]    
    @organisation_name = params[:organisation_name]
    @account_tag_name = params[:account_tag_name]
    @accounts = case scope      
    when 'group'
      group = Group.find(scope_id)
      membership_required!(group) unless group.public?
      group.members
    when 'conversation'
      conversation = Conversation.find(scope_id)
      membership_required!(conversation.group) unless conversation.group.public?
      conversation.participants
    when 'organisation'
      organisation = Organisation.find(scope_id)
      organisation.members
    else
      Account.all
    end 
    @accounts = @accounts.publicly_accessible
    @q = []    
    @q << {:id.in => Affiliation.where(:organisation_id.in => Organisation.where(:name => /#{::Regexp.escape(@organisation_name)}/i).pluck(:id)).pluck(:account_id)} if @organisation_name
    @q << {:id.in => AccountTagship.where(:account_tag_id.in => AccountTag.where(:name => /#{::Regexp.escape(@account_tag_name)}/i).pluck(:id)).pluck(:account_id)} if @account_tag_name    
    @accounts = @accounts.and(@q)    
    @accounts = @accounts.or({:name => /#{::Regexp.escape(@name)}/i}, {:name_transliterated => /#{::Regexp.escape(@name)}/i}) if @name            
    @accounts = case @o
    when :name
      @accounts.order_by(:name.asc)
    when :date
      @accounts.order_by(:created_at.desc)
    when :updated
      @accounts.order_by([:has_picture.desc, :updated_at.desc])
    end      
    @accounts = @accounts.per_page(params[:per_page] || 8).page(params[:page])
    partial :'accounts/results', locals: {full_width: params[:full_width]}
  end  
  
 get '/accounts/:id/message' do
    sign_in_required!
    @account = Account.find(params[:id]) || not_found
    if @account.unsubscribe_message
      flash[:error] = "That person has opted out of receiving messages"
      redirect back      
    end
    erb :'accounts/message'    
  end
  
  post '/accounts/:id/message' do
    sign_in_required!
    @account = Account.find(params[:id]) || not_found
    if @account.unsubscribe_message
      flash[:error] = "That person has opted out of receiving messages"
      redirect back      
    end
    
    mail = Mail.new
    mail.to = @account.email
    mail.bcc = Config['HELP_ADDRESS']
    mail.from = "#{current_account.name} <#{current_account.email}>"
    mail.subject = "Message from #{current_account.name} via #{Config['SITE_NAME']}"
    
    sender = current_account
    receiver = @account
    message = params[:message]    
    content = ERB.new(File.read(Padrino.root('app/views/emails/message.erb'))).result(binding)
    html_part = Mail::Part.new do
      content_type 'text/html; charset=UTF-8'
      body ERB.new(File.read(Padrino.root('app/views/layouts/email.erb'))).result(binding)     
    end

    mail.html_part = html_part      
    mail.deliver
    
    flash[:notice] = 'The message was sent.'
    redirect "/#{@account.username_or_id}"            
  end  
              
end