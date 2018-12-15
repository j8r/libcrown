require "./password_state"

struct Libcrown::Group
  # Unique group name.
  property name : String
  # Users who are members of the group.
  property users : Set(String)
  # Generally unused empty/blank password (set to `PasswordState::Hashed`).
  property password : PasswordState

  def initialize(@name : String, @users : Set(String) = Set(String).new, @password : PasswordState = PasswordState::Hashed)
  end

  protected def self.parse_group_line(line : String) : Tuple(UInt32, Group)
    name, password, gid, users = line.split ':', limit: 4
    group = new name, users.split(',').to_set, PasswordState.new(password)
    {gid.to_u32, group}
  end

  # :nodoc:
  def build(gid : UInt32, io)
    io << @name
    io << @password.build
    io << gid << ':'
    @users.join ',', io
  end

  # Validates `gid` and `gecos_comments` fields
  def validate
    Libcrown.validate_name @name
  end
end
