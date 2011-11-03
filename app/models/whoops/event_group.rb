class Whoops::EventGroup
  # notifier responsible for creating identifier from notice details
  include Mongoid::Document
  include FieldNames
  
  [
    :service,
    :environment,
    :event_type,
    :message,
    :group_identifier,
    :logging_strategy_name
  ].each do |string_field|
    field string_field, :type => String
  end
  
  field :last_recorded_at, :type => DateTime
  field :archived, :type => Boolean, :default => false
  field :notify_on_next_occurrence, :type => Boolean, :default => true

  class << self
    def handle_new_event(params)
      identifying_params = params.slice(*Whoops::EventGroup.identifying_fields)
      event_group = Whoops::EventGroup.first(:conditions => identifying_params)
      
      if event_group
        event_group.attributes = params
      else
        event_group = Whoops::EventGroup.new(params)
      end
      
      if event_group.valid?
        event_group.send_notifications
        event_group.save
      end
      
      event_group
    end
  end
  
  has_many :events, :class_name => "Whoops::Event"
  
  # validates_presence_of :event_type, :service, :message
  validates_presence_of :group_identifier, :event_type, :service, :message
  
  before_save :handle_archival
  
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

  def handle_archival
    if self.archived_change && !self.new_record?
      if self.archived
        self.notify_on_next_occurrence = false
      else
        self.notify_on_next_occurrence = true
      end
    end
  end
  
  def send_notifications
    # consider moving event_type check to matcher
    return unless self.notify_on_next_occurrence && self.event_type == "exception"
    matcher = Whoops::NotificationRule::Matcher.new(self)
    Whoops::NotificationMailer.event_notification(self, matcher.matching_emails).deliver unless matcher.matches.empty?
    self.notify_on_next_occurrence = false
  end
end