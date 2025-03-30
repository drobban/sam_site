defmodule SamSite.Missile do
  alias SamSite.Calculator
  alias Aircraft

  defmodule State do
    @type name :: String.t()
    @type status :: :onroute | :hit | :selfdestruct | :exploded
    @type type :: :military
    @type position :: float()
    @type speed_kmh :: integer()
    @type range_m :: integer()
    @type angle :: float()

    @type t :: %__MODULE__{
            name: name(),
            status: status(),
            pos_lat: position(),
            pos_lng: position(),
            target: Aircraft.State.t(),
            speed: speed_kmh(),
            range: range_m(),
            distance_travelled: range_m(),
            bearing: angle()
          }

    @enforce_keys [
      :name,
      :pos_lat,
      :pos_lng,
      :target
    ]
    defstruct [
      :name,
      :pos_lat,
      :pos_lng,
      :target,
      bearing: 0.0,
      distance_travelled: 0,
      range: 40_000,
      speed: 35_000,
      status: :onroute
    ]
  end

  def lock_on_target(current_lat, current_lng, %Aircraft.State{} = aircraft) do
    uid = System.unique_integer([:monotonic, :positive])

    %__MODULE__.State{
      name: "missile#{uid}",
      pos_lat: current_lat,
      pos_lng: current_lng,
      target: aircraft
    }
  end

  def track_target(%__MODULE__.State{} = missile, %Aircraft.State{} = target, tick_time) do
    # Tick time is given in micro seconds
    speed_to_m = missile.speed / 3.6 * (tick_time/10_000)

    bearing =
      Calculator.calculate_bearing(
        missile.pos_lat,
        missile.pos_lng,
        target.pos_lat,
        target.pos_lng
      )

    {new_lat, new_lng} =
      Calculator.calculate_new_position(missile.pos_lat, missile.pos_lng, bearing, speed_to_m)

    distance_to_target =
      Calculator.calculate_distance(
        missile.pos_lat,
        missile.pos_lng,
        target.pos_lat,
        target.pos_lng
      )

    prev_distance = missile.distance_travelled

    conditions = {distance_to_target < speed_to_m, missile.distance_travelled > missile.range}

    status =
      case conditions do
        {true, false} ->
          :hit

        {false, false} ->
          :onroute

        {false, true} ->
          :selfdestruct

        {true, true} ->
          :selfdestruct
      end

    %__MODULE__.State{
      missile
      | bearing: bearing,
        pos_lat: new_lat,
        pos_lng: new_lng,
        status: status,
        target: target,
        distance_travelled: prev_distance + speed_to_m
    }
  end
end
