-module(group_invite).

-export([
    create/3,
    validate/2,
    consume/1,
    from_event/1
]).

-record(invite, {
    token,
    group_id,
    created_by,
    expires_at,
    uses_left = 1
}).

%% --------------------------------------------------------
%% CREATE INVITE
%% --------------------------------------------------------

create(GroupId, CreatedBy, TTLSeconds) ->
    Token = generate_token(),
    Expiry = os:system_time(second) + TTLSeconds,

    Event = chat_event:new(
        group_invite_created,
        GroupId,
        chat_group,
        #{
            token => Token,
            created_by => CreatedBy,
            expires_at => Expiry
        }
    ),

    {ok, Event}.

%% --------------------------------------------------------
%% VALIDATION (pure logic)
%% --------------------------------------------------------

validate(Invite, UserId) ->
    case Invite#invite.expires_at > os:system_time(second) of
        true -> {ok, Invite};
        false -> {error, expired}
    end.

%% --------------------------------------------------------
%% CONSUME INVITE
%% --------------------------------------------------------

consume(Invite) ->
    Invite#invite{uses_left = Invite#invite.uses_left - 1}.

%% --------------------------------------------------------
%% BUILD FROM EVENT
%% --------------------------------------------------------

from_event(Event) ->
    P = chat_event:payload(Event),
    #invite{
        token = maps:get(token, P),
        group_id = chat_event:aggregate_id(Event),
        created_by = maps:get(created_by, P),
        expires_at = maps:get(expires_at, P)
    }.

%% --------------------------------------------------------
%% INTERNAL
%% --------------------------------------------------------

generate_token() ->
    list_to_binary(
        io_lib:format("inv-~p-~p",
            [erlang:unique_integer([monotonic]), os:system_time(nanosecond)])
    ).