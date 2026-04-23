-module(retry_queue).

-export([
    enqueue/2,
    process/0,
    retry/1,
    schedule_retry/2
]).

-record(job, {
    id,
    payload,
    attempts = 0,
    next_retry_at = 0
}).

-define(MAX_RETRIES, 5).

%% =========================================================
%% ENQUEUE FAILED JOB
%% =========================================================

enqueue(JobId, Payload) ->
    Job = #job{
        id = JobId,
        payload = Payload,
        attempts = 0,
        next_retry_at = os:system_time(second) + 5
    },

    ets:insert(retry_queue_table, {JobId, Job}),
    ok.

%% =========================================================
%% PROCESS QUEUE (CALLED BY WORKER LOOP)
%% =========================================================

process() ->
    Now = os:system_time(second),

    Jobs = ets:match_object(retry_queue_table, {'_', #job{
        next_retry_at = '$1',
        _ = '_'
    }}),

    lists:foreach(fun({_, Job}) ->
        case Job#job.next_retry_at =< Now of
            true -> retry(Job);
            false -> ok
        end
    end, Jobs).

%% =========================================================
%% RETRY LOGIC
%% =========================================================

retry(Job) when Job#job.attempts >= ?MAX_RETRIES ->
    %% send to dead-letter queue
    ets:insert(dead_letter_table, {Job#job.id, Job}),
    ets:delete(retry_queue_table, Job#job.id),
    ok;

retry(Job) ->
    Result = execute(Job#job.payload),

    case Result of
        ok ->
            ets:delete(retry_queue_table, Job#job.id),
            ok;

        {error, _Reason} ->
            schedule_retry(Job#job.id, Job)
    end.

%% =========================================================
%% BACKOFF STRATEGY
%% =========================================================

schedule_retry(JobId, Job) ->
    Attempts = Job#job.attempts + 1,
    Delay = trunc(math:pow(2, Attempts)) * 5,

    Updated = Job#job{
        attempts = Attempts,
        next_retry_at = os:system_time(second) + Delay
    },

    ets:insert(retry_queue_table, {JobId, Updated}),
    ok.

%% =========================================================
%% EXECUTION DISPATCHER
%% =========================================================

execute(Payload) ->
    case maps:get(type, Payload) of
        mpesa_b2c ->
            mpesa_b2c_api:send(Payload);

        mpesa_c2b_replay ->
            mpesa_c2b_handler:handle(Payload);

        _ ->
            {error, unknown_job}
    end.