defmodule Munchkin.Server do
  use GenServer
  require Logger

  def init(args) do
    Logger.info fn -> "Starting server" end
    {:ok, args}
  end

  def start_link(options \\ []) do
    {:ok, pid} = GenServer.start_link(__MODULE__, %{}, options)
    :global.register_name(:server, pid)
    {:ok, pid}
  end

  def handle_call({:login, name}, {pid, _ref}, state) do
    Logger.info fn -> "Received login with #{name}" end
    {response, new_state} = login(state, name, pid)
    {:reply, response, new_state}
  end

  def handle_call({:logout, name}, _pid, state) do
    Logger.info fn -> "Received logout with #{name}" end
    {response, new_state} = logout(state, name)
    {:reply, response, new_state}
  end

  def handle_call({:tell, {from, to, message}}, _pid, state) do
    Logger.info fn -> "Received tell from #{from}, to #{to}" end
    response = tell(from, to, message, state)
    {:reply, response, state}
  end

  def handle_call({:rename, names}, {pid, _ref}, state) do
    Logger.info fn -> "Received rename with #{names}" end
    {response, new_state} = rename(names, pid, state)
    {:reply, response, new_state}
  end

  def handle_call(_, _, state) do
    Logger.info fn -> "Received unprocessable request" end
    {:reply, {:err, "not found"}, state}
  end

  def handle_cast({:yell, {from, pid, message}}, state) do
    Logger.info fn -> "Received yell from #{from}" end
    yell(message, {from, pid}, state)
    {:noreply, state}
  end

  defp login(state, name, from) do
    case Map.fetch(state, name) do
      {:ok, ^from} ->
        {{:err, "Already logged in"}, state}
      {:ok, _} ->
        {{:err, "Name already taken"}, state}
      _ ->
        {:ok, Map.put(state, name, from)}
    end
  end

  defp logout(state, name) do
    case Map.fetch(state, name) do
      {:ok, _pid} ->
        {:ok, Map.delete(state, name)}
      _ ->
        {{:err, "User not found"}, state}
    end
  end

  defp tell(from, to, message, state) do
    case Map.fetch(state, to) do
      {:ok, pid} -> GenServer.cast(pid, {:msg, from, message})
      _ -> {:err, "User not found"}
    end
  end

  defp rename({old, new}, pid, state) do
    case Map.fetch(state, old) do
      {:ok, ^pid} ->
        new_state = Map.delete(state, old)
        {:ok, Map.put(new_state, new, pid)}
      {:ok, _} ->
        {{:err, "Pid not corresponding"}, state}
      _ ->
        {{:err, "User not found"}, state}
    end
  end

  defp yell(message, {from, pid}, state) do
    Enum.each(state, fn({_, to}) ->
      if pid != to do
        GenServer.cast(to, {:msg, from, message})
      end
    end)
  end
end
