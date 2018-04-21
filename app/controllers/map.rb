ActivateApp::App.controllers do
    
  get '/map' do    
    if request.xhr?      
      @points = []      
      if params[:accounts]
        @points += Account.publicly_accessible
      end
      if params[:events]
        @points += Event.future
      end        
      if params[:organisations]
        if params[:organisation_types]
          params[:organisation_types].keys.each { |t|
            @points += Organisation.where(organisation_type: t)
          }
        else
          @points += Organisation.all
        end
      end  
      if params[:groups]
        @points += Group.where(:privacy.ne => 'secret').where(:unlisted.ne => true)
      end          
      partial :'maps/map', :locals => {:points => @points, :global => params[:global]}
    else
      redirect '/'
    end
  end 
              
end