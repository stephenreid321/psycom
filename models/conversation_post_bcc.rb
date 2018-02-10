class ConversationPostBcc
  include Mongoid::Document
  include Mongoid::Timestamps
  
  belongs_to :conversation, index: true
  belongs_to :conversation_post, index: true
  belongs_to :group, index: true
  
  field :delivered_at, :type => Time
  field :message_id, :type => String
  
  index({message_id: 1})
    
  has_many :conversation_post_bcc_recipients, :dependent => :destroy
  accepts_nested_attributes_for :conversation_post_bcc_recipients
  
  validates_uniqueness_of :message_id, :allow_nil => true
    
  def self.admin_fields
    {
      :delivered_at => :datetime,
      :message_id => :text,
      :conversation_post_id => :lookup,
      :conversation_post_bcc_recipients => :collection
    }
  end
    
  attr_accessor :accounts
  before_validation do    
    self.conversation = self.conversation_post.conversation if self.conversation_post
    self.group = self.conversation.group if self.conversation
    if self.accounts
      self.accounts.each { |account|
        conversation_post_bcc_recipients.build account: account
      }
      self.accounts = nil
    end
  end  
            
  after_create :send_email
  def send_email
    return unless Config['SMTP_ADDRESS']
    # set locals for ERB binding
    conversation_post_bcc = self
    conversation_post = conversation_post_bcc.conversation_post
    conversation = conversation_post.conversation
    group = conversation.group    
    previous_conversation_posts = conversation.visible_conversation_posts.order_by(:created_at.desc)[1..-1]
                        
    mail = Mail.new
    mail.to = group.email
    if Config['REPLY_TO_GROUP']
      mail.reply_to = group.email 
    end
    mail.from = "#{conversation_post.account.name} <#{conversation_post.from_address}>"
    mail.sender = group.email('-noreply')
    mail.subject = conversation.visible_conversation_posts.count == 1 ? "[#{group.slug}] #{conversation.subject}" : "Re: [#{group.slug}] #{conversation.subject}"
    mail.headers({
        'Precedence' => 'list',
        'X-Auto-Response-Suppress' => 'OOF',
        'Auto-Submitted' => 'auto-generated',
        'List-Id' => "<#{group.slug}.list-id.#{Config['MAIL_DOMAIN']}>",
        'List-Unsubscribe' => "<http://#{Config['MAIL_DOMAIN']}/groups/#{group.slug}/notification_level?level=none>"
      })
        
    if previous_conversation_posts
      begin
        references = previous_conversation_posts.map { |previous_conversation_post| "<#{previous_conversation_post.conversation_post_bccs.order('created_at desc').first.try(:message_id)}>" }
        mail.in_reply_to = references.first
        mail.references = references.join(' ')
      rescue => e
        Airbrake.notify(e)
      end
    end
    mail.html_part do
      content_type 'text/html; charset=UTF-8'
      body ERB.new(File.read(Padrino.root('app/views/emails/conversation_post.erb'))).result(binding)
    end
    mail.bcc = conversation_post_bcc_recipients.map(&:email)
    mail = mail.deliver
    update_attribute(:message_id, mail.message_id)
    update_attribute(:delivered_at, Time.now)
  end
    
end