class Event
  include Mongoid::Document
  include Mongoid::Timestamps
  
  belongs_to :account, index: true
  belongs_to :organisation, index: true, optional: true
  
  index({coordinates: "2dsphere"})
 
  field :name, :type => String
  field :start_time, :type => Time
  field :end_time, :type => Time
  field :location, :type => String
  field :coordinates, :type => Array
  field :details, :type => String
  field :more_info, :type => String
  field :organisation_name, :type => String
  field :approved, :type => Boolean
  field :sent_notification, :type => Boolean
  
  include Geocoder::Model::Mongoid
  geocoded_by :location
  def lat; coordinates[1] if coordinates; end  
  def lng; coordinates[0] if coordinates; end  
  after_validation do
    self.geocode || (self.coordinates = nil)
  end  
  
  def self.marker_color
    '8747e6'
  end  
      
  validates_presence_of :name, :start_time, :end_time
  
  before_validation :ensure_end_after_start
  def ensure_end_after_start
    errors.add(:end_time, 'must be after the start time') unless end_time >= start_time
  end
  
  before_validation do
    self.organisation = Organisation.find_by(name: self.organisation_name) if self.organisation_name
    self.more_info = "http://#{self.more_info}" if self.more_info and !(self.more_info =~ /\Ahttps?:\/\//)
  end  
    
  def self.admin_fields
    {
      :name => :text,
      :start_time => :datetime,
      :end_time => :datetime,
      :location => :text,
      :coordinates => :geopicker,              
      :details => :text_area,
      :more_info => :text,
      :account_id => :lookup,
      :organisation_name => :text,
      :organisation_id => :lookup,
      :approved => :check_box,
      :sent_notification => :check_box
    }
  end
        
  def when_details
    if start_time.to_date == end_time.to_date
      "#{start_time.to_date.to_s(:no_year)}, #{start_time.to_s(:no_double_zeros)} &ndash; #{end_time.to_s(:no_double_zeros)}"
    else
      "#{start_time.to_date.to_s(:no_year)}, #{start_time.to_s(:no_double_zeros)} &ndash; #{end_time.to_date.to_s(:no_year)}, #{end_time.to_s(:no_double_zeros)}"
    end      
  end
  
  def future?(from=Date.today)
    start_time >= from
  end
  
  def self.future(from=Date.today)
    where(:start_time.gte => from).order('start_time asc')
  end
  
  def past?(from=Date.today)
    start_time < from
  end
  
  def self.past(from=Date.today)
    where(:start_time.lt => from).order('start_time desc')
  end      
  
  def nearby_accounts(d=25)
    Account.where(:coordinates => { "$geoWithin" => { "$centerSphere" => [coordinates, d / 3963.1676 ]}})
  end  
  
  after_create :send_admin_notification
  def send_admin_notification
    mail = Mail.new
    mail.to = ENV['HELP_ADDRESS']
    mail.from = "#{ENV['SITE_NAME']} <#{ENV['HELP_ADDRESS']}>"
    mail.subject = "New event: #{self.name}"
      
    event = self
    base_uri = ENV['BASE_URI']
    html_part = Mail::Part.new do
      content_type 'text/html; charset=UTF-8'
      body %Q{#{event.account.name} (#{event.account.email}) created a new event: <a href="#{base_uri}/events/#{event.id}">#{event.name}</a>}
    end
    mail.html_part = html_part
      
    mail.deliver
  end
  handle_asynchronously :send_admin_notification 
  
  after_save do
    if self.approved and !self.sent_notification
      send_notification
    end
  end
  def send_notification
    return unless coordinates
    event = self
    bcc = nearby_accounts.where(:unsubscribe_events.ne => true).pluck(:email)
    if bcc.count > 0      
      mail = Mail.new
      mail.bcc = bcc
      mail.from = "#{ENV['SITE_NAME']} <#{ENV['HELP_ADDRESS']}>"
      mail.subject = 'New event near you'
            
      content = ERB.new(File.read(Padrino.root('app/views/emails/event.erb'))).result(binding)
      html_part = Mail::Part.new do
        content_type 'text/html; charset=UTF-8'
        body ERB.new(File.read(Padrino.root('app/views/layouts/email.erb'))).result(binding)     
      end
      mail.html_part = html_part
      
      mail.deliver
    end
    update_attribute(:sent_notification, true)
  end
  handle_asynchronously :send_notification  
    
end
