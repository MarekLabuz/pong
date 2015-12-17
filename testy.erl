-module(testy).
-export([m/0, k/0]).



m() ->
	S = [1,2,3,4,5],
	lists:foreach(fun (element) ->
                 		io:format("fdsfsd")
                  end, S).

k() ->
	io:format("~p ", [5]).
