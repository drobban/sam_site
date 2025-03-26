defmodule SamSite do
  defmodule State do
    @type name :: String.t()
    @type status :: :online | :offline
    @type type :: :military
    @type position :: float()

    @type t :: %__MODULE__{
            name: name(),
            status: status(),
            type: type(),
            pos_lat: position(),
            pos_lng: position(),
            launches: integer()
          }

    @enforce_keys [
      :name,
      :type,
      :pos_lat,
      :pos_lng
    ]
    defstruct [
      :name,
      :type,
      :pos_lat,
      :pos_lng,
      launches: 0,
      status: :offline
    ]
  end

  def round_trip(
        control,
        name \\ "S75Dvina",
        pos_lat \\ 54.733370063961715,
        pos_lng \\ 20.489215711966924
      ) do
    state = %SamSite.State{
      name: name,
      type: :military,
      pos_lat: pos_lat,
      pos_lng: pos_lng
    }

    SamSite.Worker.start_link(%{
      initial_state: state,
      flight_control: control
    })
  end

  def get_state(name) do
    server = String.to_atom(name)
    GenServer.call(server, :get_state)
  end
end
