require "./libc_crypt"

# Represents a password line of `/etc/shadow`.
struct Libcrown::Password
  # Encryption type.
  getter crypto : Encryption
  # Password's salt.
  getter salt : String?
  # Password's hash.
  getter hash : String?
  # The number of days since January 1, 1970 (also called the epoch) that the password was last changed.
  getter days_last_change : UInt32?
  # The minimum number of days that must pass before the password can be changed.
  property days_before_change : UInt32?
  # The number of days that must pass before the password must be changed.
  property days_validity : UInt32?
  # The number of days before password expiration during which the user is warned of the impending expiration.
  property days_expiration_warning : UInt32?
  # The number of days after a password expires before the account will be disabled.
  property days_account_disabling_after_expiration : UInt32?
  # The date (stored as the number of days since the epoch) since the user account has been disabled.
  property days_since_account_disabling : UInt32?

  # Creates a new password.
  def initialize(
    @crypto : Encryption = Encryption::PasswordLocked,
    @salt : String? = nil,
    @hash : String? = nil,
    @days_last_change : UInt32? = nil,
    @days_before_change : UInt32? = 0_u32,
    @days_validity : UInt32? = 99999_u32,
    @days_expiration_warning : UInt32? = 7_u32,
    @days_account_disabling_after_expiration : UInt32? = nil,
    @days_since_account_disabling : UInt32? = nil
  )
  end

  protected def self.parse_shadow_line(line : String) : Tuple(String, Password)
    user, hashed_password, days_last_change, days_before_change, days_validity, days_expiration_warning, days_account_disabling_after_expiration, days_since_account_disabling = line.split ':', limit: 9
    crypto = case hashed_password
             # No ability to login via password, only via certificate
             when "*" then Encryption::CertOnly
               # No login authorized
             when "!" then Encryption::PasswordLocked
               # user never had a password and locked by default
             when "!!", "" then Encryption::DefaultLock
             else
               type, salt, hash = hashed_password.lchop.split '$', limit: 4
               case type
               when "6" then Encryption::SHA512
               when "5" then Encryption::SHA256
               when "2" then Encryption::Blowfish
               when "1" then Encryption::MD5
               else          raise "unsupported password: " + hashed_password
               end
             end

    password = new(
      crypto,
      salt,
      hash,
      days_last_change.to_u32?,
      days_before_change.to_u32?,
      days_validity.to_u32?,
      days_expiration_warning.to_u32?,
      days_account_disabling_after_expiration.to_u32?,
      days_since_account_disabling.to_u32?
    )
    {user, password}
  end

  # Encrypt a password. Can be used to create or update the password.
  def encrypt(password : String, @crypto : Algorithm = Algorithm::SHA512, @salt : String? = Random::Secure.base64.rchop.rchop, @days_last_change : UInt32? = (Time.utc - Time::UNIX_EPOCH).days.to_u32) : UInt32
    crypto_salt = crypto.build + salt.to_s
    @hash = String.new(LibC.crypt password, crypto_salt).lstrip crypto_salt
    @days_last_change
  end

  # Create a new encrypted password.
  def self.new(password : String, crypto : Encryption = Encryption::SHA512, salt : String? = Random::Secure.base64.rchop.rchop, days_last_change : UInt32? = (Time.utc - Time::UNIX_EPOCH).days.to_u32)
    crypto_salt = crypto.build + salt.to_s
    hash = String.new(LibC.crypt password, crypto_salt).lstrip crypto_salt
    new crypto, salt, hash, days_last_change
  end

  # The password match the encrypted hash.
  def verify(password : String) : Bool
    self == self.class.new(password, @crypto, @salt, @days_last_change)
  end

  # Build the password to the given `io`.
  def build(user : String, io : IO) : Nil
    io << user << ':'
    io << @crypto.build if @crypto
    io << @salt << '$' if @salt
    io << @hash << ':' if @hash
    io << @days_last_change << ':'
    io << @days_before_change << ':'
    io << @days_validity << ':'
    io << @days_expiration_warning << ':'
    io << @days_account_disabling_after_expiration << ':'
    io << @days_since_account_disabling << ':'
  end

  # Available password encryption types.
  enum Encryption
    CertOnly
    MD5
    Blowfish
    PasswordLocked
    DefaultLock
    SHA256
    SHA512

    # :nodoc:
    def build : String
      case self
      when CertOnly       then "*:"
      when MD5            then "$1$"
      when Blowfish       then "$2$"
      when PasswordLocked then "!:"
      when DefaultLock    then "!!:"
      when SHA256         then "$5$"
      when SHA512         then "$6$"
      else                     raise "unsupported type: #{self}"
      end
    end
  end
end
