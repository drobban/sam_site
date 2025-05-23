defmodule SamSite.Worker do
  require Logger
  alias SamSite.Missile
  alias SamSite.State
  alias SamSite.Calculator
  use GenServer

  require Logger

  @tick 10_000

  # In meters
  @missile_range 45_000

  def start_link(
        %{initial_state: %SamSite.State{}, flight_control: _flight_controller} =
          state
      ) do
    GenServer.start_link(__MODULE__, state, name: String.to_atom(state.initial_state.name))
  end

  @impl true
  def init(%{initial_state: %State{} = sam_site, flight_control: controller} = _state) do
    initial_state = %{
      sam_site: sam_site,
      timeout_ref: nil,
      flight_control: controller
    }

    status = Code.ensure_loaded(controller)
    Logger.debug("Status: #{inspect(status)}")

    {:ok, initial_state, {:continue, :setup}}
  end

  @impl true
  def handle_continue(:setup, %{sam_site: %SamSite.State{} = sam_site} = state) do
    timeout_ref = Process.send_after(self(), :tick, @tick)
    sam_site = %SamSite.State{sam_site | status: :online}

    {lat1, lng1, lat2, lng2} = interest_area(sam_site.pos_lat, sam_site.pos_lng, @missile_range)
    lat_lng = "#{lat1}:#{lng1}_#{lat2}:#{lng2}"
    {pubsub_service, pubsub} = sam_site.pubsub

    pubsub_service.subscribe(pubsub, lat_lng)
    state.flight_control.subscribe(lat_lng)

    state =
      state
      |> Map.put(:timeout_ref, timeout_ref)
      |> Map.put(:sam_site, sam_site)

    {:noreply, state}
  end

  @impl true
  def handle_call(:get_state, from, state) do
    Logger.debug("Got call from #{inspect(from)}")
    {:reply, state, state}
  end

  @impl true
  def handle_info(:tick, %{sam_site: %SamSite.State{} = sam_site} = state) do
    ping =
      ping_traffic_control(state.flight_control, state.sam_site.pos_lat, state.sam_site.pos_lng)

    case ping do
      {:ok, topics} ->
        for topic <- topics do
          broadcast(state.flight_control, topic, state)

          Enum.each(sam_site.missiles, fn {_aircraft_name, missile} ->
            broadcast(state.flight_control, topic, missile)
          end)
        end

      nil ->
        Logger.debug("No client stations in reach")
    end

    missiles = handle_missiles(state.sam_site.missiles)

    timeout_ref = Process.send_after(self(), :tick, @tick)

    sam_site =
      sam_site
      |> Map.put(:missiles, missiles)

    {:noreply,
     state
     |> Map.put(:timeout_ref, timeout_ref)
     |> Map.put(:sam_site, sam_site)}
  end

  @impl true
  def handle_info(%Aircraft.State{} = aircraft, %{sam_site: %SamSite.State{} = sam_site} = state) do
    Logger.debug("Опасность - Got contact! : #{inspect(aircraft)}")

    # Program missile.
    missiles =
      if not Map.has_key?(sam_site.missiles, aircraft.name) do
        Map.put(
          sam_site.missiles,
          aircraft.name,
          SamSite.Missile.lock_on_target(sam_site.pos_lat, sam_site.pos_lng, aircraft)
        )
      else
        sam_site.missiles
      end

    sam_site =
      sam_site
      |> Map.put(:missiles, missiles)

    state =
      state
      |> Map.put(:sam_site, sam_site)

    {:noreply, state}
  end

  @impl true
  def handle_info(%SamSite.State{} = _samsite, state) do
    # Echo

    {:noreply, state}
  end

  @impl true
  def handle_info(%Missile.State{} = _missile, state) do
    # Echo

    {:noreply, state}
  end

  # Broad cast our missiles,
  # If missile hit, crash aircraft.
  # Filter our missiles from the list.
  defp handle_missiles(missiles) do
    missiles
    # Move missiles to new state.
    |> step_missiles!()
    # Shoot them down if hit.
    |> explode_missiles!()
  end

  defp step_missiles!(missiles) do
    missiles =
      Enum.map(missiles, fn {aircraft_name, missile} ->
        aircraft =
          case missile.status do
            :selfdestruct ->
              missile.target

            :exploded ->
              missile.target

            :hit ->
              missile.target

            :onroute ->
              pid = :global.whereis_name(String.to_atom(aircraft_name))

              if pid != :undefined do
                %{aircraft: aircraft} =
                  GenServer.call(pid, :get_state)

                aircraft
              else
                missile.target
              end
          end

        if missile.status == :onroute do
          {aircraft_name, Missile.track_target(missile, aircraft, @tick)}
        else
          {aircraft_name, missile}
        end
      end)
      |> Enum.into(%{})

    missiles
  end

  defp explode_missiles!(missiles) do
    Enum.each(missiles, fn {aircraft_name, missile} ->
      if missile.status == :hit do
        pid = :global.whereis_name(String.to_atom(aircraft_name))

        if pid != :undefined do
          GenServer.call(pid, :crash)
        end
      end
    end)

    missiles
    |> Enum.map(fn {aircraft_name, missile} = tuple ->
      if missile.status == :hit do
        {aircraft_name, %SamSite.Missile.State{missile | status: :exploded}}
      else
        tuple
      end
    end)
    |> Enum.into(%{})
  end

  # Controller is a module that we assume implements a list_topics fn.
  # We could perhaps go bananas with behaviour
  defp ping_traffic_control(controller, lat, lng) do
    if function_exported?(controller, :return_topics, 2) do
      {:ok, controller.return_topics(lat, lng)}
    else
      Logger.debug("List topics not implemented in controller module #{inspect(controller)}")
      nil
    end
  end

  defp broadcast(controller, topic, %{sam_site: %SamSite.State{} = sam_site} = _state) do
    if function_exported?(controller, :broadcast, 2) do
      {:ok, controller.broadcast(topic, sam_site)}
    else
      Logger.debug("Broadcast not available")
      nil
    end
  end

  defp broadcast(controller, topic, %Missile.State{} = missile) do
    if function_exported?(controller, :broadcast, 2) do
      {:ok, controller.broadcast(topic, missile)}
    else
      Logger.debug("Broadcast not available")
      nil
    end
  end

  defp interest_area(lat, lng, radius) do
    {lat1, _} = Calculator.calculate_new_position(lat, lng, 0, radius)
    {_, lng1} = Calculator.calculate_new_position(lat, lng, 270, radius)

    {lat2, _} = Calculator.calculate_new_position(lat, lng, 180, radius)
    {_, lng2} = Calculator.calculate_new_position(lat, lng, 90, radius)

    {lat1, lng1, lat2, lng2}
  end
end
