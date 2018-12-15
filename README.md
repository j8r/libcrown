# Libcrown

Library for Unix users, groups and passwords manipulation.

Can be used to perform actions in Crystal usually done by commands like `adduser`, `deluser`.

## Warning

By essence, manipulating system users, groups and passwords is sensitive. Be careful and be sure of what you do before any action.

This library is provided "as is", with no warranties, as stated in the [ISC LICENSE](LICENSE).

## Installation

Add the dependency to your `shard.yml`:

```yaml
dependencies:
  libcrown:
    github: j8r/libcrown
```

## Usage

To add a new user

```crystal
require "libcrown"

# Root permissions are needed
libcrown = Libcrown.new

# Add a new group
libcrown.add_group Libcrown::Group.new("new_group"), 100_u32

# Add a new user with `new_group` as its main group
new_user = Libcrown::User.new(
  name:           "new_user",
  gid:            100_u32,
  gecos_comment:  "This is a newly created user",
  home_directory: "/home/new_user",
  login_shell:    "/bin/sh",
)
libcrown.add_user new_user

# Save the modifications to the disk
libcrown.write
```

## License

Copyright (c) 2018 Julien Reichardt - ISC License
