"""
Applet: Day Night Map (wide)
Summary: Day & Night World Map
Description: A map of the Earth showing the day and the night. The map is based on Equirectangular (0°) by Tobias Jung (CC BY-SA 4.0).
Author: Henry So, Jr.
"""

# Day & Night World Map
# Version 1.1.0
#
# Copyright (c) 2022 Henry So, Jr.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# See comments in the code for further attribution

load("encoding/base64.star", "base64")
load("encoding/json.star", "json")
load("math.star", "math")
load("render.star", "render")
load("schema.star", "schema")
load("time.star", "time")

WIDTH = 128
HALF_W = WIDTH // 2
HEIGHT = 64
HALF_H = HEIGHT // 2
HDIV = 360 / WIDTH
HALF_HDIV = HDIV / 2
COEF = 360 / 365.24
DATE_H = 7

CHAR_W = 9
SEP_W = 3

def main(config):
    location = config.get("location")

    #print(location)
    location = json.decode(location) if location else {}
    time_format = TIME_FORMATS.get(config.get("time_format"))
    blink_time = config.bool("blink_time")
    show_date = config.bool("show_date")

    tz = location.get(
        "timezone",
        config.get("$tz", DEFAULT_TIMEZONE),
    )

    tm = config.get("force_time")
    if tm:
        tm = time.parse_time(tm).in_location(tz)
    else:
        tm = time.now().in_location(tz)

    if config.bool("center_location"):
        map_offset = -round(float(location.get("lng", "0")) * HALF_W / 180)
    else:
        map_offset = 0

    #print(map_offset)

    formatted_date = tm.format("Mon 2 Jan 2006")
    date_shadow = render.Row(
        main_align = "center",
        expanded = True,
        children = [
            render.Text(
                content = formatted_date,
                font = "tom-thumb",
                color = "#000",
            ),
        ],
    )

    night_above, sunrise = sunrise_plot(tm)
    return render.Root(
        delay = 1000,
        child = render.Stack([
            render.Padding(
                pad = (map_offset, 0, 0, 0),
                child = render.Image(MAP),
            ),
            render.Padding(
                pad = (
                    map_offset + (-WIDTH if map_offset > 0 else WIDTH),
                    0,
                    0,
                    0,
                ),
                child = render.Image(MAP),
            ) if map_offset != 0 else None,
            render.Row([
                render.Padding(
                    pad = (0, y if night_above else 0, 0, 0),
                    child = render.Image(
                        src = PIXEL,
                        width = 1,
                        height = HEIGHT - y if night_above else y,
                    ),
                )
                for i in range(WIDTH)
                for y in [sunrise[(i - map_offset) % WIDTH]]
            ]),
            render.Column(
                main_align = "center",
                expanded = True,
                children = [
                    render.Row(
                        main_align = "center",
                        expanded = True,
                        children = [
                            render.Animation([
                                render_time(tm, time_format[0]),
                                render_time(tm, time_format[1]) if blink_time else None,
                            ]),
                            render.Padding(
                                pad = (1, 9, 0, 0),
                                child = render.Image(AM_PM[tm.hour < 12]),
                            ) if time_format[2] else None,
                        ],
                    ),
                    render.Box(
                        width = WIDTH,
                        height = 3,
                    ) if show_date else None,
                ],
            ) if time_format else None,
            render.Padding(
                pad = (0, HEIGHT - DATE_H, 0, 0),
                child = render.Stack([
                    render.Padding(
                        pad = (-1, 1, 0, 0),
                        child = date_shadow,
                    ),
                    render.Padding(
                        pad = (2, 1, 0, 0),
                        child = date_shadow,
                    ),
                    render.Padding(
                        pad = (0, 0, 0, 0),
                        child = date_shadow,
                    ),
                    render.Padding(
                        pad = (0, 2, 0, 0),
                        child = date_shadow,
                    ),
                    render.Padding(
                        pad = (0, 1, 0, 0),
                        child = render.Row(
                            main_align = "center",
                            expanded = True,
                            children = [
                                render.Text(
                                    content = formatted_date,
                                    font = "tom-thumb",
                                    color = "#ff0",
                                ),
                            ],
                        ),
                    ),
                ]),
            ) if show_date else None,
        ]),
    )

