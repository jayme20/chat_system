-module(chat_event_worker).
-behaviour(gen_server).

%% API
-export([
    start_link/0,
    publish/1
]).

%% gen_server callbacks
-export([
    init/1,
    handle_call/3,
    handle_cast/2,
    handle_info/2,
    terminate/2,
    code_change/3
]).

-define(SERVER, ?MODULE).

%%%===================================================================
%%% API
%%%===================================================================

start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

%% Async event publish (fire-and-forget)
publish(Event) ->
    gen_server:cast(?SERVER, {event, Event}).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

init([]) ->
    process_flag(trap_exit, true),
    {ok, #{events_processed => 0}}.

%% Optional synchronous interface
handle_call(_Request, _From, State) ->
    {reply, {error, unsupported_call}, State}.

%% Event handling
handle_cast({event, Event}, State) ->
    try
        event_bus:publish(Event),
        NewState = increment_counter(State),
        {noreply, NewState}
    catch
        Class:Reason:Stack ->
            error_logger:error_msg(
                "Event publish failed: ~p:~p~nStack: ~p~n",
                [Class, Reason, Stack]
            ),
            {noreply, State}
    end;

handle_cast(_, State) ->
    {noreply, State}.

%% Future async messages (timeouts, monitors, etc.)
handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%%===================================================================
%%% Internal
%%%===================================================================

increment_counter(State) ->
    Count = maps:get(events_processed, State, 0),
    State#{events_processed => Count + 1}.