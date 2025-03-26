defmodule SamSite.Worker do
  require Logger
  alias SamSite.State
  use GenServer

  @tick 10_000

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
    Logger.debug("Status: #{inspect status}")

    {:ok, initial_state, {:continue, :setup}}
  end

  @impl true
  def handle_continue(:setup, %{sam_site: %SamSite.State{} = sam_site} = state) do
    timeout_ref = Process.send_after(self(), :tick, @tick)
    sam_site = %SamSite.State{sam_site | status: :online}
    {:noreply, state |> Map.put(:timeout_ref, timeout_ref) |> Map.put(:sam_site, sam_site)}
  end

  @impl true
  def handle_call(:get_state, from, state) do
    Logger.debug("Got call from #{inspect(from)}")
    {:reply, state, state}
  end

  @impl true
  def handle_info(:tick, %{sam_site: %SamSite.State{} = _sam_site} = state) do
    ping =
      ping_traffic_control(state.flight_control, state.sam_site.pos_lat, state.sam_site.pos_lng)

    case ping do
      {:ok, topics} ->
        for topic <- topics do
          broadcast(state.flight_control, topic, state)
        end
      nil ->
        Logger.debug("No client stations in reach")
    end

    timeout_ref = Process.send_after(self(), :tick, @tick)

    {:noreply, state |> Map.put(:timeout_ref, timeout_ref)}
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
end
