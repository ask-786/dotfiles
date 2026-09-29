# tmux sessionizer and friends (ported from .zshrc)
fish_add_path --path $HOME/.local/scripts

function __tmux_sessionizer_binding --on-event fish_prompt
    functions -e __tmux_sessionizer_binding
    bind ctrl-f 'tmux-sessionizer; commandline -f repaint'
    bind ctrl-t 'tmux new; commandline -f repaint'
    bind ctrl-n 'nmtui; commandline -f repaint'
end
