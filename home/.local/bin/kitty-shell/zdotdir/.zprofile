# Part of ~/.local/bin/kitty-shell, see .zshenv: loads the real .zprofile (login shells only)
_ff_restore_zdotdir
[[ ! -r ${ZDOTDIR-~}/.zprofile ]] || 'builtin' 'source' -- ${ZDOTDIR-~}/.zprofile
_ff_remember_zdotdir
ZDOTDIR=$_ff_zdot
