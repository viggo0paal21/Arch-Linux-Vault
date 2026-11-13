# Renderer for Quickshell (Settings > Behavior > Renderer). Sourced by ~/.local/bin/qs-start and the
# wrappers ~/.local/bin/qs and ~/.local/bin/quickshell before Quickshell starts.
# Vulkan (default) or OpenGL, saved as "renderBackend" in the settings.
_qs_settings="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/by-shell/oled-bw/settings.json"
_qs_backend=vulkan
if grep -qE '"renderBackend"[[:space:]]*:[[:space:]]*"opengl"' "$_qs_settings" 2>/dev/null; then
    _qs_backend=opengl
fi
# For testing: QS_FORCE_BACKEND=opengl|vulkan takes precedence
[ -n "$QS_FORCE_BACKEND" ] && _qs_backend="$QS_FORCE_BACKEND"
export QSG_RHI_BACKEND="$_qs_backend"
unset _qs_settings _qs_backend
# Big images (e.g. 11520 x 11520) in the previews of Settings > Commands > Fastfetch images:
# otherwise Qt rejects every image that needs more than 256 MB to load. Value in MB.
export QT_IMAGEIO_MAXALLOC=1024
