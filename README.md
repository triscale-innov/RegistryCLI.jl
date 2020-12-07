# RegistryCLI

This package provides `jlreg`, a very lightweight tool helping manage private
Julia registries from the command line. It heavily relies on
[LocalRegistry.jl](https://github.com/GunnarFarneback/LocalRegistry.jl), which
actually performs all the registry bookkeeping.

## Installation

1. Install the `RegistryCLI` package from julia's package manager:

   ```
   pkg> add RegistryCLI
   ```
   
1. Install the command-line interface:

   ```
   julia> import RegistryCLI; RegistryCLI.install()
   [ Info: Installed jlreg to `/home/francois/.julia/bin/jlreg`
   ```

    Optional arguments can be provided to fine-tune the behavior of
    `RegistryCLI.install`. From the docstring:
    
   ```
   help?> RegistryCLI.install
     RegistryCLI.install(; kwargs)
   
     Install the jlreg script for use in a terminal.
   
     Keyword arguments:

       •    julia: path to the julia executable. Defaults to the currently running julia.
   
       •    flags: command-line flags for julia. Defaults to --color=yes --startup-file=no --compile=min -O0.
   
       •    destdir: directory where to install the executable script. Should be writable and available in PATH. Defaults to ~/.julia.
   
       •    command: name of the executable script. Defaults to jlreg.
   
       •    perms: permissions of the executable script. Defaults to 0o755 (i.e. "-rwxr-xr-x").
   
       •    force: allow overwriting an existing file. Defaults to false.
   ```

1. Ensure that the script directory (`destdir` above, by default `~/.julia/bin`)
   is available in the `PATH`. Add it if necessary:
   
   ```
   shell$ export PATH=$PATH:$HOME/.julia/bin
   ```

## Usage

```
$ jlreg --help
usage: jlreg [-v] [-h] {create|add}

Manage a local Julia Registry from the command line.

commands:
  create         Create a new, empty Registry
  add            Add a new version of a package in the Registry

optional arguments:
  -v, --verbose
  -h, --help     show this help message and exit
```

### Create a private registry

1. Create a git repository to host the registry. This repo should initially be
   empty, and should be accessible to anyone in your organization. In the
   following, `REG_URL` refers to the URL of this repo.
   
1. Choose a local path on your machine, where a clone of the registry will be
   downloaded. This local clone is where every change made by `jlreg` will
   happen; it is expected that the commits made automatically to this local
   clone are checked before being pushed to the "real" registry. In the
   following, `REG_PATH` refers to the path to the local registry clone. Do not
   create the clone yourself; instead, use `jlreg` to do it:
   ```
   $ jlreg create REG_URL REG_PATH
   [ Info: Created registry in directory REG_PATH
   ```

1. Check that the initial commit in `REG_PATH` is sane, before pushing it to the
   "real" registry:
   ```
   $ cd REG_PATH
   $ git push origin master
   ```

### Publish a new (version of a) package

1. The steps described here should be performed from within the local registry
   clone. If you still have a local clone from the previous step, simply `cd` to
   it. If not, just locally clone the registry:
   ```
   $ git clone REG_URL REG_PATH
   $ cd REG_PATH
   ```

1. Registering a new package in the registry or registering a new version of an
   existing package is performed in the same way. In the following, `PACKAGE_URL`
   refers to the URL of the git repository hosting the package to be registered.
   ```
   $ jlreg add PACKAGE_URL
   ┌ Info: Registering package
   │   package_path = "/tmp/jl_EV3XPI/package"
   │   package_repo = "PACKAGE_URL"
   │   registry_path = "REG_PATH"
   │   uuid = UUID("7876af07-990d-54b4-ab0e-23690620f79a")
   │   version = v"0.5.4"
   │   tree_hash = "837d87d3b25c237b06c6e468be3d147a242be7a8"
   └   subdir = ""
   ```

1. As always, a commit should have been added in the local registry
   clone. Please inspect it carefully before pushing it to the "real" registry:
   ```
   $ git push origin master
   ```


## Reference

Check the inline help in order to get the full list of available options:
```
$ jlreg create --help
usage: jlreg create [--description DESCRIPTION] [-h] URL PATH

positional arguments:
  URL         public URL of the Registry (should be an empty git repo)
  PATH        where a local clone of the Registry should be created

optional arguments:
  --description DESCRIPTION
              description of the Registry
  -h, --help  show this help message and exit




$ jlreg add --help
usage: jlreg add [--ref REF] [-h] URL

positional arguments:
  URL         public URL of the package

optional arguments:
  --ref REF   git reference identifying the version to publish
  -h, --help  show this help message and exit
```
