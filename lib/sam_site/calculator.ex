defmodule SamSite.Calculator do
  @moduledoc """
  """

  # Earth's radius in meters
  @earth_radius 6_371_000

  def degrees_to_radians(degrees), do: degrees * :math.pi() / 180
  def radians_to_degrees(radians), do: radians * 180 / :math.pi()

  @doc """
  Calculates the great-circle distance between two geographic points on the Earth's surface.
  Haversine Formula

  ## Parameters

    - `lat1` (float): Latitude of the first point in degrees.
    - `lng1` (float): Longitude of the first point in degrees.
    - `lat2` (float): Latitude of the second point in degrees.
    - `lng2` (float): Longitude of the second point in degrees.

  ## Returns

    - `distance` (float): The distance between the two points in meters.

  ## Examples

      iex> Aircraft.Calculator.calculate_distance(45.0, -93.0, 45.0001, -92.9999)
      13.618537652507671 
  """
  def calculate_distance(lat1, lng1, lat2, lng2) do
    # Convert latitudes and longitudes from degrees to radians
    lat1_rad = degrees_to_radians(lat1)
    lng1_rad = degrees_to_radians(lng1)
    lat2_rad = degrees_to_radians(lat2)
    lng2_rad = degrees_to_radians(lng2)

    # Differences in coordinates
    delta_lat = lat2_rad - lat1_rad
    delta_lng = lng2_rad - lng1_rad

    # Haversine formula
    a =
      :math.pow(:math.sin(delta_lat / 2), 2) +
        :math.cos(lat1_rad) * :math.cos(lat2_rad) * :math.pow(:math.sin(delta_lng / 2), 2)

    c = 2 * :math.atan2(:math.sqrt(a), :math.sqrt(1 - a))

    # Distance in meters
    @earth_radius * c
  end

  @doc """

  Calculates the initial bearing (forward azimuth) from one geographic point to another.

  The bearing is measured in degrees clockwise from north (0° is north, 90° is east, etc.).

  ## Parameters

    - `lat1` (float): Latitude of the starting point in degrees.
    - `lng1` (float): Longitude of the starting point in degrees.
    - `lat2` (float): Latitude of the destination point in degrees.
    - `lng2` (float): Longitude of the destination point in degrees.

  ## Returns

    - `bearing` (float): The initial bearing in degrees, normalized to the range 0°–360°.

  ## Examples

      iex> Aircraft.Calculator.calculate_bearing(51.0, 7.10, 51.0000, 7.11)
      89.99611427020855

      iex> Aircraft.Calculator.calculate_bearing(51.0, 7.11, 51.0000, 7.10)
      270.0038857297915

      iex> Aircraft.Calculator.calculate_bearing(45.0, -93.0, 45.0001, -93.0)
      0.0

      iex> Aircraft.Calculator.calculate_bearing(45.01, -93.0, 45.00, -93.0)
      180.0
  """
  def calculate_bearing(lat1, lng1, lat2, lng2) do
    # Convert latitudes and longitudes from degrees to radians
    lat1_rad = degrees_to_radians(lat1)
    lng1_rad = degrees_to_radians(lng1)
    lat2_rad = degrees_to_radians(lat2)
    lng2_rad = degrees_to_radians(lng2)

    delta_lng = lng2_rad - lng1_rad

    # Calculate the bearing using the formula
    bearing_rad =
      :math.atan2(
        :math.sin(delta_lng) * :math.cos(lat2_rad),
        :math.cos(lat1_rad) * :math.sin(lat2_rad) -
          :math.sin(lat1_rad) * :math.cos(lat2_rad) * :math.cos(delta_lng)
      )

    # Convert from radians to degrees and normalize to 0-360
    bearing_deg = radians_to_degrees(bearing_rad)
    if bearing_deg < 0, do: bearing_deg + 360, else: bearing_deg
  end

  @doc """
  Calculates a new geographic position after moving a specified distance in a given direction (bearing) 
  from a starting point.

  The calculation assumes a spherical Earth for simplicity and is suitable for small distances.

  ## Parameters

    - `lat` (float): Latitude of the starting point in degrees.
    - `lng` (float): Longitude of the starting point in degrees.
    - `bearing` (float): Direction of movement in degrees (clockwise from north).
    - `distance` (float): Distance to travel from the starting point in meters.

  ## Returns

    - `{new_lat, new_lng}` (tuple): A tuple containing the new latitude and longitude in degrees.

  ## Examples

      iex> Aircraft.Calculator.calculate_new_position(45.0, -93.0, 90.0, 1.0)
      {44.9999999999993, -92.99998728167188}

  """
  def calculate_new_position(lat, lng, bearing, distance) do
    # Convert input values to radians
    lat_rad = degrees_to_radians(lat)
    lng_rad = degrees_to_radians(lng)
    bearing_rad = degrees_to_radians(bearing)

    # Calculate new latitude
    new_lat_rad =
      :math.asin(
        :math.sin(lat_rad) * :math.cos(distance / @earth_radius) +
          :math.cos(lat_rad) * :math.sin(distance / @earth_radius) * :math.cos(bearing_rad)
      )

    # Calculate new longitude
    new_lng_rad =
      lng_rad +
        :math.atan2(
          :math.sin(bearing_rad) * :math.sin(distance / @earth_radius) * :math.cos(lat_rad),
          :math.cos(distance / @earth_radius) - :math.sin(lat_rad) * :math.sin(new_lat_rad)
        )

    # Convert results back to degrees
    new_lat = radians_to_degrees(new_lat_rad)
    new_lng = radians_to_degrees(new_lng_rad)

    {new_lat, new_lng}
  end
end
