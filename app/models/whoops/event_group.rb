class Whoops::EventGroup
  # notifier responsible for creating identifier from notice details
  include Mongoid::Document
  include FieldNames
  
  attr_accessor :recording_event
  
  [:service, :environment, :event_type, :message, :group_identifier, :logging_strategy_name].each do |string_field|
    field string_field, :type => String
  end
  field :last_recorded_at, :type => DateTime
  field :notify_on_next_occurrence, :type => Boolean, :default => true
  field :archived, :type => Boolean, :default => false

  has_many :events, :class_name => "Whoops::Event"
  
  # validates_presence_of :event_type, :service, :message
  validates_presence_of :group_identifier, :event_type, :service, :message
  
  after_validation :handle_archival, :send_notifications
  
  def self.identifying_fields
    field_names - ["message", "last_recorded_at"]
  end
  
  # @return sorted set of all applicable namespaces
  def self.services
    services = SortedSet.new
    previous_service = []
    all(:sort => [[:service, :asc]]).each do |group|
      services << group.service
      split = group.service.split(".")
      common = (previous_service & split)
      services << common.join(".") unless common.blank?
      previous_service = split
    end
    services
  end
  
  def send_notifications
    if self.notify_on_next_occurrence && recording_event
      matcher = Whoops::NotificationRule::Matcher.new(self)
      Whoops::NotificationMailer.event_notification(self, matcher.matches).deliver
      self.notify_on_next_occurrence = false
    end
  end
  
  def handle_archival
    if self.recording_event && self.archived
      self.archived = false
    end
    
    if self.archived_change
      if self.archived
        self.notify_on_next_occurrence = false
      else
        self.notify_on_next_occurrence = true
      end
    end
  end
  
end