ActivateApp::App.controllers do
  
  before do
    @environment_variables = {      
      :BASE_URI => 'Base URI of web app (scheme + domain)',
      :DOMAIN => 'Domain of web app',
      :MAIL_DOMAIN => 'Domain from which mails will be sent and received',
            
      :SMTP_ADDRESS => 'Address of SMTP server',
      :SMTP_USERNAME => 'Username of SMTP server',
      :SMTP_PASSWORD => 'Password for SMTP server',      
      :MAILGUN_API_KEY => 'Mailgun API key',
            
      :DRAGONFLY_SECRET => 'Dragonfly secret',
      :SESSION_SECRET => 'Session secret',      
      
      :S3_BUCKET_NAME => 'S3 bucket name',
      :S3_ACCESS_KEY => 'S3 access key',
      :S3_SECRET => 'S3 secret',
      :S3_REGION => 'S3 region',
            
      :AIRBRAKE_HOST => 'Airbrake host (no http://)',
      :AIRBRAKE_API_KEY => 'Airbrake API key',  
                        
      :SITE_NAME => 'Name of site',
      :SITE_NAME_DEFINITE => "Name of site with 'the' if appropriate",
      :SITE_NAME_SHORT => 'Short site name',
      :HELP_ADDRESS => 'Email address for general queries',            
      
      :DEFAULT_TIME_ZONE => 'Default time zone (see dropdown in profile for options, defaults to London)',
      :SANITIZE => ['Sanitize user input'],  
      :GROUP_CREATION_BY_ADMINS_ONLY => ['Only allow admins to create new groups'],
      :LIST_EMAIL_ADDRESSES => ['Enables the \'List email addresses\' link in groups, allowing group members to copy a full list of emails'],                  
      :ACCOUNT_TAGS_PREDEFINED => ['Turns the tagships profile field into a series of checkboxes'],           
      :REPLY_TO_GROUP => ['Sets the reply-to header to the group address'],      
      :GROUP_INDEX_CONVERSATION_LIMIT => 'Shows this many conversations per group on /groups',
      :DMARC_FAIL_DOMAINS => 'Comma-separated list of domains with strict DMARC policies',

      :GOOGLE_MAPS_API_KEY => 'Google Maps API key',
      :GOOGLE_ANALYTICS_TRACKING_ID => 'Google Analytics tracking ID',                        
      :FACEBOOK_KEY => 'Facebook API key',
      :FACEBOOK_SECRET => 'Facebook API secret',
      :GOOGLE_KEY => 'Google API key',
      :GOOGLE_SECRET => 'Google API secret',
                                                                 
      :PRIMARY_COLOR => 'Default #228DFF',
      :PRIMARY_CONTRAST_COLOR => 'Default #FFFFFF',
      :SECONDARY_COLOR => 'Default #228DFF',      
      :GREY_LIGHT_COLOR => 'Default #ECF0F1',
      :GREY_MID_COLOR => 'Default #D6DBDF',
      :DARK_COLOR => 'Default #333333',    
      :DARK_CONTRAST_COLOR => 'Default #228DFF'    
    } 
    
    @fragments = {
      :'head' => 'Extra content for &lt;head&gt;',
      :'footer' => 'Extra content for footer',
      :'navbar' => 'Extra content for the navbar'
    }     
  end
  
  get '/config' do
    site_admins_only!
    erb :'config/vars'
  end
  
  get '/fragments' do
    site_admins_only!
    erb :'config/fragments'
  end
     
  post '/config' do
    site_admins_only!
    @environment_variables.each { |k,v|
      config = Config.find_by(slug: k) || Config.create(slug: k)
      config.update_attribute(:body, params[k])
    }
    flash[:notice] = "Your config vars were updated. You may need to restart the server for your changes to take effect."
    redirect '/config'
  end  
         
  get '/config/create_fragment/:slug' do
    redirect "/admin/edit/Fragment/#{Fragment.create(slug: params[:slug]).id}"
  end
      
end