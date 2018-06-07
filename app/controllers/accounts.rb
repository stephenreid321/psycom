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
      flash[:notice] = "Welcome to #{ENV['SITE_NAME']}!"
      redirect '/'
    else
      flash.now[:notice] = 'We need a few more details to finish creating your account'
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
    @accounts = case scope      
    when 'group'
      group = Group.find(scope_id) || not_found
      membership_required!(group) unless group.public?
      group.members
    when 'conversation'
      conversation = Conversation.find(scope_id) || not_found
      membership_required!(conversation.group) unless conversation.group.public?
      conversation.participants
    when 'organisation'
      organisation = Organisation.find(scope_id) || not_found
      organisation.members
    else
      Account.publicly_accessible
    end 
    @accounts = @accounts.where({:id.in => Affiliation.where(:organisation_id.in => Organisation.where(:name => /#{::Regexp.escape(params[:organisation_name])}/i).pluck(:id)).pluck(:account_id)}) if params[:organisation_name]
    @accounts = @accounts.or(
      {:id.in => AccountTagship.where(:account_tag_id.in => AccountTag.where(:name => /#{::Regexp.escape(params[:q])}/i).pluck(:id)).pluck(:account_id)},
      {:headline => /#{::Regexp.escape(params[:q])}/i},
      {:story => /#{::Regexp.escape(params[:q])}/i}
    ) if params[:q]    
    @accounts = @accounts.or(
      {:name => /#{::Regexp.escape(params[:name])}/i},
      {:name_transliterated => /#{::Regexp.escape(params[:name])}/i}
    ) if params[:name]            
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
    mail.bcc = ENV['HELP_ADDRESS']
    mail.from = "#{current_account.name} <#{current_account.email}>"
    mail.subject = "Message from #{current_account.name} via #{ENV['SITE_NAME']}"
    
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