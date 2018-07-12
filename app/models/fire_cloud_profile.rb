class FireCloudProfile
  include ActiveModel::Model

  attr_accessor :contactEmail, :email, :firstName, :lastName, :institute, :institutionalProgram,
                :nonProfitStatus, :pi, :programLocationCity, :programLocationState,
                :programLocationCountry, :title

  validates_format_of :firstName, :lastName, :pi, :programLocationCity,
                      :programLocationState, :programLocationCountry, with: ValidationTools::NAME_CHARS,
                      message: ValidationTools::NAME_CHARS_ERROR

  validates_format_of :institute, :institutionalProgram, :title, with: ValidationTools::NAME_EXT_CHARS,
                      message: ValidationTools::NAME_EXT_CHARS_ERROR

  validates_format_of :email, :contactEmail, with: Devise.email_regexp, message: 'is not a valid email address.'

  validates_inclusion_of :nonProfitStatus, in: ['true', 'false']
end