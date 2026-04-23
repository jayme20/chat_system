-module(finance_handler).
-behaviour(cowboy_handler).

-export([init/2]).

init(Req0, State) ->
    Method = cowboy_req:method(Req0),
    GroupId = cowboy_req:binding(group_id, Req0),
    Path = cowboy_req:path(Req0),
    case {Method, action(Path)} of
        {<<"GET">>, statement} ->
            Month = query_bin(cowboy_req:parse_qs(Req0), <<"month">>, undefined),
            Payload = finance_statement_service:group_statement(GroupId, Month),
            chat_api_response:success(Payload, Req0, State, 200);
        {<<"GET">>, receipt} ->
            ReceiptId = cowboy_req:binding(receipt_id, Req0),
            case finance_statement_service:receipt(GroupId, ReceiptId) of
                {error, not_found} ->
                    chat_api_response:error(not_found, <<"receipt not found">>, Req0, State, 404);
                Payload ->
                    chat_api_response:success(Payload, Req0, State, 200)
            end;
        _ ->
            chat_api_response:error(method_not_allowed, <<"method not allowed">>, Req0, State, 405)
    end.

action(Path) ->
    case {has_suffix(Path, <<"/statements">>), has_segment(Path, <<"/receipts/">>)} of
        {true, _} -> statement;
        {_, true} -> receipt;
        _ -> unknown
    end.

has_suffix(Bin, Suffix) ->
    BinSize = byte_size(Bin),
    SuffixSize = byte_size(Suffix),
    case BinSize >= SuffixSize of
        true -> binary:part(Bin, BinSize - SuffixSize, SuffixSize) =:= Suffix;
        false -> false
    end.

has_segment(Path, Segment) ->
    case binary:match(Path, Segment) of
        nomatch -> false;
        _ -> true
    end.

query_bin(Qs, Key, Default) ->
    case lists:keyfind(Key, 1, Qs) of
        {Key, Value} -> Value;
        false -> Default
    end.
