# Part of ~/.local/bin/kitty-shell, see .zshenv: restore the real ZDOTDIR, load the real .zshrc, then the
# fastfetch hook. From here on zsh reads everything (.zlogin, .zsh_history etc.) from the real place again.
_ff_restore_zdotdir
'builtin' 'unfunction' _ff_remember_zdotdir _ff_restore_zdotdir
'builtin' 'unset' _ff_real_zdotdir
[[ ! -r ${ZDOTDIR-~}/.zshrc ]] || 'builtin' 'source' -- ${ZDOTDIR-~}/.zshrc
[[ ! -r $_ff_zdot/fastfetch.zsh ]] || 'builtin' 'source' -- $_ff_zdot/fastfetch.zsh
'builtin' 'unset' _ff_zdot
