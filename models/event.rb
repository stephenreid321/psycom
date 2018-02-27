class Event
  include Mongoid::Document
  include Mongoid::Timestamps
  
  belongs_to :account, index: true
  belongs_to :organisation, index: true, optional: true
  
  index({coordinates: "2dsphere"})
 
  field :name, :type => String
  field :start_time, :type => Time
  field :end_time, :type => Time
  field :all_day, :type => Boolean
  field :location, :type => String
  field :coordinates, :type => Array
  field :details, :type => String
  field :ticketing, :type => String
  field :tickets_link, :type => String
  field :more_info, :type => String
  field :organisation_name, :type => String
  field :highlighted, :type => Boolean
  field :approved, :type => Boolean
  
  include Geocoder::Model::Mongoid
  geocoded_by :location
  def lat; coordinates[1] if coordinates; end  
  def lng; coordinates[0] if coordinates; end  
  after_validation do
    self.geocode || (self.coordinates = nil)
  end  
  
  def self.marker_color
    '9C3DE4'
  end  
      
  validates_presence_of :name, :start_time, :end_time, :ticketing
  
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
      :all_day => :check_box,
      :location => :text,
      :coordinates => :geopicker,              
      :details => :text_area,
      :more_info => :text,
      :ticketing => :select,
      :tickets_link => :text,
      :highlighted => :check_box,
      :account_id => :lookup,
      :organisation_name => :text,
      :organisation_id => :lookup
    }
  end
    
  def self.ticketings
    ['No ticket required','Free, but please RSVP', 'Ticket required']
  end
    
  def when_details
    if all_day
      if start_time.to_date == end_time.to_date
        start_time.to_date.to_s(:no_year)
      else
        "#{start_time.to_date.to_s(:no_year)} &ndash; #{end_time.to_date.to_s(:no_year)}"
      end
    else
      if start_time.to_date == end_time.to_date
        "#{start_time.to_date.to_s(:no_year)}, #{start_time.to_s(:no_double_zeros)} &ndash; #{end_time.to_s(:no_double_zeros)}"
      else
        "#{start_time.to_date.to_s(:no_year)}, #{start_time.to_s(:no_double_zeros)} &ndash; #{end_time.to_date.to_s(:no_year)}, #{end_time.to_s(:no_double_zeros)}"
      end      
    end
  end
    
end
