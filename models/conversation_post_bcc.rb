class ConversationPostBcc
  include Mongoid::Document
  include Mongoid::Timestamps
  
  belongs_to :conversation, index: true
  belongs_to :conversation_post, index: true
  belongs_to :group, index: true
  
  field :delivered_at, :type => Time
  field :message_id, :type => String
  field :message_ids, :type => Array
  
  index({message_id: 1})
  index({message_ids: 1})
    
  has_many :conversation_post_bcc_recipients, :dependent => :destroy
  accepts_nested_attributes_for :conversation_post_bcc_recipients
  
  validates_uniqueness_of :message_id, :allow_nil => true
    
  def self.admin_fields
    {
      :delivered_at => :datetime,
      :message_id => :text,
      :message_ids => {:type => :text_area, :edit => :false},
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
    return unless ENV['MAILGUN_API_KEY']
    # set locals for ERB binding
    conversation_post_bcc = self
    conversation_post = conversation_post_bcc.conversation_post
    conversation = conversation_post.conversation
    group = conversation.group    
    previous_conversation_posts = conversation.visible_conversation_posts.order_by(:created_at.desc)[1..-1]
    
    mg_client = Mailgun::Client.new ENV['MAILGUN_API_KEY']
    batch_message = Mailgun::BatchMessage.new(mg_client, ENV['MAILGUN_DOMAIN'])    
    
    batch_message.from "#{conversation_post.account.name.gsub(',','')} <#{conversation_post.from_address}>"
    batch_message.subject conversation.visible_conversation_posts.count == 1 ? "[#{group.slug}] #{conversation.subject}" : "Re: [#{group.slug}] #{conversation.subject}"      
    if ENV['REPLY_TO_GROUP']
      batch_message.reply_to = group.email 
    end    
    
    {
      'Sender' => group.email('-noreply'),
      'Precedence' => 'list',
      'X-Auto-Response-Suppress' => 'OOF',
      'Auto-Submitted' => 'auto-generated',
      'List-Id' => "<#{group.slug}.list-id.#{ENV['MAIL_DOMAIN']}>",
      'List-Unsubscribe' => "<http://#{ENV['MAIL_DOMAIN']}/groups/#{group.slug}/notification_level?level=none>"
    }.each { |name, data|
      batch_message.header name, data
    }
                                                           
    if previous_conversation_posts
      begin
        references = previous_conversation_posts.map { |previous_conversation_post|
          previous_conversation_post.conversation_post_bccs.order('created_at desc').map { |conversation_post_bcc|
            conversation_post_bcc.message_ids.map { |message_id|
              "<#{message_id}>"  
            }
          }
        }.flatten          
        batch_message.header 'References', references.join(' ')
      rescue => e
        Airbrake.notify(e)
      end
    end
    
    batch_message.body_html ERB.new(File.read(Padrino.root('app/views/emails/conversation_post.erb'))).result(binding)

    batch_message.add_recipient(:to, group.email)    
    conversation_post_bcc_recipients.pluck(:email).each { |bcc|
      batch_message.add_recipient(:bcc, bcc)
    }    
    
    finalized = batch_message.finalize 
   
    update_attribute(:message_ids, finalized.keys)
    update_attribute(:delivered_at, Time.now)
  end
    
end