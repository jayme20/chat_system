-module(chat_financial_summary).

-export([build/1]).

build(GroupId) ->
    Events = event_store:get_stream(GroupId),

    Treasury = chat_treasury_projection:project(Events),
    Revenue = chat_revenue_ledger:project(Events),
    Leaderboard = chat_leaderboard_projection:project(Events),
    Insights = chat_insights_projection:project(Events),

    #{
        treasury => chat_treasury_projection:get_balance(Treasury),
        fees => chat_revenue_ledger:total_fees(Revenue),
        leaderboard => chat_leaderboard_projection:top(Leaderboard),
        insights => chat_insights_projection:insights(Insights)
    }.