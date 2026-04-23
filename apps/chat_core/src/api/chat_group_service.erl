-module(chat_group_service).

-export([
    create_group/5,
    create_group/6,
    get_group/1,
    list_groups/0,
    list_groups_for_user/1,
    add_member/3,
    add_member/4,
    remove_member/3,
    leave_group/2,
    update_target/3
]).



create_group(GroupId, Name, Purpose, Target, Visibility) ->
    {ok, Event} =
        chat_group:create(GroupId, Name, Purpose, Target, Visibility),

    persist(Event),
    {ok, GroupId}.

create_group(GroupId, CreatorId, Name, Purpose, Target, Visibility) ->
    {ok, CreatedEvent} =
        chat_group:create(GroupId, Name, Purpose, Target, Visibility),
    persist(CreatedEvent),

    %% WhatsApp-style: creator is first admin
    {ok, GroupState} = chat_store:lookup_group(GroupId),
    {ok, MemberEvent} =
        chat_group:add_member(GroupState, creator, CreatorId, creator),
    persist(MemberEvent),

    {ok, GroupId}.

get_group(GroupId) ->
    case group_state(GroupId) of
        not_found -> {error, not_found};
        Group -> {ok, Group}
    end.

list_groups_for_user(UserId) ->
    Groups = apply(group_repo(), list_groups_for_user, [UserId]),
    lists:foreach(
        fun(Group) ->
            GroupId = maps:get(group_id, Group),
            chat_store:insert_group(GroupId, Group)
        end,
        Groups
    ),
    {ok, Groups}.

list_groups() ->
    Groups = apply(group_repo(), list_groups, []),
    lists:foreach(
        fun(Group) ->
            GroupId = maps:get(group_id, Group),
            chat_store:insert_group(GroupId, Group)
        end,
        Groups
    ),
    {ok, Groups}.



add_member(GroupId, Role, UserId) ->
    add_member(GroupId, Role, UserId, member).

add_member(GroupId, Role, UserId, MemberRole) ->
    State = group_state(GroupId),

    case chat_group:add_member(State, Role, UserId, MemberRole) of
        {ok, Event} ->
            persist(Event),
            {ok, added};

        Error ->
            Error
    end.

leave_group(GroupId, UserId) ->
    case group_state(GroupId) of
        not_found ->
            {error, not_found};
        State ->
            GroupId1 = maps:get(group_id, State),
            {ok, Event} =
                chat_event:new(
                    member_removed,
                    GroupId1,
                    chat_group,
                    #{user_id => UserId}
                ),
            persist(Event),
            {ok, left}
    end.


remove_member(GroupId, Role, UserId) ->
    State = group_state(GroupId),

    case chat_group:remove_member(State, Role, UserId) of
        {ok, Event} ->
            persist(Event),
            {ok, removed};

        Error ->
            Error
    end.



update_target(GroupId, Role, Target) ->
    State = group_state(GroupId),

    case chat_group:update_target(State, Role, Target) of
        {ok, Event} ->
            persist(Event),
            {ok, updated};

        Error ->
            Error
    end.



persist(Event) ->
    event_store:append(Event),
    event_bus:publish(Event),
    apply_cache(Event).

apply_cache(Event) ->
    chat_store:ensure_tables(),
    GroupId = chat_event:aggregate_id(Event),
    case chat_event:type(Event) of
        group_created ->
            P = chat_event:payload(Event),
            Snapshot = #{
                group_id => GroupId,
                name => maps:get(name, P),
                purpose => maps:get(purpose, P),
                target => maps:get(target, P),
                visibility => maps:get(visibility, P),
                members => #{}
            },
            chat_store:insert_group(GroupId, Snapshot),
            _ = apply(group_repo(), create_group, [Snapshot]),
            ok;

        member_added ->
            P = chat_event:payload(Event),
            UserId = maps:get(user_id, P),
            Role = maps:get(role, P, member),
            {ok, S0} = chat_store:lookup_group(GroupId),
            Members0 = maps:get(members, S0, #{}),
            S1 = S0#{members => maps:put(UserId, Role, Members0)},
            chat_store:insert_group(GroupId, S1),
            _ = apply(group_repo(), add_member, [GroupId, UserId, Role]),
            ok;

        member_removed ->
            P = chat_event:payload(Event),
            UserId = maps:get(user_id, P),
            {ok, S0} = chat_store:lookup_group(GroupId),
            Members0 = maps:get(members, S0, #{}),
            S1 = S0#{members => maps:remove(UserId, Members0)},
            chat_store:insert_group(GroupId, S1),
            _ = apply(group_repo(), remove_member, [GroupId, UserId]),
            ok;

        _ ->
            ok
    end.

group_state(GroupId) ->
    case chat_store:lookup_group(GroupId) of
        {ok, S} ->
            S;
        _ ->
            case apply(group_repo(), get_group, [GroupId]) of
                {ok, Group} ->
                    Members = maps:from_list(apply(group_repo(), list_members, [GroupId])),
                    Snapshot = Group#{members => Members},
                    chat_store:insert_group(GroupId, Snapshot),
                    {ok, Snapshot};
                _ ->
                    not_found
            end
    end.

group_repo() ->
    group_repo_selector:module().