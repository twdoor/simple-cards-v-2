#!/usr/bin/env python3
"""Send a real X11 button transition for rendered drag tests (also works in Xvfb)."""
import ctypes
import ctypes.util
import sys

x11_library = ctypes.util.find_library('X11')
xtst_library = ctypes.util.find_library('Xtst')
if not x11_library or not xtst_library:
    raise SystemExit('Rendered mouse tests require the X11 and Xtst libraries; validation does not install system packages.')
x11 = ctypes.CDLL(x11_library)
xtst = ctypes.CDLL(xtst_library)
x11.XOpenDisplay.argtypes = [ctypes.c_char_p]
x11.XOpenDisplay.restype = ctypes.c_void_p
x11.XSync.argtypes = [ctypes.c_void_p, ctypes.c_int]
x11.XCloseDisplay.argtypes = [ctypes.c_void_p]
xtst.XTestFakeButtonEvent.argtypes = [ctypes.c_void_p, ctypes.c_uint, ctypes.c_int, ctypes.c_ulong]
display = x11.XOpenDisplay(None)
if not display:
    raise SystemExit('Rendered mouse tests require an X11 display.')
try:
    if not xtst.XTestFakeButtonEvent(display, 1, int(sys.argv[1]), 0):
        raise SystemExit('XTest button injection failed.')
    x11.XSync(display, 0)
finally:
    x11.XCloseDisplay(display)
