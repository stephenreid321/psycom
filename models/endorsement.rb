class Endorsement
  include Mongoid::Document
  include Mongoid::Timestamps
  
  field :body, :type => String

  belongs_to :endorser, index: true, class_name: "Account", inverse_of: :endorsements_as_endorser
  belongs_to :endorsee, index: true, class_name: "Account", inverse_of: :endorsements_as_endorsee
  
  validates_presence_of :endorser, :endorsee
  validates_uniqueness_of :endorsee, :scope => :endorser
  
  before_validation do
    errors.add(:endorsee, "can't be the same as endorser") if endorser.id == endorsee.id
  end
  
  after_create :update_endorsement_count
  after_destroy :update_endorsement_count
  
  def update_endorsement_count
    endorsee.update_endorsement_count
  end
  
  after_create do
    unless endorsee.unsubscribe_endorsement
      endorsement = self
      mail = Mail.new
      mail.to = endorsee.email
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
      :endorsee_id => :lookup,
    }
  end
    
end
