-module(chat_api_listener).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).
-define(LISTENER, api_listener).
-define(DEFAULT_PORT, 8080).



start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).



init([]) ->
    Dispatch = dispatcher:dispatch(),

    rate_limiter:init(),

    {ok, _} = start_cowboy(Dispatch),

    {ok, #{dispatch => Dispatch}}.



start_cowboy(Dispatch) ->
    Port = port(),
    cowboy:start_clear(?LISTENER,
        [{port, Port}],
        #{
            env => #{
                dispatch => Dispatch
            },
            middlewares => [cowboy_router, auth_middleware, cowboy_handler]
        }
    ).

port() ->
    case os:getenv("CHAT_API_PORT") of
        false ->
            application:get_env(chat_api, port, ?DEFAULT_PORT);
        PortStr ->
            try list_to_integer(PortStr) of
                Port when is_integer(Port), Port > 0, Port < 65536 ->
                    Port
            catch
                _:_ ->
                    ?DEFAULT_PORT
            end
    end.


handle_call(_Msg, _From, State) ->
    {reply, ok, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Msg, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    catch cowboy:stop_listener(?LISTENER),
    ok.