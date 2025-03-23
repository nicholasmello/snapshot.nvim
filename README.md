# snapshot.nvim

A Neovim plugin to create a snapshot of your neovim config that can be used
offline.

## Installation

Install using your favorite plugin manager

### lazy.nvim

```lua
{
  'nicholasmello/snapshot.nvim',
  opts = {}
}
```

## Usage

A new command is added, `:Snapshot` which will create a tar file named with the
current date and time containing your config and dependencies at the location
`output_dir`. The default location is `~/tmp/`.

This file can be copied to another machine and extracted. The included
`unpack.sh` script which is bundled in the tar file will put the config and
dependencies in the correct place to work without an internet connection.

## Configuration

Configuration can be passed to the setup function. Here is an example with the
default options:

```lua
require('snapshot').setup {
  output_dir = "~/tmp/"
}
```
