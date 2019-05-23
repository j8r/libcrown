require "./spec_helper"
require "../src/libcrown"
require "file_utils"

describe Libcrown do
  libcrown = Libcrown.new(
    shadow: SHADOW,
    passwd: File.read("/etc/passwd"),
    group: File.read("/etc/group")
  )
  id = libcrown.available_id

  describe "parse and build from file" do
    it "shadow" do
      shadow_temp = File.tempfile "shadow"
      begin
        File.write shadow_temp.path, SHADOW
        librown_shadow = Libcrown.new(shadow_file: Path[shadow_temp.path], passwd_file: nil, group_file: nil)
        librown_shadow.write
        File.read(shadow_temp.path).should eq SHADOW
      ensure
        shadow_temp.delete
      end
    end
    it "passwd" do
      passwd_temp = File.tempfile "passwd"
      begin
        FileUtils.cp "/etc/passwd", passwd_temp.path
        passwd = File.read passwd_temp.path
        librown_passwd = Libcrown.new(shadow_file: nil, passwd_file: Path[passwd_temp.path], group_file: nil)
        librown_passwd.write
        File.read(passwd_temp.path).should eq passwd
      ensure
        passwd_temp.delete
      end
    end
    it "group" do
      group_temp = File.tempfile "group"
      begin
        FileUtils.cp "/etc/group", group_temp.path
        group = File.read group_temp.path
        librown_group = Libcrown.new(shadow_file: nil, passwd_file: nil, group_file: Path[group_temp.path])
        librown_group.write
        File.read(group_temp.path).should eq group
      ensure
        group_temp.delete
      end
    end
  end

  describe "builds from a string" do
    it "shadow file" do
      libcrown_tobuild = Libcrown.new(shadow: SHADOW)
      libcrown_tobuild.build_shadow.should eq SHADOW
    end
    it "passwd file" do
      passwd = File.read("/etc/passwd")
      libcrown_tobuild = Libcrown.new(passwd: passwd)
      libcrown_tobuild.build_passwd.should eq passwd
    end
    it "group file" do
      group = File.read("/etc/group")
      libcrown_tobuild = Libcrown.new(group: group)
      libcrown_tobuild.build_group.should eq group
    end
  end

  describe "check available" do
    it "gid" do
      libcrown.check_available_gid(id).should eq id
    end

    it "uid" do
      libcrown.check_available_uid(id).should eq id
    end

    it "id" do
      libcrown.check_available_id(id).should eq id
    end

    it "user" do
      expect_raises Exception do
        libcrown.check_available_user "root"
      end
    end

    it "group" do
      expect_raises Exception do
        libcrown.check_available_group "root"
      end
    end

    it "name" do
      expect_raises Exception do
        libcrown.check_available_name "root"
      end
    end
  end

  describe "to_uid" do
    it "for one available" do
      libcrown.to_uid("root").should eq 0
    end
    it "for one non-existing" do
      libcrown.to_uid?("-").should be_nil
    end
  end

  describe "to_gid" do
    it "for one available" do
      libcrown.to_gid("root").should eq 0
    end
    it "for one non-existing" do
      libcrown.to_gid?("-").should be_nil
    end
  end

  describe "validate name" do
    it "starting with a dash" do
      expect_raises Exception do
        Libcrown.validate_name "-invalid"
      end
    end

    it "which is too long (> 256 characters)" do
      expect_raises Exception do
        Libcrown.validate_name "a" * 256
      end
    end
  end

  describe "adds" do
    describe "an user" do
      it "without a password" do
        user = Libcrown::User.new "__new_user", 0
        libcrown.add_user(user, id).should eq id
        libcrown.to_uid?("__new_user").should eq id
      ensure
        libcrown.del_user(id).should eq user
      end

      it "with a password" do
        user = Libcrown::User.new "__user_with_password", 0
        libcrown.add_user user, id, Libcrown::Password.new("passw0rd")
        libcrown.passwords[user.name].verify("passw0rd").should be_true
      ensure
        libcrown.del_user(id).should eq user
      end

      it "already existing" do
        user = Libcrown::User.new "__new_user", 0
        libcrown.add_user user, id
        expect_raises Exception do
          libcrown.add_user user, id
        end
      ensure
        libcrown.del_user(id).should eq user
      end

      it "with no existing group" do
        user = Libcrown::User.new "__new_user", id
        expect_raises Exception do
          libcrown.add_user user, id
        end
      ensure
        libcrown.del_user(id).should be_nil
      end
    end

    describe "a group" do
      it "with gid" do
        group_entry = Libcrown::Group.new "__new_group"
        libcrown.add_group group_entry, id
        libcrown.to_gid("__new_group").should eq id
      ensure
        libcrown.del_group(id).should eq group_entry
      end

      it "already present" do
        group_entry = Libcrown::Group.new "__new_group"
        libcrown.add_group group_entry, id
        expect_raises Exception do
          libcrown.add_group group_entry, id
        end
        libcrown.del_group(id).should eq group_entry
      end
    end
  end

  describe "deletes" do
    describe "an user" do
      it "without a group" do
        user = Libcrown::User.new "__user_todelete", 0
        uid = libcrown.add_user user, 99992
      ensure
        del_entry = libcrown.del_user(99992).not_nil!
        del_entry.name.should eq "__user_todelete"
        libcrown.users.has_key?(99992).should be_false
      end

      it "with a group" do
        libcrown.add_group Libcrown::Group.new("__group_todel_2"), 99993
        user = Libcrown::User.new "__user_todel_2", 99993
        uid = libcrown.add_user user, 99993
      ensure
        libcrown.del_user(uid: 99993, del_group: true)
        libcrown.users.has_key?(99993).should be_false
        libcrown.groups.has_key?(99993).should be_false
      end
    end

    describe "a group" do
      it "with gid" do
        group_entry = Libcrown::Group.new "__new_group_to_delete"
        libcrown.add_group group_entry, 99998
      ensure
        libcrown.del_group 99998
        libcrown.to_gid?("__new_group_to_delete").should be_nil
      end
    end
  end

  describe "group member" do
    it "user has the group as primary" do
      libcrown.user_group_member?(0, 0).should be_true
    end

    it "add user" do
      group_entry = Libcrown::Group.new "__new_temp_group"
      libcrown.add_group group_entry, 99996
      libcrown.add_group_member 0, 99996
      libcrown.user_group_member?(0, 99996).should be_true
    ensure
      libcrown.del_group 99996
    end

    it "delete user" do
      group_entry = Libcrown::Group.new "__new_temp_group"
      libcrown.add_group group_entry, 99995
      libcrown.add_group_member 0, 99995
      libcrown.del_group_member 0, 99995
      libcrown.user_group_member?(0, 99995).should be_false
    ensure
      libcrown.del_group 99995
    end
  end
end
