-module(group_repo_amnesia).

-behaviour(group_repo_behaviour).

-export([
    create_group/1,
    get_group/1,
    add_member/3,
    remove_member/2,
    list_members/1,
    list_groups_for_user/1,
    list_groups/0
]).

create_group(Group) ->
    ok = chat_amnesia_bootstrap:ensure_started(),
    GroupId = maps:get(group_id, Group),
    Name = maps:get(name, Group),
    Purpose = maps:get(purpose, Group),
    Target = maps:get(target, Group, 0),
    Visibility = maps:get(visibility, Group, public),
    CreatedBy = maps:get(created_by, Group, <<>>),
    CreatedAt = maps:get(created_at, Group, erlang:system_time(second)),
    Fun = fun() ->
        ok = mnesia:write({groups, GroupId, Name, Purpose, Target, Visibility, CreatedBy, CreatedAt}),
        {ok, GroupId}
    end,
    tx(Fun).

get_group(GroupId) ->
    ok = chat_amnesia_bootstrap:ensure_started(),
    case mnesia:dirty_read(groups, GroupId) of
        [{groups, Id, Name, Purpose, Target, Visibility, CreatedBy, CreatedAt}] ->
            {ok, #{
                group_id => Id,
                name => Name,
                purpose => Purpose,
                target => Target,
                visibility => Visibility,
                created_by => CreatedBy,
                created_at => CreatedAt
            }};
        [] ->
            {error, not_found}
    end.

add_member(GroupId, UserId, Role) ->
    ok = chat_amnesia_bootstrap:ensure_started(),
    Key = {GroupId, UserId},
    AddedAt = erlang:system_time(second),
    Fun = fun() ->
        ok = mnesia:write({group_members, Key, GroupId, UserId, Role, AddedAt}),
        ok
    end,
    tx(Fun).

remove_member(GroupId, UserId) ->
    ok = chat_amnesia_bootstrap:ensure_started(),
    Key = {GroupId, UserId},
    Fun = fun() ->
        mnesia:delete({group_members, Key}),
        ok
    end,
    tx(Fun).

list_members(GroupId) ->
    ok = chat_amnesia_bootstrap:ensure_started(),
    Rows = mnesia:dirty_index_read(group_members, GroupId, group_id),
    [{UserId, Role} || {group_members, _Key, _GroupId, UserId, Role, _AddedAt} <- Rows].

list_groups_for_user(UserId) ->
    ok = chat_amnesia_bootstrap:ensure_started(),
    Rows = mnesia:dirty_match_object({group_members, '_', '_', UserId, '_', '_'}),
    lists:foldl(
        fun({group_members, _Key, GroupId, _U, Role, _AddedAt}, Acc) ->
            case get_group(GroupId) of
                {ok, Group} ->
                    Members = maps:from_list(list_members(GroupId)),
                    [Group#{members => Members, my_role => Role} | Acc];
                {error, not_found} ->
                    Acc
            end
        end,
        [],
        Rows
    ).

list_groups() ->
    ok = chat_amnesia_bootstrap:ensure_started(),
    GroupIds = mnesia:dirty_all_keys(groups),
    lists:foldl(
        fun(GroupId, Acc) ->
            case get_group(GroupId) of
                {ok, Group} ->
                    Members = maps:from_list(list_members(GroupId)),
                    [Group#{members => Members} | Acc];
                {error, not_found} ->
                    Acc
            end
        end,
        [],
        GroupIds
    ).

tx(Fun) ->
    case mnesia:transaction(Fun) of
        {atomic, Result} -> Result;
        {aborted, Reason} -> {error, Reason}
    end.
