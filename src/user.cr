require "./password_state"

struct Libcrown::User
  # Unique user name.
  property name : String
  # Primary group ID.
  property gid : UInt32
  # Comment field to add informations related to the user.
  property gecos_comment : String
  # Absolute path to the directory the user will be in when they log in. Defaults to `/` if not defined.
  property home_directory : String
  # Absolute path of a command (/bin/false) or shell (/bin/bash) executed at user's login.
  property login_shell : String
  # Usually hashed password stored in `/etc/shadow`.
  property password : PasswordState

  def initialize(
    @name : String,
    @gid : UInt32 = 100_u32,
    @gecos_comment : String = "",
    @home_directory : String = "/",
    @login_shell : String = "/bin/false",
    @password : PasswordState = PasswordState::Hashed
  )
  end

  protected def self.parse_passwd_line(line : String) : Tuple(UInt32, User)
    name, password, uid, gid, gecos_comment, home_directory, login_shell = line.split ':', limit: 7
    user = new name, gid.to_u32, gecos_comment, home_directory, login_shell, PasswordState.new(password)
    {uid.to_u32, user}
  end

  # Validates the `name` and `gecos_comment` fields
  def validate
    Libcrown.validate_name @name
    @gecos_comment.each_char do |char|
      raise "invalid char in the GECOS comment field: `#{char}`" if char == ':' || !char.ascii?
    end
  end

  # :nodoc:
  def build(uid : UInt32, io)
    io << @name
    io << @password.build
    io << uid << ':'
    io << @gid << ':'
    io << @gecos_comment << ':'
    io << @home_directory << ':'
    io << @login_shell
  end
end
