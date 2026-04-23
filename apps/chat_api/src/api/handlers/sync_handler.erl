-module(sync_handler).
-behaviour(cowboy_handler).

-export([init/2]).

-define(DEFAULT_LIMIT, 50).
-define(MAX_LIMIT, 200).

init(Req0, State) ->
    Method = cowboy_req:method(Req0),
    Path = cowboy_req:path(Req0),
    case {Method, has_suffix(Path, <<"/sync/resume">>)} of
        {<<"POST">>, true} ->
            handle_resume(Req0, State);
        {<<"POST">>, false} ->
            chat_api_response:error(not_found, <<"route not found">>, Req0, State, 404);
        _ ->
            chat_api_response:error(method_not_allowed, <<"method not allowed">>, Req0, State, 405)
    end.

handle_resume(Req0, State) ->
    case user_id_from_token(Req0) of
        undefined ->
            chat_api_response:error(unauthorized, <<"missing bearer token">>, Req0, State, 401);
        UserId ->
            {ok, Body, Req1} = cowboy_req:read_body(Req0),
            case decode_json(Body) of
                {error, invalid_json} ->
                    chat_api_response:error(invalid_json, <<"invalid json">>, Req1, State, 400);
                {ok, Data} ->
                    DeviceId = maps:get(<<"device_id">>, Data, <<"default">>),
                    Cursors = maps:get(<<"cursors">>, Data, []),
                    UpdatedOnly = maps:get(<<"updated_groups_only">>, Data, false),
                    case is_list(Cursors) of
                        false ->
                            chat_api_response:error(validation_error, <<"cursors must be an array">>, Req1, State, 400);
                        true ->
                            Groups0 = [resume_group(UserId, DeviceId, Cursor) || Cursor <- Cursors],
                            Groups = maybe_filter_updated_only(Groups0, UpdatedOnly),
                            Summary = sync_summary(Groups0, Groups),
                            chat_api_response:success(
                                #{
                                    device_id => DeviceId,
                                    updated_groups_only => UpdatedOnly,
                                    summary => Summary,
                                    groups => Groups
                                },
                                Req1,
                                State,
                                200
                            )
                    end
            end
    end.

resume_group(UserId, DeviceId, Cursor) ->
    GroupId = maps:get(<<"group_id">>, Cursor, undefined),
    AfterSeq = read_int(Cursor, <<"after_seq">>, 0),
    Limit0 = read_int(Cursor, <<"limit">>, ?DEFAULT_LIMIT),
    Limit = clamp(Limit0, 1, ?MAX_LIMIT),
    case GroupId of
        undefined ->
            #{
                group_id => undefined,
                status => <<"invalid">>,
                error => <<"group_id required">>
            };
        _ ->
            case ensure_group_member(GroupId, UserId) of
                {error, not_found} ->
                    #{
                        group_id => GroupId,
                        status => <<"not_found">>,
                        error => <<"group not found">>
                    };
                {error, forbidden} ->
                    #{
                        group_id => GroupId,
                        status => <<"forbidden">>,
                        error => <<"not a member">>
                    };
                ok ->
                    MessagesPlus = chat_store:get_group_messages_after(GroupId, AfterSeq, Limit + 1),
                    HasMore = length(MessagesPlus) > Limit,
                    Messages = case HasMore of
                        true -> lists:sublist(MessagesPlus, Limit);
                        false -> MessagesPlus
                    end,
                    NextCursor = next_cursor(AfterSeq, Messages),
                    AckSeq = chat_store:get_group_ack(GroupId, UserId, DeviceId),
                    #{
                        group_id => GroupId,
                        status => <<"ok">>,
                        messages => Messages,
                        paging => #{
                            after_seq => AfterSeq,
                            next_cursor => NextCursor,
                            limit => Limit,
                            has_more => HasMore
                        },
                        ack => #{
                            device_id => DeviceId,
                            ack_seq => AckSeq
                        }
                    }
            end
    end.

ensure_group_member(GroupId, UserId) ->
    case chat_store:lookup_group(GroupId) of
        not_found ->
            {error, not_found};
        {ok, GroupState} ->
            Members = maps:get(members, GroupState, #{}),
            case maps:is_key(UserId, Members) of
                true -> ok;
                false -> {error, forbidden}
            end
    end.

read_int(Map, Key, Default) ->
    case maps:get(Key, Map, Default) of
        I when is_integer(I) -> I;
        Bin when is_binary(Bin) ->
            try binary_to_integer(Bin) of
                Int -> Int
            catch
                _:_ -> Default
            end;
        _ ->
            Default
    end.

next_cursor(AfterSeq, []) ->
    AfterSeq;
next_cursor(_AfterSeq, Messages) ->
    Last = lists:last(Messages),
    maps:get(seq, Last, 0).

clamp(Value, Min, Max) when Value < Min -> Min;
clamp(Value, _Min, Max) when Value > Max -> Max;
clamp(Value, _Min, _Max) -> Value.

maybe_filter_updated_only(Groups, true) ->
    [G || G <- Groups, group_has_updates(G)];
maybe_filter_updated_only(Groups, _) ->
    Groups.

group_has_updates(Group) ->
    case maps:get(status, Group, <<"invalid">>) of
        <<"ok">> ->
            case maps:get(messages, Group, []) of
                [] -> false;
                _ -> true
            end;
        _ ->
            true
    end.

sync_summary(AllGroups, ReturnedGroups) ->
    #{
        total_groups => length(AllGroups),
        returned_groups => length(ReturnedGroups),
        updated_count => count_updated(ReturnedGroups),
        error_count => count_errors(ReturnedGroups)
    }.

count_updated(Groups) ->
    length([G || G <- Groups, maps:get(status, G, <<"invalid">>) =:= <<"ok">>,
        maps:get(messages, G, []) =/= []]).

count_errors(Groups) ->
    length([G || G <- Groups, maps:get(status, G, <<"ok">>) =/= <<"ok">>]).

has_suffix(Bin, Suffix) ->
    BinSize = byte_size(Bin),
    SuffixSize = byte_size(Suffix),
    case BinSize >= SuffixSize of
        true ->
            binary:part(Bin, BinSize - SuffixSize, SuffixSize) =:= Suffix;
        false ->
            false
    end.

decode_json(Body) ->
    try
        {ok, jsx:decode(Body, [return_maps])}
    catch
        _:_ ->
            {error, invalid_json}
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
