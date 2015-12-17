-module(chatserver).
-export([start/1]).
-export([init/1,loop/8,accepter/2,client/2,client_loop/2]).
 
-record(chat,{socket,accepter,clients}).
-record(client,{socket,name,pid}).
 
start(Port) -> spawn(?MODULE, init, [Port]).
 
init(Port) ->
    {ok,S} = gen_tcp:listen(Port, [{packet,0},{active,false}]),
    % po co jest ten spawn_link, sprawdzić dla samego spawn
    A = spawn(?MODULE, accepter, [S, self()]), 
    loop(#chat{socket=S, accepter=A, clients=[], rooms=[]}).

% #chat{accepter=A,clients=Cs} = #chat{socket=S, accepter=A, clients=[]}

% [X,Y] = [5,6]
% X = 5
% Y = 6

loop(Chat=#chat{accepter=A, clients=Cs, rooms=Rs}) ->
    receive
    	% {'ball move', BX2, BY2} ->
    	% 	receive
    	% 		after 1000 ->
    	% 			io:write(BX2),
    	% 			% self() ! {'ball move', BX, BY},
    	% 			loop(Chat=#chat{accepter=A,clients=Cs}, P1X, P1Y, P2X, P2Y, BX2, BY2, B)
    	% 	end;
        {'available rooms', From} ->
            lists:foreach(fun (#client{socket=Sock}) ->
                          gen_tcp:send(Sock,S)
                  end, Clients).


        {'join room', Client, RoomName} ->
            self() ! {'new client', lists:keysearch(RoomName, #room.name, Rs), Client, RoomName};
            % case lists:keysearch(Room, #room.name, Rs) of
            %     false -> 
            %         self() ! {'new client', true, Client, Room};
            %     {value, Room} -> 
            %         self() ! {'new client', false, Client, Room}
            % end,
        {'new client', RoomResult, Client, RoomName} ->
            % chyba niepotrzebne
            erlang:monitor(process,Client#client.pid),
            Cs1 = [Client|Cs],

            case RoomResult of
                false ->
                    Rs1 = [#room{name=RoomName, clientCount=0, clients=[]}|Rs];,
                    lists:keyreplace(RoomName, #room.name, Rs, #room{clientCount=1, clients=[Client]}),
                    broadcast(Cs1,["new connection from ~s to room ~s\n", Client#client.name, RoomName]),
                    loop(Chat#chat{clients=Cs1, rooms=Rs1});
                {value, Room} ->
                    NewClientCount = Room#room.clientCount + 1,
                    NewClients = [Client|Room#room.clients],
                    lists:keyreplace(RoomName, #room.name, Rs, #room{clientCount=NewClientCount, clients=NewClients}),
                    broadcast(Cs1,["new connection from ~s to room ~s\n", Client#client.name, RoomName]),
                    loop(Chat#chat{clients=Cs1, rooms=Rs})
            end;
        {'DOWN', _, process, Pid, _Info} ->
            case lists:keysearch(Pid, #client.pid, Cs) of
                false -> loop(Chat);
                {value,Client} -> 
                    self() ! {'lost client', Client},
                    loop(Chat)
            end;
        {'lost client', Client} ->
            broadcast(Cs,["lost connection from ~s\n",
                          Client#client.name]),
            gen_tcp:close(Client#client.socket),
            loop(Chat#chat{clients=lists:delete(Client,Cs)});
        {message, Client, PX} ->
        	case Client#client.name of
        		"1" -> broadcast(Cs,["~s:~s:~s:~s:~s:~s\n"]),
        			loop(Chat);
        		"2" ->
        			case B of
        				true ->
        					self() ! {'ball move', "100", "100"},
        					loop(Chat, P1X, P1Y, PX, P2Y, BX, BY, false);
        				false ->
        					broadcast(Cs,["~s:~s:~s:~s:~s:~s\n"]),
        					loop(Chat)
        			end
        	end;
        refresh ->
            A ! refresh,
            lists:foreach(fun (#client{pid=CP}) -> CP ! refresh end, Cs),
            ?MODULE:loop(Chat)
    end.
 
accepter(Sock, Server) ->
    {ok, Client} = gen_tcp:accept(Sock),
    spawn(?MODULE, client, [Client, Server]),
    accepter(Sock, Server)
    % receive
    %     refresh -> ?MODULE:accepter(Sock, Server)
    % after 0 -> accepter(Sock, Server)
    end.
 
client(Sock, Server) ->
    gen_tcp:send(Sock, "What is your name?\n"),
    {ok, N} = gen_tcp:recv(Sock,0),

    Server ! {'available rooms', self()},
    receive
        {available rooms, Rooms} -> 
            gen_tcp:send(Sock, Rooms),
            {ok, R} = gen_tcp:recv(Sock,0)
    end.

    

    % string:tokens - odwołanie do funkcji tokens dotyczącej string, dzieli N na tablice w zależności od drugiego algumentu,
    % np "ab\ncd" -> ["ab","cd"]
    % "czesc\n" -> ["czesc"]
    case string:tokens(N,"\n") of
        [Name] ->
            Client = #client{socket=Sock, name=Name, pid=self()},
            Server ! {'new client', Client},
            client_loop(Client, Server);
        _ ->
            gen_tcp:send(Sock, "Try again"),
            gen_tcp:close(Sock)
    end.
 
client_loop(Client, Server) ->
    {ok,Recv} = gen_tcp:recv(Client#client.socket,0),

    % lists:foreach - wykonuje fun(S) na każdym elemencie listy podanej jako argument
    lists:foreach(fun (S) -> Server ! {message,Client,S} end, string:tokens(Recv,"\n")),
    receive
        refresh -> ?MODULE:client_loop(Client, Server)
    after 0 -> client_loop(Client, Server)
    end.
 
broadcast(Clients, [Fmt|Args]) ->
    S = lists:flatten(io_lib:fwrite(Fmt,Args)),
    lists:foreach(fun (#client{socket=Sock}) ->
                          gen_tcp:send(Sock,S)
                  end, Clients).