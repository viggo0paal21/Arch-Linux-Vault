# Part of ~/.local/bin/kitty-shell: redraw fastfetch to fit the window size as long as no command has run
# in this kitty (so only fastfetch and the prompt are visible). If e.g. a window gets
# smaller because a second one opens, the next smaller variant that fits completely is shown (fastfetch-show).
# If the shown variant still fits, everything stays. Every window keeps its image.
# After the first command everything stays as it is.
[[ -n ${_FF_RESIZE-} ]] || return 0
'builtin' 'typeset' -g _ff_live=1 _ff_size="$LINES $COLUMNS"
'builtin' 'typeset' -g _ff_wd=${_FF_WD-} _ff_name=${_FF_NAME:--} _ff_src=${_FF_SRC-} _ff_drawn=${_FF_SIZE-}
'builtin' 'unset' _FF_RESIZE _FF_WD _FF_NAME _FF_SRC _FF_SIZE

# How many rows the prompt needs (starship e.g. adds an empty line before it). fastfetch-fit uses it,
# so nothing scrolls out of the window at the top after the prompt.
() {
    'builtin' 'local' p n f=$HOME/.config/fastfetch/.prompt-lines
    p=$('builtin' 'print' -rP -- "$PS1" 2>/dev/null) || return 0
    n=$(( ${#${p//[^$'\n']}} + 1 ))
    [[ -r $f && "$(<$f)" == "$n" ]] || 'builtin' 'print' -r -- "$n" >| $f 2>/dev/null
    return 0
}

_ff_redraw() {
    'builtin' 'local' res st= out= wd=$_ff_wd n c r best= fast=
    'builtin' 'local' -a f
    # Finish computing first, then draw everything at once.
    # Fast: fastfetch-show has already stored all variants with this window's image
    # (order in "order", size in <variant>.size, finished output in <variant>.fixed).
    if [[ -n $wd && -r $wd/order ]] && 'builtin' 'zmodload' zsh/mapfile 2>/dev/null; then
        fast=1
        for n in ${(f)mapfile[$wd/order]}; do
            [[ -r $wd/$n.size ]] || { fast=; break; }
            'builtin' 'read' -r c r < $wd/$n.size
            if (( c <= COLUMNS && r <= LINES )); then best=$n; break; fi
        done
        if [[ -n $fast ]]; then
            if [[ -z $best ]]; then
                [[ $_ff_name == - ]] && return 0
                st=none
            elif [[ $best == $_ff_name ]]; then
                # The shown variant still fits and no larger one does: do nothing
                return 0
            elif [[ -r $wd/$best.fixed ]]; then
                st=shown out=$mapfile[$wd/$best.fixed] _ff_name=$best
            else
                fast=  # this window's image is not decided yet
            fi
        fi
    fi
    # Otherwise (not everything prepared yet) through fastfetch-show
    if [[ -z $fast ]]; then
        res=$(FF_WD=$wd "$HOME/.local/bin/fastfetch-show" redraw "$_ff_name" "$_ff_src" 2>/dev/null; 'builtin' 'print' -n x)
        res=${res%x}
        st=${res%%$'\n'*}
        if [[ $st == shown$'\t'* ]]; then
            out=${res#*$'\n'}
            f=("${(@ps:\t:)st}")
            _ff_name=${f[2]} _ff_src=${f[3]-} st=shown
        elif [[ $st != none ]]; then
            return 0
        fi
    fi
    [[ $st == none ]] && _ff_name=-
    # Synchronized (kitty only shows the finished picture, no empty intermediate state): old images gone, screen
    # and scrollback cleared (only fastfetch was visible), new variant, then the prompt mark for kitty (otherwise
    # kitty thinks a program is still running when closing)
    'builtin' 'printf' '\e[?2026h'
    'builtin' 'zle' && 'builtin' 'zle' -I
    'builtin' 'printf' '%s' $'\e_Ga=d,d=A\e\\\e[H\e[2J\e[3J'"$out"$'\e]133;A\a\e[?2026l'
    return 0
}

'builtin' 'autoload' -Uz add-zsh-hook
_ff_preexec() {
    _ff_live=
    add-zsh-hook -d preexec _ff_preexec
}
add-zsh-hook preexec _ff_preexec

# An existing TRAPWINCH (e.g. from your own .zshrc) keeps running too
(( ${+functions[TRAPWINCH]} )) && functions[_ff_prev_winch]=$functions[TRAPWINCH]
TRAPWINCH() {
    (( ${+functions[_ff_prev_winch]} )) && _ff_prev_winch "$@"
    [[ -n $_ff_live ]] || return 0
    [[ "$LINES $COLUMNS" != "$_ff_size" ]] || return 0
    _ff_size="$LINES $COLUMNS"
    _ff_redraw
    return 0
}

# If the size changed before zsh finished loading: redraw to fit right away
[[ -z $_ff_drawn || $_ff_drawn == "$LINES $COLUMNS" ]] || _ff_redraw
'builtin' 'unset' _ff_drawn
