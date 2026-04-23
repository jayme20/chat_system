-module(mpesa_circuit_breaker).
-behaviour(gen_server).

-export([start_link/0, execute/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

execute(Fun) when is_function(Fun, 0) ->
    gen_server:call(?MODULE, {execute, Fun}, 15000).

init([]) ->
    FailThreshold = chat_runtime_config:get(mpesa_breaker_fail_threshold),
    CooldownMs = chat_runtime_config:get(mpesa_breaker_cooldown_ms),
    {ok, #{
        state => closed,
        failure_count => 0,
        opened_until_ms => 0,
        fail_threshold => default(FailThreshold, 3),
        cooldown_ms => default(CooldownMs, 10000)
    }}.

handle_call({execute, Fun}, _From, State = #{state := open, opened_until_ms := UntilMs}) ->
    NowMs = now_ms(),
    case NowMs < UntilMs of
        true ->
            telemetry:execute([chat_system, mpesa, breaker, reject], #{count => 1}, #{}),
            {reply, {error, circuit_open}, State};
        false ->
            handle_execute(Fun, State#{state => half_open})
    end;
handle_call({execute, Fun}, _From, State) ->
    handle_execute(Fun, State).

handle_execute(Fun, State) ->
    StartUs = erlang:monotonic_time(microsecond),
    Result =
        try
            Fun()
        catch
            Class:Reason ->
                {error, {Class, Reason}}
        end,
    DurationUs = erlang:monotonic_time(microsecond) - StartUs,
    case is_error(Result) of
        true ->
            NewState = on_failure(State),
            telemetry:execute([chat_system, mpesa, call], #{duration_us => DurationUs, success => 0}, #{}),
            {reply, Result, NewState};
        false ->
            NewState = State#{state => closed, failure_count => 0, opened_until_ms => 0},
            telemetry:execute([chat_system, mpesa, call], #{duration_us => DurationUs, success => 1}, #{}),
            {reply, Result, NewState}
    end.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

on_failure(State = #{failure_count := Count, fail_threshold := Threshold, cooldown_ms := CooldownMs}) ->
    NewCount = Count + 1,
    case NewCount >= Threshold of
        true ->
            OpenUntil = now_ms() + CooldownMs,
            telemetry:execute([chat_system, mpesa, breaker, open], #{count => 1}, #{until_ms => OpenUntil}),
            State#{state => open, failure_count => NewCount, opened_until_ms => OpenUntil};
        false ->
            State#{failure_count => NewCount}
    end.

is_error({error, _}) -> true;
is_error(_) -> false.

default(undefined, Fallback) -> Fallback;
default(Value, _Fallback) -> Value.

now_ms() ->
    erlang:monotonic_time(millisecond).
