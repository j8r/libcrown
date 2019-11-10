struct Libcrown
  # Reprents a password field. Only `/etc/shadow` is supported to store encrypted password.
  enum PasswordState
    Hashed
    LoginDisabled
    NISServer

    # :nodoc:
    def self.new(password : String) : PasswordState
      case password
      when "x"    then Hashed
      when "*"    then LoginDisabled
      when "*NP*" then NISServer
      else             raise "unsupported password: " + password
      end
    end

    # :nodoc:
    def build : String
      case self
      when Hashed        then ":x:"
      when LoginDisabled then ":*:"
      when NISServer     then ":*NP*:"
      else                    raise "unsupported password: #{self}"
      end
    end
  end
end
