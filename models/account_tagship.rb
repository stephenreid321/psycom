class AccountTagship
  include Mongoid::Document
  include Mongoid::Timestamps
    
  belongs_to :account, index: true  
  belongs_to :account_tag, index: true
      
  attr_accessor :account_tag_name
  before_validation :find_or_create_account_tag
  def find_or_create_account_tag
    if account_tag_name
      created_account_tag = AccountTag.find_or_create_by(name: self.account_tag_name)
      if created_account_tag.persisted?
        self.account_tag = created_account_tag
      end
    end
  end
    
  validates_presence_of :account, :account_tag
  validates_uniqueness_of :account, :scope => :account_tag
    
  def self.admin_fields
    {
      :account_id => :lookup,
      :account_tag_id => :lookup,
    }
  end
  
  
end
