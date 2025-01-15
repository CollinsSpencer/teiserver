defmodule Teiserver.Game.MatchRatingLibTest do
  @moduledoc false
  use Teiserver.DataCase, async: true
  alias Teiserver.Game.MatchRatingLib
  alias Teiserver.Account.AccountTestLib
  alias Teiserver.Battle.MatchLib
  alias Teiserver.Account
  alias Teiserver.Battle
  alias Teiserver.Game

  test "num_matches is updated after rating a match" do
    # Create two user
    user1 = AccountTestLib.user_fixture()
    user2 = AccountTestLib.user_fixture()

    match = create_fake_match(user1.id, user2.id)

    # Check ratings of users before we rate the match
    rating_type_id = Game.get_or_add_rating_type(match.game_type)

    ratings =
      Account.list_ratings(
        search: [
          rating_type_id: rating_type_id,
          user_id_in: [user1.id, user2.id]
        ]
      )
      |> Map.new(fn rating ->
        {rating.user_id, rating}
      end)

    assert ratings[user1.id] == nil
    assert ratings[user2.id] == nil

    MatchRatingLib.rate_match(match.id)

    # Check ratings of users after match
    ratings = get_ratings([user1.id, user2.id], rating_type_id)

    assert ratings[user1.id].skill == 27.637760127073694
    assert ratings[user2.id].skill == 22.362239872926306

    assert ratings[user1.id].num_matches == 1
    assert ratings[user1.id].num_matches == 1

    # Create another match
    match = create_fake_match(user1.id, user2.id)
    MatchRatingLib.rate_match(match.id)

    # Check ratings of users after match
    ratings = get_ratings([user1.id, user2.id], rating_type_id)

    assert ratings[user1.id].skill == 29.662576313923775
    assert ratings[user2.id].skill == 20.337423686076225

    # Check num_matches has increased
    assert ratings[user1.id].num_matches == 2
    assert ratings[user1.id].num_matches == 2

    # Rerate the same match
    MatchRatingLib.re_rate_specific_matches([match.id])

    # Check num_matches unchanged
    assert ratings[user1.id].num_matches == 2
    assert ratings[user1.id].num_matches == 2
  end

  defp get_ratings(userids, rating_type_id) do
    Account.list_ratings(
      search: [
        rating_type_id: rating_type_id,
        user_id_in: userids
      ]
    )
    |> Map.new(fn rating ->
      {rating.user_id, rating}
    end)
  end

  defp create_fake_match(user1_id, user2_id) do
    team_count = 2
    team_size = 1
    game_type = MatchLib.game_type(team_size, team_count)
    server_uuid = UUID.uuid1()
    end_time = Timex.now()

    start_time = DateTime.add(end_time, 50, :minute)

    # Create a match
    {:ok, match} =
      Battle.create_match(%{
        server_uuid: server_uuid,
        uuid: UUID.uuid1(),
        map: "Koom valley",
        data: %{},
        tags: %{},
        winning_team: 0,
        team_count: team_count,
        team_size: team_size,
        passworded: false,
        processed: true,
        game_type: game_type,
        # All rooms are hosted by the same user for now
        founder_id: 1,
        bots: %{},
        queue_id: nil,
        started: start_time,
        finished: end_time
      })

    # Create match memberships
    memberships1 = [
      %{
        team_id: 0,
        win: match.winning_team == 0,
        stats: %{},
        party_id: nil,
        user_id: user1_id,
        match_id: match.id
      }
    ]

    memberships2 = [
      %{
        team_id: 1,
        win: match.winning_team == 1,
        stats: %{},
        party_id: nil,
        user_id: user2_id,
        match_id: match.id
      }
    ]

    Ecto.Multi.new()
    |> Ecto.Multi.insert_all(
      :insert_all,
      Battle.MatchMembership,
      memberships1 ++ memberships2
    )
    |> Teiserver.Repo.transaction()

    match
  end
end