import 'dart:math' as math;
import 'dart:ui';

// Ordered groups (ages), youngest lightest: the steps spread over the groups shown,
// neighbours alternate the theme's ocean and violet so two slices side by side always differ.

const double _chroma = 0.12;

// Lightness of the first and last step on the white card.
const double _lightTop = 0.76;
const double _lightBottom = 0.27;

// In the dark the last step stops where it still clears 2:1 on the card.
const double _darkTop = 0.93;
const double _darkFloorStart = 0.40;
const double _darkFloorStep = 0.005;
const double _darkFloorContrast = 2.0;

const int _gamutSearch = 30;

List<Color> orderedChartSteps(int count, {required Color ocean, required Color violet, required Color card, required bool dark})
{
  if (count <= 0)
  {
    return const [];
  }

  final double oceanHue = _oklch(ocean).$3;
  final double violetHue = _oklch(violet).$3;
  final double top = dark ? _darkTop : _lightTop;
  final double bottom = dark ? _darkFloor(violetHue, card) : _lightBottom;

  return [
    for (var i = 0; i < count; i++)
      _fromOklch(
        top + (bottom - top) * (count == 1 ? 0 : i / (count - 1)),
        _chroma,
        i.isEven ? oceanHue : violetHue,
      ),
  ];
}

double _darkFloor(double hue, Color card)
{
  var lightness = _darkFloorStart;

  while (lightness < _darkTop && _contrast(_fromOklch(lightness, _chroma, hue), card) < _darkFloorContrast)
  {
    lightness += _darkFloorStep;
  }

  return lightness;
}

double _contrast(Color a, Color b)
{
  final double la = a.computeLuminance();
  final double lb = b.computeLuminance();

  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

double _toLinear(double c) => c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _toGamma(double c) => c <= 0.0031308 ? 12.92 * c : 1.055 * math.pow(c, 1 / 2.4) - 0.055;

double _cbrt(double x) => x < 0 ? -math.pow(-x, 1 / 3).toDouble() : math.pow(x, 1 / 3).toDouble();

(double, double, double) _oklch(Color colour)
{
  final double r = _toLinear(colour.r);
  final double g = _toLinear(colour.g);
  final double b = _toLinear(colour.b);

  final double l = _cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
  final double m = _cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
  final double s = _cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);

  final double lightness = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s;
  final double a = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s;
  final double bb = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s;

  return (lightness, math.sqrt(a * a + bb * bb), (math.atan2(bb, a) * 180 / math.pi) % 360);
}

(double, double, double) _linearRgb(double lightness, double chroma, double hue)
{
  final double a = chroma * math.cos(hue * math.pi / 180);
  final double b = chroma * math.sin(hue * math.pi / 180);

  final double l = math.pow(lightness + 0.3963377774 * a + 0.2158037573 * b, 3).toDouble();
  final double m = math.pow(lightness - 0.1055613458 * a - 0.0638541728 * b, 3).toDouble();
  final double s = math.pow(lightness - 0.0894841775 * a - 1.2914855480 * b, 3).toDouble();

  return (
    4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
    -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
    -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s,
  );
}

bool _inGamut((double, double, double) rgb)
{
  bool fits(double c) => c >= -0.0005 && c <= 1.0005;

  return fits(rgb.$1) && fits(rgb.$2) && fits(rgb.$3);
}

// Lowers the chroma until the colour fits sRGB, as the mockups' oklch.py does.
Color _fromOklch(double lightness, double chroma, double hue)
{
  var rgb = _linearRgb(lightness, chroma, hue);

  if (!_inGamut(rgb))
  {
    var low = 0.0;
    var high = chroma;

    for (var i = 0; i < _gamutSearch; i++)
    {
      final double middle = (low + high) / 2;

      if (_inGamut(_linearRgb(lightness, middle, hue)))
      {
        low = middle;
      }
      else
      {
        high = middle;
      }
    }

    rgb = _linearRgb(lightness, low, hue);
  }

  int channel(double c) => (_toGamma(c.clamp(0.0, 1.0)) * 255).round().clamp(0, 255);

  return Color.fromARGB(255, channel(rgb.$1), channel(rgb.$2), channel(rgb.$3));
}
