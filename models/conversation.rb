class Conversation
  include Mongoid::Document
  include Mongoid::Timestamps
  
  belongs_to :group, index: true  
  belongs_to :account, index: true
  
  has_many :conversation_posts, :dependent => :destroy
  accepts_nested_attributes_for :conversation_posts
  has_many :conversation_mutes, :dependent => :destroy
  has_many :conversation_post_bccs, :dependent => :destroy
  has_many :conversation_post_bcc_recipients, :dependent => :destroy
  
  def merge(other_conversation)
    [conversation_posts, conversation_post_bccs, conversation_post_bcc_recipients, conversation_mutes].each { |collection|
      collection.each { |x|
        x.update_attribute(:conversation_id, other_conversation.id)
      }
    }
    self.update_attribute(:hidden, true)
  end
    
  def visible_conversation_posts
    conversation_posts.where(:hidden.ne => true)
  end
  
  field :subject, :type => String
  field :slug, :type => Integer
  field :hidden, :type => Boolean, :default => false
  field :pinned, :type => Boolean
  
  index({slug: 1 }, {unique: true})
  
  validates_presence_of :subject, :slug
  validates_uniqueness_of :slug
  
  def tags
    subject.scan(/(?:\s|^)(?:#(?!(?:\d+|\w+?_|_\w+?)(?:\s|$)))(\w+)(?=\s|$)/i).flatten
  end
          
  before_validation :set_slug
  def set_slug
    if !self.slug
      if Conversation.count > 0
        self.slug = Conversation.only(:slug).order_by(:slug.desc).first.slug + 1
      else
        self.slug = 1
      end
    end
  end
  
  attr_accessor :body, :file       
  before_validation :set_conversation_post
  def set_conversation_post
    if self.body
      conversation_post = self.conversation_posts.build body: self.body, account: self.account
      if self.file
        conversation_post.attachments.build file: self.file
      end
    end
  end
    
  before_validation :ensure_not_duplicate
  def ensure_not_duplicate
    if most_recent = Conversation.order_by(:created_at.desc).limit(1).first
      errors.add(:subject, 'is a duplicate') if self.group == most_recent.group and self.subject == most_recent.subject
    end
  end
        
  def self.admin_fields
    {
      :subject => :text,
      :slug => :text,
      :hidden => :check_box,
      :pinned => :check_box,
      :group_id => :lookup,      
      :account_id => :lookup,      
      :conversation_posts => :collection
    }
  end
  
  
  def last_conversation_post
    visible_conversation_posts.order_by(:created_at.desc).first
  end
  
  def participants
    Account.where(:id.in => visible_conversation_posts.map(&:account_id))
  end

end
