-module(user_repo_amnesia).

-behaviour(user_repo_behaviour).

-export([
    create/4,
    find/1,
    update/2,
    find_by_email/1,
    find_by_phone/1,
    activate/1
]).

create(UserId, Name, Email, Phone) ->
    ok = chat_amnesia_bootstrap:ensure_started(),
    CreatedAt = erlang:system_time(second),
    Fun = fun() ->
        case mnesia:read(users, UserId, write) of
            [] ->
                ok = mnesia:write({users, UserId, Name, Email, Phone, pending, CreatedAt}),
                {ok, UserId};
            [_] ->
                {error, already_exists}
        end
    end,
    tx(Fun).

find(UserId) ->
    ok = chat_amnesia_bootstrap:ensure_started(),
    case mnesia:dirty_read(users, UserId) of
        [{users, Id, Name, Email, Phone, Status, CreatedAt}] ->
            {ok, #{
                user_id => Id,
                name => Name,
                email => Email,
                phone => Phone,
                status => Status,
                created_at => CreatedAt
            }};
        [] ->
            {error, not_found}
    end.

find_by_email(Email) ->
    ok = chat_amnesia_bootstrap:ensure_started(),
    Rows = mnesia:dirty_index_read(users, Email, email),
    case Rows of
        [{users, UserId, _Name, _Email, _Phone, _Status, _CreatedAt} | _] ->
            {ok, UserId};
        [] ->
            {error, not_found}
    end.

find_by_phone(Phone) ->
    ok = chat_amnesia_bootstrap:ensure_started(),
    Rows = mnesia:dirty_index_read(users, Phone, phone),
    case Rows of
        [{users, UserId, _Name, _Email, _Phone, _Status, _CreatedAt} | _] ->
            {ok, UserId};
        [] ->
            {error, not_found}
    end.

update(UserId, Changes) ->
    ok = chat_amnesia_bootstrap:ensure_started(),
    Fun = fun() ->
        case mnesia:read(users, UserId, write) of
            [{users, Id, Name, Email, Phone, Status, CreatedAt}] ->
                NewName = maps:get(name, Changes, Name),
                NewPhone = maps:get(phone, Changes, Phone),
                ok = mnesia:write({users, Id, NewName, Email, NewPhone, Status, CreatedAt}),
                {ok, #{
                    user_id => Id,
                    name => NewName,
                    email => Email,
                    phone => NewPhone,
                    status => Status,
                    created_at => CreatedAt
                }};
            [] ->
                {error, not_found}
        end
    end,
    tx(Fun).

activate(UserId) ->
    ok = chat_amnesia_bootstrap:ensure_started(),
    Fun = fun() ->
        case mnesia:read(users, UserId, write) of
            [{users, Id, Name, Email, Phone, _Status, CreatedAt}] ->
                ok = mnesia:write({users, Id, Name, Email, Phone, active, CreatedAt}),
                {ok, #{
                    user_id => Id,
                    name => Name,
                    email => Email,
                    phone => Phone,
                    status => active,
                    created_at => CreatedAt
                }};
            [] ->
                {error, not_found}
        end
    end,
    tx(Fun).

tx(Fun) ->
    case mnesia:transaction(Fun) of
        {atomic, Result} -> Result;
        {aborted, Reason} -> {error, Reason}
    end.
