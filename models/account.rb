class Account
  include Mongoid::Document
  include Mongoid::Timestamps
  extend Dragonfly::Model
  
  index({coordinates: "2dsphere"})
    
  field :name, :type => String
  field :name_transliterated, :type => String
  field :email, :type => String
  field :username, :type => String

  field :location, :type => String
  field :coordinates, :type => Array       
  field :time_zone, :type => String
  field :has_picture, :type => Boolean
  field :picture_uid, :type => String    
  field :headline, :type => String     
  field :story, :type => String
  field :website, :type => String   
  field :facebook_profile_url, :type => String
  field :twitter_profile_url, :type => String  
  
  field :unsubscribe_events, :type => Boolean
  field :unsubscribe_new_member, :type => Boolean
  field :unsubscribe_message, :type => Boolean
  
  field :secret_token, :type => String
  field :crypted_password, :type => String  
  field :password_reset_token, :type => String   
  field :admin, :type => Boolean
  field :translator, :type => Boolean  
  field :prevent_new_memberships, :type => Boolean
  field :root, :type => Boolean
  
  field :gender, :type => String
  field :date_of_birth, :type => Date  
  
  def self.protected_attributes
    %w{secret_token crypted_password password_reset_token admin translator prevent_new_memberships root}
  end  
        
  def self.e(email)
    find_by(email: email)
  end
  
  include Geocoder::Model::Mongoid
  geocoded_by :location
  def lat; coordinates[1] if coordinates; end  
  def lng; coordinates[0] if coordinates; end  
  after_validation do
    self.geocode || (self.coordinates = nil)
  end
  
  has_many :sign_ins, :dependent => :destroy  
  has_many :memberships, :class_name => "Membership", :inverse_of => :account, :dependent => :destroy
  has_many :memberships_added, :class_name => "Membership", :inverse_of => :added_by, :dependent => :nullify
  has_many :membership_requests, :dependent => :destroy  
  has_many :conversation_mutes, :dependent => :destroy
  has_many :conversation_post_bcc_recipients, :dependent => :destroy
  has_many :conversations_as_creator, :class_name => 'Conversation', :dependent => :destroy
  has_many :conversation_posts_as_creator, :class_name => 'ConversationPost', :dependent => :destroy
  has_many :events_as_creator, :class_name => 'Event', :inverse_of => :account, :dependent => :destroy
  has_many :likes, :dependent => :destroy
  
  belongs_to :language, index: true, optional: true
  
  has_many :affiliations, :dependent => :destroy
  accepts_nested_attributes_for :affiliations, allow_destroy: true, reject_if: :all_blank
  
  has_many :account_tagships, :dependent => :destroy
  accepts_nested_attributes_for :account_tagships, allow_destroy: true, reject_if: :all_blank
      
  attr_accessor :account_tag_ids
  before_validation :create_account_tags
  def create_account_tags
    if @account_tag_ids
      current_account_tag_ids = account_tagships.map(&:account_tag_id).map(&:to_s)
      tags_to_remove = current_account_tag_ids - @account_tag_ids
      tags_to_add = @account_tag_ids - current_account_tag_ids
      tags_to_remove.each { |account_tag_id| account_tagships.find_by(account_tag_id: account_tag_id).destroy }
      tags_to_add.each { |account_tag_id| account_tagships.create(account_tag_id: account_tag_id) }
    end
  end  
  
  attr_accessor :group_ids
  before_validation :join_groups_via_profile
  def join_groups_via_profile
    if @group_ids
      current_group_ids = memberships.map(&:group).select { |group| group.group_type.try(:join_groups_via_profile) and (group.public? or group.open?) }.map(&:id).map(&:to_s)
      groups_to_leave = current_group_ids - @group_ids
      groups_to_join = @group_ids - current_group_ids
      groups_to_leave.each { |group_id| memberships.find_by(group_id: group_id).try(:destroy) }
      groups_to_join.each { |group_id| memberships.create(:group_id => group_id) }
    end
  end  
      
  attr_accessor :request_membership
  attr_accessor :antispam
  before_validation do
    if self.request_membership
      errors.add(:antispam, 'is not correct') unless self.antispam and ['2','two'].include?(self.antispam.strip.downcase)
    end
  end  
  
  attr_accessor :groups_to_join
  attr_accessor :confirm_memberships
  attr_accessor :welcome_email_body
  attr_accessor :welcome_email_subject
  attr_accessor :in_callback
  after_save :join_groups
  def join_groups
    unless @in_callback
      @in_callback = true
      
      account = self
      if @groups_to_join
            
        @groups_to_join.each { |group_id|
          memberships.create(:group_id => group_id, :status => ('confirmed' if (account.sign_ins.count == 0 and account.confirm_memberships.to_i == 1)))
        }
                                        
        sign_in_details = ''              
        if account.sign_ins.count == 0 and account.confirm_memberships.to_i == 0
          sign_in_details << "You need to sign in to start receiving email notifications. "
        end    
        
        if account.sign_ins.count == 0 and account.password    
          sign_in_details << %Q{Sign in at #{Config['BASE_URI']}/sign_in with the email address #{account.email} and the password <div class="password">#{account.password}</div>}
        else
          sign_in_details << "Sign in at #{Config['BASE_URI']}/sign_in."
        end
                  
        if Config['SMTP_ADDRESS']
          mail = Mail.new
          mail.to = account.email
          mail.from = "#{Config['SITE_NAME']} <#{Config['HELP_ADDRESS']}>"
          mail.subject = account.welcome_email_subject

          content = account.welcome_email_body
          .gsub('[firstname]',account.name.split(' ').first)
          .gsub('[group_list]',@groups_to_join.map { |id| Group.find(id).name }.to_sentence)
          .gsub('[sign_in_details]', sign_in_details)
    
          html_part = Mail::Part.new do
            content_type 'text/html; charset=UTF-8'
            body ERB.new(File.read(Padrino.root('app/views/layouts/email.erb'))).result(binding)     
          end    
          mail.html_part = html_part            
          
          mail.deliver
        end
      
        @groups_to_join = nil
      end
    end
  end
    
  def self.marker_color
    '3DA2E4'
  end
    
  def public_memberships
    Membership.where(:id.in => memberships.select { |membership| !membership.group.secret? }.map(&:id))
  end  
          
  def network    
    Account.where(:id.in => memberships.map(&:group).map { |group| group.memberships.only(:account_id).where(:status => 'confirmed') }.flatten.map(&:account_id))
  end
  
  def people
    network
  end
  
  def network_organisations
    Organisation.where(:id.in => Affiliation.where(:account_id.in => network.pluck(:id)).pluck(:organisation_id))
  end
          
  def conversations
    Conversation.where(:group_id.in => memberships.pluck(:group_id))
  end
  
  def latest_conversations
    conversations.order('updated_at desc')
  end
  
  def visible_conversations
    conversations.where(:hidden.ne => true)
  end
  
  def conversation_posts
    ConversationPost.where(:group_id.in => memberships.pluck(:group_id))
  end
  
  def visible_conversation_posts
    conversation_posts.where(:hidden.ne => true).where(:conversation_id.in => visible_conversations.pluck(:id))
  end  
                
  def groups
    Group.where(:id.in => memberships.pluck(:group_id))
  end
              
  # Picture
  dragonfly_accessor :picture do
    after_assign { |picture| self.picture = picture.thumb('500x500>') }
  end
  attr_accessor :rotate_picture_by
  before_validation :rotate_picture
  def rotate_picture
    if self.picture and self.rotate_picture_by
      picture.rotate(self.rotate_picture_by)
    end
    return true
  end
    
  # Provider links  
  has_many :provider_links, :dependent => :destroy
  accepts_nested_attributes_for :provider_links
                        
  attr_accessor :password
      
  validates_presence_of :name, :email
  validates_presence_of :password, :if => :password_required
  validates_format_of :username, :with => /\A[a-z0-9_\.]+\z/, :allow_nil => true
  validates_uniqueness_of :username, :allow_nil => true
    
  validates_length_of :email, :within => 3..100
  validates_uniqueness_of :email, :case_sensitive => false
  validates_format_of :email, :with => /\A[^@\s]+@[^@\s]+\.[^@\s]+\Z/i
  validates_length_of :password, :within => 4..40, :if => :password_required
  
  validates_length_of :headline, maximum: 150
  
  index({email: 1 }, {unique: true})
  
  def firstname
    name.split(' ').first if name
  end
  
  def lastname
    if name
      nameparts = name.split(' ')
      if nameparts.length > 1
        nameparts[1..-1].join(' ') 
      else
        nil
      end
    end
  end  
    
  def username_or_id
    username or id
  end  
  
  before_validation do    
    errors.add(:name, 'must not contain an @') if self.name and self.name.include?('@')
    self.username = self.username.downcase if self.username
    self.email = self.email.gsub(' ','') if self.email # strip unicode \u00a0
    self.secret_token = SecureRandom.uuid if !self.secret_token
    self.website = "http://#{self.website}" if self.website and !(self.website =~ /\Ahttps?:\/\//)
    self.name_transliterated = I18n.transliterate(self.name)
    
    self.twitter_profile_url = "twitter.com/#{self.twitter_profile_url}" if self.twitter_profile_url and !self.twitter_profile_url.include?('twitter.com')      
    errors.add(:facebook_profile_url, 'must contain facebook.com') if self.facebook_profile_url and !self.facebook_profile_url.include?('facebook.com')    
    self.twitter_profile_url = self.twitter_profile_url.gsub('twitter.com/', 'twitter.com/@') if self.twitter_profile_url and !self.twitter_profile_url.include?('@')                
    self.twitter_profile_url = "http://#{self.twitter_profile_url}" if self.twitter_profile_url and !(self.twitter_profile_url =~ /\Ahttps?:\/\//)
    self.facebook_profile_url = "http://#{self.facebook_profile_url}" if self.facebook_profile_url and !(self.facebook_profile_url =~ /\Ahttps?:\/\//)   
  end  
      
  before_validation :set_has_picture
  def set_has_picture
    self.has_picture = (self.picture ? true : false)
    return true
  end
    
  def self.new_tips
    {
      :username => 'Letters, numbers, underscores and periods'
    }
  end
  
  def self.edit_tips
    self.new_tips
  end  
              
  def self.admin_fields
    {
      :name => :text,
      :username => :text,
      :firstname => {:type => :text, :edit => false},
      :lastname => {:type => :text, :edit => false},
      :email => :text,
      :secret_token => :text,
      :headline => :text,
      :story => :text_area,
      :website => :text,
      :location => :text,
      :coordinates => :geopicker,      
      :picture => :image,
      :twitter_profile_url => :text,
      :facebook_profile_url => :text,
      :admin => :check_box,
      :translator => :check_box,
      :time_zone => :select,
      :language_id => :lookup,
      :password => :password,
      :prevent_new_memberships => :check_box,      
      :root => :check_box,
      :affiliations => :collection,
      :affiliations_summary => {:type => :text, :edit => false},
      :title_of_first_affiliation => {:type => :text, :edit => false},      
      :organisation_name_of_first_affiliation => {:type => :text, :edit => false},
      :memberships => :collection,
      :memberships_summary => {:type => :text, :edit => false},
      :membership_requests => :collection,
      :unsubscribe_events => :check_box,
      :unsubscribe_new_member => :check_box,
      :unsubscribe_message => :check_box,      
    }
  end
  
  after_create :send_new_member_email
  def send_new_member_email          
    if coordinates
      account = self      
      bcc = Account.where(:id.in => Account.geo_near(coordinates).spherical.max_distance(25 / 3963.167).pluck(:id)).where(:id.ne => account.id).where(:unsubscribe_new_member.ne => true).pluck(:email)    
      if bcc.count > 0        
        mail = Mail.new
        mail.bcc = bcc
        mail.from = "#{Config['SITE_NAME']} <#{Config['HELP_ADDRESS']}>"
        mail.subject = 'Someone joined near you'
            
        content = ERB.new(File.read(Padrino.root('app/views/emails/new_member.erb'))).result(binding)
        html_part = Mail::Part.new do
          content_type 'text/html; charset=UTF-8'
          body ERB.new(File.read(Padrino.root('app/views/layouts/email.erb'))).result(binding)     
        end
        mail.html_part = html_part
      
        mail.deliver
      end
    end
  end
  handle_asynchronously :send_new_member_email  
  
  def affiliations_summary
    affiliations.map { |affiliation| "#{affiliation.title} at #{affiliation.organisation.name}" }.join(', ')
  end
  
  def title_of_first_affiliation
    affiliations.first.try(:title)
  end      
  
  def organisation_name_of_first_affiliation
    affiliations.first.try(:organisation).try(:name)    
  end  
    
  def memberships_summary
    memberships.map { |membership| membership.group.slug }.join(', ')
  end
  
  def self.countries
    [''] + ISO3166::Country.all_translated(I18n.locale)
  end
    
  def self.edit_hints
    {
      :password => 'Leave blank to keep existing password'      
    }
  end   
                
  def self.time_zones
    ['']+ActiveSupport::TimeZone::MAPPING.keys.sort
  end          
    
  def uid
    id
  end
  
  def info
    {:email => email, :name => name}
  end
  
  def self.authenticate(email, password)
    account = find_by(email: /^#{::Regexp.escape(email)}$/i) if email.present?
    account && account.has_password?(password) ? account : nil
  end
  
  before_save :encrypt_password, :if => :password_required

  def has_password?(password)
    ::BCrypt::Password.new(crypted_password) == password
  end
  
  def self.generate_password(len)
    chars = ("a".."z").to_a + ("0".."9").to_a
    return Array.new(len) { chars[rand(chars.size)] }.join
  end 

  private
  def encrypt_password
    self.crypted_password = ::BCrypt::Password.create(self.password)
  end

  def password_required
    crypted_password.blank? || self.password.present?
  end  
    
end
