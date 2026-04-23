-module(group_sync_handler).
-behaviour(cowboy_handler).

-export([init/2]).

-define(DEFAULT_LIMIT, 50).
-define(MAX_LIMIT, 200).

init(Req0, State) ->
    Method = cowboy_req:method(Req0),
    GroupId = cowboy_req:binding(group_id, Req0),
    Path = cowboy_req:path(Req0),
    case user_id_from_token(Req0) of
        undefined ->
            chat_api_response:error(unauthorized, <<"missing bearer token">>, Req0, State, 401);
        UserId ->
            case ensure_group_member(GroupId, UserId) of
                {error, not_found} ->
                    chat_api_response:error(not_found, <<"group not found">>, Req0, State, 404);
                {error, forbidden} ->
                    chat_api_response:error(forbidden, <<"you are not a member of this group">>, Req0, State, 403);
                ok ->
                    route(Method, Path, GroupId, UserId, Req0, State)
            end
    end.

route(<<"GET">>, Path, GroupId, UserId, Req0, State) ->
    case has_suffix(Path, <<"/messages">>) of
        true -> get_messages(GroupId, UserId, Req0, State);
        false -> chat_api_response:error(not_found, <<"route not found">>, Req0, State, 404)
    end;
route(<<"POST">>, Path, GroupId, UserId, Req0, State) ->
    case has_suffix(Path, <<"/acks">>) of
        true -> post_ack(GroupId, UserId, Req0, State);
        false -> chat_api_response:error(not_found, <<"route not found">>, Req0, State, 404)
    end;
route(_, _Path, _GroupId, _UserId, Req0, State) ->
    chat_api_response:error(method_not_allowed, <<"method not allowed">>, Req0, State, 405).

get_messages(GroupId, UserId, Req0, State) ->
    Qs = cowboy_req:parse_qs(Req0),
    AfterSeq = query_int(Qs, <<"after_seq">>, 0),
    Limit0 = query_int(Qs, <<"limit">>, ?DEFAULT_LIMIT),
    Limit = clamp(Limit0, 1, ?MAX_LIMIT),
    DeviceId = query_bin(Qs, <<"device_id">>, <<"default">>),
    MessagesPlus = chat_store:get_group_messages_after(GroupId, AfterSeq, Limit + 1),
    HasMore = length(MessagesPlus) > Limit,
    Messages = case HasMore of
        true -> lists:sublist(MessagesPlus, Limit);
        false -> MessagesPlus
    end,
    NextCursor = next_cursor(AfterSeq, Messages),
    AckSeq = chat_store:get_group_ack(GroupId, UserId, DeviceId),
    chat_api_response:success(
        #{
            group_id => GroupId,
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
        },
        Req0,
        State,
        200
    ).

post_ack(GroupId, UserId, Req0, State) ->
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    case decode_json(Body) of
        {error, invalid_json} ->
            chat_api_response:error(invalid_json, <<"invalid json">>, Req1, State, 400);
        {ok, Data} ->
            DeviceId = maps:get(<<"device_id">>, Data, <<"default">>),
            AckSeq = maps:get(<<"ack_seq">>, Data, undefined),
            case AckSeq of
                Seq when is_integer(Seq), Seq >= 0 ->
                    AppliedSeq = chat_store:ack_group_seq(GroupId, UserId, DeviceId, Seq),
                    chat_api_response:success(
                        #{
                            group_id => GroupId,
                            device_id => DeviceId,
                            ack_seq => AppliedSeq
                        },
                        Req1,
                        State,
                        200
                    );
                _ ->
                    chat_api_response:error(validation_error, <<"ack_seq must be integer >= 0">>, Req1, State, 400)
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

next_cursor(AfterSeq, []) ->
    AfterSeq;
next_cursor(_AfterSeq, Messages) ->
    Last = lists:last(Messages),
    maps:get(seq, Last, 0).

query_int(Qs, Key, Default) ->
    case query_bin(Qs, Key, undefined) of
        undefined -> Default;
        Value ->
            try binary_to_integer(Value) of
                Int -> Int
            catch
                _:_ -> Default
            end
    end.

query_bin(Qs, Key, Default) ->
    case lists:keyfind(Key, 1, Qs) of
        {Key, Value} -> Value;
        false -> Default
    end.

clamp(Value, Min, Max) when Value < Min -> Min;
clamp(Value, _Min, Max) when Value > Max -> Max;
clamp(Value, _Min, _Max) -> Value.

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
