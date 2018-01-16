class AccountTag
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, :type => String
  
  has_many :account_tagships, :dependent => :destroy
  
  validates_presence_of :name
  validates_uniqueness_of :name, :case_sensitive => false
  
  before_validation do
    self.name = self.name.strip.downcase if self.name
  end
    
  def self.admin_fields
    {
      :name => :text,
      :account_tagships => :collection
    }
  end
      
end
