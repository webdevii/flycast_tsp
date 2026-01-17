#!/bin/sh

APPDIR="$(cd "$(dirname "$0")" && pwd)"
BIN="/mnt/SDCARD/Emus/_Emulators/FLYCAST-SA/flycast"
LOG="/mnt/SDCARD/taskmgr_launch.log"
PIDFILE="/tmp/taskmgr.pid"

# Всё, что скрипт мог бы вывести на экран — уходит в лог
exec >>"$LOG" 2>&1

msg() {
  echo "$(date '+%F %T') $*"
}

apply_fb_fix_in() {
  if [ -e /sys/class/graphics/fb0/rotate ]; then
    cat /sys/class/graphics/fb0/rotate 2>/dev/null > /tmp/taskmgr_fb_rotate.prev || true
    echo 0 > /sys/class/graphics/fb0/rotate 2>/dev/null || true
  fi
  if [ -e /sys/class/graphics/fb0/mirror ]; then
    cat /sys/class/graphics/fb0/mirror 2>/dev/null > /tmp/taskmgr_fb_mirror.prev || true
    echo 0 > /sys/class/graphics/fb0/mirror 2>/dev/null || true
  fi
}

apply_fb_fix_out() {
  if [ -e /sys/class/graphics/fb0/rotate ] && [ -f /tmp/taskmgr_fb_rotate.prev ]; then
    PREV="$(cat /tmp/taskmgr_fb_rotate.prev 2>/dev/null || true)"
    rm -f /tmp/taskmgr_fb_rotate.prev 2>/dev/null || true
    [ -n "$PREV" ] && echo "$PREV" > /sys/class/graphics/fb0/rotate 2>/dev/null || true
  fi
  if [ -e /sys/class/graphics/fb0/mirror ] && [ -f /tmp/taskmgr_fb_mirror.prev ]; then
    PREV="$(cat /tmp/taskmgr_fb_mirror.prev 2>/dev/null || true)"
    rm -f /tmp/taskmgr_fb_mirror.prev 2>/dev/null || true
    [ -n "$PREV" ] && echo "$PREV" > /sys/class/graphics/fb0/mirror 2>/dev/null || true
  fi
}

stop_ui() {
  UI_PIDS=""
  for p in minui crossmix menu frontend launcher; do
    P="$(pidof "$p" 2>/dev/null || true)"
    [ -n "$P" ] && UI_PIDS="$UI_PIDS $P"
  done
  echo "$UI_PIDS" > /tmp/taskmgr_ui.pids 2>/dev/null || true
  [ -n "$UI_PIDS" ] && kill -STOP $UI_PIDS 2>/dev/null || true
}

resume_ui() {
  UI_PIDS="$(cat /tmp/taskmgr_ui.pids 2>/dev/null || true)"
  rm -f /tmp/taskmgr_ui.pids 2>/dev/null || true
  [ -n "$UI_PIDS" ] && kill -CONT $UI_PIDS 2>/dev/null || true
}

switch_vt_in() {
  if command -v chvt >/dev/null 2>&1; then
    CUR="$(cat /sys/class/tty/tty0/active 2>/dev/null || true)"
    echo "$CUR" > /tmp/taskmgr_vt.prev 2>/dev/null || true
    chvt 2 2>/dev/null || true
    sleep 0.1
  fi
}

switch_vt_out() {
  if command -v chvt >/dev/null 2>&1; then
    PREV="$(cat /tmp/taskmgr_vt.prev 2>/dev/null || true)"
    rm -f /tmp/taskmgr_vt.prev 2>/dev/null || true
    if [ -n "$PREV" ]; then
      N="$(echo "$PREV" | sed 's/[^0-9]//g')"
      [ -n "$N" ] && chvt "$N" 2>/dev/null || chvt 1 2>/dev/null || true
    else
      chvt 1 2>/dev/null || true
    fi
    sleep 0.1
  fi
}

run_app() {
  [ -x "$BIN" ] || { msg "ERROR: not executable: $BIN"; return 1; }

  export LD_LIBRARY_PATH="$APPDIR/lib:/usr/trimui/lib:$LD_LIBRARY_PATH"
  export SDL_NOMOUSE=1
  export SDL_FBDEV=/dev/fb0
  export TASKMGR_MIRROR_X=0
  export SDL_VIDEODRIVER=mali
  export SDL_RENDER_DRIVER=software

  "$BIN" &
  PID=$!
  echo "$PID" > "$PIDFILE"

  wait "$PID"
  RC=$?

  rm -f "$PIDFILE" 2>/dev/null || true
  return "$RC"
}

# --- main ---
msg "LAUNCH start (pwd=$APPDIR)"
killall sdl2imgshow 2>/dev/null || true

apply_fb_fix_in
switch_vt_in
stop_ui

run_app
RC=$?

resume_ui
switch_vt_out
apply_fb_fix_out

msg "LAUNCH end rc=$RC"
exit 0
