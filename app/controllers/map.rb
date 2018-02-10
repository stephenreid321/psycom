ActivateApp::App.controllers do
    
  get '/map' do    
    if request.xhr?      
      @points = []      
      if params[:accounts]
        @points += Account.all
      end
      if params[:events]
        @points += Event.future
      end        
      if params[:organisations]
        @points += Organisation.all
      end      
      partial :'maps/map', :locals => {:points => @points, :global => params[:global]}
    else
      redirect '/'
    end
  end 
              
end