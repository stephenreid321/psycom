class Endorsement
  include Mongoid::Document
  include Mongoid::Timestamps
  
  field :body, :type => String

  belongs_to :endorser, index: true, class_name: "Account", inverse_of: :endorsements_as_endorser
  belongs_to :endorsed, index: true, class_name: "Account", inverse_of: :endorsements_as_endorsed
  
  validates_presence_of :endorser, :endorsed, :body
  validates_uniqueness_of :endorsed, :scope => :endorser
  
  before_validation do
    errors.add(:endorser, "hasn't yet been endorsed") if Endorsement.where(endorsed_id: endorser.id).count == 0 and !endorser.root    
    errors.add(:endorsed, "can't be the same as endorser") if endorser.id == endorsed.id
    errors.add(:endorsed, "is a root") if endorsed.root
    errors.add(:endorsed, "is already an ancestor of endorser") if tree = Endorsement.tree(endorser) and tree.flatten.include?(endorsed)    
  end
  
  after_create :update_endorsement_count
  after_destroy :update_endorsement_count
  
  def update_endorsement_count
    endorsed.update_endorsement_count
  end
  
  after_create do
    unless endorsed.unsubscribe_endorsement
      endorsement = self
      mail = Mail.new
      mail.to = endorsed.email
      mail.from = 'psychedelic.community <team@psychedelic.community>'
      mail.subject = "#{endorsement.endorser.name} endorsed you"
            
      content = ERB.new(File.read(Padrino.root('app/views/emails/endorse.erb'))).result(binding)
      html_part = Mail::Part.new do
        content_type 'text/html; charset=UTF-8'
        body ERB.new(File.read(Padrino.root('app/views/layouts/email.erb'))).result(binding)     
      end
      mail.html_part = html_part
      
      mail.deliver if ENV['SMTP_USERNAME']  
    end
  end
          
  def self.admin_fields
    {
      :body => :text,
      :endorser_id => :lookup,
      :endorsed_id => :lookup
    }
  end
    
  def self.tree(account)    
    endorsements = Endorsement.where(endorsed: account)
    if endorsements.count > 0
      x =  []
      endorsements.each { |endorsement|        
          x << endorsement.endorser                  
          if subtree = Endorsement.tree(endorsement.endorser)
            x << subtree
          end           
      }
      x
    end        
  end
      
end
