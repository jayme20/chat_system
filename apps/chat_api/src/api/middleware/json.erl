-module(json).
-export([decode/1, encode/1]).

decode(Bin) ->
    jsx:decode(Bin, [return_maps]).

encode(Map) ->
    jsx:encode(Map).