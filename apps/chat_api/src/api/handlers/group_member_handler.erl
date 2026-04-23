-module(group_member_handler).
-behaviour(cowboy_handler).

-export([init/2]).

init(Req, State) ->
    Method = cowboy_req:method(Req),
    Path = cowboy_req:path(Req),
    GroupId = cowboy_req:binding(id, Req),

    case user_id_from_token(Req) of
        undefined ->
            chat_api_response:error(
                unauthorized,
                <<"missing bearer token">>,
                Req,
                State,
                401
            );
        ActorId ->
            Role = actor_role(GroupId, ActorId),
            dispatch(Method, Path, GroupId, ActorId, Role, Req, State)
    end.

dispatch(<<"GET">>, Path, GroupId, _ActorId, _Role, Req, State) ->
    case action(Path, <<"GET">>) of
        participants_list ->
            list_participants(GroupId, Req, State);
        _ ->
            chat_api_response:error(method_not_allowed, <<"Method not allowed">>, Req, State, 405)
    end;

dispatch(<<"POST">>, Path, GroupId, ActorId, Role, Req0, State) ->
    case action(Path, <<"POST">>) of
        participant_add ->
            add_member_by_phone(GroupId, Role, Req0, State);
        participant_promote ->
            update_member_role_by_phone(GroupId, Role, admin, Req0, State);
        participant_demote ->
            update_member_role_by_phone(GroupId, Role, member, Req0, State);
        participant_leave ->
            leave_group(GroupId, ActorId, Req0, State);
        _ ->
            chat_api_response:error(method_not_allowed, <<"Method not allowed">>, Req0, State, 405)
    end;

dispatch(<<"DELETE">>, Path, GroupId, ActorId, Role, Req0, State) ->
    case action(Path, <<"DELETE">>) of
        participant_remove ->
            remove_member_by_phone(GroupId, Role, Req0, State);
        participant_leave ->
            leave_group(GroupId, ActorId, Req0, State);
        _ ->
            chat_api_response:error(method_not_allowed, <<"Method not allowed">>, Req0, State, 405)
    end;

dispatch(_, _Path, _GroupId, _ActorId, _Role, Req, State) ->
    chat_api_response:error(method_not_allowed, <<"Method not allowed">>, Req, State, 405).

add_member_by_phone(GroupId, Role, Req0, State) ->
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    case decode_json(Body) of
        {error, invalid_json} ->
            chat_api_response:error(invalid_json, <<"invalid json">>, Req1, State, 400);
        {ok, Data} ->
            Phone = maps:get(<<"phone">>, Data, undefined),
            case Phone of
                undefined ->
                    chat_api_response:error(validation_error, <<"phone required">>, Req1, State, 400);
                _ ->
                    case resolve_user_by_phone(Phone) of
                        {ok, UserId} ->
                            case chat_group_service:add_member(GroupId, Role, UserId) of
                                {ok, added} ->
                                    chat_api_response:success(
                                        #{member_status => added, phone => Phone},
                                        Req1,
                                        State,
                                        200
                                    );
                                {error, forbidden} ->
                                    chat_api_response:error(forbidden, <<"admin required">>, Req1, State, 403);
                                {error, Reason} ->
                                    chat_api_response:error(add_member_failed, Reason, Req1, State, 400)
                            end;
                        {error, not_found} ->
                            chat_api_response:error(not_found, <<"user not found for phone">>, Req1, State, 404)
                    end
            end
    end.

remove_member_by_phone(GroupId, Role, Req0, State) ->
    case member_phone(Req0) of
        {ok, Phone, Req1} ->
            case resolve_user_by_phone(Phone) of
                {ok, UserId} ->
                    case chat_group_service:remove_member(GroupId, Role, UserId) of
                        {ok, removed} ->
                            chat_api_response:success(
                                #{member_status => removed, phone => Phone},
                                Req1,
                                State,
                                200
                            );
                        {error, forbidden} ->
                            chat_api_response:error(forbidden, <<"admin required">>, Req1, State, 403);
                        {error, Reason} ->
                            chat_api_response:error(remove_member_failed, Reason, Req1, State, 400)
                    end;
                {error, not_found} ->
                    chat_api_response:error(not_found, <<"user not found for phone">>, Req1, State, 404)
            end;
        {error, invalid_json, Req1} ->
            chat_api_response:error(invalid_json, <<"invalid json">>, Req1, State, 400);
        {error, missing_phone, Req1} ->
            chat_api_response:error(validation_error, <<"phone required">>, Req1, State, 400)
    end.

