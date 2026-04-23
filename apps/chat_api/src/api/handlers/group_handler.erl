-module(group_handler).
-export([init/2]).

init(Req0, State) ->
    Method = cowboy_req:method(Req0),
    GroupId = cowboy_req:binding(id, Req0),

    case Method of

        <<"POST">> ->
            case user_id_from_token(Req0) of
                undefined ->
                    chat_api_response:error(
                        unauthorized,
                        <<"missing bearer token">>,
                        Req0,
                        State,
                        401
                    );
                CreatorId ->
                    {ok, Body, Req1} = cowboy_req:read_body(Req0),
                    case decode_json(Body) of
                        {error, invalid_json} ->
                            chat_api_response:error(invalid_json, <<"invalid json">>, Req1, State, 400);
                        {ok, Json} ->
                            Name = maps:get(<<"name">>, Json, undefined),
                            Purpose = maps:get(<<"purpose">>, Json, undefined),
                            Target = maps:get(<<"target">>, Json, undefined),
                            Visibility0 = maps:get(<<"visibility">>, Json, undefined),

                            case validate_create(Name, Purpose, Target, Visibility0) of
                                {error, Msg} ->
                                    chat_api_response:error(validation_error, Msg, Req1, State, 400);
                                ok ->
                                    Visibility = normalize_visibility(Visibility0),

                                    {ok, NewGroupId} =
                                        chat_group_service:create_group(
                                            chat_id:generate(),
                                            CreatorId,
                                            Name,
                                            Purpose,
                                            Target,
                                            Visibility
                                        ),

                                    chat_api_response:created(
                                        #{group_id => NewGroupId},
                                        Req1,
                                        State,
                                        201
                                    )
                            end
                    end
            end;

        <<"GET">> ->
            case user_id_from_token(Req0) of
                undefined ->
                    chat_api_response:error(
                        unauthorized,
                        <<"missing bearer token">>,
                        Req0,
                        State,
                        401
                    );
                UserId ->
                    case GroupId of
                        undefined ->
                            list_all_groups(UserId, Req0, State);
                        _ ->
                            get_group_details(GroupId, UserId, Req0, State)
                    end
            end;

        _ ->
            chat_api_response:error(
                method_not_allowed,
                <<"method not allowed">>,
                Req0,
                State,
                405
            )
    end.

list_all_groups(UserId, Req, State) ->
    {ok, Groups} = chat_group_service:list_groups(),
    Payload = [group_summary(Group, UserId) || Group <- Groups],
    chat_api_response:success(
        #{groups => Payload},
        Req,
        State,
        200
    ).

get_group_details(GroupId, UserId, Req, State) ->
    case chat_group_service:list_groups_for_user(UserId) of
        {ok, Groups} ->
            case find_group(GroupId, Groups) of
                {ok, Group} ->
                    chat_api_response:success(
                        #{group => group_details(Group, UserId)},
                        Req,
                        State,
                        200
                    );
                not_found ->
                    case chat_group_service:get_group(GroupId) of
                        {ok, _Group} ->
                            chat_api_response:error(
                                forbidden,
                                <<"you are not a member of this group">>,
                                Req,
                                State,
                                403
                            );
                        {error, not_found} ->
                            chat_api_response:error(
                                not_found,
                                <<"group not found">>,
                                Req,
                                State,
                                404
                            )
                    end
            end
    end.

group_summary(Group, UserId) ->
    GroupId = maps:get(group_id, Group),
    Target = maps:get(target, Group, 0),
    Members = maps:get(members, Group, #{}),
    WalletBalance = chat_store:group_total(GroupId),
    Progress = chat_store:group_progress(GroupId, Target),
    #{
        group_id => GroupId,
        name => maps:get(name, Group, <<>>),
        purpose => maps:get(purpose, Group, <<>>),
        visibility => maps:get(visibility, Group, public),
        wallet_balance => WalletBalance,
        target => Target,
        progress => Progress,
        participant_count => maps:size(Members),
        my_role => maps:get(UserId, Members, maps:get(my_role, Group, member))
    }.

group_details(Group, UserId) ->
    Summary = group_summary(Group, UserId),
    Members = maps:get(members, Group, #{}),
    Participants = maps:fold(
        fun(MemberId, Role, Acc) ->
            [#{user_id => MemberId, role => Role} | Acc]
        end,
        [],
        Members
    ),
    Summary#{
        participants => Participants
    }.

find_group(GroupId, [Group | Rest]) ->
    case maps:get(group_id, Group, undefined) =:= GroupId of
        true -> {ok, Group};
        false -> find_group(GroupId, Rest)
    end;
find_group(_GroupId, []) ->
    not_found.

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

validate_create(Name, Purpose, Target, Visibility) ->
    case {Name, Purpose, Target, Visibility} of
        {undefined, _, _, _} -> {error, <<"name required">>};
        {_, undefined, _, _} -> {error, <<"purpose required">>};
        {_, _, undefined, _} -> {error, <<"target required">>};
        {_, _, _, undefined} -> {error, <<"visibility required">>};
        {_, _, T, _} when not is_integer(T) -> {error, <<"target must be integer">>};
        {_, _, T, _} when T < 0 -> {error, <<"target must be >= 0">>};
        {_, _, _, V} ->
            case normalize_visibility(V) of
                invalid -> {error, <<"visibility must be 'public' or 'private'">>};
                _ -> ok
            end
    end.

normalize_visibility(public) -> public;
normalize_visibility(private) -> private;
normalize_visibility(<<"public">>) -> public;
normalize_visibility(<<"private">>) -> private;
normalize_visibility("public") -> public;
normalize_visibility("private") -> private;
normalize_visibility(_) -> invalid.

decode_json(Body) ->
    try
        {ok, jsx:decode(Body, [return_maps])}
    catch
        _:_ ->
            {error, invalid_json}
    end.