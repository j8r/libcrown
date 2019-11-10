require "./password_state"

# Represents a password line of `/etc/group`.
struct Libcrown::Group
  # Unique group name.
  getter name : String

  # :ditto:
  def name=(@name : String) : String
    Libcrown.validate_name @name
  end

  # Users who are members of the group.
  property users : Set(String)
  # Generally unused empty/blank password (set to `PasswordState::Hashed`).
  property password : PasswordState

  # Creates a new group.
  def initialize(@name : String, @users : Set(String) = Set(String).new, @password : PasswordState = PasswordState::Hashed)
  end

  protected def self.parse_group_line(line : String) : Tuple(UInt32, Group)
    name, password, gid, users = line.split ':', limit: 4
    users_set = Set(String).new
    users.split ',' { |user| users_set << user }
    group = new name, users_set, PasswordState.new(password)
    {gid.to_u32, group}
  end

  # :nodoc:
  def build(gid : UInt32, io : IO) : Nil
    io << @name
    io << @password.build
    io << gid << ':'
    @users.join ',', io
  end
end