update_member_role_by_phone(GroupId, Role, TargetRole, Req0, State) ->
    case member_phone(Req0) of
        {ok, Phone, Req1} ->
            case resolve_user_by_phone(Phone) of
                {ok, UserId} ->
                    case chat_group_service:add_member(GroupId, Role, UserId, TargetRole) of
                        {ok, added} ->
                            chat_api_response:success(
                                #{
                                    member_status => role_updated,
                                    phone => Phone,
                                    role => TargetRole
                                },
                                Req1,
                                State,
                                200
                            );
                        {error, forbidden} ->
                            chat_api_response:error(forbidden, <<"admin required">>, Req1, State, 403);
                        {error, Reason} ->
                            chat_api_response:error(update_member_role_failed, Reason, Req1, State, 400)
                    end;
                {error, not_found} ->
                    chat_api_response:error(not_found, <<"user not found for phone">>, Req1, State, 404)
            end;
        {error, invalid_json, Req1} ->
            chat_api_response:error(invalid_json, <<"invalid json">>, Req1, State, 400);
        {error, missing_phone, Req1} ->
            chat_api_response:error(validation_error, <<"phone required">>, Req1, State, 400)
    end.

leave_group(GroupId, ActorId, Req, State) ->
    case chat_group_service:leave_group(GroupId, ActorId) of
        {ok, left} ->
            chat_api_response:success(
                #{member_status => left},
                Req,
                State,
                200
            );
        {error, not_found} ->
            chat_api_response:error(not_found, <<"group not found">>, Req, State, 404);
        {error, Reason} ->
            chat_api_response:error(leave_group_failed, Reason, Req, State, 400)
    end.

