module RegistryCLI
using ArgParse: ArgParse, ArgParseSettings, @add_arg_table!
using LibGit2: LibGit2, GitRepo, GitRemote, GitCommit, GitHash, GitObject
using LocalRegistry
using Mustache

# Create a new local Registry:
#
# - make a local clone of the public Registry (which should be initially empty)
# - prepare a commit in the local clone, initializing the Registry
#
# Everything made in the local clone of the Registry should be manually
# inspected before being pushed to the public Registry.

function arg_table_create!(s)
    @add_arg_table! s["create"] begin
        "URL"
        #==# help = "public URL of the Registry (should be an empty git repo)"
        #==# required = true

        "PATH"
        #==# help = "where a local clone of the Registry should be created"
        #==# required = true

        "--description"
        #==# help = "description of the Registry"
    end
end

function create(args)
    verbose = args[:verbose]
    url     = args[:create][:URL]
    path    = args[:create][:PATH] |> abspath
    desc    = args[:create][:description]

    verbose && @info "Creating and populating local clone for registry" url path
    LocalRegistry.create_registry(path, url; description=desc)
end

# Publish a new package version in the Registry.
#
# This function should be called from a local clone of the public Registry; a
# commit will be added to it to register the new package version.
#
# Everything made in the local clone of the Registry should be manually inspected
# before being pushed to the public Registry.

function arg_table_add!(s)
    @add_arg_table! s["add"] begin
        "URL"
        #==# help = "public URL of the package"
        #==# required = true

        "--ref"
        #==# help = "git reference identifying the version to publish"
    end
end

function add(args)
    verbose = args[:verbose]
    url     = args[:add][:URL]
    gitref  = args[:add][:ref]

    # Check that pwd() is a clone of a Julia Registry
    try
        repo = GitRepo(pwd())
        reg_url = LibGit2.get(GitRemote, repo, "origin") |> LibGit2.url
        @assert isfile("Registry.toml")
        verbose && @info "Registry" url=reg_url path=pwd()
    catch
        @error "Not in the git repository of a Registry"
        return 1
    end

    verbose && @info "Releasing new version of package" url gitref

    Base.Filesystem.mktempdir() do dir
        path = joinpath(dir, "package")

        verbose && @info "Cloning package repository"
        repo = LibGit2.clone(url, path)

        if gitref !== nothing
            verbose && @info "Checking out requested commit"
            commit = LibGit2.peel(GitCommit, GitObject(repo, gitref))
            LibGit2.checkout!(repo, string(GitHash(commit)))
        end

        verbose && @info "Registering new version in the registry"
        LocalRegistry.register(path, registry = pwd())
    end

    return 0
end


# Main entry point

function parse_args(args)
    function exc_handler(settings::ArgParseSettings, err, err_code::Int = 1)
        @error err.text
        ArgParse.show_help(stderr, settings; exit_when_done=false)
        exit(err_code)
    end

    s = ArgParseSettings(
        prog = "jlreg",
        description = "Manage a local Julia Registry from the command line.",
        exit_after_help = false,
        exc_handler = exc_handler
    )

    @add_arg_table! s begin
        "create"
        #==# help = "Create and populate a local clone of a new, empty Registry"
        #==# action = :command

        "add"
        #==# help = "Publish a new version of a package in the Registry"
        #==# action = :command

        "--verbose", "-v"
        #==# help = "Print informative messages at each step"
        #==# action = :store_true
    end

    arg_table_create!(s)
    arg_table_add!(s)

    ArgParse.parse_args(args, s, as_symbols=true)
end

function main(clargs :: Vector{<:AbstractString})
    args = parse_args(clargs)

    # --help: nothing more to do
    args === nothing && return

    # command: call the relevant function
    getfield(@__MODULE__, args[:_COMMAND_])(args)
end

function main(clargs...)
    main(collect(clargs))
end




"""
    RegistryCLI.install(; kwargs)

Install the `jlreg` script for use in a terminal.

*Keyword arguments:*
- `julia`: path to the julia executable. Defaults to the currently running julia.
- `flags`: command-line flags for julia. Defaults to `--color=yes --startup-file=no --compile=min -O0`.
- `destdir`: directory where to install the executable script. Should be writable and available in PATH. Defaults to `~/.julia`.
- `command`: name of the executable script. Defaults to `jlreg`.
- `perms`: permissions of the executable script. Defaults to `0o755` (i.e. "-rwxr-xr-x").
- `force`: allow overwriting an existing file. Defaults to `false`.
"""
function install(;
                 julia::String   = first(Base.julia_cmd()),
                 flags::String   = "--color=yes --startup-file=no --compile=min -O0",
                 destdir::String = joinpath(first(DEPOT_PATH), "bin"),
                 command::String = "jlreg",
                 perms::Integer  = 0o755,
                 force::Bool     = false,
                 )
    if Sys.iswindows()
        @error "RegistryCLI does not (yet) support installing the command-line script on Windows systems."
    end

    destdir = abspath(expanduser(destdir))
    script  = joinpath(destdir, command)
    if ispath(script) && !force
        @error("Refusing to overwrite existing file. Use `RegistryCLI.install(force=true)` to force overwriting.",
               dest=script)
        return
    end

    mkpath(destdir)
    open(script, "w") do f
        tmpl = Mustache.load(joinpath(@__DIR__, "..", "bin", "jlreg-bash"))
        write(f, render(tmpl, Dict(
            :JULIA   => julia,
            :FLAGS   => flags,
            :COMMAND => command,
            :DESTDIR => destdir,
            :PROJECT => joinpath(@__DIR__, ".."),
        )))
    end
    chmod(script, perms)

    @info "Installed Registry CLI to `$script`"
end

end # module
