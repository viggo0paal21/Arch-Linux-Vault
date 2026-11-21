# Part of ~/.local/bin/kitty-shell: redraw fastfetch to fit the window size as long as no command has run
# in this kitty (so only fastfetch and the prompt are visible). If e.g. a window gets
# smaller because a second one opens, the next smaller variant that fits completely is shown (fastfetch-show).
# If the shown variant still fits, everything stays. Every window keeps its image.
# Live: as long as only fastfetch is visible, the values (time, uptime, RAM, disks ...) are refreshed about once
# a second. Only the text is rewritten, the image stays, the prompt stays as it is
# (synchronized, no flicker). While you type, it waits.
# "fastfetch" without arguments shows it again like at the start (clear screen, the command line disappears)
# and live again.
# After the first command everything stays as it is.
[[ -n ${_FF_RESIZE-} ]] || return 0
'builtin' 'typeset' -g _ff_live=1 _ff_size="$LINES $COLUMNS"
'builtin' 'typeset' -g _ff_wd=${_FF_WD-} _ff_name=${_FF_NAME:--} _ff_src=${_FF_SRC-} _ff_drawn=${_FF_SIZE-}
# "Fastfetch in kitty" off: nothing was shown at the start, only "fastfetch" by hand does it (live etc.)
[[ -n ${_FF_MANUAL-} ]] && _ff_live=
'builtin' 'unset' _FF_RESIZE _FF_WD _FF_NAME _FF_SRC _FF_SIZE _FF_MANUAL

