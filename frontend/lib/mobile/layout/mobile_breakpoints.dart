import 'package:flutter/widgets.dart';

// The one axis the mobile UI is allowed to differ on: never Android against iOS.
enum MobileFormFactor
{
  phone,

  tablet,
}

abstract final class MobileBreakpoints
{
  // Material's tablet threshold, on the shortest side so rotation never changes it.
  static const double tabletMinShortestSide = 600;

  static MobileFormFactor fromShortestSide(double side)
  {
    return side >= tabletMinShortestSide ? MobileFormFactor.tablet : MobileFormFactor.phone;
  }

  static MobileFormFactor of(BuildContext context)
  {
    return fromShortestSide(MediaQuery.sizeOf(context).shortestSide);
  }
}

extension MobileFormFactorX on MobileFormFactor
{
  bool get isPhone => this == MobileFormFactor.phone;

  bool get isTablet => this == MobileFormFactor.tablet;
}
