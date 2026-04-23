-module(chat_registry_srv).
-behaviour(gen_server).

-export([
    start_link/0,
    status/0
]).

-export([
    init/1,
    handle_call/3,
    handle_cast/2,
    terminate/2,
    code_change/3
]).



start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

status() ->
    gen_server:call(?MODULE, status).



init([]) ->

    chat_store:ensure_tables(),


    ensure_table(chat_registry, set),
    ensure_table(chat_inbox, bag),
    ensure_table(chat_messages, set),
    ensure_table(chat_groups, set),
    ensure_table(chat_message_reliability, set),

   
    ensure_table(chat_payments, set),
    ensure_table(chat_group_state, set),
    ensure_table(chat_ledger, bag),
    ensure_table(chat_revenue, bag),
    ensure_table(chat_contributions, bag),

    {ok, #{booted => true}}.


handle_call(status, _From, State) ->
    Info = #{
        registry => ets:info(chat_registry),
        inbox => ets:info(chat_inbox),
        messages => ets:info(chat_messages),
        groups => ets:info(chat_groups),
        payments => ets:info(chat_payments),
        contributions => ets:info(chat_contributions)
    },
    {reply, Info, State};

handle_call(_, _, State) ->
    {reply, ok, State}.


handle_cast(_, State) ->
    {noreply, State}.


terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.


ensure_table(Name, Type) ->
    case ets:info(Name) of
        undefined ->
            try
                ets:new(Name, [named_table, public, Type])
            catch
                error:badarg ->
                    ok
            end;
        _ ->
            ok
    end.