-module(user_repo_ets).

-behaviour(user_repo_behaviour).

-export([
    create/4,
    find/1,
    update/2,
    find_by_email/1,
    find_by_phone/1,
    activate/1
]).

-record(user_record, {
    user_id,
    name,
    email,
    phone,
    status = pending,
    created_at
}).

create(UserId, Name, Email, Phone) ->
    ensure_table(),
    Timestamp = erlang:system_time(second),
    Rec = #user_record{
        user_id = UserId,
        name = Name,
        email = Email,
        phone = Phone,
        status = pending,
        created_at = Timestamp
    },
    ets:insert(user_table, {UserId, Rec}),
    {ok, UserId}.

find(UserId) ->
    ensure_table(),
    case ets:lookup(user_table, UserId) of
        [{_, #user_record{} = Rec}] ->
            {ok, to_map(Rec)};
        [] ->
            {error, not_found}
    end.

find_by_phone(Phone) ->
    ensure_table(),
    MatchSpec = [
        {
            {'$1', {user_record, '$1', '_', '_', '$2', '_', '_'}},
            [{'==', '$2', Phone}],
            ['$1']
        }
    ],
    case ets:select(user_table, MatchSpec) of
        [UserId] -> {ok, UserId};
        [] -> {error, not_found}
    end.

find_by_email(Email) ->
    ensure_table(),
    MatchSpec = [
        {
            {'$1', {user_record, '$1', '_', '$2', '_', '_', '_'}},
            [{'==', '$2', Email}],
            ['$1']
        }
    ],
    case ets:select(user_table, MatchSpec) of
        [UserId] -> {ok, UserId};
        [] -> {error, not_found}
    end.

update(UserId, Changes) ->
    ensure_table(),
    case ets:lookup(user_table, UserId) of
        [{_, #user_record{} = Rec}] ->
            Updated = Rec#user_record{
                name = maps:get(name, Changes, Rec#user_record.name),
                phone = maps:get(phone, Changes, Rec#user_record.phone)
            },
            ets:insert(user_table, {UserId, Updated}),
            {ok, to_map(Updated)};
        [] ->
            {error, not_found}
    end.

activate(UserId) ->
    ensure_table(),
    case ets:lookup(user_table, UserId) of
        [{_, #user_record{} = Rec}] ->
            Activated = Rec#user_record{status = active},
            ets:insert(user_table, {UserId, Activated}),
            {ok, to_map(Activated)};
        [] ->
            {error, not_found}
    end.

ensure_table() ->
    case ets:info(user_table) of
        undefined ->
            _ = ets:new(user_table, [
                named_table,
                public,
                set,
                {read_concurrency, true},
                {write_concurrency, true}
            ]),
            ok;
        _ ->
            ok
    end.

to_map(#user_record{
    user_id = Id,
    name = Name,
    email = Email,
    phone = Phone,
    status = Status,
    created_at = CreatedAt
}) ->
    #{
        user_id => Id,
        name => Name,
        email => Email,
        phone => Phone,
        status => Status,
        created_at => CreatedAt
    }.
