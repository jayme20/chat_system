-module(event_repo_behaviour).

-callback append(Event :: term()) -> {ok, stored | duplicate_ignored} | {error, term()}.
-callback exists(EventId :: binary()) -> boolean().
-callback get_stream(AggregateId :: binary()) -> [term()].
