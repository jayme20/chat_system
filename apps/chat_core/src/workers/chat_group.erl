-module(chat_group).

-behaviour(gen_server).

-export([
    start_link/1,
    get_state/1,
    apply_event/2,
    whereis/1
]).

-export([
    init/1,
    handle_call/3,
    handle_cast/2,
    handle_info/2,
    terminate/2,
    code_change/3
]).

-record(state, {
    group_id,
    data = #{},
    version = 0
}).



start_link(GroupId) ->
    gen_server:start_link({via, chat_proc_registry, name(GroupId)}, ?MODULE, GroupId, []).


get_state(GroupId) ->
    gen_server:call({via, chat_proc_registry, name(GroupId)}, get_state).

apply_event(GroupId, Event) ->
    gen_server:cast({via, chat_proc_registry, name(GroupId)}, {apply_event, Event}).

whereis(GroupId) ->
    chat_proc_registry:whereis_name(name(GroupId)).


init(GroupId) ->
    {ok, #state{group_id = GroupId}}.



handle_call(get_state, _From, State) ->
    {reply, State, State};

handle_call(_, _, State) ->
    {reply, ok, State}.



handle_cast({apply_event, Event}, State) ->
    StartUs = erlang:monotonic_time(microsecond),
    NewState = evolve(State, Event),
    telemetry:execute(
        [chat_system, group, apply_event],
        #{duration_us => erlang:monotonic_time(microsecond) - StartUs, count => 1},
        #{group_id => State#state.group_id, event_type => chat_event:type(Event)}
    ),
    {noreply, NewState};

handle_cast(_, State) ->
    {noreply, State}.



evolve(State, Event) ->
    case chat_event:type(Event) of

        member_added ->
            State;

        member_removed ->
            State;

        target_updated ->
            State;

        group_created ->
            State#state{
                data = chat_event:payload(Event),
                version = 1
            };

        _ ->
            State
    end.



handle_info(_, State) -> {noreply, State}.
terminate(_, _) -> ok.
code_change(_, State, _) -> {ok, State}.

name(GroupId) ->
    chat_proc_registry:group_name(GroupId).