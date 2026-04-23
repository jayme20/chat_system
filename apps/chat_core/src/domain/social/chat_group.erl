-module(chat_group).

-export([
    create/5,
    add_member/3,
    add_member/4,
    remove_member/3,
    update_target/3
]).

-record(group, {
    group_id,
    name,
    purpose,
    target = 0,
    members = #{},
    visibility = public,
    version = 0
}).

-record(state, {
    group = undefined
}).


create(GroupId, Name, Purpose, Target, Visibility) ->
    {ok, chat_event:new(
        group_created,
        GroupId,
        chat_group,
        #{
            name => Name,
            purpose => Purpose,
            target => Target,
            visibility => Visibility
        }
    )}.


add_member(State, Role, UserId) ->
    add_member(State, Role, UserId, member).

add_member(State, Role, UserId, MemberRole) ->
    case group_policy:can_add_member(Role, State) of
        true ->
            {ok, chat_event:new(
                member_added,
                group_id(State),
                chat_group,
                #{user_id => UserId, role => MemberRole}
            )};
        false ->
            {error, forbidden}
    end.


remove_member(State, Role, UserId) ->
    case group_policy:can_remove_member(Role, State) of
        true ->
            {ok, chat_event:new(
                member_removed,
                group_id(State),
                chat_group,
                #{user_id => UserId}
            )};
        false ->
            {error, forbidden}
    end.


update_target(State, Role, Target) ->
    case group_policy:can_update_target(Role, State) of
        true ->
            {ok, chat_event:new(
                target_updated,
                group_id(State),
                chat_group,
                #{target => Target}
            )};
        false ->
            {error, forbidden}
    end.

state(#state{group = G}) -> G;
state(G) -> G.

group_id(State) ->
    Group = state(State),
    case Group of
        #group{group_id = GroupId} ->
            GroupId;
        #{group_id := GroupId} ->
            GroupId
    end.