using RegistryCLI: main
using LibGit2
using Test

function grep(str, file)
    contents = read(file) |> String
    findfirst(str, contents) !== nothing
end

function count_commits(path)
    repo   = LibGit2.GitRepo(path)
    walker = LibGit2.GitRevWalker(repo)
    LibGit2.count(walker) do _...
        true
    end
end

@testset "RegistryCLI" begin
    main("-h")

    Base.Filesystem.mktempdir() do tmpdir
        reg_url  = joinpath(tmpdir, "registry_public.git")  # Public registry URL
        reg_path = joinpath(tmpdir, "registry_local")       # Path to local clone

        # Create git repo for the public Registry
        LibGit2.init(#=path=# reg_url,
                     #=bare=# true)

        # Initialize public Registry
        main("create", "--help")
        main("-v", "create", reg_url, reg_path,
             "--description", "Test registry")

        @test isfile(joinpath(reg_path, "Registry.toml"))
        @test count_commits(reg_path) == 1

        # Register package
        main("add", "--help")
        cd(reg_path) do
            main("-v", "add", "https://github.com/JuliaLang/Example.jl.git",
                 "--ref", "v0.5.3")
        end

        versions = joinpath(reg_path, "E", "Example", "Versions.toml")
        @test isfile(versions)
        @test grep("""["0.5.3"]""", versions)
        @test count_commits(reg_path) == 2

        cd(reg_path) do
            main("-v", "add", "https://github.com/JuliaLang/Example.jl.git",
                 "--ref", "29aa1b4") # v0.5.3, again
        end

        @test count_commits(reg_path) == 2

        cd(reg_path) do
            main("-v", "add", "https://github.com/JuliaLang/Example.jl.git")
        end

        @test count_commits(reg_path) == 3

        cd(reg_path) do
            main("-v", "add", "https://github.com/JuliaLang/Example.jl.git",
                 "--ref", "master") # latest version, again
        end

        @test count_commits(reg_path) == 3
    end
end
