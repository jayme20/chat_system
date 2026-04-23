-module(group_message_bus).

-export([publish/1]).

publish(Event) ->
    Message = group_message:from_event(Event),
    io:format("MSG: ~p~n", [Message]),
    ok.