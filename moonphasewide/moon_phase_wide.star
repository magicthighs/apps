"""
Applet: Moon Phase (wide)
Summary: Shows current moon phase
Description: Shows phase of moon based on location.
Author: Chris Wyman
"""

# Moon Phase
#
# Copyright (c) 2022 Chris Wyman
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

load("encoding/base64.star", "base64")
load("encoding/json.star", "json")
load("math.star", "math")
load("render.star", "render")
load("schema.star", "schema")
load("time.star", "time")

#
# Default location
#

DEFAULT_LOCATION = """
{
    "lat": 47.606,
    "lng": -122.332,
    "locality": "Seattle, WA, USA",
    "timezone": "America/Los_Angeles"
}
"""

#
# Time formats used in get_schema
#

TIME_FORMATS = {
    "None": None,
    "12 hour": ("3:04", "3 04", True),
    "24 hour": ("15:04", "15 04", False),
}

#
# moon image constants
#

MOONIMG_WIDTH = 64  # Width of moon image
MOONIMG_HEIGHT = 64  # Height of moon image

#
# background MOON_IMG constants
#

X_C = MOONIMG_WIDTH / 2.0 - 0.5  # X-center of MOON_IMG in pixel coordinates, - 0.5 so it's middle of the pixel
Y_C = MOONIMG_HEIGHT / 2.0 - 0.5  # Y-center of MOON_IMG in pixel coordinates, - 0.5 so it's middle of the pixel
R = (MOONIMG_HEIGHT - 2) / 2.0  # radius of MOON_IMG in pixel coordinates, HEIGHT - 2 because of the 1 pixel margin about disc (specific to MOON_IMG)

#
# moon cycle constants
#

LUNATION = 2551443  # lunar cycle in seconds (29 days 12 hours 44 minutes 3 seconds)
REF_NEWMOON = time.parse_time("30-Apr-2022 20:28:00", format = "02-Jan-2006 15:04:05").unix

#
# geometric/graphic constants
#

SHADOW_LEVEL = 0.15
FADE_LNG = math.pi / 6  # 30 degrees in moon longitude, but fade is non-linear (see comment in percent_illuminated())
FONT = "tom-thumb"
CLOCK_PADDING = 48  # y-offset of clock in pixels

def main(config):
    location = json.decode(config.get("location", DEFAULT_LOCATION))
    latitude = float(location["lat"])
    tz = location.get("timezone")

    currtime = time.now("UTC")
    #currtime = time.parse_time("16-Sep-2022 20:17:00", format="02-Jan-2006 15:04:05")    # pick any date to debug/unit test

    currsecofmooncycle = (currtime.unix - REF_NEWMOON) % LUNATION

    moon_phase = (currsecofmooncycle / LUNATION) * 2 * math.pi
    #moon_phase = (currtime.unix % 60) / 60 * 2*math.pi    # debug/unit test with fake 60 second lunar cycle

    #print(moon_phase)

    time_format = TIME_FORMATS.get(config.get("time_format"))
    blink_time = config.bool("blink_time")

    disp_time = time.now().in_location(tz).format(time_format[0]) if time_format else None
    disp_time_blink = time.now().in_location(tz).format(time_format[1]) if time_format else None

    return render.Root(
        delay = 1000,
        child = render.Row(
            expanded = True,
            main_align = "space_evenly",
            cross_align = "left",
            children = [
                render.Stack([
                    render.Image(src = MOON_IMG),
                    # Stack below is a dynamically generated shadow mask built one pixel at a time
                    render.Stack([
                        # Each child of Stack is a row of pixels
                        render.Row([
                            # Each Row is a 1 pixel tall stack at height "y"
                            render.Padding(
                                # This element represents the mask pixel at (x, y)
                                pad = (0, y, 0, 0),
                                child = render.Image(
                                    src = getmaskpixel(x, y, moon_phase, latitude),
                                ),
                            )
                            for x in range(MOONIMG_WIDTH)
                        ])
                        for y in range(MOONIMG_HEIGHT)
                    ]),
                ]),
                # optional clock below
                render.Animation(
                    children = [
                        render.Padding(
                            pad = (0, CLOCK_PADDING, 0, 0),
                            child = render.Stack(
                                children = [
                                    render.Padding(
                                        # render extra pixels to the right to push time closer to moon
                                        pad = (3, 0, 0, 0),
                                        child = render.Text(
                                            content = disp_time,
                                            font = FONT,
                                            color = "#000",
                                        ),
                                    ),
                                    render.Padding(
                                        # faint shadow right
                                        pad = (1, 0, 0, 0),
                                        child = render.Text(
                                            content = disp_time,
                                            font = FONT,
                                            color = "#222",
                                        ),
                                    ),
                                    render.Padding(
                                        # faint shadow down
                                        pad = (0, 1, 0, 0),
                                        child = render.Text(
                                            content = disp_time,
                                            font = FONT,
                                            color = "#222",
                                        ),
                                    ),
                                    render.Padding(
                                        # medium shadow diagonal down-right
                                        pad = (1, 1, 0, 0),
                                        child = render.Text(
                                            content = disp_time,
                                            font = FONT,
                                            color = "#444",
                                        ),
                                    ),
                                    render.Text(
                                        # bright time
                                        content = disp_time,
                                        font = FONT,
                                        color = "#AAA",
                                    ),
                                ],
                            ),
                        ),
                        render.Padding(
                            pad = (0, CLOCK_PADDING, 0, 0),
                            child = render.Stack(
                                children = [
                                    render.Padding(
                                        pad = (3, 0, 0, 0),
                                        child = render.Text(
                                            content = disp_time_blink,
                                            font = FONT,
                                            color = "#000",
                                        ),
                                    ),
                                    render.Padding(
                                        pad = (1, 0, 0, 0),
                                        child = render.Text(
                                            content = disp_time_blink,
                                            font = FONT,
                                            color = "#222",
                                        ),
                                    ),
                                    render.Padding(
                                        pad = (0, 1, 0, 0),
                                        child = render.Text(
                                            content = disp_time_blink,
                                            font = FONT,
                                            color = "#222",
                                        ),
                                    ),
                                    render.Padding(
                                        pad = (1, 1, 0, 0),
                                        child = render.Text(
                                            content = disp_time_blink,
                                            font = FONT,
                                            color = "#444",
                                        ),
                                    ),
                                    render.Text(
                                        content = disp_time_blink,
                                        font = FONT,
                                        color = "#AAA",
                                    ),
                                ],
                            ),
                        ) if blink_time else None,
                    ],
                ) if time_format else None,
            ],
        ),
    )

