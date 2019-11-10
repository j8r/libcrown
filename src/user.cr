require "./password_state"

# Represents a user line of `/etc/passwd`.
struct Libcrown::User
  # Unique user name.
  getter name : String

  # :ditto:
  def name=(@name : String) : String
    Libcrown.validate_name @name
  end

  # Primary group ID.
  property gid : UInt32
  # Name is the user's real or display name.
  # It might be blank.
  # This is the first (or only) entry in the GECOS field list.
  getter full_name : String

  # :ditto:
  def full_name=(@full_name : String) : String
    validate_gecos @full_name
  end

  # Comment field to add informations related to the user, excluding the first one (full name).
  getter gecos_comment : String

  # :ditto:
  def gecos_comment=(@gecos_comment : String) : String
    validate_gecos @gecos_comment
  end

  # Absolute path to the directory the user will be in when they log in. Defaults to `/` if not defined.
  property home_directory : String
  # Absolute path of a command (/bin/false) or shell (/bin/bash) executed at user's login.
  property login_shell : String
  # Usually hashed password stored in `/etc/shadow`.
  property password : PasswordState

  # Creates a new user.
  def initialize(
    @name : String,
    @gid : UInt32 = 100_u32,
    @full_name : String = "",
    @gecos_comment : String = "",
    @home_directory : String = "/",
    @login_shell : String = "/bin/false",
    @password : PasswordState = PasswordState::Hashed
  )
  end

  protected def self.parse_passwd_line(line : String) : Tuple(UInt32, User)
    name, password, uid, gid, full_gecos_comment, home_directory, login_shell = line.split ':', limit: 7
    full_name, _, gecos_comment = full_gecos_comment.partition(',')
    user = new name, gid.to_u32, full_name, gecos_comment, home_directory, login_shell, PasswordState.new(password)
    {uid.to_u32, user}
  end

  private def validate_gecos(gecos : String) : Nil
    gecos.each_char do |char|
      raise "invalid char in the GECOS comment field: `#{char}`" if char == ':' || !char.ascii?
    end
  end

  # :nodoc:
  def build(uid : UInt32, io : IO) : Nil
    io << @name
    io << @password.build
    io << uid << ':'
    io << @gid << ':'
    io << @full_name
    io << ',' if !@gecos_comment.empty?
    io << @gecos_comment << ':'
    io << @home_directory << ':'
    io << @login_shell
  end
end