list_participants(GroupId, Req, State) ->
    case chat_store:lookup_group(GroupId) of
        {ok, Snapshot} ->
            Members = maps:get(members, Snapshot, #{}),
            Participants = participants_payload(Members),
            chat_api_response:success(#{participants => Participants}, Req, State, 200);
        _ ->
            chat_api_response:error(not_found, <<"group not found">>, Req, State, 404)
    end.

participants_payload(Members) ->
    maps:fold(
        fun(UserId, MemberRole, Acc) ->
            case user_store:find(UserId) of
                {ok, User} ->
                    [
                        #{
                            user_id => UserId,
                            phone => maps:get(phone, User, undefined),
                            role => MemberRole
                        }
                        | Acc
                    ];
                _ ->
                    [#{user_id => UserId, role => MemberRole} | Acc]
            end
        end,
        [],
        Members
    ).

actor_role(GroupId, ActorId) ->
    case chat_store:lookup_group(GroupId) of
        {ok, S} ->
            Members = maps:get(members, S, #{}),
            maps:get(ActorId, Members, actor_role_from_repo(GroupId, ActorId));
        _ ->
            actor_role_from_repo(GroupId, ActorId)
    end.

actor_role_from_repo(GroupId, ActorId) ->
    Repo = group_repo_selector:module(),
    Members = apply(Repo, list_members, [GroupId]),
    case lists:keyfind(ActorId, 1, Members) of
        {ActorId, Role} -> Role;
        false -> member
    end.

user_id_from_token(Req) ->
    case cowboy_req:header(<<"authorization">>, Req) of
        undefined ->
            undefined;
        <<"Bearer ", Token/binary>> ->
            case auth_token:decode(Token) of
                {ok, UserId, _DeviceId, _Secret} -> UserId;
                _ -> undefined
            end;
        _ ->
            undefined
    end.

decode_json(Body) ->
    try
        {ok, jsx:decode(Body, [return_maps])}
    catch
        _:_ ->
            {error, invalid_json}
    end.

action(Path, Method) ->
    IsParticipants = has_suffix(Path, <<"/participants">>),
    IsMembers = has_suffix(Path, <<"/members">>),
    IsMembersPhone = has_suffix(Path, <<"/members/phone">>),
    IsLeave = has_suffix(Path, <<"/participants/leave">>),
    IsPromote = has_suffix(Path, <<"/promote">>),
    IsDemote = has_suffix(Path, <<"/demote">>),
    IsParticipantMemberPath = is_participant_member_path(Path),
    case {Method, IsParticipants, IsMembers, IsMembersPhone, IsLeave, IsPromote, IsDemote, IsParticipantMemberPath} of
        {<<"GET">>, true, _, _, _, _, _, _} -> participants_list;
        {<<"GET">>, _, true, _, _, _, _, _} -> participants_list;
        {<<"POST">>, _, _, _, true, _, _, _} -> participant_leave;
        {<<"POST">>, _, _, _, _, true, _, _} -> participant_promote;
        {<<"POST">>, _, _, _, _, _, true, _} -> participant_demote;
        {<<"POST">>, true, _, _, _, _, _, _} -> participant_add;
        {<<"POST">>, _, true, _, _, _, _, _} -> participant_add;
        {<<"POST">>, _, _, true, _, _, _, _} -> participant_add;
        {<<"DELETE">>, _, _, _, true, _, _, _} -> participant_leave;
        {<<"DELETE">>, true, _, _, _, _, _, _} -> participant_remove;
        {<<"DELETE">>, _, true, _, _, _, _, _} -> participant_remove;
        {<<"DELETE">>, _, _, true, _, _, _, _} -> participant_remove;
        {<<"DELETE">>, _, _, _, _, _, _, true} -> participant_remove;
        _ -> unknown
    end.

is_participant_member_path(Path) ->
    has_segment(Path, <<"/participants/">>) orelse has_segment(Path, <<"/members/phone/">>).

has_segment(Path, Segment) ->
    case binary:match(Path, Segment) of
        nomatch -> false;
        _ -> true
    end.

has_suffix(Bin, Suffix) ->
    BinSize = byte_size(Bin),
    SuffixSize = byte_size(Suffix),
    case BinSize >= SuffixSize of
        true ->
            binary:part(Bin, BinSize - SuffixSize, SuffixSize) =:= Suffix;
        false ->
            false
    end.

resolve_user_by_phone(Phone) ->
    Candidates = phone_candidates(Phone),
    resolve_user_by_phone_candidates(Candidates).

resolve_user_by_phone_candidates([Phone | Rest]) ->
    case user_store:find_by_phone(Phone) of
        {ok, UserId} ->
            {ok, UserId};
        {error, not_found} ->
            resolve_user_by_phone_candidates(Rest)
    end;
resolve_user_by_phone_candidates([]) ->
    {error, not_found}.

phone_candidates(Phone) when is_binary(Phone) ->
    Clean = strip_phone_separators(Phone),
    Digits = strip_plus(Clean),
    Local9 =
        case Digits of
            <<"254", Rest/binary>> when byte_size(Rest) =:= 9 -> Rest;
            <<"0", Rest/binary>> when byte_size(Rest) =:= 9 -> Rest;
            Raw when byte_size(Raw) =:= 9 -> Raw;
            _ -> <<>>
        end,
    Base = [Phone, Clean, Digits],
    MaybeKenya =
        case Local9 of
            <<>> ->
                [];
            _ ->
                [<<"+254", Local9/binary>>, <<"254", Local9/binary>>, <<"0", Local9/binary>>, Local9]
        end,
    unique_binaries(Base ++ MaybeKenya);
phone_candidates(_) ->
    [].

strip_phone_separators(Phone) ->
    binary:replace(
        binary:replace(
            binary:replace(Phone, <<" ">>, <<>>, [global]),
            <<"-">>,
            <<>>,
            [global]
        ),
        <<"(">>,
        <<>>,
        [global]
    ).

strip_plus(<<"+", Rest/binary>>) ->
    Rest;
strip_plus(Phone) ->
    Phone.

unique_binaries(List) ->
    unique_binaries(List, []).

unique_binaries([H | T], Acc) ->
    case (H =:= <<>>) orelse lists:member(H, Acc) of
        true ->
            unique_binaries(T, Acc);
        false ->
            unique_binaries(T, Acc ++ [H])
    end;
unique_binaries([], Acc) ->
    Acc.

member_phone(Req0) ->
    case cowboy_req:binding(phone, Req0) of
        undefined ->
            case cowboy_req:read_body(Req0) of
                {ok, Body, Req1} ->
                    case decode_json(Body) of
                        {ok, Data} ->
                            case maps:get(<<"phone">>, Data, undefined) of
                                undefined -> {error, missing_phone, Req1};
                                Phone -> {ok, Phone, Req1}
                            end;
                        {error, invalid_json} ->
                            {error, invalid_json, Req1}
                    end;
                {more, _, Req1} ->
                    {error, missing_phone, Req1}
            end;
        Phone ->
            {ok, Phone, Req0}
    end.
