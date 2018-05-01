class Organisation
  include Mongoid::Document
  include Mongoid::Timestamps
  extend Dragonfly::Model
  
  has_many :events, :dependent => :destroy  
  has_many :affiliations, :dependent => :destroy  
  
  index({coordinates: "2dsphere"})

  field :name, :type => String
  field :username, :type => String
  field :location, :type => String
  field :coordinates, :type => Array
  field :email, :type => String
  field :website, :type => String
  field :facebook_profile_url, :type => String
  field :twitter_profile_url, :type => String    
  field :picture_uid, :type => String  
  field :organisation_type, :type => String
  field :sent_notification, :type => Boolean
    
  include Geocoder::Model::Mongoid
  geocoded_by :location  
  def lat; coordinates[1] if coordinates; end  
  def lng; coordinates[0] if coordinates; end  
  after_validation do
    self.geocode || (self.coordinates = nil)
  end
  
  def username_or_id
    username or id
  end  
  
  validates_presence_of :name
  validates_uniqueness_of :name, :case_sensitive => false   
  validates_format_of :username, :with => /\A[a-z0-9_\.]+\z/, :allow_nil => true
  validates_uniqueness_of :username, :allow_nil => true  
    
  def members
    Account.where(:id.in => affiliations.pluck(:account_id))
  end  
    
  def conversation_posts
    ConversationPost.where(:account_id.in => affiliations.pluck(:account_id))
  end  
  
  def conversations
    Conversation.where(:id.in => conversation_posts.pluck(:conversation_id))
  end  
    
  before_validation do
    self.username = self.username.downcase if self.username
    
    self.website = "http://#{self.website}" if self.website and !(self.website =~ /\Ahttps?:\/\//)
    
    self.twitter_profile_url = "twitter.com/#{self.twitter_profile_url}" if self.twitter_profile_url and !self.twitter_profile_url.include?('twitter.com')         
    self.twitter_profile_url = self.twitter_profile_url.gsub('twitter.com/', 'twitter.com/@') if self.twitter_profile_url and !self.twitter_profile_url.include?('@')                
    self.twitter_profile_url = "http://#{self.twitter_profile_url}" if self.twitter_profile_url and !(self.twitter_profile_url =~ /\Ahttps?:\/\//)
    
    errors.add(:facebook_profile_url, 'must contain facebook.com') if self.facebook_profile_url and !self.facebook_profile_url.include?('facebook.com')        
    self.facebook_profile_url = "http://#{self.facebook_profile_url}" if self.facebook_profile_url and !(self.facebook_profile_url =~ /\Ahttps?:\/\//)   
  end
  
  def self.marker_color
    'e647a6'
  end
    
  def self.admin_fields
    {
      :name => :text,
      :username => :text,
      :location => :text,
      :email => :email,
      :website => :text,
      :twitter_profile_url => :text,
      :facebook_profile_url => :text,
      :picture => :image,
      :organisation_type => :select,
      :affiliations => :collection,
      :sent_notification => :check_box
    }
  end
  
  def self.organisation_types
    ['', 'Psychedelic Society', 'NGO', 'Service provider'].sort
  end
  
  def self.new_tips
    {
      :username => 'Letters, numbers, underscores and periods'
    }
  end
    
  def self.edit_tips
    self.new_tips
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
  end
  
  def self.human_attribute_name(attr, options={})  
    {
      :facebook_profile_url => 'Facebook URL',
      :twitter_profile_url => 'Twitter URL'
    }[attr.to_sym] || super  
  end       
  
  def nearby_accounts(d=25)
    Account.where(:coordinates => { "$geoWithin" => { "$centerSphere" => [coordinates, d / 3963.1676 ]}})
  end 
  
  after_save do
    if !self.sent_notification
      send_notification
    end
  end
  def send_notification
    return unless coordinates    
    organisation = self
    bcc = nearby_accounts.where(:unsubscribe_organisations.ne => true).pluck(:email)
    if bcc.count > 0      
      mail = Mail.new
      mail.bcc = bcc
      mail.from = "#{ENV['SITE_NAME']} <#{ENV['HELP_ADDRESS']}>"
      mail.subject = 'New organisation near you'
            
      content = ERB.new(File.read(Padrino.root('app/views/emails/organisation.erb'))).result(binding)
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
