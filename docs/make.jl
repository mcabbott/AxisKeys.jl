using Documenter, DocumenterMarkdown
using AxisKeys, BenchmarkTools

makedocs(
    modules=[AxisKeys],
    clean=true,
    doctest=false,
    #format   = Documenter.HTML(prettyurls = get(ENV, "CI", nothing) == "true"),
    sitename="AxisKeys.jl",
    authors="Michael Abbott et al.",
    strict=[
        :doctest,
        :linkcheck,
        :parse_error,
        :example_block,
        # Other available options are
        # :autodocs_block, :cross_references, :docs_block, :eval_block, :example_block,
        # :footnote, :meta_block, :missing_docs, :setup_block
    ], checkdocs=:all, format=Markdown(), draft=false,
    build=joinpath(@__DIR__, "docs")
)

deploydocs(; repo="https://github.com/mcabbott/AxisKeys.jl", push_preview=true,
    deps=Deps.pip("mkdocs", "pygments", "python-markdown-math", "mkdocs-material",
        "pymdown-extensions", "mkdocstrings", "mknotebooks",
        "pytkdocs_tweaks", "mkdocs_include_exclude_files", "jinja2"),
    make=() -> run(`mkdocs build`), target="site", devbranch="master")