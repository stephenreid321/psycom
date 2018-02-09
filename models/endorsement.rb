class Endorsement
  include Mongoid::Document
  include Mongoid::Timestamps
  
  belongs_to :endorser, index: true, class_name: "Account", inverse_of: :endorsements_as_endorser
  belongs_to :endorsed, index: true, class_name: "Account", inverse_of: :endorsements_as_endorsed
  
  validates_presence_of :endorser, :endorsed
  validates_uniqueness_of :endorsed, :scope => :endorser
  
  before_validation do
    errors.add(:endorser, "isn't yet part of the trustchain and isn't a root") if Endorsement.where(endorsed_id: endorser.id).count == 0 and !endorser.root    
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
      mail.from = "#{Config['SITE_NAME']} <#{Config['HELP_ADDRESS']}>"
      mail.subject = "#{endorsement.endorser.name} trusted you"
            
      content = ERB.new(File.read(Padrino.root('app/views/emails/endorse.erb'))).result(binding)
      html_part = Mail::Part.new do
        content_type 'text/html; charset=UTF-8'
        body ERB.new(File.read(Padrino.root('app/views/layouts/email.erb'))).result(binding)     
      end
      mail.html_part = html_part
      
      mail.deliver
    end
  end
          
  def self.admin_fields
    {
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
  
  after_destroy do
    accounts = Account.where(:id.in => Endorsement.pluck(:endorser_id)).where(:root.ne => true).where(:id.nin => Endorsement.pluck(:endorsed_id))
    while accounts.count > 0
      accounts.each { |account|
        account.endorsements_as_endorser.destroy_all
      }
      accounts = Account.where(:id.in => Endorsement.pluck(:endorser_id)).where(:root.ne => true).where(:id.nin => Endorsement.pluck(:endorsed_id))
    end
  end
      
end