#######
#
# return specific mask 1x1 pixel image from array sorted by alpha percentage
#
#######
def getmaskpixel(x, y, phase, latitude):
    return mask_images[select_mask_image(percent_illuminated(x, y, phase, latitude))]

#######
#
# return percent illumination of moon image based on pixel coordinates, moon phase, and user's (earth) latitude
#
#######
def percent_illuminated(x, y, phase, latitude):
    # Offset x and y so that (0, 0) is center of moon
    x -= X_C
    y -= Y_C

    # Rotate x and y by latitude so that crescents look as at user's latitude
    # (crescents look vertical at poles, horizontal at equator)
    rot = math.pi / 2 - math.radians(latitude)
    xr = x * math.cos(rot) - y * math.sin(rot)
    yr = x * math.sin(rot) + y * math.cos(rot)

    lambda_0 = phase  # lambda_0 represents lunar longitude offset in orthographic projection onto plane, in this case treating lunar longitude as moon phase, where 0 is new, pi is full

    # following equations are simplified from the inverse functions in https://en.wikipedia.org/wiki/Orthographic_map_projection, specifically phi_0 = 0 (phi_0 representing latitude tilt of moon, so phi_0 = 0 represents equator-centric view, i.e., just the crescent/gibbous view of the longitude lines)
    rho = math.sqrt(xr * xr + yr * yr)
    c = math.asin(rho / R)
    moon_lng = lambda_0 + math.atan2(xr * math.sin(c), rho * math.cos(c))

    illum = 0.0  # default

    # logic: if moon_lng < 90 or > 270, it's fully in shadow (meaning start fade at 90/270, don't center fade around those angles)
    # reason: don't want time around new moon to have extended appearance of new moon, new moon should be as close to instantaneous as possible
    # reason #2: totally ok and desirable to have day or two around full moon to change fading around edges of moon and still look basically full - moon does this in real life

    # logic: within FADE_LNG, take 4th root of delta to determine brightness
    # reason: make line between light/shadow crisp, sharp at the dark side, soften the curve towards maximum brightness, no other reason than it looked good to me and made time near full moon look good shading-wise

    if (moon_lng < math.pi / 2 or moon_lng > 3 * math.pi / 2):
        illum = SHADOW_LEVEL
    elif (moon_lng - math.pi / 2 > 0 and moon_lng - math.pi / 2 <= FADE_LNG):
        illum = SHADOW_LEVEL + math.sqrt(math.sqrt(1 - SHADOW_LEVEL) * ((moon_lng - math.pi / 2) / FADE_LNG))
    elif (3 * math.pi / 2 - moon_lng > 0 and 3 * math.pi / 2 - moon_lng <= FADE_LNG):
        illum = SHADOW_LEVEL + math.sqrt(math.sqrt(1 - SHADOW_LEVEL) * ((3 * math.pi / 2 - moon_lng) / FADE_LNG))
    elif (moon_lng > math.pi / 2 + FADE_LNG or moon_lng < 3 * math.pi / 2 - FADE_LNG):
        illum = 1.0

    return illum

