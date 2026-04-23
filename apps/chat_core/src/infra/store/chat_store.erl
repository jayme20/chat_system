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
    append_group_message/2,
    get_group_messages_after/3,
    ack_group_seq/4,
    get_group_ack/3,

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
    ensure(chat_group_messages, ordered_set),
    ensure(chat_group_seq, set),
    ensure(chat_group_ack, set),
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

append_group_message(GroupId, Message) ->
    case durable_sync_enabled() of
        true ->
            append_group_message_mnesia(GroupId, Message);
        false ->
            ensure(chat_group_seq, set),
            ensure(chat_group_messages, ordered_set),
            Seq = ets:update_counter(chat_group_seq, GroupId, {2, 1}, {GroupId, 0}),
            Stored = Message#{
                seq => Seq,
                group_id => GroupId,
                stored_at => erlang:system_time(second)
            },
            ets:insert(chat_group_messages, {{GroupId, Seq}, Stored}),
            Stored
    end.

get_group_messages_after(GroupId, AfterSeq, Limit) ->
    case durable_sync_enabled() of
        true ->
            get_group_messages_after_mnesia(GroupId, AfterSeq, Limit);
        false ->
            ensure(chat_group_messages, ordered_set),
            StartKey = {GroupId, AfterSeq},
            collect_group_messages(ets:next(chat_group_messages, StartKey), GroupId, Limit, [])
    end.

collect_group_messages('$end_of_table', _GroupId, _Limit, Acc) ->
    lists:reverse(Acc);
collect_group_messages(_Key, _GroupId, 0, Acc) ->
    lists:reverse(Acc);
collect_group_messages({GroupId, Seq} = Key, GroupId, Limit, Acc) ->
    case ets:lookup(chat_group_messages, Key) of
        [{_, Message}] ->
            collect_group_messages(
                ets:next(chat_group_messages, Key),
                GroupId,
                Limit - 1,
                [Message#{seq => Seq} | Acc]
            );
        [] ->
            collect_group_messages(
                ets:next(chat_group_messages, Key),
                GroupId,
                Limit,
                Acc
            )
    end;
collect_group_messages(_OtherGroupKey, _GroupId, _Limit, Acc) ->
    lists:reverse(Acc).

ack_group_seq(GroupId, UserId, DeviceId, Seq) ->
    case durable_sync_enabled() of
        true ->
            ack_group_seq_mnesia(GroupId, UserId, DeviceId, Seq);
        false ->
            ensure(chat_group_ack, set),
            Key = {GroupId, UserId, DeviceId},
            Current = get_group_ack(GroupId, UserId, DeviceId),
            Next = erlang:max(Current, Seq),
            ets:insert(chat_group_ack, {Key, Next, erlang:system_time(second)}),
            Next
    end.

get_group_ack(GroupId, UserId, DeviceId) ->
    case durable_sync_enabled() of
        true ->
            get_group_ack_mnesia(GroupId, UserId, DeviceId);
        false ->
            ensure(chat_group_ack, set),
            Key = {GroupId, UserId, DeviceId},
            case ets:lookup(chat_group_ack, Key) of
                [{Key, Seq, _At}] -> Seq;
                [] -> 0
            end
    end.

durable_sync_enabled() ->
    application:get_env(chat_core, sync_store_backend, amnesia) =:= amnesia.

append_group_message_mnesia(GroupId, Message) ->
    ok = chat_amnesia_bootstrap:ensure_started(),
    Fun = fun() ->
        Seq = next_group_seq_mnesia(GroupId),
        StoredAt = erlang:system_time(second),
        Stored = Message#{
            seq => Seq,
            group_id => GroupId,
            stored_at => StoredAt
        },
        Key = {GroupId, Seq},
        ok = mnesia:write({sync_group_messages, Key, GroupId, Seq, Stored, StoredAt}),
        Stored
    end,
    tx(Fun, Message#{group_id => GroupId}).

next_group_seq_mnesia(GroupId) ->
    case mnesia:read(sync_group_seq, GroupId, write) of
        [] ->
            ok = mnesia:write({sync_group_seq, GroupId, 1}),
            1;
        [{sync_group_seq, GroupId, Current}] ->
            Next = Current + 1,
            ok = mnesia:write({sync_group_seq, GroupId, Next}),
            Next
    end.

get_group_messages_after_mnesia(GroupId, AfterSeq, Limit) ->
    ok = chat_amnesia_bootstrap:ensure_started(),
    Rows = mnesia:dirty_index_read(sync_group_messages, GroupId, group_id),
    Sorted = lists:sort(fun
        ({sync_group_messages, _, _, SeqA, _, _},
         {sync_group_messages, _, _, SeqB, _, _}) -> SeqA =< SeqB
    end, Rows),
    Messages = [Payload || {sync_group_messages, _, _, Seq, Payload, _} <- Sorted, Seq > AfterSeq],
    lists:sublist(Messages, Limit).

ack_group_seq_mnesia(GroupId, UserId, DeviceId, Seq) ->
    ok = chat_amnesia_bootstrap:ensure_started(),
    Fun = fun() ->
        Key = {GroupId, UserId, DeviceId},
        Current = case mnesia:read(sync_group_acks, Key, write) of
            [{sync_group_acks, _, _, _, _, AckSeq, _}] -> AckSeq;
            [] -> 0
        end,
        Next = erlang:max(Current, Seq),
        UpdatedAt = erlang:system_time(second),
        ok = mnesia:write({sync_group_acks, Key, GroupId, UserId, DeviceId, Next, UpdatedAt}),
        Next
    end,
    tx(Fun, 0).

get_group_ack_mnesia(GroupId, UserId, DeviceId) ->
    ok = chat_amnesia_bootstrap:ensure_started(),
    Key = {GroupId, UserId, DeviceId},
    case mnesia:dirty_read(sync_group_acks, Key) of
        [{sync_group_acks, _, _, _, _, AckSeq, _}] -> AckSeq;
        [] -> 0
    end.

tx(Fun, Fallback) ->
    case mnesia:transaction(Fun) of
        {atomic, Result} -> Result;
        {aborted, _} -> Fallback
    end.

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