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
