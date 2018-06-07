module ValidationTools
  SCRIPT_TAG_REGEX = /(\<|\&lt;)script.*(\>|\&gt;).*(\<|\&lt;)\/script(\>|\&gt;)/
  UNSAFE_URL_CHARACTERS = /[\;\/\?\:\@\=\&\'\"\<\>\#\%\{\}\|\\\^\~\[\]\`]/
  ALPHANUMERIC_ONLY = /[^a-zA-Z0-9]+/
  ALPHANUMERIC_WITH_WHITESPACE = /[^a-zA-Z0-9\s]+/
end