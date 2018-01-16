Padrino.configure_apps do
  set :session_secret, Config['SESSION_SECRET']
end

Padrino.mount('ActivateAdmin::App', :app_file => ActivateAdmin.root('app/app.rb')).to('/admin')
Padrino.mount('Lumen::App', :app_file => Padrino.root('app/app.rb')).to('/')
