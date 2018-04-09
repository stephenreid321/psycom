class Organisation
  include Mongoid::Document
  include Mongoid::Timestamps
  extend Dragonfly::Model
  
  index({coordinates: "2dsphere"})

  field :name, :type => String
  field :username, :type => String
  field :address, :type => String
  field :coordinates, :type => Array
  field :website, :type => String
  field :picture_uid, :type => String  
  field :organisation_type, :type => String
    
  include Geocoder::Model::Mongoid
  geocoded_by :address  
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
  
  has_many :events, :dependent => :destroy
  
  has_many :affiliations, :dependent => :restrict
  
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
  end
  
  def self.marker_color
    'E43D3D'
  end
    
  def self.admin_fields
    {
      :name => :text,
      :username => :text,
      :address => :text,
      :website => :text,
      :picture => :image,
      :organisation_type => :select,
      :affiliations => :collection
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
        
end
