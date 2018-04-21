ActivateApp::App.controllers do
  
  get '/organisations' do
    erb :'organisations/organisations'
  end
    
  get '/organisations/results' do
    @o = (params[:o] ? params[:o] : 'date').to_sym
    @organisations = Organisation.all
    @q = []
    @organisations = @organisations.and(@q)
    @organisations = @organisations.where(:name => /#{::Regexp.escape(params[:name])}/i) if params[:name]    
    @organisations = @organisations.where(:organisation_type => params[:organisation_type]) if params[:organisation_type]
    @organisations = @organisations.where(:id.in => Affiliation.pluck(:organisation_id)) if params[:with_affiliations]
    @organisations = case @o
    when :name
      @organisations.order_by(:name.asc)
    when :date
      @organisations.order_by(:updated_at.desc)
    end      
    @organisations = @organisations.per_page(10).page(params[:page])
    partial :'organisations/results'    
  end  
  
  get '/organisations/merge' do
    erb :'organisations/merge'
  end
  
  post '/organisations/merge' do
    org1 = Organisation.find(params[:org1]) || not_found
    org2 = Organisation.find(params[:org2]) || not_found
    Event.where(organisation_id: org1.id).set(organisation_id: org2.id)
    Affiliation.where(organisation_id: org1.id).set(organisation_id: org2.id)
    org1.destroy
    redirect back
  end
  
  get '/organisations/new' do
    sign_in_required!
    @organisation = Organisation.new
    erb :'organisations/build'
  end
  
  post '/organisations/new' do
    sign_in_required!
    @organisation = Organisation.new(params[:organisation])
    if @organisation.save
      flash[:notice] = "<strong>Great!</strong> The organisation was created successfully."
      redirect "/organisations/#{@organisation.id}"
    else
      flash.now[:error] = "<strong>Oops.</strong> Some errors prevented the organisation from being saved."
      erb :'organisations/build'
    end
  end
  
  get '/organisations/:id' do
    redirect "/o/#{params[:id]}"
  end
  
  get '/o/:username' do
    @organisation = Organisation.find_by(username: params[:username])
    if !@organisation
      @organisation = Organisation.find(params[:username]) || not_found
    end
    @title = @organisation.name
    erb :'organisations/organisation'
  end
       
  get '/organisations/:id/edit' do
    sign_in_required!
    @organisation = Organisation.find(params[:id]) || not_found
    erb :'organisations/build'
  end
  
  post '/organisations/:id/edit' do
    sign_in_required!
    @organisation = Organisation.find(params[:id]) || not_found
    if @organisation.update_attributes(params[:organisation])      
      flash[:notice] = "<strong>Great!</strong> The organisation was updated successfully."
      redirect "/organisations/#{@organisation.id}"
    else
      flash.now[:error] = "<strong>Oops.</strong> Some errors prevented the organisation from being saved."
      erb :'organisations/build'
    end
  end  
  
  get '/organisations/:id/destroy' do
    admins_only!
    @organisation = Organisation.find(params[:id]) || not_found
    @organisation.destroy    
    redirect '/organisations'
  end   
  
end