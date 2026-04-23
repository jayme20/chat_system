-module(chat_session).

-export([open/1, send_message/4]).

open(UserId) ->
    {ok, #{user_id => UserId, started_at => erlang:system_time(second)}}.

send_message(GroupId, UserId, MsgId, Msg) ->
    case chat_registry:whereis(GroupId) of
        {ok, _Pid} ->
            Event = chat_event:new(
                group_message_sent,
                GroupId,
                chat_group,
                #{
                    user_id => UserId,
                    message_id => MsgId,
                    message => Msg
                }
            ),

            event_store:append(Event),
            group_message_bus:publish(Event),
            {ok, sent};

        not_found ->
            {error, group_not_found}
    end.