-module(event_bus).

-export([publish/1, subscribe/1]).

publish(Event) ->
    StartUs = erlang:monotonic_time(microsecond),
    wallet_projection:update(Event),
    group_message_bus:publish(Event),
    notification_service:handle_event(Event),
    fraud_engine:analyze(Event),
    telemetry:execute(
        [chat_system, event_bus, publish],
        #{duration_us => erlang:monotonic_time(microsecond) - StartUs, count => 1},
        #{event_type => chat_event:type(Event)}
    ),
    ok.

subscribe(_Handler) ->
    ok.