-module(notification_service).

-export([handle_event/1, queue/4, list_user_notifications/1]).

handle_event(Event) ->
    EventType = chat_event:type(Event),
    GroupId = chat_event:aggregate_id(Event),
    Payload = chat_event:payload(Event),
    case EventType of
        contribution_received ->
            notify_group(GroupId, new_contribution, Payload);
        withdrawal_completed ->
            notify_group(GroupId, withdrawal_completed, Payload);
        group_announcement_posted ->
            notify_group(GroupId, announcement, Payload);
        _ ->
            ok
    end.

notify_group(GroupId, Kind, Payload) ->
    case chat_store:lookup_group(GroupId) of
        {ok, GroupState} ->
            Members = maps:keys(maps:get(members, GroupState, #{})),
            lists:foreach(fun(UserId) ->
                _ = queue(UserId, fcm, queued, #{kind => Kind, group_id => GroupId, payload => Payload})
            end, Members),
            ok;
        _ ->
            ok
    end.

queue(UserId, Channel, Status, Payload) ->
    ok = chat_amnesia_bootstrap:ensure_started(),
    NotificationId = id(<<"ntf">>),
    CreatedAt = erlang:system_time(second),
    Fun = fun() ->
        ok = mnesia:write({
            notifications,
            NotificationId,
            UserId,
            Channel,
            Status,
            Payload,
            CreatedAt,
            CreatedAt
        }),
        ok
    end,
    tx(Fun, ok),
    NotificationId.

list_user_notifications(UserId) ->
    ok = chat_amnesia_bootstrap:ensure_started(),
    Rows = mnesia:dirty_index_read(notifications, UserId, user_id),
    [to_map(Row) || Row <- Rows].

to_map({notifications, Id, UserId, Channel, Status, Payload, CreatedAt, UpdatedAt}) ->
    #{
        notification_id => Id,
        user_id => UserId,
        channel => Channel,
        status => Status,
        payload => Payload,
        created_at => CreatedAt,
        updated_at => UpdatedAt
    }.

id(Prefix) ->
    PrefixList = binary_to_list(Prefix),
    list_to_binary(
        io_lib:format("~s-~p-~p", [
            PrefixList,
            erlang:unique_integer([monotonic, positive]),
            erlang:system_time(millisecond)
        ])
    ).

tx(Fun, Fallback) ->
    case mnesia:transaction(Fun) of
        {atomic, Result} -> Result;
        {aborted, _} -> Fallback
    end.
