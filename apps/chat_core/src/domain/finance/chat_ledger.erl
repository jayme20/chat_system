-module(chat_ledger).

-export([
    init/0,
    record/6,
    record_contribution/4,
    record_withdrawal/4,
    get_group_entries/1,
    get_user_entries/2
]).

-record(entry, {
    id,
    event_id,
    group_id,
    user_id,
    type,
    amount,
    timestamp
}).

%% =========================================================
%% INIT (SAFE ETS CREATION)
%% =========================================================

init() ->
    case ets:info(chat_ledger) of
        undefined ->
            ets:new(chat_ledger, [
                named_table,
                public,
                bag,
                {read_concurrency, true}
            ]);
        _ ->
            ok
    end.

%% =========================================================
%% GENERIC LEDGER RECORD
%% =========================================================

record(Id, EventId, GroupId, UserId, Type, Amount) ->
    init(),

    case exists(EventId) of
        true ->
            {ok, duplicate_ignored};

        false ->
            ets:insert(chat_ledger, #entry{
                id = Id,
                event_id = EventId,
                group_id = GroupId,
                user_id = UserId,
                type = Type,
                amount = Amount,
                timestamp = erlang:system_time(second)
            }),
            {ok, recorded}
    end.

%% =========================================================
%% CONTRIBUTION ENTRY
%% =========================================================

record_contribution(EventId, GroupId, UserId, Amount) ->
    record(make_ref(), EventId, GroupId, UserId, contribution, Amount).

%% =========================================================
%% WITHDRAWAL ENTRY
%% =========================================================

record_withdrawal(EventId, GroupId, UserId, Amount) ->
    record(make_ref(), EventId, GroupId, UserId, withdrawal, Amount).

%% =========================================================
%% IDENTITY / IDEMPOTENCY CHECK
%% =========================================================

exists(EventId) ->
    Match = ets:match_object(chat_ledger, #entry{
        id = '_',
        event_id = EventId,
        group_id = '_',
        user_id = '_',
        type = '_',
        amount = '_',
        timestamp = '_'
    }),

    Match =/= [].

%% =========================================================
%% QUERY: GROUP LEDGER
%% =========================================================

get_group_entries(GroupId) ->
    ets:match_object(chat_ledger, #entry{
        id = '_',
        event_id = '_',
        group_id = GroupId,
        user_id = '_',
        type = '_',
        amount = '_',
        timestamp = '_'
    }).

%% =========================================================
%% QUERY: USER LEDGER
%% =========================================================

get_user_entries(GroupId, UserId) ->
    ets:match_object(chat_ledger, #entry{
        id = '_',
        event_id = '_',
        group_id = GroupId,
        user_id = UserId,
        type = '_',
        amount = '_',
        timestamp = '_'
    }).