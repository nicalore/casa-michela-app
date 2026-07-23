// Canonical input of every categorical chart. It replaces the separate
// ChartBarItem and ChartPieItem, which were the same pair of fields declared
// twice: the distribution models keep their own semantic field names and are
// mapped onto this at the call site.
class ChartDatum
{
  final String label;
  final int count;

  const ChartDatum({required this.label, required this.count});
}

// Horizontal grid lines below the top one, shared by the line and bar charts.
const int gridDivisions = 4;

// Vertical extent of a chart: the tallest value plus 20% headroom, rounded up to
// a multiple of gridDivisions so the axis labels come out as whole numbers.
int chartMaxValue(int rawMax)
{
  final withHeadroom = rawMax == 0 ? gridDivisions : (rawMax * 1.2).ceil();

  if (withHeadroom < gridDivisions)
  {
    return gridDivisions;
  }

  return ((withHeadroom + gridDivisions - 1) ~/ gridDivisions) * gridDivisions;
}