-module(chat_user).
-behaviour(gen_server).

-export([
    start_link/1,
    bind_device/2,
    state/1,
    whereis/1
]).

-export([
    init/1,
    handle_call/3,
    handle_cast/2,
    terminate/2,
    code_change/3
]).

-record(state, {
    user_id,
    user_model,
    last_seen,
    active_groups = []
}).



start_link(UserId) ->
    gen_server:start_link(
        {via, chat_proc_registry, name(UserId)},
        ?MODULE,
        UserId,
        []
    ).


bind_device(UserId, DeviceId) ->
    gen_server:call({via, chat_proc_registry, name(UserId)}, {bind_device, DeviceId}).

state(UserId) ->
    gen_server:call({via, chat_proc_registry, name(UserId)}, get_state).

whereis(UserId) ->
    chat_proc_registry:whereis_name(name(UserId)).


init(UserId) ->
    User = user:new(UserId, undefined, undefined, undefined),

    {ok, #state{
        user_id = UserId,
        user_model = User,
        last_seen = erlang:system_time(second)
    }}.


handle_call({bind_device, DeviceId}, _From, S) ->
    Updated = user:bind_device(S#state.user_model, DeviceId),
    {reply, ok, S#state{user_model = Updated}};

handle_call(get_state, _From, S) ->
    {reply, S, S};

handle_call(_, _From, S) ->
    {reply, error, S}.


handle_cast(_, State) ->
    {noreply, State}.

terminate(_, _) ->
    ok.

code_change(_, State, _) ->
    {ok, State}.

name(UserId) ->
    chat_proc_registry:user_name(UserId).