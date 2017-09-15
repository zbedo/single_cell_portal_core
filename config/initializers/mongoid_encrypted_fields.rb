# configure AES encryption for user refresh tokens
Mongoid::EncryptedFields.cipher = Gibberish::AES.new(ENV['SECRET_KEY_BASE'])