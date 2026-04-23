-module(finance_statement_service).

-export([group_statement/2, receipt/2]).

group_statement(GroupId, Month) ->
    Entries = chat_ledger:get_group_entries(GroupId),
    Normalized = [normalize_entry(E) || E <- Entries],
    Filtered = filter_by_month(Normalized, Month),
    GrossIn = lists:sum([maps:get(amount, E, 0) || E <- Filtered, maps:get(type, E, unknown) =:= contribution]),
    GrossOut = lists:sum([maps:get(amount, E, 0) || E <- Filtered, maps:get(type, E, unknown) =:= withdrawal]),
    Fees = lists:sum([maps:get(fee, maps:get(metadata, E, #{}), 0) || E <- Filtered]),
    #{
        group_id => GroupId,
        month => Month,
        summary => #{
            gross_in => GrossIn,
            gross_out => GrossOut,
            fees => Fees,
            net => GrossIn - GrossOut - Fees
        },
        entries => Filtered
    }.

receipt(GroupId, ReceiptId) ->
    Entries = [normalize_entry(E) || E <- chat_ledger:get_group_entries(GroupId)],
    case lists:filter(fun(E) -> maps:get(event_id, E, undefined) =:= ReceiptId end, Entries) of
        [Match | _] ->
            #{receipt_id => ReceiptId, group_id => GroupId, entry => Match};
        [] ->
            {error, not_found}
    end.

normalize_entry({entry, Id, EventId, GroupId, UserId, Type, Amount, Timestamp}) ->
    #{
        id => Id,
        event_id => EventId,
        group_id => GroupId,
        user_id => UserId,
        type => Type,
        amount => Amount,
        timestamp => Timestamp,
        metadata => #{}
    };
normalize_entry(Map) when is_map(Map) ->
    Map;
normalize_entry(Other) ->
    #{raw => Other}.

filter_by_month(Entries, undefined) ->
    Entries;
filter_by_month(Entries, <<>>) ->
    Entries;
filter_by_month(Entries, Month) ->
    lists:filter(fun(E) ->
        TS = maps:get(timestamp, E, 0),
        month_key(TS) =:= Month
    end, Entries).

month_key(Timestamp) when is_integer(Timestamp), Timestamp > 0 ->
    {{Year, Month, _Day}, _} = calendar:system_time_to_universal_time(Timestamp, second),
    list_to_binary(io_lib:format("~4..0B-~2..0B", [Year, Month]));
month_key(_) ->
    <<>>.
