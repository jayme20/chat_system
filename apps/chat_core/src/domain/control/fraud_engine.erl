-module(fraud_engine).

-export([
    analyze/1,
    risk_score/1,
    flag/2,
    is_duplicate/1
]).

-record(risk, {
    group_id,
    score = 0,
    flags = []
}).



analyze(Event) ->
    Score = risk_score(Event),

    case Score#risk.score >= 80 of
        true ->
            flag(Event, Score),
            {blocked, Score};

        false ->
            {ok, Score}
    end.



risk_score(Event) ->
    Type = chat_event:type(Event),
    P = chat_event:payload(Event),
    GroupId = chat_event:aggregate_id(Event),

    Base = #risk{group_id = GroupId},

    Score1 = duplicate_check(Event, Base),
    Score2 = velocity_check(Event, Score1),
    Score3 = anomaly_check(Type, P, Score2),

    Score3.



duplicate_check(Event, Risk) ->
    case chat_event:type(Event) of
        contribution_received ->
            Receipt = maps:get(mpesa_receipt, chat_event:payload(Event), undefined),

            case ets:lookup(mpesa_receipt_index, Receipt) of
                [] ->
                    ets:insert(mpesa_receipt_index, {Receipt, true}),
                    Risk;

                _ ->
                    Risk#risk{
                        score = Risk#risk.score + 90,
                        flags = [duplicate_transaction | Risk#risk.flags]
                    }
            end;

        _ ->
            Risk
    end.



velocity_check(Event, Risk) ->
    GroupId = chat_event:aggregate_id(Event),
    Now = os:system_time(second),

    Key = {GroupId, Now div 60},

    Count = case ets:lookup(velocity_table, Key) of
        [{Key, C}] -> C;
        [] -> 0
    end,

    ets:insert(velocity_table, {Key, Count + 1}),

    case Count > 20 of
        true ->
            Risk#risk{
                score = Risk#risk.score + 40,
                flags = [high_velocity | Risk#risk.flags]
            };
        false ->
            Risk
    end.



anomaly_check(Type, Payload, Risk) ->
    Amount = maps:get(amount, Payload, 0),

    case Amount > 50000 of
        true when Type == contribution_received ->
            Risk#risk{
                score = Risk#risk.score + 30,
                flags = [large_transaction | Risk#risk.flags]
            };

        true when Type == withdrawal_processing ->
            Risk#risk{
                score = Risk#risk.score + 50,
                flags = [large_withdrawal | Risk#risk.flags]
            };

        _ ->
            Risk
    end.



flag(Event, Risk) ->
    ets:insert(fraud_flags, {
        chat_event:aggregate_id(Event),
        Risk
    }).



is_duplicate(Receipt) ->
    case ets:lookup(mpesa_receipt_index, Receipt) of
        [] -> false;
        _ -> true
    end.