# How many rows the prompt needs (starship e.g. adds an empty line before it). fastfetch-fit uses it,
# so nothing scrolls out of the window at the top after the prompt. The live values need it too (_ff_plines).
'builtin' 'typeset' -g _ff_plines=1
_ff_prompt_lines() {
    'builtin' 'local' p n f=$HOME/.config/fastfetch/.prompt-lines
    _ff_plines=1
    p=$('builtin' 'print' -rP -- "$PS1" 2>/dev/null) || return 0
    n=$(( ${#${p//[^$'\n']}} + 1 ))
    _ff_plines=$n
    [[ -r $f && "$(<$f)" == "$n" ]] || 'builtin' 'print' -r -- "$n" >| $f 2>/dev/null
    return 0
}
_ff_prompt_lines

# $1 = 1: called from a widget (then zle redraws the prompt still inside the synchronized update)
_ff_redraw() {
    'builtin' 'local' inwidget=${1-} res st= out= wd=$_ff_wd n c r best= fast=
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
    _ff_paint_full "$out" "$inwidget"
    return 0
}

# Redraw everything (image and text): synchronized, old images gone, screen and scrollback cleared, output,
# prompt mark for kitty. In a widget zle redraws the prompt before the synchronized update ends.
_ff_paint_full() {
    'builtin' 'printf' '\e[?2026h'
    'builtin' 'zle' && 'builtin' 'zle' -I
    'builtin' 'printf' '%s' $'\e_Ga=d,d=A\e\\\e[H\e[2J\e[3J'"$1"$'\e]133;A\a'
    [[ -n ${2-} ]] && 'builtin' 'zle' -R
    'builtin' 'printf' '\e[?2026l'
}

# ---- Live-Werte ----
# One background job per tick: waits until just after the next full second (so the clock ticks evenly),
# runs the shown variant fresh at the lowest priority (fastfetch-show live) and returns the
# result through a pipe. zle then calls _ff_tick (zle -F), so never in the middle of an input.
# If fastfetch itself takes longer, the tick gets slower accordingly (computing at most ~1/8 of the time).
'builtin' 'zmodload' zsh/datetime 2>/dev/null
'builtin' 'typeset' -g _ff_tick_fd= _ff_tick_key= _ff_gen=0 _ff_ms=0 _ff_full= _ff_count=0 _ff_prompts=0

_ff_tick_stop() {
    (( ++_ff_gen ))
    [[ -n $_ff_wd ]] && 'builtin' 'print' -r -- $_ff_gen >| $_ff_wd/live-gen 2>/dev/null
    if [[ -n $_ff_tick_fd ]]; then
        'builtin' 'zle' -F $_ff_tick_fd 2>/dev/null
        'builtin' 'exec' {_ff_tick_fd}<&-
        _ff_tick_fd=
    fi
    return 0
}

_ff_tick_start() {
    [[ -n $_ff_live && -z $_ff_tick_fd && -n $_ff_wd && $_ff_name != - && -x $HOME/.local/bin/fastfetch-show ]] || return 0
    'builtin' 'local' d=1 now=${EPOCHREALTIME-} full=
    if [[ -n $now ]]; then
        now=${now/,/.}
        d=$(( 1.02 - (now - ${now%.*}) ))
    fi
    (( _ff_ms > 125 )) && d=$(( d + (_ff_ms * 8 < 5000 ? _ff_ms * 8 : 5000) / 1000.0 - 1 ))
    (( d < 0.05 )) && d=0.05
    d=$(( d ))
    # Every now and then (and after Enter without a command or Ctrl+L) redraw everything, so image and prompt are surely right
    if [[ -n $_ff_full ]] || (( ++_ff_count % 60 == 0 )); then full=full; fi
    _ff_full=
    [[ -r $_ff_wd/live-gen && "$(<$_ff_wd/live-gen)" == $_ff_gen ]] || 'builtin' 'print' -r -- $_ff_gen >| $_ff_wd/live-gen 2>/dev/null
    _ff_tick_key="$_ff_name $LINES $COLUMNS"
    'builtin' 'exec' {_ff_tick_fd}< <(
        sleep $d 2>/dev/null || sleep 1
        FF_WD=$_ff_wd exec nice -n 19 $HOME/.local/bin/fastfetch-show live $_ff_name "$_ff_src" $_ff_gen $$ $full 2>/dev/null
    )
    'builtin' 'zle' -F -w $_ff_tick_fd _ff_tick 2>/dev/null || _ff_tick_stop
    return 0
}

_ff_tick() {
    'builtin' 'local' fd=$1 res= st out _ff_in_tick=1
    IFS= 'builtin' 'read' -r -d '' -u $fd res
    'builtin' 'zle' -F $fd 2>/dev/null
    'builtin' 'exec' {fd}<&-
    [[ $fd == $_ff_tick_fd ]] && _ff_tick_fd=
    [[ -n $_ff_live ]] || return 0
    st=${res%%$'\n'*}
    out=${res#*$'\n'}
    'builtin' 'local' -a f
    f=("${(@ps:\t:)st}")
    [[ ${f[3]-} == <-> ]] && _ff_ms=${f[3]}
    # Only if the same variant is still shown at the same window size
    if [[ $_ff_tick_key == "$_ff_name $LINES $COLUMNS" ]]; then
        case ${f[1]-} in
            (live)
                if [[ ${f[2]-} == $_ff_name && -z $BUFFER && ${PENDING:-0} -eq 0 ]]; then
                    # Only the text: clear from the top left (the image stays), new values, prompt mark for kitty
                    # where the prompt starts (like at the start). Then the cursor goes to the last prompt line, because
                    # that's where zle thinks it is: when redrawing, zle goes back from there to the prompt start. Without this
                    # the prompt lands one row too high, zle deletes the mark doing so, and kitty asks before closing.
                    [[ -n $_ff_plines ]] || _ff_prompt_lines
                    'builtin' 'printf' '%s' $'\e[?2026h\e[H\e[J'"$out"$'\e]133;A\a'
                    (( _ff_plines > 1 )) && 'builtin' 'printf' '\e[%dB' $(( _ff_plines - 1 ))
                    'builtin' 'zle' .redisplay
                    'builtin' 'zle' -R
                    'builtin' 'printf' '\e[?2026l'
                fi  # otherwise someone is typing: skip this tick
                ;;
            (full)
                if [[ ${f[2]-} == $_ff_name && -z $BUFFER && ${PENDING:-0} -eq 0 ]]; then
                    _ff_paint_full "$out" 1
                else
                    _ff_full=1
                fi
                ;;
            (refit)
                _ff_redraw 1
                ;;
        esac
    fi
    _ff_tick_start
    return 0
}
'builtin' 'zle' -N _ff_tick

_ff_precmd() {
    # Another prompt without a command (Enter on an empty line): redraw everything on the next tick
    (( _ff_prompts++ )) && _ff_full=1
    _ff_tick_start
}

# "fastfetch" without arguments: like at the start (clear screen, the command line too, matching variant with
# this window's image) and live again. With arguments or redirected: the normal fastfetch.
fastfetch() {
    if (( $# )) || [[ ! -t 1 || -z $_ff_wd || ! -x $HOME/.local/bin/fastfetch-show ]]; then
        'builtin' 'command' fastfetch "$@"
        return
    fi
    'builtin' 'local' res st out
    'builtin' 'local' -a f
    res=$(FF_WD=$_ff_wd "$HOME/.local/bin/fastfetch-show" redraw - "$_ff_src" 2>/dev/null; 'builtin' 'print' -n x)
    res=${res%x}
    st=${res%%$'\n'*}
    if [[ $st != shown$'\t'* ]]; then
        # No variant fits right now: the normal fastfetch
        'builtin' 'command' fastfetch
        return
    fi
    out=${res#*$'\n'}
    f=("${(@ps:\t:)st}")
    _ff_name=${f[2]} _ff_src=${f[3]-}
    'builtin' 'printf' '%s' $'\e[?2026h\e_Ga=d,d=A\e\\\e[H\e[2J\e[3J'"$out"$'\e[?2026l'
    _ff_live=1 _ff_size="$LINES $COLUMNS" _ff_prompts=0 _ff_full= _ff_count=0 _ff_plines=
    add-zsh-hook preexec _ff_preexec
    # Not all variants prepared for this window yet (e.g. "Fastfetch in kitty" off): do it now in the
    # background, at the lowest priority (for an instant redraw on a resize)
    if [[ ! -r $_ff_wd/order ]]; then
        ( sleep 0.5; FF_WD=$_ff_wd exec nice -n 19 "$HOME/.local/bin/fastfetch-show" prerender ) </dev/null >/dev/null 2>&1 &!
    fi
    return 0
}

# Ctrl+L (clear-screen): redraw everything on the next tick (fastfetch on top, prompt below)
_ff_pre_redraw() {
    [[ -z ${_ff_in_tick-} && -n $_ff_live && $LASTWIDGET == *clear-screen* ]] && _ff_full=1
    return 0
}

'builtin' 'autoload' -Uz add-zsh-hook add-zle-hook-widget
_ff_preexec() {
    _ff_live=
    _ff_tick_stop
    add-zsh-hook -d preexec _ff_preexec
}
add-zsh-hook preexec _ff_preexec
add-zsh-hook precmd _ff_precmd
add-zle-hook-widget line-pre-redraw _ff_pre_redraw 2>/dev/null

# An existing TRAPWINCH (e.g. from your own .zshrc) keeps running too
(( ${+functions[TRAPWINCH]} )) && functions[_ff_prev_winch]=$functions[TRAPWINCH]
TRAPWINCH() {
    (( ${+functions[_ff_prev_winch]} )) && _ff_prev_winch "$@"
    [[ -n $_ff_live ]] || return 0
    [[ "$LINES $COLUMNS" != "$_ff_size" ]] || return 0
    _ff_size="$LINES $COLUMNS" _ff_plines=
    _ff_redraw
    _ff_tick_start
    return 0
}

# If the size changed before zsh finished loading: redraw to fit right away
[[ -z $_ff_live || -z $_ff_drawn || $_ff_drawn == "$LINES $COLUMNS" ]] || _ff_redraw
'builtin' 'unset' _ff_drawn