#######
#
# convert illumination percentage (0 <= illumination_percent <= 1) to index into mask_images array
#
#######
def select_mask_image(illumination_percent):
    val = min(15, math.floor(math.round(illumination_percent * 16)))
    return val

#######
#
# get_schema
#
#######
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
            schema.Dropdown(
                id = "time_format",
                name = "Time Format",
                desc = "The format used for the time.",
                icon = "clock",
                default = "None",
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
        ],
    )

#######
#
# image data and array of images follows
#
#######

# Moon image is taken from NASA video at https://svs.gsfc.nasa.gov/4310, retouched by Chris Wyman
MOON_IMG = base64.decode("""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""")

BLACK_PIXEL = base64.decode("""iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAAXNSR0IArs4c6QAAAA1JREFUGFdjYGBg+AcAAQMA/60lLy8AAAAASUVORK5CYII=""")
DARK01_PIXEL = base64.decode("""iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAAXNSR0IArs4c6QAAAA1JREFUGFdjYGBgeAEAAO0A6Rx+CV4AAAAASUVORK5CYII=""")
DARK02_PIXEL = base64.decode("""iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAAXNSR0IArs4c6QAAAA1JREFUGFdjYGBguA0AAOAA3PnKAd4AAAAASUVORK5CYII=""")
DARK03_PIXEL = base64.decode("""iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAAXNSR0IArs4c6QAAAA1JREFUGFdjYGBgOAcAANMAz3LU0l0AAAAASUVORK5CYII=""")
DARK04_PIXEL = base64.decode("""iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAAXNSR0IArs4c6QAAAA1JREFUGFdjYGBg2A8AAMQAwBTxXkMAAAAASUVORK5CYII=""")
DARK05_PIXEL = base64.decode("""iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAAXNSR0IArs4c6QAAAA1JREFUGFdjYGBg2AQAALcAs+GNWA8AAAAASUVORK5CYII=""")
DARK06_PIXEL = base64.decode("""iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAAXNSR0IArs4c6QAAAA1JREFUGFdjYGBgWAoAAKoApiqyB0UAAAAASUVORK5CYII=""")
DARK07_PIXEL = base64.decode("""iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAAXNSR0IArs4c6QAAAA1JREFUGFdjYGBgmAEAAJ0AmRsqtiUAAAAASUVORK5CYII=""")
DARK08_PIXEL = base64.decode("""iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAAXNSR0IArs4c6QAAAA1JREFUGFdjYGBg6AQAAI4Aij1Rq0oAAAAASUVORK5CYII=""")
DARK09_PIXEL = base64.decode("""iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAAXNSR0IArs4c6QAAAA1JREFUGFdjYGBgqAEAAIEAfQESbwIAAAAASUVORK5CYII=""")
DARK10_PIXEL = base64.decode("""iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAAXNSR0IArs4c6QAAAA1JREFUGFdjYGBgyAcAAHQAcJFDDXwAAAAASUVORK5CYII=""")
DARK11_PIXEL = base64.decode("""iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAAXNSR0IArs4c6QAAAA1JREFUGFdjYGBgSAIAAGcAY9NGKsoAAAAASUVORK5CYII=""")
DARK12_PIXEL = base64.decode("""iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAAXNSR0IArs4c6QAAAA1JREFUGFdjYGBgCAYAAFgAVJtWGgcAAAAASUVORK5CYII=""")
DARK13_PIXEL = base64.decode("""iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAAXNSR0IArs4c6QAAAA1JREFUGFdjYGBgMAUAADoANm6hnKYAAAAASUVORK5CYII=""")
DARK14_PIXEL = base64.decode("""iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAAXNSR0IArs4c6QAAAA1JREFUGFdjYGBgEAcAABwAGAzCM6wAAAAASUVORK5CYII=""")
CLEAR_PIXEL = base64.decode("""iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAAXNSR0IArs4c6QAAAAtJREFUGFdjYAACAAAFAAGq1chRAAAAAElFTkSuQmCC""")

#######
#
# array of 1x1 pixel images from opaque black to transparent black in equal transparency jumps
#
#######
mask_images = [
    BLACK_PIXEL,
    DARK01_PIXEL,
    DARK02_PIXEL,
    DARK03_PIXEL,
    DARK04_PIXEL,
    DARK05_PIXEL,
    DARK06_PIXEL,
    DARK07_PIXEL,
    DARK08_PIXEL,
    DARK09_PIXEL,
    DARK10_PIXEL,
    DARK11_PIXEL,
    DARK12_PIXEL,
    DARK13_PIXEL,
    DARK14_PIXEL,
    CLEAR_PIXEL,
]
