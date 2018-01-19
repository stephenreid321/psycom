class Group    
  include Mongoid::Document
  include Mongoid::Timestamps
  extend Dragonfly::Model
  
  field :name, :type => String  
  field :slug, :type => String
  field :primary, :type => Boolean
  field :allow_external_membership_requests, :type => Boolean
  field :description, :type => String
  field :privacy, :type => String
  field :default_notification_level, :type => String, :default => 'each'
  field :request_intro, :type => String  
  field :request_questions, :type => String
  field :landing_tab, :type => String
  field :picture_uid, :type => String 
  field :coordinates, :type => Array
  field :hide_from_dropdown, :type => Boolean
  field :conversation_creation_by_admins_only, :type => Boolean
  field :join_on_first_sign_in, :type => Boolean
        
  dragonfly_accessor :picture do
    after_assign { |picture| self.picture = picture.thumb('500x500>') }
  end  
    
  field :reminder_email_subject, :type => String, :default => -> { "A reminder to complete your profile on #{Config['SITE_NAME_SHORT']}" }
  field :reminder_email, :type => String, :default => -> {
    %Q{Hi [firstname],
   <br /><br />
[admin] noticed that you haven't yet [issue] on #{Config['SITE_NAME_DEFINITE']}.
<br /><br />
Well-maintained profiles help build a stronger community. Will you spare a minute to provide the missing details?
<br /><br />
You can sign in at #{Config['BASE_URI']}/sign_in.}
  }
    
  field :invite_email_subject, :type => String, :default => -> { "You were added to the group #{self.name} (#{self.email}) on #{Config['SITE_NAME_SHORT']}" }
  field :invite_email, :type => String, :default => -> { 
    %Q{Hi [firstname],
<br /><br />
[admin] added you to the group #{self.name} (#{self.email}) on #{Config['SITE_NAME_DEFINITE']}.
<br /><br />
[sign_in_details]}
  }    
  
  field :membership_request_thanks_email_subject, :type => String, :default => -> { "Thanks for requesting membership of #{self.name} (#{self.email}) on #{Config['SITE_NAME_SHORT']}" }
  field :membership_request_thanks_email, :type => String, :default => -> {
    %Q{Hi [firstname],
<br /><br />
Thanks for requesting membership of the group #{self.name} (#{self.email}) on #{Config['SITE_NAME_DEFINITE']}.
<br /><br />
The group administrators have been notified and will process your request shortly.}
  }
  
  field :membership_request_acceptance_email_subject, :type => String, :default => -> { "You're now a member of #{self.name} (#{self.email}) on #{Config['SITE_NAME_SHORT']}" }
  field :membership_request_acceptance_email, :type => String, :default => -> {
    %Q{Hi [firstname],
<br /><br />
You have been granted membership of the group #{self.name} (#{self.email}) on #{Config['SITE_NAME_DEFINITE']}.
<br /><br />
[sign_in_details]}
  }
    
  index({slug: 1 }, {unique: true})
  
  validates_presence_of :name, :slug, :privacy
  validates_uniqueness_of :name, :slug
  validates_uniqueness_of :primary, :if => -> { self.primary }
  validates_format_of :slug, :with => /\A[a-z0-9\-]+\z/  
  
  def email(suffix = '')
    "#{self.slug}#{suffix}@#{Config['MAIL_DOMAIN']}"
  end
                 
  def smtp_settings
    {:address => Config['SMTP_ADDRESS'], :user_name => Config['SMTP_USERNAME'], :password => Config['SMTP_PASSWORD'], :port => 587}
  end  
    
  has_many :conversations, :dependent => :destroy
  has_many :conversation_posts, :dependent => :destroy
  has_many :conversation_post_bccs, :dependent => :destroy
  has_many :memberships, :dependent => :destroy
  has_many :membership_requests, :dependent => :destroy
  has_many :didyouknows, :dependent => :destroy
  
  def tags
    conversations.where(subject: /(?:\s|^)(?:#(?!(?:\d+|\w+?_|_\w+?)(?:\s|$)))(\w+)(?=\s|$)/i).map(&:tags).flatten.uniq.sort
  end
  
  def visible_conversations
    conversations.where(:hidden.ne => true)
  end
  
  def visible_conversation_posts
    conversation_posts.where(:hidden.ne => true).where(:conversation_id.in => visible_conversations.pluck(:id))
  end
  
  belongs_to :group_type, index: true
        
  def new_people(from,to)
    Account.where(:id.in => memberships.where(:created_at.gte => from).where(:created_at.lt => to+1).pluck(:account_id)).where(:has_picture => true)
  end
      
  def members
    Account.where(:id.in => memberships.where(:status => 'confirmed').pluck(:account_id))
  end
  
  def people
    members
  end
  
  def admins
    Account.where(:id.in => memberships.where(:admin => true).pluck(:account_id))
  end
  
  def admins_receiving_membership_requests
    Account.where(:id.in => memberships.where(:admin => true, :receive_membership_requests => true).pluck(:account_id))
  end  
    
  def request_questions_a
    q = (request_questions || '').split("\n").map(&:strip) 
    q.empty? ? [] : q
  end

  def self.default_notification_levels
    {'On' => 'each', 'Off' => 'none'}
  end
    
  def default_didyouknows
    [
      %Q{You can <a href="[conversation_url]">view this conversation on the web</a> to learn more about its participants.},
      %Q{You can <a href="[site_url]/groups/[slug]">search past conversations</a> of this group.},
      %Q{#{slug} has <a href="[site_url]/groups/[slug]">[members]</a>.},      
      %Q{The most recent profile update was made by <a href="[most_recently_updated_url]">[most_recently_updated_name]</a>.}
    ]
  end
         
  after_create :create_default_didyouknows
  def create_default_didyouknows
    default_didyouknows.each { |d| didyouknows.create :body => d }
  end
      
  def self.admin_fields
    {
      :name => :text,
      :slug => :text,
      :primary => :check_box,
      :allow_external_membership_requests => :check_box,
      :description => :text_area,
      :picture => :image,
      :privacy => :radio,
      :default_notification_level => :text,
      :request_intro => :text_area,      
      :request_questions => :text_area,
      :reminder_email => :text_area,
      :invite_email => :text_area,
      :membership_request_thanks_email => :text_area,
      :membership_request_acceptance_email => :text_area,
      :group_type_id => :lookup,
      :coordinates => :geopicker,      
      :hide_from_dropdown => :check_box,
      :conversation_creation_by_admins_only => :check_box,
      :join_on_first_sign_in => :check_box,
      :memberships => :collection,
      :membership_requests => :collection,
      :conversations => :collection
    }
  end
  
  def self.new_tips
    {
      :name => 'Full group name, all characters allowed',
      :request_intro => 'HTML to display above request form',
      :request_questions => 'Questions to ask to people requesting membership. One per line.',
      :invite_email => 'HTML. Replacements: [firstname], [admin], [sign_in_details]',
      :reminder_email => 'HTML. Replacements: [firstname], [admin], [issue]',
      :membership_request_thanks_email => 'HTML. Replacements: [firstname]',
      :membership_request_acceptance_email => 'HTML. Replacements: [firstname], [sign_in_details]'
    }
  end
  
  def self.edit_tips
    self.new_tips
  end
      
  def self.privacies
    p = {}
    p['Public: group content is public and anyone can choose to join'] = 'public'
    p['Open: anyone can choose to join'] = 'open'
    p['Closed: people must request membership'] = 'closed'
    p['Secret: group is hidden and people can only join via invitation'] = 'secret'      
    p
  end
  
  def public?
    privacy == 'public'
  end  
  
  def open?
    privacy == 'open'
  end
  
  def closed?
    privacy == 'closed'
  end
  
  def secret?
    privacy == 'secret'
  end
                     
  def send_welcome_emails
    memberships.where(:welcome_email_pending => true).each(&:send_welcome_email)
  end
  handle_asynchronously :send_welcome_emails
        
end
