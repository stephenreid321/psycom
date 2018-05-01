class Group    
  include Mongoid::Document
  include Mongoid::Timestamps
  extend Dragonfly::Model
  
  index({coordinates: "2dsphere"})
     
  field :name, :type => String  
  field :slug, :type => String
  field :location, :type => String
  field :coordinates, :type => Array  
  field :primary, :type => Boolean
  field :description, :type => String
  field :privacy, :type => String
  field :unlisted, :type => Boolean
  field :default_notification_level, :type => String
  field :request_intro, :type => String  
  field :request_questions, :type => String
  field :landing_tab, :type => String
  field :picture_uid, :type => String 
  field :conversation_creation_by_admins_only, :type => Boolean
  
  include Geocoder::Model::Mongoid
  geocoded_by :location  
  def lat; coordinates[1] if coordinates; end  
  def lng; coordinates[0] if coordinates; end  
  after_validation do
    self.geocode || (self.coordinates = nil)
  end  
  
  def self.marker_color
    '54e645'
  end
        
  dragonfly_accessor :picture do
    after_assign { |picture| self.picture = picture.thumb('500x500>') }
  end  
    
  field :reminder_email_subject, :type => String
  def reminder_email_subject_default
    "A reminder to complete your profile on [site_name]"
  end
  field :reminder_email, :type => String
  def reminder_email_default
    %Q{Hi [firstname],
   <br /><br />
[admin] noticed that you haven't yet [issue] on [site_name].
<br /><br />
Well-maintained profiles help build a stronger community. Will you spare a minute to provide the missing details?
<br /><br />
You can sign in at [base_uri]/sign_in.}
  end
    
  field :invite_email_subject, :type => String
  def invite_email_subject_default
    "You were added to the group [group_name] ([group_email]) on [site_name]"
  end
  field :invite_email, :type => String
  def invite_email_default
    %Q{Hi [firstname],
<br /><br />
[admin] added you to the group [group_name] ([group_email]) on [site_name].
<br /><br />
[sign_in_details]}
  end
  
  field :membership_request_thanks_email_subject, :type => String
  def membership_request_thanks_email_subject_default
    "Thanks for requesting membership of [group_name] ([group_email]) on [site_name]"
  end
  field :membership_request_thanks_email, :type => String
  def membership_request_thanks_email_default
    %Q{Hi [firstname],
<br /><br />
Thanks for requesting membership of the group [group_name] ([group_email]) on [site_name].
<br /><br />
The group administrators have been notified and will process your request shortly.}
  end
  
  field :membership_request_acceptance_email_subject, :type => String
  def membership_request_acceptance_email_subject_default
    "You're now a member of [group_name] ([group_email]) on [site_name]"
  end
  field :membership_request_acceptance_email, :type => String
  def membership_request_acceptance_email_default
    %Q{Hi [firstname],
<br /><br />
You have been granted membership of the group [group_name] ([group_email]) on [site_name].
<br /><br />
[sign_in_details]}        
  end
  
  def prepare_email_subject(e)
    self.send("#{e}_email_subject")
    .gsub('[site_name]',ENV['SITE_NAME'])
    .gsub('[base_uri]',ENV['BASE_URI'])
    .gsub('[group_name]',self.name)
    .gsub('[group_email]',self.email)
  end  
  
  def prepare_email(e)
    self.send("#{e}_email")
    .gsub('[site_name]',ENV['SITE_NAME'])
    .gsub('[base_uri]',ENV['BASE_URI'])
    .gsub('[group_name]',self.name)
    .gsub('[group_email]',self.email)
  end   
  
  before_validation do
    %w{reminder invite membership_request_acceptance membership_request_thanks}.each { |e|
      self.send("#{e}_email=",self.send("#{e}_email_default")) if Nokogiri::HTML(self.send("#{e}_email")).text.blank?
      self.send("#{e}_email_subject=",self.send("#{e}_email_subject_default")) if Nokogiri::HTML(self.send("#{e}_email_subject")).text.blank?
    }
    self.unlisted = nil if self.public?
    self.default_notification_level = 'each' if !self.default_notification_level
  end
    
  index({slug: 1 }, {unique: true})
  
  validates_presence_of :name, :slug, :privacy
  validates_uniqueness_of :name, :slug
  validates_uniqueness_of :primary, :if => -> { self.primary }
  validates_format_of :slug, :with => /\A[a-z0-9\-]+\z/  
  
  def email(suffix = '')
    "#{self.slug}#{suffix}@#{ENV['MAIL_DOMAIN']}"
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
  
  belongs_to :group_type, index: true, optional: true
  belongs_to :account, index: true, optional: true
        
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
      :location => :text,
      :primary => :check_box,
      :description => :text_area,
      :picture => :image,
      :privacy => :radio,
      :unlisted => :check_box,
      :default_notification_level => :text,
      :request_intro => :text_area,      
      :request_questions => :text_area,
      :reminder_email => :text_area,
      :invite_email => :text_area,
      :membership_request_thanks_email => :text_area,
      :membership_request_acceptance_email => :text_area,
      :conversation_creation_by_admins_only => :check_box,
      :group_type_id => :lookup,      
      :account_id => :lookup,
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
      :invite_email_subject => 'Replacements: [site_name] [base_uri] [group_name] [group_email]',
      :invite_email => 'HTML. Replacements: [site_name] [base_uri] [group_name] [group_email] [firstname] [admin] [sign_in_details]',
      :reminder_email_subject => 'Replacements: [site_name] [base_uri] [group_name] [group_email]',
      :reminder_email => 'HTML. Replacements: [site_name] [base_uri] [group_name] [group_email] [firstname] [admin] [issue]',
      :membership_request_thanks_email_subject => 'Replacements: [site_name] [base_uri] [group_name] [group_email]',
      :membership_request_thanks_email => 'HTML. Replacements: [site_name] [base_uri] [group_name] [group_email] [firstname]',
      :membership_request_acceptance_email_subject => 'Replacements: [site_name] [base_uri] [group_name] [group_email]',
      :membership_request_acceptance_email => 'HTML. Replacements: [site_name] [base_uri] [group_name] [group_email] [firstname] [sign_in_details]'
    }
  end
  
  def self.edit_tips
    self.new_tips
  end
      
  def self.privacies
    p = {}
    p['Public: group content is public and anyone can choose to join'] = 'public'
    p['Closed: people must request membership'] = 'closed'
    p['Secret: group is hidden and people can only join via invitation'] = 'secret'      
    p
  end
  
  def public?
    privacy == 'public'
  end  
    
  def closed?
    privacy == 'closed'
  end
  
  def secret?
    privacy == 'secret'
  end
                     
  def send_welcome_emails
    memberships.where(:welcome_email_pending => true).each { |membership|
      begin
        membership.send_welcome_email
      rescue => e
        Airbrake.notify(e)
      end
    }
  end
  handle_asynchronously :send_welcome_emails
  
  def nearby_accounts(d=25)
    Account.where(:coordinates => { "$geoWithin" => { "$centerSphere" => [coordinates, d / 3963.1676 ]}})
  end  
  
  after_create :send_admin_notification
  def send_admin_notification
    mail = Mail.new
    mail.to = ENV['HELP_ADDRESS']
    mail.from = "#{ENV['SITE_NAME']} <#{ENV['HELP_ADDRESS']}>"
    mail.subject = "New group: #{self.name}"
      
    group = self
    base_uri = ENV['BASE_URI']
    html_part = Mail::Part.new do
      content_type 'text/html; charset=UTF-8'
      body %Q{#{group.account.name} (#{group.account.email}) created a new group: <a href="#{base_uri}/groups/#{group.slug}">#{group.name}</a>}
    end
    mail.html_part = html_part
      
    mail.deliver
  end
  handle_asynchronously :send_admin_notification 
  
  after_create :send_notification
  def send_notification
    return unless coordinates
    return unless public? or (closed? and !unlisted)
    group = self
    bcc = nearby_accounts.where(:unsubscribe_groups.ne => true).pluck(:email)
    if bcc.count > 0      
      mail = Mail.new
      mail.bcc = bcc
      mail.from = "#{ENV['SITE_NAME']} <#{ENV['HELP_ADDRESS']}>"
      mail.subject = 'New group near you'
            
      content = ERB.new(File.read(Padrino.root('app/views/emails/group.erb'))).result(binding)
      html_part = Mail::Part.new do
        content_type 'text/html; charset=UTF-8'
        body ERB.new(File.read(Padrino.root('app/views/layouts/email.erb'))).result(binding)     
      end
      mail.html_part = html_part
      
      mail.deliver
    end
    update_attribute(:sent_notification, true)
  end
  handle_asynchronously :send_notification   
        
end
