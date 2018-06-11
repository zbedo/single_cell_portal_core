module ValidationTools
  SCRIPT_TAG_REGEX = /(\<|\&lt;)script.*(\>|\&gt;).*(\<|\&lt;)\/script(\>|\&gt;)/
  URL_SAFE_CHARS = /\A[\w+\s?]+[^\;\/\?\:\@\=\&\'\"\<\>\#\%\{\}\|\\\^\~\[\]\`]\z/
  ALPHANUMERIC_ONLY = /\A\w*\Z/
  ALPHANUMERIC_SPACE_DASH = /\A[\w+\s?\-]*\z/
  # an extended regex with some slightly 'unsafe' non-word characters added in
  ALPHANUMERIC_EXTENDED = /\A[\w+\s?[\-\!\@\#\%\^\*\(\)\.\,]+]*\z/
end