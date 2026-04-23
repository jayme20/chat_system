-module(group_message_bus).

-export([publish/1]).

publish(Event) ->
    Message = group_message:from_event(Event),
    case Message of
        undefined ->
            ok;
        _ ->
            MessageMap = group_message:to_map(Message),
            _Stored = chat_store:append_group_message(
                chat_event:aggregate_id(Event),
                MessageMap
            ),
            ok
    end,
    ok.