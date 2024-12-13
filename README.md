
# Extended Window Manager

A managed window manager by a TCP stream for kiosks and embedded applications.

## Description

ExtendedWM is a window manager for the X window system protocol. Layout configurations can be made
in a JSON file where applications/windows will automatically be mapped to depending on the current
layout, and layouts can be dynamically selected through the TCP interface of the window manager by
external processes or applications.

For example, a kiosk application with an (idle) advertisement and out-of-order fallback is defined
in the following way:

```json
{
    "default": [
        {
            "titles": "advertisement video 720x405"
            "coordinates": [0, 0, 720, 405]
        },
        {
            "titles": "COMPANY main kiosk",
            "coordinates": [0, 405, 720, 875],
            "fallback_to": "fallback"
        }

    ],
    "idle": [
        {
            "titles": "idle video 720x1280"
            "coordinates": [0, 0, 720, 1280],
            "touch_jump_to": "default",
            "fallback_to": "default"
        }
    ],
    "fallback": []
}
```

The kiosk mapping has a `fallback_to` clause defined. If the currently-selected layout is `default`,
but the kiosk application is missing, the effective layout will be `fallback`. Furthermore, the
kiosk process can detect an idle and instruct ExtendedWM (over TCP) to select the `idle` layout. The
`idle` layout's application has a `touch_jump_to` clause defined that will jump to the `default`
layout when a user's touch was registered.

Currently, applications can only be mapped in an absolute configuration (x, y, width, height). If a
flexible layout must be created where an application can appear and disappear, use two layouts with
a fallback clause.

### TCP API

ExtendedWM opens a TCP server on port `1025`. Currently, only a single connection can be handled a
time. An application can send a JSON message to ExtendedWM to change its current layout:

```json
{ "layout_select": "idle" }
```

### Instantiating the wm

In the `.xinitrc` script which gets called by running `startx` (or any X init process), exec the
window manager with its layout configuration as argument.

```sh
exec /bin/ExtendedWM # uses ./configuration.json
exec /bin/ExtendedWM /Layout/1080x1920.json # specific resolution layout
```

## Development

Commit HEAD compiled with Zig `0.13.0`.

* Xorg (`xorg` on Debian) and an active X session (i.e. with `startx`)
* Xephyr (`xserver-xephyr` on Debian) for hosting the ExtendedWM root window inside an existing X session
* X11 lib (`libx11-dev` on Debian) as compilation dependency
