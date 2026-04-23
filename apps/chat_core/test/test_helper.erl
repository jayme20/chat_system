-module(test_helper).

-export([setup/0, cleanup/0, with_fresh_store/1]).

setup() ->
    chat_store:ensure_tables(),
    ok.

cleanup() ->
    catch ets:delete_all_objects(chat_inbox),
    catch ets:delete_all_objects(chat_groups),
    catch ets:delete_all_objects(chat_contributions),
    catch ets:delete_all_objects(chat_message_reliability),
    ok.

with_fresh_store(Fun) ->
    setup(),
    Result = Fun(),
    cleanup(),
    Result.