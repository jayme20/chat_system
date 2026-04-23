-module(chat_store).

-export([
    ensure_tables/0,

    %% inbox
    store_inbox/4,
    fetch_inbox/1,

    %% reliability tracking
    init_group_message/3,
    mark_delivered/3,
    get_group_status/2,

    %% group cache (read model only)
    insert_group/2,
    lookup_group/1,

    %% contribution cache (NON-LEDGER)
    record_contribution/4,
    get_contributions/2,

    group_total/1,
    group_leaderboard/1,
    group_member_totals/1,
    group_progress/2,
    inactive_members/2
]).

ensure_tables() ->
    ensure(chat_inbox, bag),
    ensure(chat_message_reliability, set),
    ensure(chat_groups_cache, set),
    ensure(chat_contributions_cache, bag),
    ensure(chat_analytics_cache, set),
    ensure(chat_user, set),
    ensure(chat_group, set),
    ensure(user_table, set),
    ensure(otp_table, set),
    ensure(device_table, set),
    ensure(velocity_table, set),
    ok.


ensure(Name, Type) ->
    case ets:info(Name) of
        undefined ->
            create_table(Name, Type);
        _ ->
            ok
    end.

create_table(Name, Type) ->
    try
        ets:new(Name, [
            named_table,
            public,
            Type,
            {read_concurrency, true},
            {write_concurrency, true}
        ]),
        ok
    catch
        error:badarg ->
            %% race condition safety (already created)
            ok
    end.



store_inbox(To, From, MsgId, Msg) ->
    ensure(chat_inbox, bag),
    ets:insert(chat_inbox, {{To, MsgId}, From, Msg}).

fetch_inbox(UserId) ->
    ets:match_object(chat_inbox, {{UserId, '_'}, '_', '_'}).



init_group_message(GroupId, MsgId, Recipients) ->
    ensure(chat_message_reliability, set),
    States = [{User, pending} || User <- Recipients],
    ets:insert(chat_message_reliability, {{GroupId, MsgId}, States}).

mark_delivered(GroupId, MsgId, UserId) ->
    case ets:lookup(chat_message_reliability, {GroupId, MsgId}) of
        [{{GroupId, MsgId}, States}] ->
            Updated =
                lists:map(fun
                    ({User, _}) when User =:= UserId ->
                        {User, delivered};
                    (Other) ->
                        Other
                end, States),

            ets:insert(chat_message_reliability,
                {{GroupId, MsgId}, Updated});

        [] ->
            ok
    end.

get_group_status(GroupId, MsgId) ->
    ets:lookup(chat_message_reliability, {GroupId, MsgId}).

%% =====================================================
%% GROUP CACHE (READ MODEL ONLY)
%% =====================================================

insert_group(GroupId, Snapshot) ->
    ensure(chat_groups_cache, set),
    ets:insert(chat_groups_cache, {GroupId, Snapshot}).

lookup_group(GroupId) ->
    case ets:lookup(chat_groups_cache, GroupId) of
        [{GroupId, Snapshot}] ->
            {ok, Snapshot};
        [] ->
            not_found
    end.

%% =====================================================
%% CONTRIBUTION CACHE (NOT SOURCE OF TRUTH)
%% =====================================================

record_contribution(GroupId, UserId, Amount, Net) ->
    ensure(chat_contributions_cache, bag),
    TxId = make_ref(),

    ets:insert(chat_contributions_cache,
        {GroupId, UserId, Amount, Net, TxId, erlang:system_time(second)}),

    TxId.

get_contributions(GroupId, UserId) ->
    ets:match_object(chat_contributions_cache,
        {GroupId, UserId, '_', '_', '_', '_'}).

%% =====================================================
%% ANALYTICS (DERIVED ONLY)
%% =====================================================

group_total(GroupId) ->
    Records = ets:match_object(chat_contributions_cache,
        {GroupId, '_', '_', '_', '_', '_'}),

    lists:sum([Amount || {_, _, Amount, _, _, _} <- Records]).

group_member_totals(GroupId) ->
    Records = ets:match_object(chat_contributions_cache,
        {GroupId, '_', '_', '_', '_', '_'}),

    lists:foldl(fun({_, User, Amount, _, _, _}, Acc) ->
        maps:update_with(User,
            fun(V) -> V + Amount end,
            Amount,
            Acc)
    end, #{}, Records).

group_leaderboard(GroupId) ->
    Totals = group_member_totals(GroupId),
    lists:sort(fun({_, A}, {_, B}) -> A > B end,
        maps:to_list(Totals)).

group_progress(GroupId, Target) ->
    Total = group_total(GroupId),
    case Target of
        0 -> 0;
        _ -> (Total * 100) div Target
    end.

inactive_members(GroupId, Members) ->
    Totals = group_member_totals(GroupId),
    [User || User <- Members,
        not maps:is_key(User, Totals)].