ActivateApp::App.controllers do
    
  get '/events' do    
    case params[:view]
    when 'calendar'
      erb :'events/calendar'    
    else
      erb :'events/events'    
    end
  end
  
  get '/events/ical' do
    sign_in_required!
    Event.ical
  end
        
  get '/events/feed' do
    sign_in_required!
    Event.json(params[:start], params[:end])
  end  
  
  get '/events/new' do
    sign_in_required!
    @title = 'Add an event'
    @event = Event.new
    erb :'events/build'
  end  
          
  post '/events/new' do
    sign_in_required!
    @event = Event.new(params[:event])    
    @event.account = current_account
    if @event.save  
      flash[:notice] = "<strong>Great!</strong> The event was created successfully."
      redirect "/events/#{@event.id}"
    else
      flash.now[:error] = "<strong>Oops.</strong> Some errors prevented the event from being saved."
      erb :'events/build'
    end
  end   
  
  get '/events/:id/edit' do
    sign_in_required!
    @event = Event.find(params[:id]) || not_found
    erb :'events/build'
  end     
      
  post '/events/:id/edit' do
    sign_in_required!
    @event = Event.find(params[:id]) || not_found
    if @event.update_attributes(params[:event])
      flash[:notice] = "<strong>Great!</strong> The event was updated successfully."
      redirect "/events/#{@event.id}"
    else
      flash.now[:error] = "<strong>Oops.</strong> Some errors prevented the event from being saved."
      erb :'events/build'
    end
  end 
  
  get '/events/:id/destroy' do
    sign_in_required!
    @event = Event.find(params[:id]) || not_found
    @event.destroy    
    redirect "/events/"
  end 
  
  get '/events/:id' do
    @event = Event.find(params[:id]) || not_found
    @title = @event.name
    erb :'events/event'
  end  
  
  get '/events/:id/minimal' do
    @event = Event.find(params[:id]) || not_found
    partial :'events/minimal', :locals => {:event => @event, :read_more => true}
  end    
  
end