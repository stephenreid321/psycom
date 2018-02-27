module ActivateApp
  class App < Padrino::Application
    
    set :sessions, :expire_after => 1.year    

    require 'sass/plugin/rack'
    Sass::Plugin.options[:template_location] = Padrino.root('app', 'assets', 'stylesheets')
    Sass::Plugin.options[:css_location] = Padrino.root('app', 'assets', 'stylesheets')
    use Sass::Plugin::Rack
    
    register Padrino::Rendering
    register Padrino::Helpers
    register WillPaginate::Sinatra
    helpers Activate::DatetimeHelpers
    helpers Activate::ParamHelpers  
    helpers Activate::NavigationHelpers
    
    use Dragonfly::Middleware
    use Airbrake::Rack::Middleware
    use OmniAuth::Builder do
      provider :account
      Provider.registered.each { |provider|
        provider provider.omniauth_name, ENV["#{provider.display_name.upcase}_KEY"], ENV["#{provider.display_name.upcase}_SECRET"], {provider_ignores_state: true}
      }
    end  
    OmniAuth.config.on_failure = Proc.new { |env|
      OmniAuth::FailureEndpoint.new(env).redirect_to_failure
    }    
    
    set :public_folder, Padrino.root('app', 'assets')
    set :default_builder, 'ActivateFormBuilder'    
    
    Mail.defaults do
      delivery_method :smtp, {
        :user_name => ENV['SMTP_USERNAME'],
        :password => ENV['SMTP_PASSWORD'],
        :address => ENV['SMTP_ADDRESS'],
        :port => 587
      }   
    end     
                      
    before do
      redirect "#{ENV['BASE_URI']}#{request.path}" if ENV['BASE_URI'] and "#{request.scheme}://#{request.env['HTTP_HOST']}" != ENV['BASE_URI']
      Time.zone = (current_account and current_account.time_zone) ? current_account.time_zone : (ENV['DEFAULT_TIME_ZONE'] || 'London')
      I18n.locale = (current_account and current_account.language) ? current_account.language.code : Language.default.code      
      fix_params!
      @_params = params; def params; @_params; end # force controllers to inherit the fixed params
      if params[:token] and account = Account.find_by(secret_token: params[:token])
        session[:account_id] = account.id.to_s
      end
    end     
     
    error do
      Airbrake.notify(env['sinatra.error'], :session => session)
      erb :error
    end 
               
    not_found do
      erb :not_found
    end
        
    ############
    
    get '/' do    
      erb :home
    end
                                   
    get '/:slug' do
      if @fragment = Fragment.find_by(slug: params[:slug], page: true)
        sign_in_required! unless @fragment.public?
        erb :page
      elsif @account = Account.find_by(username: params[:slug]) or @account = Account.find(params[:slug])
        if !@account.public?
          unless current_account and (current_account.id == @account.id or current_account.admin?)
            flash[:notice] = "You can't access that profile."
            session[:return_to] = request.url
            request.xhr? ? halt(403) : redirect((current_account ? '/' : '/sign_in'))
          end         
        end
        @title = @account.name
        @shared_conversations = current_account.visible_conversation_posts.where(account_id: @account.id).order_by(:created_at.desc).limit(10).map(&:conversation).uniq if current_account
        erb :'accounts/account'
      else
        pass
      end
    end     
                             
  end
end