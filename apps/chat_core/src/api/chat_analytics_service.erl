-module(chat_analytics_service).

-export([group_summary/1, leaderboard/1, insights/1]).

group_summary(GroupId) ->
    chat_financial_summary:build(GroupId).

leaderboard(GroupId) ->
    Projection = chat_leaderboard_projection:project(
        event_store:get_stream(GroupId)
    ),
    chat_leaderboard_projection:top(Projection).

insights(GroupId) ->
    Projection = chat_insights_projection:project(
        event_store:get_stream(GroupId)
    ),
    chat_insights_projection:insights(Projection).