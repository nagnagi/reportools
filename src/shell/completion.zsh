_reportools_shorts() {
  local -a shorts
  shorts=(${(f)"$(reportools list --short 2>/dev/null)"})
  _describe -t reports 'report' shorts
}

_reportools() {
  local curcontext="$curcontext" state line
  typeset -A opt_args
  local -a subcommands columns values
  subcommands=(
    'list:show every report, soonest deadline first'
    'at:show the details of one report'
    'get:clone an existing report repository and register it'
    'sync:pull from and push to the upstream repository'
    'init:create a report project and its private repository'
    'add:register an existing report directory'
    'remove:forget a report (its files and repository are kept)'
    'modify:update the details or state of a report'
    'ok:mark a report as finished'
    'export:dump every report as TSV on standard output'
    'config:read or change settings in config.ini'
  )
  columns=(
    '(-t --short)'{-t,--short}'[short name]'
    '(-l --title --long)'{-l,--title,--long}'[title]'
    '(-j --subj --subject)'{-j,--subj,--subject}'[subject]'
    '(-d --in --deadline)'{-d,--in,--deadline}'[deadline]'
    '(-s --state)'{-s,--state}'[state]'
    '--style[project style]'
    '(-p --path)'{-p,--path}'[project directory]'
  )
  values=(
    '(-l --title --long)'{-l,--title,--long}'[title]:title: '
    '(-j --subj --subject)'{-j,--subj,--subject}'[subject]:subject: '
    '(-d --in --deadline)'{-d,--in,--deadline}'[deadline]:YYYY-MM-DD HH\:MM: '
  )

  _arguments -C \
    '(- *)--help[show usage]' \
    '(- *)--version[show version]' \
    '(- *)--env[print shell setup for eval]:shell:(zsh bash)' \
    '1: :->subcommand' \
    '*:: :->arguments' && return

  case $state in
    subcommand)
      _describe -t subcommands 'subcommand' subcommands
      ;;
    arguments)
      case $line[1] in
        list)
          _arguments '--help[show usage]' $columns
          ;;
        at)
          _arguments '--help[show usage]' $columns '1:report:_reportools_shorts'
          ;;
        remove|ok)
          _arguments '--help[show usage]' '1:report:_reportools_shorts'
          ;;
        sync)
          _arguments '--help[show usage]' '(-a --all 1)'{-a,--all}'[every report]' '1:report:_reportools_shorts'
          ;;
        modify)
          _arguments '--help[show usage]' $values \
            '(-s --state)'{-s,--state}'[state]:state:(draft submit resub ok)' \
            '(-p --path)'{-p,--path}'[project directory]:directory:_files -/' \
            '1:report:_reportools_shorts'
          ;;
        init)
          _arguments '--help[show usage]' $values \
            '--style[project style]:style:(typst latex)' \
            '1:short: '
          ;;
        add)
          _arguments '--help[show usage]' $values \
            '(-t --short)'{-t,--short}'[short name]:short: ' \
            '(-s --state)'{-s,--state}'[state]:state:(draft submit resub ok)' \
            '--style[project style]:style:(typst latex)' \
            '1:directory:_files -/'
          ;;
        get)
          _arguments '--help[show usage]' '1:short: '
          ;;
        export)
          _arguments '--help[show usage]'
          ;;
        config)
          _arguments '--help[show usage]' '--list[print every setting]' \
            '1:key:(release.title init.style github.user commit.auto)' \
            '2:value: '
          ;;
      esac
      ;;
  esac
}

if (( $+functions[compdef] )); then
  compdef _reportools reportools rt
fi
