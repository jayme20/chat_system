-module(user_store).

-export([
    create/4,
    find/1,
    update/2,
    find_by_email/1,
    find_by_phone/1,
    activate/1
]).

create(UserId, Name, Email, Phone) ->
    apply(repo(), create, [UserId, Name, Email, Phone]).



find(UserId) ->
    apply(repo(), find, [UserId]).



find_by_phone(Phone) ->
    apply(repo(), find_by_phone, [Phone]).

find_by_email(Email) ->
    apply(repo(), find_by_email, [Email]).



update(UserId, Changes) ->
    apply(repo(), update, [UserId, Changes]).


activate(UserId) ->
    apply(repo(), activate, [UserId]).

repo() ->
    user_repo_selector:module().