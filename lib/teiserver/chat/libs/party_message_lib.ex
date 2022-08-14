defmodule Teiserver.Chat.PartyMessageLib do
  use CentralWeb, :library
  alias Teiserver.Chat.PartyMessage

  # Functions
  @spec icon :: String.t()
  def icon, do: "fa-regular fa-comment"

  @spec colours :: atom
  def colours, do: :default

  # Queries
  @spec query_party_messages() :: Ecto.Query.t
  def query_party_messages do
    from party_messages in PartyMessage
  end

  @spec search(Ecto.Query.t, Map.t | nil) :: Ecto.Query.t
  def search(query, nil), do: query
  def search(query, params) do
    params
    |> Enum.reduce(query, fn ({key, value}, query_acc) ->
      _search(query_acc, key, value)
    end)
  end

  @spec _search(Ecto.Query.t, Atom.t(), any()) :: Ecto.Query.t
  def _search(query, _, ""), do: query
  def _search(query, _, nil), do: query

  def _search(query, :id, id) do
    from party_messages in query,
      where: party_messages.id == ^id
  end

  def _search(query, :user_id, user_id) do
    from room_messages in query,
      where: room_messages.user_id == ^user_id
  end

  def _search(query, :party_guid, party_guid) do
    from room_messages in query,
      where: room_messages.party_guid == ^party_guid
  end

  def _search(query, :party_guid_in, party_guids) do
    from room_messages in query,
      where: room_messages.party_guid in ^party_guids
  end

  def _search(query, :id_list, id_list) do
    from party_messages in query,
      where: party_messages.id in ^id_list
  end

  def _search(query, :basic_search, ref) do
    ref_like = "%" <> String.replace(ref, "*", "%") <> "%"

    from party_messages in query,
      where: (
            ilike(party_messages.name, ^ref_like)
        )
  end

  def _search(query, :term, ref) do
    ref_like = "%" <> String.replace(ref, "*", "%") <> "%"

    from party_messages in query,
      where: (
            ilike(party_messages.content, ^ref_like)
        )
  end

  def _search(query, :inserted_after, timestamp) do
    from party_messages in query,
      where: party_messages.inserted_at >= ^timestamp
  end

  def _search(query, :inserted_before, timestamp) do
    from party_messages in query,
      where: party_messages.inserted_at < ^timestamp
  end

  @spec order_by(Ecto.Query.t, String.t | nil) :: Ecto.Query.t
  def order_by(query, nil), do: query
  def order_by(query, "Name (A-Z)") do
    from party_messages in query,
      order_by: [asc: party_messages.name]
  end

  def order_by(query, "Name (Z-A)") do
    from party_messages in query,
      order_by: [desc: party_messages.name]
  end

  def order_by(query, "Newest first") do
    from party_messages in query,
      order_by: [desc: party_messages.inserted_at, desc: party_messages.id]
  end

  def order_by(query, "Oldest first") do
    from party_messages in query,
      order_by: [asc: party_messages.inserted_at]
  end

  @spec preload(Ecto.Query.t, List.t | nil) :: Ecto.Query.t
  def preload(query, nil), do: query
  def preload(query, preloads) do
    query = if :user in preloads, do: _preload_users(query), else: query
    query
  end

  def _preload_users(query) do
    from party_messages in query,
      left_join: users in assoc(party_messages, :user),
      preload: [user: users]
  end
end
