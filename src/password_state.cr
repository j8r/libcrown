# Reprents a password field. only `/etc/shadow` is supported to store encrypted password
enum Libcrown::PasswordState
  Hashed
  LoginDisabled
  NISServer

  def self.new(password : String) : PasswordState
    case password
    when "x"    then Hashed
    when "*"    then LoginDisabled
    when "*NP*" then NISServer
    else             raise "unsupported password: " + password
    end
  end

  def build : String
    case self
    when Hashed        then ":x:"
    when LoginDisabled then ":*:"
    when NISServer     then ":*NP*:"
    else                    raise "unsupported password: #{self}"
    end
  end
end