def get_schema():
    return schema.Schema(
        version = "1",
        fields = [
            schema.Location(
                id = "location",
                name = "Location",
                desc = "Location for the display of date/time.",
                icon = "locationDot",
            ),
            schema.Toggle(
                id = "center_location",
                name = "Center On Location",
                desc = "Whether to center the map on the location.",
                icon = "compress",
                default = False,
            ),
            schema.Dropdown(
                id = "time_format",
                name = "Time Format",
                desc = "The format used for the time.",
                icon = "clock",
                default = "omit",
                options = [
                    schema.Option(
                        display = format,
                        value = format,
                    )
                    for format in TIME_FORMATS
                ],
            ),
            schema.Toggle(
                id = "blink_time",
                name = "Blinking Time Separator",
                desc = "Whether to blink the colon between hours and minutes.",
                icon = "asterisk",
                default = False,
            ),
            schema.Toggle(
                id = "show_date",
                name = "Date Overlay",
                desc = "Whether the date overlay should be shown.",
                icon = "calendarCheck",
                default = False,
            ),
        ],
    )

def sunrise_plot(tm):
    tm = tm.in_location("UTC")
    anchor = time.time(
        year = tm.year,
        month = 1,
        day = 1,
        location = "UTC",
    )
    days = int((tm - anchor).hours // 24)

    tan_dec = TAN_DEC[days]
    tau = 15 * (tm.hour + tm.minute / 60) - 180

    # Use the sunrise equation to compute the latitude
    # See https://en.wikipedia.org/wiki/Position_of_the_Sun
    def lat(lon):
        return atan(-cos(lon + tau) / tan_dec)

    return (
        tan_dec > 0,
        [
            HALF_H - round(lat(lon) * HALF_H / 90)
            #lat(lon)
            for lon in LONGITUDES
        ],
    )

def sin(degrees):
    return math.sin(math.radians(degrees))

def cos(degrees):
    return math.cos(math.radians(degrees))

def tan(degrees):
    return math.tan(math.radians(degrees))

def asin(x):
    return math.degrees(math.asin(x))

def atan(x):
    return math.degrees(math.atan(x))

def round(x):
    return int(math.round(x))

def render_time(tm, format):
    formatted_time = tm.format(format)
    offset = 5 - len(formatted_time)
    offset_pad = pad_of(offset)
    return render.Stack([
        render.Padding(
            pad = (pad_of(i + offset) - offset_pad, 0, 0, 0),
            child = render.Image(CHARS[c]),
        )
        for i, c in enumerate(formatted_time.elems())
        if c != " "
    ])

def pad_of(i):
    if i > 2:
        return (i - 1) * CHAR_W + SEP_W
    elif i > 0:
        return i * CHAR_W
    else:
        return 0

# Pre-compute the tangent to the declination of the sun
# See https://en.wikipedia.org/wiki/Position_of_the_Sun
TAN_DEC = [
    tan(asin(sin(-23.44) * cos(
        COEF * (d + 10) +
        (360 / math.pi * 0.0167 * sin(COEF * (d - 2))),
    )))
    for d in range(366)
]

LONGITUDES = [
    (x - HALF_W) * HDIV + HALF_HDIV
    for x in range(WIDTH)
]

DEFAULT_TIMEZONE = "America/New_York"

TIME_FORMATS = {
    "omit": None,
    "12-hour": ("3:04", "3 04", True),
    "24-hour": ("15:04", "15 04", False),
}

CHARS = {
    "0": base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAAAoAAAAQAgMAAABSEQbTAAAACVBMVEUAAAAAAAD//wCu3yBfAAAA
AXRSTlMAQObYZgAAACBJREFUCNdjYAxhYGBbycAgFeXAkMk2gSgMUgvSA9QLAKtLDWcg9zY2AAAA
AElFTkSuQmCC
"""),
    "1": base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAAAoAAAAQAgMAAABSEQbTAAAACVBMVEUAAAAAAAD//wCu3yBfAAAA
AXRSTlMAQObYZgAAAClJREFUCNdjYAhgYGBcwsDABsRSQJwJxKJLIGK4sOhSB4asVRMYREMdAFsh
C+/brVnSAAAAAElFTkSuQmCC
"""),
    "2": base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAAAoAAAAQAgMAAABSEQbTAAAACVBMVEUAAAAAAAD//wCu3yBfAAAA
AXRSTlMAQObYZgAAADVJREFUCNdjYAxhYGBbycAgFeXAkMk2gUEEiBlgWMqBgSGTgYFxCQqXITPU
gSFr1QQG0VAHADcPCpvNILtaAAAAAElFTkSuQmCC
"""),
    "3": base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAAAoAAAAQAgMAAABSEQbTAAAACVBMVEUAAAAAAAD//wCu3yBfAAAA
AXRSTlMAQObYZgAAADdJREFUCNdjEA11YMhaNYFBNGwCA4OUAwNDJgMD4xIGBraVQDoKyGebAMci
QJwJxFJAcbB8CAMAe1kLH6u//1EAAAAASUVORK5CYII=
"""),
    "4": base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAAAoAAAAQAgMAAABSEQbTAAAACVBMVEUAAAAAAAD//wCu3yBfAAAA
