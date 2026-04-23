-module(chat_billing).

-export([calculate_group_revenue/1, platform_fees/1]).

calculate_group_revenue(GroupId) ->
    chat_revenue_ledger:project(
        event_store:get_stream(GroupId)
    ).

platform_fees(GroupId) ->
    Revenue = calculate_group_revenue(GroupId),
    chat_revenue_ledger:total_fees(Revenue).