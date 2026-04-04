#!/bin/bash
# Bash completion script for fpdev
# Install: source scripts/completions/fpdev.bash
# Or copy to /etc/bash_completion.d/fpdev

_fpdev_completions() {
    local cur prev words cword
    _init_completion || return

    local commands="fpc lazarus cross package project system"

    local fpc_commands="install uninstall list use current show doctor test verify auto-install update update-manifest help cache policy"
    local fpc_cache_commands="list stats clean path"
    local fpc_policy_commands="check"

    local lazarus_commands="install uninstall list use current show run test doctor update configure help"

    local cross_commands="list install uninstall enable disable show test configure update clean build doctor help"
    local system_commands="help version repo config env index cache doctor perf toolchain"
    local system_env_commands="data-root vars path export hook resolve"
    local system_repo_commands="add list remove show use versions help"
    local system_config_commands="show get set export import list"
    local system_index_commands="status show update"
    local system_cache_commands="status stats path"
    local system_perf_commands="clear report save summary"
    local system_toolchain_commands="check self-test fetch extract ensure-source import-bundle"

    local package_commands="install uninstall update list search info publish clean install-local repo deps why help"
    local package_repo_commands="add list remove update"

    local project_commands="new list info build run test clean template help"
    local project_template_commands="list install remove update"

    case "${cword}" in
        1)
            COMPREPLY=($(compgen -W "${commands}" -- "${cur}"))
            ;;
        2)
            case "${prev}" in
                fpc)
                    COMPREPLY=($(compgen -W "${fpc_commands}" -- "${cur}"))
                    ;;
                lazarus)
                    COMPREPLY=($(compgen -W "${lazarus_commands}" -- "${cur}"))
                    ;;
                cross)
                    COMPREPLY=($(compgen -W "${cross_commands}" -- "${cur}"))
                    ;;
                package)
                    COMPREPLY=($(compgen -W "${package_commands}" -- "${cur}"))
                    ;;
                project)
                    COMPREPLY=($(compgen -W "${project_commands}" -- "${cur}"))
                    ;;
                system)
                    COMPREPLY=($(compgen -W "${system_commands}" -- "${cur}"))
                    ;;
            esac
            ;;
        3)
            local cmd="${words[1]}"
            local subcmd="${words[2]}"
            case "${cmd}" in
                fpc)
                    case "${subcmd}" in
                        cache)
                            COMPREPLY=($(compgen -W "${fpc_cache_commands}" -- "${cur}"))
                            ;;
                        policy)
                            COMPREPLY=($(compgen -W "${fpc_policy_commands}" -- "${cur}"))
                            ;;
                        install|uninstall|use|show|test|verify|update)
                            # Version completion - common versions
                            COMPREPLY=($(compgen -W "3.2.2 3.2.0 3.0.4 main trunk" -- "${cur}"))
                            ;;
                    esac
                    ;;
                package)
                    case "${subcmd}" in
                        repo)
                            COMPREPLY=($(compgen -W "${package_repo_commands}" -- "${cur}"))
                            ;;
                    esac
                    ;;
                cross)
                    case "${subcmd}" in
                        install|uninstall|enable|disable|show|test|configure|update|clean|build)
                            # Target completion
                            COMPREPLY=($(compgen -W "win64 win32 linux-arm linux-arm64 darwin-x64 darwin-arm64 android-arm android-arm64" -- "${cur}"))
                            ;;
                    esac
                    ;;
                system)
                    case "${subcmd}" in
                        config)
                            COMPREPLY=($(compgen -W "${system_config_commands}" -- "${cur}"))
                            ;;
                        index)
                            COMPREPLY=($(compgen -W "${system_index_commands}" -- "${cur}"))
                            ;;
                        cache)
                            COMPREPLY=($(compgen -W "${system_cache_commands}" -- "${cur}"))
                            ;;
                        perf)
                            COMPREPLY=($(compgen -W "${system_perf_commands}" -- "${cur}"))
                            ;;
                        toolchain)
                            COMPREPLY=($(compgen -W "${system_toolchain_commands}" -- "${cur}"))
                            ;;
                        env)
                            COMPREPLY=($(compgen -W "${system_env_commands}" -- "${cur}"))
                            ;;
                        repo)
                            COMPREPLY=($(compgen -W "${system_repo_commands}" -- "${cur}"))
                            ;;
                    esac
                    ;;
                project)
                    case "${subcmd}" in
                        new|info)
                            # Template completion
                            COMPREPLY=($(compgen -W "console gui library package service game" -- "${cur}"))
                            ;;
                        template)
                            COMPREPLY=($(compgen -W "${project_template_commands}" -- "${cur}"))
                            ;;
                    esac
                    ;;
            esac
            ;;
    esac
}

complete -F _fpdev_completions fpdev
