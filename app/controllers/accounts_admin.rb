ActivateApp::App.controllers do
   
  get '/accounts/new' do
    site_admins_only!
    @account = Account.new
    @account.welcome_email_subject = "You were added to #{Config['SITE_NAME_DEFINITE']}"
    @account.welcome_email_body = %Q{Hi [firstname],
<br /><br />
You were added to the groups [group_list] on #{Config['SITE_NAME_DEFINITE']}.
<br /><br />
[sign_in_details]}
    erb :'accounts/build_admin'      
  end  
    
  post '/accounts/new' do
    site_admins_only!
    @account = Account.new(mass_assigning(params[:account], Account))
    password = Account.generate_password(8)
    @account.password = password
    if @account.save
      flash[:notice] = 'The account was created successfully'              
      redirect back
    else
      flash.now[:error] = 'Some errors prevented the account from being saved'
      erb :'accounts/build_admin'      
    end
  end
    
  get '/accounts/:id/edit' do
    site_admins_only!
    @account = Account.find(params[:id])
    @account.welcome_email_subject = "You were added to groups on #{Config['SITE_NAME_DEFINITE']}"
    @account.welcome_email_body = %Q{Hi [firstname],
<br /><br />
You were added to the groups [group_list] on #{Config['SITE_NAME_DEFINITE']}.
<br /><br />
[sign_in_details]}    
    erb :'accounts/build_admin'
  end
  
  post '/accounts/:id/edit' do
    site_admins_only!
    @account = Account.find(params[:id])
    if @account.update_attributes(mass_assigning(params[:account], Account))
      flash[:notice] = "<strong>Great!</strong> The account was updated successfully."
      redirect back
    else
      flash.now[:error] = "<strong>Oops.</strong> Some errors prevented the account from being saved."
      erb :'accounts/build_admin'
    end    
  end
  
end