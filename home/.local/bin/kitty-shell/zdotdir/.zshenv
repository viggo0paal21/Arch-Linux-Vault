# Part of ~/.local/bin/kitty-shell (redraw fastfetch to fit the window size).
# kitty-shell/zsh makes zsh read these files first via ZDOTDIR. They load the real ones (~/.zshenv,
# ~/.zprofile, ~/.zshrc or the ones from the real ZDOTDIR), restore ZDOTDIR, and .zshrc adds
# fastfetch.zsh at the end. After that everything is as without this detour (.zlogin etc. come from the real place).

# This folder
'builtin' 'typeset' -g _ff_zdot=${${(%):-%x}:A:h}

# Real ZDOTDIR as at kitty's start (set or not)
if [[ -n ${_FF_ORIG_ZDOTDIR+x} ]]; then
    'builtin' 'export' ZDOTDIR=$_FF_ORIG_ZDOTDIR
else
    'builtin' 'unset' ZDOTDIR
fi
'builtin' 'unset' _FF_ORIG_ZDOTDIR

[[ ! -r ${ZDOTDIR-~}/.zshenv ]] || 'builtin' 'source' -- ${ZDOTDIR-~}/.zshenv

# The real .zshenv may set ZDOTDIR itself: remember what applies now
_ff_remember_zdotdir() {
    if [[ -n ${ZDOTDIR+x} ]]; then
        'builtin' 'typeset' -g _ff_real_zdotdir=$ZDOTDIR
    else
        'builtin' 'unset' _ff_real_zdotdir
    fi
}
_ff_restore_zdotdir() {
    if [[ -n ${_ff_real_zdotdir+x} ]]; then
        ZDOTDIR=$_ff_real_zdotdir
    else
        'builtin' 'unset' ZDOTDIR
    fi
}
_ff_remember_zdotdir

if [[ -o interactive ]]; then
    # So zsh reads our .zprofile/.zshrc next
    ZDOTDIR=$_ff_zdot
else
    # Not interactive (no prompt): nothing else to do
    _ff_restore_zdotdir
    'builtin' 'unfunction' _ff_remember_zdotdir _ff_restore_zdotdir
    'builtin' 'unset' _ff_zdot _ff_real_zdotdir _FF_RESIZE _FF_SIZE _FF_ADVANCED
fi
