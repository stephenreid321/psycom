class ConversationPost
  include Mongoid::Document
  include Mongoid::Timestamps

  field :body, :type => String
  field :message_id, :type => String
  field :hidden, :type => Boolean, :default => false
  
  belongs_to :conversation, index: true
  belongs_to :group, index: true
  belongs_to :account, index: true
  
  has_many :conversation_post_bccs, :dependent => :destroy
  has_many :conversation_post_bcc_recipients, :dependent => :destroy
  
  has_many :attachments, :dependent => :destroy
  accepts_nested_attributes_for :attachments
  has_many :likes, :dependent => :destroy
  
  validates_presence_of :body
  validates_uniqueness_of :message_id, :allow_nil => true
      
  index({message_id: 1})
  
  before_validation :set_group
  def set_group
    self.group = self.conversation.try(:group)
  end
      
  def self.admin_fields
    {
      :id => {:type => :text, :index => false},
      :body => :wysiwyg,
      :message_id => :text,
      :account_id => :lookup,      
      :conversation_id => :lookup,
      :group_id => :lookup,      
      :hidden => :check_box,           
      :conversation_post_bccs => :collection
    }
  end
  
  attr_accessor :file
  before_validation :set_attachment
  def set_attachment
    if self.file
      self.attachments.build file: self.file
      self.file = nil
    end  
  end
  
  def account_name
    account.name
  end
  
  before_validation :check_membership_is_not_muted
  def check_membership_is_not_muted
    errors.add(:account, 'is muted') if self.group.memberships.find_by(account: self.account, muted: true)
  end   
  
  after_create :touch_conversation
  def touch_conversation
    conversation.update_attribute(:updated_at, Time.now) unless conversation.hidden
  end
  
  def didyouknow_replacements(string)
    group = conversation.group
    members = group.members
    base_uri = Config['BASE_URI']
    string.gsub!('[site_url]', base_uri)
    string.gsub!('[name]', group.name)
    string.gsub!('[slug]', group.slug)        
    string.gsub!('[conversation_url]', "#{base_uri}/conversations/#{conversation.slug}")
    string.gsub!('[members]', "#{m = members.count} #{m == 1 ? 'member' : 'members'}")
    most_recently_updated_account = members.order_by([:has_picture.desc, :updated_at.desc]).first
    string.gsub!('[most_recently_updated_url]', "#{base_uri}/#{most_recently_updated_account.username_or_id}")
    string.gsub!('[most_recently_updated_name]', most_recently_updated_account.name)
    string
  end  
  
  def self.dmarc_fail_domains
    %w{yahoo.com y7mail.com yahoo.at yahoo.be yahoo.bg yahoo.ca yahoo.cl yahoo.co.hu yahoo.co.id yahoo.co.il yahoo.co.in yahoo.co.kr yahoo.co.nz yahoo.co.th yahoo.co.uk yahoo.co.za yahoo.com.ar yahoo.com.au yahoo.com.br yahoo.com.co yahoo.com.hk yahoo.com.hr yahoo.com.mx yahoo.com.my yahoo.com.pe yahoo.com.ph yahoo.com.sg yahoo.com.tr yahoo.com.tw yahoo.com.ua yahoo.com.ve yahoo.com.vn yahoo.cz yahoo.de yahoo.dk yahoo.ee yahoo.es yahoo.fi yahoo.fr yahoo.gr yahoo.hr yahoo.hu yahoo.ie yahoo.in yahoo.it yahoo.lt yahoo.lv yahoo.nl yahoo.no yahoo.pl yahoo.pt yahoo.ro yahoo.rs yahoo.se yahoo.si yahoo.sk yahoogroups.co.kr yahoogroups.com.cn yahoogroups.com.sg yahoogroups.com.tw yahoogrupper.dk yahoogruppi.it yahooxtra.co.nz aol.com protonmail.com} + (Config['DMARC_FAIL_DOMAINS'] ? Config['DMARC_FAIL_DOMAINS'].split(',') : [])
  end

  def from_address
    group = conversation.group
    from = account.email
    if ConversationPost.dmarc_fail_domains.include?(from.split('@').last)
      group.email('-noreply')
    else
      from
    end
  end    
   
  def accounts_to_notify   
    Account.where(:id.in => (group.memberships.where(:status => 'confirmed').where(:notification_level => 'each').pluck(:account_id) - conversation.conversation_mutes.pluck(:account_id)))
  end
        
  def send_notifications!(force: false)
    # force may help with caching issues
    unless force
      return if conversation.hidden
    end
    conversation_post_bccs.create(accounts: accounts_to_notify)
  end
  handle_asynchronously :send_notifications!
             
  def replace_cids!
    self.body = body.gsub(/src="cid:(\S+)"/) { |match|
      begin
        %Q{src="#{Config['BASE_URI']}#{attachments.find_by(cid: $1).file.url}"}
      rescue
        nil
      end
    }    
    self.body = body.gsub(/\[cid:(\S+)\]/) { |match|
      begin
        %Q{<img src="#{Config['BASE_URI']}#{attachments.find_by(cid: $1).file.url}">}
      rescue
        nil
      end
    }    
    self
  end
  
  def replace_iframes!
    self.body = body.gsub(/(<iframe\b[^>]*><\/iframe>)/) do |match|
      src = Nokogiri::HTML.parse($1).search('iframe').first['src']
      %Q{<a href="#{src}">#{src}</a>}
    end
    self
  end
  
end
