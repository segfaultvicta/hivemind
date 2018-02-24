defmodule Hivemind.Actors.Room do
	require Logger

	def start_link do
		Agent.start_link(fn -> %{} end, name: __MODULE__)
	end

	def join_or_create(hive_name, user_name) do
		maybe_hive = get(hive_name)
		hive = if maybe_hive do Map.put(maybe_hive, user_name, "neutral") else %{user_name => "neutral"} end
		save(hive_name, hive)
	end

	def get_hive(hive_name) do
		maybe_hive = get(hive_name)
		if maybe_hive do {:ok, maybe_hive} else {:error, "Tried to get data for a hive that doesn't exist."} end
	end

	def part(hive_name, user_name) do
		maybe_hive = get(hive_name)
		hive = if maybe_hive do Map.delete(maybe_hive, user_name) else false end
		if hive !== false and Enum.count(hive) > 0 do save(hive_name, hive) else close(hive_name) end
	end

	def update(hive_name, user_name, new_sentiment) do
		maybe_hive = get(hive_name)
		cond do
			maybe_hive == false ->
				{:error, "Tried to update a sentiment for a hive that doesn't exist."}
			Map.get(maybe_hive, user_name) == nil ->
				{:error, "Tried to update a sentiment for a user that isn't in the hive."}
			true ->
				{:ok, save(hive_name, Map.put(maybe_hive, user_name, new_sentiment))}
		end
	end

	defp get(room) do
		room = Agent.get(__MODULE__, fn(state) -> state[room] end)
		if is_nil(room) do false else room end
	end

	defp save(hive_name, hive) do
		Agent.update(__MODULE__,
			fn state ->
				Map.put(state, hive_name, hive)
			end)
		hive
	end

	defp close(hive_name) do
		Agent.update(__MODULE__,
			fn state ->
				Map.delete(state, hive_name)
			end)
		nil
	end
end