ActivateApp::App.controllers do
  
  before do
    admins_only!    
    @from = params[:from] ? Date.parse(params[:from]) : 1.week.ago.to_date
    @to =  params[:to] ? Date.parse(params[:to]) : Date.today
  end
  
  get '/analytics' do
    redirect '/analytics/cumulative_totals'
  end

  get '/analytics/cumulative_totals' do      
    @collections = [ConversationPost, Account, Event]
    erb :'analytics/cumulative_totals'
  end
    
  get '/analytics/groups', :provides => [:html, :csv] do
    @header = [
      I18n.t(:group).capitalize,
      %Q{Members at start of period},
      %Q{Members at end of period},
      %Q{Change in group size},
      %Q{Conversations},
      %Q{Conversation posts},
      %Q{Conversation post BCCs},
      %Q{Distinct posters},
      %Q{Fraction of people that posted},        
    ]
    @stats = Group.order(:slug.asc).map { |group|      
      [
        group.name,
        m1 = group.memberships.where(:created_at.lte => @from).count,
        m2 = group.memberships.where(:created_at.lte => @to).count,
        if m1 > 0 and m2 > 0; ((m2-m1).to_f/m1); end,
        group.conversations.where(:created_at.gte => @from).where(:created_at.lte => @to).count,
        group.conversation_posts.where(:created_at.gte => @from).where(:created_at.lte => @to).count,
        b = group.conversation_post_bccs.where(:created_at.gte => @from).where(:created_at.lte => @to).count,
        d = group.conversation_posts.where(:created_at.gte => @from).where(:created_at.lte => @to).pluck(:account_id).uniq.count,
        if m2 > 0; (d.to_f/m2); end
      ]      
    }   
    case content_type
    when :html    
      @active = 'Groups'
      @csv = true
      erb :'analytics/stats'
    when :csv
      CSV.generate do |csv|
        csv << @header
        @stats.each { |row| csv << row }
      end    
    end
  end
  
  get '/analytics/organisations', :provides => [:html, :csv] do
    @header = [
      I18n.t(:organisation).capitalize,
      %Q{Members at start of period},
      %Q{Members at end of period},
      %Q{Change in organisation size},
      %Q{Conversations},
      %Q{Conversation posts},
      %Q{Distinct posters},
      %Q{Fraction of people that posted}            
    ]
    @stats = Organisation.order(:name.asc).map { |organisation|
      [
        organisation.name,
        m1 = organisation.affiliations.where(:created_at.lte => @from).count,
        m2 = organisation.affiliations.where(:created_at.lte => @to).count,
        if m1 > 0 and m2 > 0; ((m2-m1).to_f/m1); end,
        organisation.conversations.where(:created_at.gte => @from).where(:created_at.lte => @to).count,
        organisation.conversation_posts.where(:created_at.gte => @from).where(:created_at.lte => @to).count,
        d = organisation.conversation_posts.where(:created_at.gte => @from).where(:created_at.lte => @to).pluck(:account_id).uniq.count,
        if m2 > 0; (d.to_f/m2); end
      ]
    }
    case content_type
    when :html    
      @active = 'Organisations'
      @csv = true
      erb :'analytics/stats'
    when :csv
      CSV.generate do |csv|
        csv << @header
        @stats.each { |row| csv << row }
      end    
    end    
  end  
  
end