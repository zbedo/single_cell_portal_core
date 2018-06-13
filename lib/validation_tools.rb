##
# ValidationTools
#
# Module with values for validating/santizing form & model values
module ValidationTools
  # Model Tools
  # Regex for validations
  SCRIPT_TAG_REGEX = /(\<|\&lt;)script.*(\>|\&gt;).*(\<|\&lt;)\/script(\>|\&gt;)/
  NO_SCRIPT_TAGS = /\A.*[^(\<|\&lt;)\/?script.*(\>|\&gt;)].*\z/
  NO_JS_FUNCTIONS = /\A.*javascript\:.*\z/

  ALPHANUMERIC_ONLY = /\A\w*\z/
  ALPHANUMERIC_DASH = /\A[\w+\-?]*\z/
  ALPHANUMERIC_SPACE_DASH = /\A[\w+\s?\-]*\z/
  URL_SAFE_CHARS = /\A[\w+\-]+[^\;\/\?\:\@\=\&\'\"\<\>\#\%\{\}\|\\\^\~\[\]\`]\z/
  FILENAME_CHARS = /\A[\w+[\s\-\.\/]?]+\z/
  OBJECT_LABELS = /\A[\w+\s*[\-\.\/\(\)\+]?]+\z/
  # an extended regex with some slightly 'unsafe' non-word characters added in
  ALPHANUMERIC_EXTENDED = /\A[\w+\s?[\-\!\@\#\%\^\*\(\)\.\,]+]*\z/

  # Error messages for custom validators
  ALPHANUMERIC_ONLY_ERROR = 'contains invalid characters. Please use only alphanumeric characters.'
  ALPHANUMERIC_DASH_ERROR = 'contains invalid characters. Please use only alphanumeric characters or dashes.'
  ALPHANUMERIC_SPACE_DASH_ERROR = 'contains invalid characters. Please use only alphanumeric characters, spaces, or dashes.'
  URL_SAFE_CHARS_ERROR = 'contains invalid characters. Please use only URL safe characters (e.g. aphanumeric & dashes)'
  FILENAME_CHARS_ERROR = 'contains invalid characters. Please use only alphanumeric, spaces, or the following: - _ . /'
  OBJECT_LABELS_ERROR = 'contains invalid characters. Please use only alphanumeric, spaces, or the following: - _ . / ( ) +'
  ALPHANUMERIC_EXTENDED_ERROR = 'contains invalid characters. Please use only alphanumeric characters, spaces, dashes, or the following: ! @ # % ( ) . ,'
  NO_SCRIPT_TAGS_ERROR = 'contains invalid characters (inline javascript).  Please remove these before continuing.'
  # GCS tools
  GCS_HOSTNAMES = %w(storage.googleapis.com www.googleapis.com)
  SIGNED_URL_KEYS = %w(GoogleAccessId Expires Signature)
end