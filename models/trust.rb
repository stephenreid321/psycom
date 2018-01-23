class Trust
  include Mongoid::Document
  include Mongoid::Timestamps
  
  field :endorsement, :type => String

  belongs_to :truster, index: true, class_name: "Account", inverse_of: :trusts_as_truster
  belongs_to :trustee, index: true, class_name: "Account", inverse_of: :trusts_as_trustee
  
  validates_presence_of :truster, :trustee
  validates_uniqueness_of :trustee, :scope => :truster
  
  before_validation do
    errors.add(:trustee, "can't be the same as truster") if truster.id == trustee.id
  end
  
  after_create :update_trust_count
  after_destroy :update_trust_count
  
  def update_trust_count
    trustee.update_trust_count
  end
  
  after_create do
    unless trustee.unsubscribe_trust
      trust = self
      mail = Mail.new
      mail.to = trustee.email
      mail.from = 'psychedelic.community <team@psychedelic.community>'
      mail.subject = "#{trust.truster.name} trusts you"
            
      content = ERB.new(File.read(Padrino.root('app/views/emails/trust.erb'))).result(binding)
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
      :endorsement => :text,
      :truster_id => :lookup,
      :trustee_id => :lookup,
    }
  end
    
end
