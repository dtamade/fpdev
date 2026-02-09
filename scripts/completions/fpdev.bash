#!/bin/bash
# Bash completion script for fpdev
# Install: source scripts/completions/fpdev.bash
# Or copy to /etc/bash_completion.d/fpdev

_fpdev_completions() {
    local cur prev words cword
    _init_completion || return

    local commands="help version fpc lazarus cross package project config doctor default show shell-hook resolve-version"

    local fpc_commands="install uninstall list use current show doctor test update clean help cache"
    local fpc_cache_commands="list stats clean path"

    local lazarus_commands="install uninstall list use current show run test doctor update configure help"

    local cross_commands="list install uninstall enable disable show test configure build doctor help"

    local package_commands="install uninstall update list search info create publish clean install-local repo deps why help"
    local package_repo_commands="add list remove update"

    local project_commands="new list info build run test clean help"

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
                cross|x)
                    COMPREPLY=($(compgen -W "${cross_commands}" -- "${cur}"))
                    ;;
                package|pkg)
                    COMPREPLY=($(compgen -W "${package_commands}" -- "${cur}"))
                    ;;
                project|proj)
                    COMPREPLY=($(compgen -W "${project_commands}" -- "${cur}"))
                    ;;
                help|h|\?)
                    COMPREPLY=($(compgen -W "fpc lazarus cross package project config" -- "${cur}"))
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
                        install|uninstall|use|show|test|update)
                            # Version completion - common versions
                            COMPREPLY=($(compgen -W "3.2.2 3.2.0 3.0.4 main trunk" -- "${cur}"))
                            ;;
                    esac
                    ;;
                package|pkg)
                    case "${subcmd}" in
                        repo)
                            COMPREPLY=($(compgen -W "${package_repo_commands}" -- "${cur}"))
                            ;;
                    esac
                    ;;
                cross|x)
                    case "${subcmd}" in
                        install|uninstall|enable|disable|show|test|configure|build)
                            # Target completion
                            COMPREPLY=($(compgen -W "win64 win32 linux-arm linux-arm64 darwin-x64 darwin-arm64 android-arm android-arm64" -- "${cur}"))
                            ;;
                    esac
                    ;;
                project|proj)
                    case "${subcmd}" in
                        new)
                            # Template completion
                            COMPREPLY=($(compgen -W "console gui library package service daemon" -- "${cur}"))
                            ;;
                    esac
                    ;;
            esac
            ;;
    esac
}

complete -F _fpdev_completions fpdev
