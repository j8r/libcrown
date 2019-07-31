# Safe High level API to manipulate users, groups and passwords from /etc/passwd, /etc/group and /etc/shadow.
#
# It's highly recommended to use this wrapper for any manipulation. `users`, `groups` and `passwords`
# getters have to be considered read-only.
#
# ```crystal
# require "libcrown"
#
# # Root permissions are needed
# libcrown = Libcrown.new
#
# # Add a new group
# libcrown.add_group Libcrown::Group.new("new_group"), 100_u32
#
# # Add a new user with `new_group` as its main group
# new_user = Libcrown::User.new(
#   name: "new_user",
#   gid: 100_u32,
#   gecos_comment: "This is a newly created user",
#   home_directory: "/home/new_user",
#   login_shell: "/bin/sh",
# )
# libcrown.add_user new_user
#
# # Save the modifications to the disk
# libcrown.write
# ```
#
struct Libcrown
  # System users. Modifying it directly is **unsafe**.
  getter users : Hash(UInt32, User) = Hash(UInt32, User).new
  # System groups. Modifying it directly is **unsafe**.
  getter groups : Hash(UInt32, Group) = Hash(UInt32, Group).new
  # User's passwords. Modifying it directly is **unsafe**.
  getter passwords : Hash(String, Password) = Hash(String, Password).new
  # User file, commonly stored in `/etc/passwd`.
  getter passwd_file : Path? = nil
  # Group file, commonly stored in `/etc/group`.
  getter group_file : Path? = nil
  # Password file, commonly stored in `/etc/shadow`.
  getter shadow_file : Path? = nil

  # Requires root permissions to read the shadow file and write passwd and group files
  # As non-root, to only read passwd and group files
  # ```crystal
  # libcrown = Libcrown.new nil
  # ```
  #
  def initialize(shadow_file : Path? = Path["/etc/shadow"], passwd_file : Path? = Path["/etc/passwd"], group_file : Path? = Path["/etc/group"])
    if @shadow_file = shadow_file
      File.each_line shadow_file.to_s do |line|
        user, password = Password.parse_shadow_line line
        @passwords[user] = password
      end
    end

    if @passwd_file = passwd_file
      File.each_line passwd_file.to_s do |line|
        uid, user = User.parse_passwd_line line
        @users[uid] = user
      end
    end

    if @group_file = group_file
      File.each_line group_file.to_s do |line|
        gid, group = Group.parse_group_line line
        @groups[gid] = group
      end
    end
  end

  # Parse shadow, passwd and group files from strings.
  def initialize(shadow : String = "", passwd : String = "", group : String = "")
    shadow.each_line do |line|
      user, password = Password.parse_shadow_line line
      @passwords[user] = password
    end

    passwd.each_line do |line|
      uid, password = User.parse_passwd_line line
      @users[uid] = password
    end

    group.each_line do |line|
      gid, password = Group.parse_group_line line
      @groups[gid] = password
    end
  end

  # Validates a name for use as user or group name.
  def self.validate_name(name : String) : Nil
    raise "the name can't start with a dash `-`: " + name if name.starts_with? '-'
    size = 0
    name.each_char do |char|
      size += 1
      raise "the name has more than 255 characters: " + name if size > 255
      case char
      when '.', '_', '-', .ascii_alphanumeric?
      else raise "invalid character: " + char
      end
    end
  end

  # Add a new group.
  def add_group(group_entry : Group, gid : UInt32 = available_gid) : UInt32
    check_available_group group_entry.name
    check_available_gid gid
    group_entry.validate

    @groups[gid] = group_entry
    gid
  end

  # Adds a new user along, to an existing group.
  def add_user(user_entry : User, uid : UInt32 = available_uid, password_entry : Password = Password.new) : UInt32
    user_entry.validate
    check_available_user user_entry.name
    check_available_uid uid
    raise "gid doens't exist: #{user_entry.gid}" if !@groups.has_key? user_entry.gid
    @passwords[user_entry.name] = password_entry
    @users[uid] = user_entry
    uid
  end

  # Deletes a group.
  def del_group(gid : UInt32) : Group?
    @users.each do |id, entry|
      raise "the group #{gid} is still the primary one of the user #{id}" if entry.gid == gid
    end
    @groups.delete gid
  end

  # Delete an user and optionally with its main group, returns the deleted `User`.
  def del_user(uid : UInt32, del_group : Bool = false) : User?
    if user_entry = @users[uid]?
      name = user_entry.name
      gid = user_entry.gid

      @users.delete uid
      @passwords.delete name
      # Delete the user entry in groups where the user is a member
      @groups.each do |id, entry|
        entry.users.delete entry.name
      end
      del_group(gid) if del_group
      user_entry
    end
  end

  # Adds/ensure an user is member of the group. Not needed if the group is the main one of the user.
  def add_group_member(uid : UInt32, gid : UInt32) : Set(String)
    @groups[gid].users << @users[uid].name
  end

  # Delete?/ensure an user isn't a member of the group.
  def del_group_member(uid : UInt32, gid : UInt32) : Set(String)
    @groups[gid].users.delete @users[uid].name
  end

  # Returns `true` if the user is a member of the group or if the group is primary one of the user.
  def user_group_member?(uid : UInt32, gid : UInt32) : Bool
    @users[uid].gid == gid || @groups[gid].users.includes?(@users[uid].name)
  end

  # Get the user's password entry.
  def get_password(uid : UInt32) : Password
    @password[@users[uid].name]
  end

  # Change the user's password entry.
  def change_password(uid : UInt32, password : Password) : Password
    @password[@users[uid].name] = password
  end

  {% for owner in %w(group user) %}
  {% id_type = owner.chars[0].id + "id" %}
  # Returns an {{id_type.id}} matching the name, else raise.
  def to_{{id_type.id}}(name : String) : UInt32
    match_id = nil
    to_{{id_type.id}}(name) do |id|
      raise "multiple {{id_type.id}}s match the name #{name}: #{match_id}, #{id}" if match_id
      match_id = id
    end
    raise "no {{id_type.id}} match the name: #{name}" if !match_id
    match_id
  end

  # Yields each {{id_type.id}} matching the name.
  def to_{{id_type.id}}(name : String, &block)
    {{owner.id}}s.each do |id, obj|
      yield id if obj.name == name
    end
  end

  # Returns an {{id_type.id}} matching the name, if any.
  def to_{{id_type.id}}?(name : String) : UInt32?
    to_{{id_type.id}}(name) { |id| return id }
  end

  # Returns the first available {{id_type.id}}.
  def available_{{id_type.id}}(start : UInt32 = 0_u32) : UInt32
    (start..UInt32::MAX).each do |id|
      return id if !{{owner.id}}s.has_key? id
    end
    raise "the limit of #{UInt32::MAX} for {{id_type.id}} numbers is reached, no ids available"
  end

  # Raise if the {{owner.id}} name is taken.
  def check_available_{{owner.id}}(name : String) : String
    if id = to_{{id_type.id}}?(name)
      raise "{{owner.id}} name `#{name}` already taken: #{id}"
    end
    name
  end

  # Raise if the {{id_type.id}} is taken.
  def check_available_{{id_type.id}}(id : UInt32) : UInt32
    if existing_entry = {{owner.id}}s[id]?
      raise "{{id_type.id}} #{id} already taken: #{existing_entry.name}"
    end
    id
  end
  {% end %}

  # Finds the first available user and group id.
  def available_id(start : UInt32 = 0_u32) : UInt32
    uid = available_uid start
    gid = available_gid start

    return uid if uid == gid
    available_id({uid, gid}.max)
  end

  # Raise if the name is taken.
  def check_available_name(name : String) : String
    check_available_user name
    check_available_group name
  end

  # Raise if an id is taken.
  def check_available_id(id : UInt32) : UInt32
    check_available_gid id
    check_available_uid id
  end

  private def build(entries) : String
    String.build do |str|
      entries.each do |id, entry|
        entry.build id, str
        str << '\n'
      end
    end
  end

  # Builds `passwords` to shadow.
  def build_shadow : String
    build @passwords
  end

  # Builds `users` to passwd.
  def build_passwd : String
    build @users
  end

  # Builds `groups` to group.
  def build_group : String
    build @groups
  end

  # Save the state by writing the files to the file system.
  def write : Nil
    if shadow_file = @shadow_file
      File.write shadow_file.to_s, build_shadow
    end
    if passwd_file = @passwd_file
      File.write passwd_file.to_s, build_passwd
    end
    if group_file = @group_file
      File.write group_file.to_s, build_group
    end
  end
end

require "./user"
require "./group"
require "./password"
