-module(group_repo_behaviour).

-callback create_group(Group :: map()) -> {ok, binary()} | {error, term()}.
-callback get_group(GroupId :: binary()) -> {ok, map()} | {error, not_found}.
-callback add_member(GroupId :: binary(), UserId :: binary(), Role :: atom()) ->
    ok | {error, term()}.
-callback remove_member(GroupId :: binary(), UserId :: binary()) -> ok | {error, term()}.
-callback list_members(GroupId :: binary()) -> [{binary(), atom()}].
-callback list_groups_for_user(UserId :: binary()) -> [map()].
-callback list_groups() -> [map()].
