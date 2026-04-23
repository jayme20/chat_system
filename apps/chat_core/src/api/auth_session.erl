-module(auth_session).
-behaviour(gen_statem).

-export([
    start/3,
    is_valid/2,
    get_info/1,
    stop/1
]).

-export([
    init/1,
    callback_mode/0,
    active/3,
    expired/3,
    terminated/3,
    terminate/2,
    code_change/3
]).

-record(state, {
    user_id,
    device_id,
    secret,
    created_at,
    last_seen,
    expiry
}).

start(UserId, DeviceId, Secret) ->
    gen_statem:start(?MODULE, {UserId, DeviceId, Secret}, []).


init({UserId, DeviceId, Secret}) ->

    Now = erlang:system_time(second),
    TtlSeconds = chat_runtime_config:session_ttl_seconds(),

    State = #state{
        user_id = UserId,
        device_id = DeviceId,
        secret = Secret,
        created_at = Now,
        last_seen = Now,
        expiry = Now + TtlSeconds
    },
    {ok, active, State}.

callback_mode() ->
    state_functions.



%% Validate session (used by session_handler)
is_valid(Pid, Secret) ->
    gen_statem:call(Pid, {is_valid, Secret}).

%% Get session info (debug / admin)
get_info(Pid) ->
    gen_statem:call(Pid, get_info).

%% Stop session (logout)
stop(Pid) ->
    gen_statem:call(Pid, stop).


active({call, From}, {is_valid, Secret}, State) ->
    StartUs = erlang:monotonic_time(microsecond),
    Now = erlang:system_time(second),

    case Now > State#state.expiry of
        true ->
            emit_validation_telemetry(expired, StartUs),
            {next_state, expired, State, [{reply, From, false}]};

        false when Secret =:= State#state.secret ->
            NewState = State#state{last_seen = Now},
            emit_validation_telemetry(ok, StartUs),
            {keep_state, NewState, [{reply, From, true}]};

        false ->
            emit_validation_telemetry(invalid_secret, StartUs),
            {keep_state_and_data, [{reply, From, false}]}
    end;
active({call, From}, get_info, State) ->
    {keep_state_and_data, [{reply, From, State}]};
active({call, From}, stop, State) ->
    {next_state, terminated, State, [{reply, From, ok}, stop]};
active(_EventType, _EventContent, _State) ->
    keep_state_and_data.


expired({call, From}, {is_valid, _Secret}, _State) ->
    {keep_state_and_data, [{reply, From, false}]};
expired({call, From}, get_info, State) ->
    {keep_state_and_data, [{reply, From, State}]};
expired({call, From}, stop, State) ->
    {next_state, terminated, State, [{reply, From, ok}, stop]};
expired(_EventType, _EventContent, _State) ->
    keep_state_and_data.


terminated({call, From}, _Msg, _State) ->
    {keep_state_and_data, [{reply, From, {error, terminated}}]};
terminated(_EventType, _EventContent, _State) ->
    keep_state_and_data.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

emit_validation_telemetry(Result, StartUs) ->
    DurationUs = erlang:monotonic_time(microsecond) - StartUs,
    telemetry:execute(
        [chat_system, auth, session, validate],
        #{duration_us => DurationUs, count => 1},
        #{result => Result}
    ).