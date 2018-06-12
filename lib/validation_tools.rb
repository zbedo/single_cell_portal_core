module ValidationTools
  # Regex for validations
  SCRIPT_TAG_REGEX = /(\<|\&lt;)script.*(\>|\&gt;).*(\<|\&lt;)\/script(\>|\&gt;)/
  URL_SAFE_CHARS = /\A[\w+\-]+[^\;\/\?\:\@\=\&\'\"\<\>\#\%\{\}\|\\\^\~\[\]\`]\z/
  FILENAME_CHARS = /\A[\w+[\s\-\.\/]?]+\z/
  OBJECT_LABELS = /\A[\w+\s*[\-\.\/\(\)\+]?]+\z/
  ALPHANUMERIC_ONLY = /\A\w*\Z/
  ALPHANUMERIC_SPACE_DASH = /\A[\w+\s?\-]*\z/
  # an extended regex with some slightly 'unsafe' non-word characters added in
  ALPHANUMERIC_EXTENDED = /\A[\w+\s?[\-\!\@\#\%\^\*\(\)\.\,]+]*\z/

  # Error messages for custom validators
  ALPHANUMERIC_ONLY_ERROR = 'contains invalid characters. Please use only alphanumeric characters.'
  ALPHANUMERIC_SPACE_DASH_ERROR = 'contains invalid characters. Please use only alphanumeric characters, spaces, or dashes.'
  URL_SAFE_CHARS_ERROR = 'contains invalid characters. Please use only URL safe characters (e.g. aphanumeric & dashes)'
  FILENAME_CHARS_ERROR = 'contains invalid characters. Please use only alphanumeric, spaces, or the following: - _ . /'
  OBJECT_LABELS_ERROR = 'contains invalid characters. Please use only alphanumeric, spaces, or the following: - _ . / ( ) +'
end