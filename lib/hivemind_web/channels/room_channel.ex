defmodule HivemindWeb.RoomChannel do
	use HivemindWeb, :channel
	alias Hivemind.Actors.Room
	require Logger

	def join("room:" <> hive_name, _, socket) do
		user_name = generate_name()
		socket = socket
		|> Phoenix.Socket.assign(:user_name, user_name)
		|> Phoenix.Socket.assign(:hive_name, hive_name)
		
		hive = Room.join_or_create(hive_name, user_name)

		send(self, :after_join)
      	{:ok, build_sentiment_map(hive, user_name), socket}
	end

	def handle_info(:after_join, socket) do
		{status, response} = Room.get_hive(socket.assigns[:hive_name])
		if status == :ok do broadcast!(socket, "hive_update", build_sentiment_map(response)) end
		{:noreply, socket}
	end

	def handle_in("sentiment", %{"sentiment" => sentiment}, socket) do
		# Any time we get this, username should already exist in the room, so we want to replace its sentiment with a new sentiment
		hive_name = socket.assigns[:hive_name]
		user_name = socket.assigns[:user_name]

		{status, hive} = Room.update(hive_name, user_name, sentiment)
		if status == :ok do
			broadcast!(socket, "hive_update", build_sentiment_map(hive))
			{:reply, {:ok, %{"new_sentiment" => sentiment}}, socket}
		else
			{:reply, {:error, hive}, socket}
		end
	end

	def terminate(_, socket) do
		hive = Room.part(socket.assigns[:hive_name], socket.assigns[:user_name])
		if hive !== nil do broadcast!(socket, "hive_update", build_sentiment_map(hive)) end
	end

	defp generate_name do
		:rand.seed(:exsplus)
		[Application.get_env(:hivemind, :adjectives), Application.get_env(:hivemind, :nouns)]
		|> Enum.map(&Enum.random/1)
		|> Enum.map(&String.capitalize/1)
		|> Enum.join(" ");
	end

	defp build_sentiment_map(hive, username \\ "") do
		{happy, neutral, sad} = calculate_temperature(hive)
		debug = hive |> Map.to_list |> Enum.map(fn({u,s}) -> "#{u}:#{s}" end) |> Enum.join(", ")
		blocks = hive 
			|> Map.to_list 
			|> Enum.filter(fn({_, sentiment}) -> sentiment in Application.get_env(:hivemind, :blocking_sentiments) end)
			|> Enum.map(fn({user, sentiment}) -> %{"username" => user, "sentiment" => sentiment} end)
		%{name: username, happy: happy, neutral: neutral, sad: sad, blocks: blocks, debug: debug}
	end

	defp calculate_temperature(hive) do
		room_count = Enum.count(hive)
		happy_count = hive |> Map.to_list |> Enum.filter(fn({_,y}) -> y in Application.get_env(:hivemind, :happy_sentiments) end) |> Enum.count
		sad_count = hive |> Map.to_list |> Enum.filter(fn({_,y}) -> y in Application.get_env(:hivemind, :sad_sentiments) end) |> Enum.count
		happy_ratio = happy_count / room_count
		sad_ratio = sad_count / room_count
		happies = round(happy_ratio * 100)
		sads = round(sad_ratio * 100)
		neutrals = 100 - (happies + sads)
		{happies, neutrals, sads}
	end

end