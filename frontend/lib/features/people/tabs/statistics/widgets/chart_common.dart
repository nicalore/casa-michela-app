class ChartDatum
{
  final String label;
  final int count;

  const ChartDatum({required this.label, required this.count});
}

// Shared by the line and bar charts.
const int gridDivisions = 4;

// Tallest value plus 20% headroom, rounded up to a multiple of gridDivisions so
// the axis labels come out as whole numbers.
int chartMaxValue(int rawMax)
{
  final withHeadroom = rawMax == 0 ? gridDivisions : (rawMax * 1.2).ceil();

  if (withHeadroom < gridDivisions)
  {
    return gridDivisions;
  }

  return ((withHeadroom + gridDivisions - 1) ~/ gridDivisions) * gridDivisions;
}