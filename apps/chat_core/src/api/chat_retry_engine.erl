-module(chat_retry_engine).

-export([enqueue/1, process/0]).

enqueue(Job) ->
    retry_queue:enqueue(Job),
    {ok, queued}.

process() ->
    Jobs = retry_queue:process(),

    lists:foreach(fun(Job) ->
        case execute(Job) of
            ok -> ok;
            _ -> retry_queue:enqueue(Job)
        end
    end, Jobs).

execute(Job) ->
    case Job of
        {mpesa_withdrawal, Payload} ->
            mpesa_b2c_api:send(Payload);

        _ ->
            ok
    end.