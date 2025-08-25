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
