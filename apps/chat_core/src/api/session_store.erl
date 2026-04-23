-module(session_store).

-export([
    create/3,
    find/2,
    revoke/1,
    revoke/2
]).

create(UserId, DeviceId, Token) ->
    apply(repo(), create, [UserId, DeviceId, Token]).

find(UserId, DeviceId) ->
    apply(repo(), find, [UserId, DeviceId]).

revoke(UserId) ->
    apply(repo(), revoke_user, [UserId]).

revoke(UserId, DeviceId) ->
    apply(repo(), revoke_device, [UserId, DeviceId]).

repo() ->
    session_repo_selector:module().

