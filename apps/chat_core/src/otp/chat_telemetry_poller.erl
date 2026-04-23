-module(chat_telemetry_poller).

-export([start_link/0, emit_runtime_metrics/0]).

start_link() ->
    telemetry_poller:start_link([
        {name, ?MODULE},
        {measurements, [{?MODULE, emit_runtime_metrics, []}]},
        {period, 10000}
    ]).

emit_runtime_metrics() ->
    ProcCount = erlang:system_info(process_count),
    RunQueue = erlang:statistics(run_queue),
    telemetry:execute(
        [chat_system, runtime, snapshot],
        #{
            process_count => ProcCount,
            run_queue => RunQueue
        },
        #{}
    ).
