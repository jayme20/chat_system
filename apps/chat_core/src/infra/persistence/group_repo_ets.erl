-module(group_repo_ets).

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
    ensure_tables(),
    GroupId = maps:get(group_id, Group),
    ets:insert(group_store_table, {GroupId, Group}),
    {ok, GroupId}.

get_group(GroupId) ->
    ensure_tables(),
    case ets:lookup(group_store_table, GroupId) of
        [{GroupId, Group}] -> {ok, Group};
        [] -> {error, not_found}
    end.

add_member(GroupId, UserId, Role) ->
    ensure_tables(),
    ets:insert(group_members_store_table, {{GroupId, UserId}, Role}),
    ok.

remove_member(GroupId, UserId) ->
    ensure_tables(),
    ets:delete(group_members_store_table, {GroupId, UserId}),
    ok.

list_members(GroupId) ->
    ensure_tables(),
    Match = ets:match_object(group_members_store_table, {{GroupId, '_'}, '_'}),
    [{UserId, Role} || {{_G, UserId}, Role} <- Match].

list_groups_for_user(UserId) ->
    ensure_tables(),
    Memberships = ets:match_object(group_members_store_table, {{'_', UserId}, '_'}),
    lists:foldl(
        fun({{GroupId, _}, Role}, Acc) ->
            case get_group(GroupId) of
                {ok, Group} ->
                    Members = maps:from_list(list_members(GroupId)),
                    [Group#{members => Members, my_role => Role} | Acc];
                {error, not_found} ->
                    Acc
            end
        end,
        [],
        Memberships
    ).

list_groups() ->
    ensure_tables(),
    Groups = ets:match_object(group_store_table, {'_', '_'}),
    lists:foldl(
        fun({GroupId, Group}, Acc) ->
            Members = maps:from_list(list_members(GroupId)),
            [Group#{members => Members} | Acc]
        end,
        [],
        Groups
    ).

ensure_tables() ->
    ensure(group_store_table, set),
    ensure(group_members_store_table, set),
    ok.

ensure(Name, Type) ->
    case ets:info(Name) of
        undefined ->
            _ = ets:new(Name, [
                named_table,
                public,
                Type,
                {read_concurrency, true},
                {write_concurrency, true}
            ]),
            ok;
        _ ->
            ok
    end.
