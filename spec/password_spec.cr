require "./spec_helper"
require "../../src/password"

describe Libcrown::Password do
  {Libcrown::Password::Encryption::SHA512, Libcrown::Password::Encryption::SHA256, Libcrown::Password::Encryption::MD5}.each do |type|
    it "encrypts a passsword with #{type}" do
      password = "abcd01?"
      crypt = Libcrown::Password.new password, type
      crypt.match?(password).should be_true
      crypt.match?(password + ' ').should be_false
    end
  end
end