AXRSTlMAQObYZgAAADBJREFUCNdjYBBhYGDIhGDGJRDMNhWIZzkwSEVBcKYUEAPprFUTGESBNIMU
FLMyAAAufAnmFFlNYwAAAABJRU5ErkJggg==
"""),
    "5": base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAAAoAAAAQAgMAAABSEQbTAAAACVBMVEUAAAAAAAD//wCu3yBfAAAA
AXRSTlMAQObYZgAAADZJREFUCNdjEA11YMhaNYEhE0hnMjBAcAgDQ9ZKBgbRKAcGBrYJcCwCxJlA
LAUUZwPKM4YwAACW7wvBgXaX4AAAAABJRU5ErkJggg==
"""),
    "6": base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAAAoAAAAQAgMAAABSEQbTAAAACVBMVEUAAAAAAAD//wCu3yBfAAAA
AXRSTlMAQObYZgAAADNJREFUCNdjYAhhYGBcycDANoWBQcqBgSGTAYiBYllAscwoB4ZMtgkYWAoo
zgaUZwxhAABkVQvi4c4RfwAAAABJRU5ErkJggg==
"""),
    "7": base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAAAoAAAAQAgMAAABSEQbTAAAACVBMVEUAAAAAAAD//wCu3yBfAAAA
AXRSTlMAQObYZgAAACpJREFUCNdjEA11YMhaNYFBNGwCAwMbEEs5QHAmAxgzLoFgtgmYmNGBAQBj
PAnf/Sy1fwAAAABJRU5ErkJggg==
"""),
    "8": base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAAAoAAAAQAgMAAABSEQbTAAAACVBMVEUAAAAAAAD//wCu3yBfAAAA
AXRSTlMAQObYZgAAACFJREFUCNdjYAxhYGBbycAgFeXAkMk2AY5BfGziyHJAvQCM7gyBEuAcCAAA
AABJRU5ErkJggg==
"""),
    "9": base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAAAoAAAAQAgMAAABSEQbTAAAACVBMVEUAAAAAAAD//wCu3yBfAAAA
AXRSTlMAQObYZgAAADVJREFUCNdjYAxhYGBbycAgFeXAkMk2AQNLhU1gYFs1gYERSDMA+QxSDgyM
mUDmEgYGxgAGAJsMDDArz8tGAAAAAElFTkSuQmCC
"""),
    ":": base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAAAQAAAAQAgMAAABM2DZgAAAACVBMVEUAAAAAAAD//wCu3yBfAAAA
AXRSTlMAQObYZgAAABRJREFUCNdjYIACEYZMIBRBYQEBAB1sAfXTJxecAAAAAElFTkSuQmCC
"""),
}

AM_PM = {
    True: base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAAAwAAAAHAgMAAABB3ES3AAAACVBMVEUAAAAAAAD//wCu3yBfAAAA
AXRSTlMAQObYZgAAACNJREFUCNdjYGVhYZCKlGRInZXJkDpzJkPWzEggLckg4MICAFINBmTAfA6Y
AAAAAElFTkSuQmCC
"""),
    False: base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAAAwAAAAHAgMAAABB3ES3AAAACVBMVEUAAAAAAAD//wCu3yBfAAAA
AXRSTlMAQObYZgAAACNJREFUCNdjEGVhYciKlGRInZXJkDpzJpAdyZAqKckgwMICAFTtBcSrM+2h
AAAAAElFTkSuQmCC
"""),
}

PIXEL = base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVQI12NgaAAAAIMAgR+3QgAA
AAAASUVORK5CYII=
""")

# The following Base64-encoded image is a scaled-down version of
# Equirectangular (0°) by Tobias Jung
# found at https://map-projections.net/single-view/rectang-0:flat-stf
# This image released under the CC BY-SA 4.0 International license
MAP = base64.decode("""
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
""")
