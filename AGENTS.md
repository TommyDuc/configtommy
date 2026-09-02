# Agents

## Project Description

This is a config repository for various things like bash, neovim, etc.
Each thing configured have its own top level directory (except for `./bashrc.sh`).
Tools that use a single config file (e.g. starship) still get a top level directory,
but the file itself is symlinked into `~/.config` by its basename.
Configurations are installed with `./install.sh` by using symlinks.
