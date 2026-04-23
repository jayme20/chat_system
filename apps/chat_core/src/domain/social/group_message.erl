-module(group_message).

-export([
    from_event/1,
    format/1,
    classify/1,
    to_map/1
]).

-record(message, {
    group_id,
    type,
    text,
    metadata = #{},
    timestamp
}).

%% =========================================================
%% ENTRY POINT: EVENT → MESSAGE
%% =========================================================

from_event(Event) ->
    Type = chat_event:type(Event),
    P = chat_event:payload(Event),
    GroupId = chat_event:aggregate_id(Event),

    case classify(Type) of

        financial ->
            #message{
                group_id = GroupId,
                type = financial,
                text = format_financial(Type, P),
                metadata = P,
                timestamp = os:system_time(second)
            };

        social ->
            #message{
                group_id = GroupId,
                type = social,
                text = format_social(Type, P),
                metadata = P,
                timestamp = os:system_time(second)
            };

        system ->
            #message{
                group_id = GroupId,
                type = system,
                text = format_system(Type, P),
                metadata = P,
                timestamp = os:system_time(second)
            };

        _ ->
            undefined
    end.

%% =========================================================
%% CLASSIFICATION LAYER
%% =========================================================

classify(contribution_received) -> financial;
classify(withdrawal_completed) -> financial;
classify(withdrawal_failed) -> system;
classify(group_created) -> social;
classify(member_added) -> social;
classify(member_removed) -> social;
classify(group_joined_via_invite) -> social;
classify(group_announcement_posted) -> social;
classify(target_updated) -> social;
classify(_) -> ignore.

%% =========================================================
%% FORMATTERS
%% =========================================================

format_financial(contribution_received, P) ->
    DisplayAmount = maps:get(gross_amount, P, maps:get(amount, P)),
    io_lib:format("~p contributed Ksh ~p",
        [maps:get(user_id, P), DisplayAmount]);

format_financial(withdrawal_completed, P) ->
    io_lib:format("Withdrawal of Ksh ~p completed",
        [maps:get(amount, P)]);

format_financial(_, _) ->
    "Financial event occurred".

%% --------------------------------------------------------

format_social(group_created, P) ->
    io_lib:format("Group created: ~s",
        [maps:get(name, P)]);

format_social(member_added, P) ->
    io_lib:format("User ~p joined the group",
        [maps:get(user_id, P)]);

format_social(member_removed, P) ->
    io_lib:format("User ~p was removed from group",
        [maps:get(user_id, P)]);

format_social(group_joined_via_invite, P) ->
    io_lib:format("User ~p joined via invite",
        [maps:get(user_id, P)]);

format_social(group_announcement_posted, P) ->
    maps:get(message, P);

format_social(target_updated, P) ->
    io_lib:format("Target updated to Ksh ~p",
        [maps:get(target, P)]);

format_social(_, _) ->
    "Group update occurred".

%% --------------------------------------------------------

format_system(withdrawal_failed, P) ->
    io_lib:format("Withdrawal failed for ~p",
        [maps:get(withdrawal_id, P)]);

format_system(_, _) ->
    "System event occurred".

%% =========================================================
%% OPTIONAL RAW FORMAT OUTPUT
%% =========================================================

format(Message) ->
    Message#message.text.

to_map(#message{
    group_id = GroupId,
    type = Type,
    text = Text,
    metadata = Metadata,
    timestamp = Timestamp
}) ->
    #{
        group_id => GroupId,
        type => atom_to_binary(Type, utf8),
        text => to_binary(Text),
        metadata => Metadata,
        timestamp => Timestamp
    }.

to_binary(Bin) when is_binary(Bin) ->
    Bin;
to_binary(List) when is_list(List) ->
    unicode:characters_to_binary(List);
to_binary(Other) ->
    unicode:characters_to_binary(io_lib:format("~p", [Other])).