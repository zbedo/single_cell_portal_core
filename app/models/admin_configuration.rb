class AdminConfiguration
  include Mongoid::Document
  field :config_type, type: String
  field :value_type, type: String
  field :multiplier, type: String
  field :value, type: String

  validates_uniqueness_of :config_type, message: ": '%{value}' has already been set.  Please edit the corresponding entry to update."

  validate :validate_value_by_type

  GLOBAL_DOWNLOAD_STATUS_NAME = 'Global Data Download Status'
  BOOLEAN_VALS = %w(1 yes y on true enabled)
  NUMERIC_VALS = %w(byte kilobyte megabyte terabyte petabyte exabyte)

  # really only used for IDs in the table...
  def url_safe_name
    self.config_type.downcase.gsub(/[^a-zA-Z0-9]+/, '-').chomp('-')
  end

  def self.config_types
    ['Daily User Download Quota']
  end

  def self.value_types
    ['Numeric', 'Boolean', 'String']
  end

  def display_value
    case self.value_type
      when 'Numeric'
        unless self.multiplier.nil? || self.multiplier.blank?
          "#{self.value} #{self.multiplier}(s) <span class='badge'>#{self.convert_value_by_type} bytes</span>"
        else
          self.value
        end
      else
        self.value == '1' ? 'Yes' : 'No'
    end
  end

  # converter to return requested value as an instance of its value type
  # numerics will return an interger or float depending on value contents (also understands Rails shorthands for byte size increments)
  # booleans return true/false based on matching a variety of possible 'true' values
  # strings just return themselves
  def convert_value_by_type
    case self.value_type
      when 'Numeric'
        unless self.multiplier.nil? || self.multiplier.blank?
          val = self.value.include?('.') ? self.value.to_f : self.value.to_i
          return val.send(self.multiplier.to_sym)
        else
          return self.value.to_f
        end
      when 'Boolean'
        return self.value == '1'
      else
        return self.value
    end
  end

  private

  def validate_value_by_type
    case self.value_type
      when 'Numeric'

      when 'Boolean'
      else
        return true
    end
  end
end
