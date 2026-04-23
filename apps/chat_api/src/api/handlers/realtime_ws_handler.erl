-module(realtime_ws_handler).

-export([init/2]).
-export([websocket_init/1, websocket_handle/2, websocket_info/2, terminate/3]).

-define(MAX_BATCH, 200).
-define(MAX_OUTBOUND, 500).

init(Req0, _State) ->
    case user_id_from_token(Req0) of
        undefined ->
            {ok, cowboy_req:reply(401, #{}, <<"unauthorized">>, Req0), undefined};
        UserId ->
            GroupId = query_bin(cowboy_req:parse_qs(Req0), <<"group_id">>, undefined),
            AfterSeq = query_int(cowboy_req:parse_qs(Req0), <<"after_seq">>, 0),
            {cowboy_websocket, Req0, #{
                user_id => UserId,
                group_id => GroupId,
                after_seq => AfterSeq,
                outbound_count => 0
            }}
    end.

websocket_init(State0) ->
    telemetry:execute(
        [chat_system, realtime, ws, connected],
        #{count => 1},
        #{user_id => maps:get(user_id, State0), group_id => maps:get(group_id, State0, undefined)}
    ),
    {reply, {text, jsx:encode(#{op => <<"welcome">>, protocol => <<"resume-v1">>})}, State0}.

websocket_handle({text, Raw}, State) ->
    case decode_json(Raw) of
        {ok, Msg} ->
            handle_client_message(Msg, State);
        {error, _} ->
            {reply, {text, jsx:encode(#{op => <<"error">>, reason => <<"invalid_json">>})}, State}
    end;
websocket_handle(_Frame, State) ->
    {ok, State}.

handle_client_message(#{<<"op">> := <<"resume">>} = Msg, State) ->
    GroupId = maps:get(<<"group_id">>, Msg, maps:get(group_id, State, undefined)),
    AfterSeq = maps:get(<<"after_seq">>, Msg, maps:get(after_seq, State, 0)),
    Limit0 = maps:get(<<"limit">>, Msg, 50),
    Limit = erlang:min(Limit0, ?MAX_BATCH),
    Messages = chat_store:get_group_messages_after(GroupId, AfterSeq, Limit),
    Outbound = maps:get(outbound_count, State, 0) + length(Messages),
    case Outbound > ?MAX_OUTBOUND of
        true ->
            telemetry:execute([chat_system, realtime, ws, backpressure], #{count => 1}, #{}),
            {stop, State};
        false ->
            Payload = #{
                op => <<"resume_result">>,
                group_id => GroupId,
                messages => Messages,
                next_cursor => next_cursor(AfterSeq, Messages),
                has_more => length(Messages) =:= Limit
            },
            {reply, {text, jsx:encode(Payload)}, State#{group_id => GroupId, after_seq => next_cursor(AfterSeq, Messages), outbound_count => Outbound}}
    end;
handle_client_message(#{<<"op">> := <<"ack">>} = Msg, State) ->
    GroupId = maps:get(<<"group_id">>, Msg, maps:get(group_id, State, undefined)),
    DeviceId = maps:get(<<"device_id">>, Msg, <<"default">>),
    AckSeq = maps:get(<<"ack_seq">>, Msg, 0),
    UserId = maps:get(user_id, State),
    Applied = chat_store:ack_group_seq(GroupId, UserId, DeviceId, AckSeq),
    telemetry:execute([chat_system, realtime, ws, ack], #{count => 1}, #{group_id => GroupId, ack_seq => Applied}),
    {reply, {text, jsx:encode(#{op => <<"ack_result">>, group_id => GroupId, ack_seq => Applied})}, State};
handle_client_message(#{<<"op">> := <<"ping">>}, State) ->
    {reply, {text, jsx:encode(#{op => <<"pong">>, ts => erlang:system_time(second)})}, State};
handle_client_message(_, State) ->
    {reply, {text, jsx:encode(#{op => <<"error">>, reason => <<"unknown_op">>})}, State}.

websocket_info(_Info, State) ->
    {ok, State}.

terminate(_Reason, _Req, State) ->
    telemetry:execute(
        [chat_system, realtime, ws, disconnected],
        #{count => 1},
        #{user_id => maps:get(user_id, State, undefined), group_id => maps:get(group_id, State, undefined)}
    ),
    ok.

decode_json(Bin) when is_binary(Bin) ->
    try
        {ok, jsx:decode(Bin, [return_maps])}
    catch
        _:_ -> {error, invalid_json}
    end.

next_cursor(AfterSeq, []) ->
    AfterSeq;
next_cursor(_AfterSeq, Messages) ->
    maps:get(seq, lists:last(Messages), 0).

query_bin(Qs, Key, Default) ->
    case lists:keyfind(Key, 1, Qs) of
        {Key, V} -> V;
        false -> Default
    end.

query_int(Qs, Key, Default) ->
    case query_bin(Qs, Key, undefined) of
        undefined -> Default;
        Bin ->
            try binary_to_integer(Bin) of
                I -> I
            catch
                _:_ -> Default
            end
    end.

user_id_from_token(Req) ->
    case cowboy_req:header(<<"authorization">>, Req) of
        undefined -> undefined;
        <<"Bearer ", Token/binary>> ->
            case auth_token:decode(Token) of
                {ok, UserId, _DeviceId, _Secret} -> UserId;
                _ -> undefined
            end;
        _ -> undefined
    end.
