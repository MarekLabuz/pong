-module(chatserver).
-export([start/1]).
-export([init/1,loop/1,accepter/2,client/2,client_loop/2]).
 
-record(chat,{socket,accepter,clients,rooms}).
-record(client,{socket,name,pid,room}).
-record(room,{name,clientCount,clients,pp1,pp2}).
 
start(Port) -> spawn(?MODULE, init, [Port]).
 
init(Port) ->
    {ok,S} = gen_tcp:listen(Port, [{packet,0},{active,false}]),
    % po co jest ten spawn_link, sprawdzić dla samego spawn
    A = spawn_link(?MODULE, accepter, [S, self()]), 
    loop(#chat{socket=S, accepter=A, clients=[], rooms=[#room{name="pokoj1", clientCount=0, clients=[], pp1=0, pp2=0},#room{name="pokoj2", clientCount=0, clients=[], pp1=0, pp2=0}]}).

% #chat{accepter=A,clients=Cs} = #chat{socket=S, accepter=A, clients=[]}

% [X,Y] = [5,6]
% X = 5
% Y = 6

loop(Chat=#chat{accepter=A, clients=Cs, rooms=Rs}) ->
    receive
        {'available rooms', Sock} ->
            gen_tcp:send(Sock, getRoomNames(Rs) ++ "\n"),
            loop(Chat);
        {'join room', Client} ->
            case lists:keysearch(Client#client.room, #room.name, Rs) of
                false ->
                    io:format("nie znalazlem"),

                    Rs1 = [#room{name=Client#client.room, clientCount=1, clients=[Client], pp1=0, pp2=0}|Rs],
                    gen_tcp:send(Client#client.socket, "1\n"),
                    loop(Chat#chat{rooms=Rs1});
                {value, Room} ->
                    io:format("znalazlem"),
                    NewClientCount = Room#room.clientCount + 1,
                    NewClients = [Client|Room#room.clients],
                    Rs1 = lists:keyreplace(Client#client.room, #room.name, Rs, #room{name=Client#client.room, clientCount=NewClientCount, clients=NewClients, pp1=0, pp2=0}),
                    gen_tcp:send(Client#client.socket, "2\n"),
                    loop(Chat#chat{rooms=Rs1})
            end;
            % loop(Chat);
        {'new client', Client} ->
            erlang:monitor(process,Client#client.pid),
            Cs1 = [Client|Cs],
            self() ! {'join room', Client},

            % case RoomResult of
            %     false ->
            %         Rs1 = [#room{name=RoomName, clientCount=0, clients=[]}|Rs];,
            %         lists:keyreplace(RoomName, #room.name, Rs, #room{clientCount=1, clients=[Client]}),
            %         broadcast(Cs1,["new connection from ~s to room ~s\n", Client#client.name, RoomName]),
            %         loop(Chat#chat{clients=Cs1, rooms=Rs1});
            %     {value, Room} ->
            %         NewClientCount = Room#room.clientCount + 1,
            %         NewClients = [Client|Room#room.clients],
            %         lists:keyreplace(RoomName, #room.name, Rs, #room{clientCount=NewClientCount, clients=NewClients}),
            %         broadcast(Cs1,["new connection from ~s to room ~s\n", Client#client.name, RoomName]),
            %         loop(Chat#chat{clients=Cs1, rooms=Rs})
            % end;

            loop(Chat#chat{clients=Cs1});
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
        {message, Client, Position} ->
            {room, Room} = findRoomByClient(Client, Rs),
            UpdatedRoom = updatePlayerPosition(Position, Client, Room),
            case lists:keytake(Client#client.name, #client.name, Room#room.clients) of
                false ->
                    broadcast(Room#room.clients, ["~s\n", Position]);
                 {value, Tuple, TupleList2} ->
                    broadcast(TupleList2, ["~s\n", Position])
             end,

            Rs1 = lists:keyreplace(Client#client.room, #room.name, Rs, UpdatedRoom),

        	% case Client#client.name of
        	% 	"1" -> broadcast(Cs,["~s:~s:~s:~s:~s:~s\n"]),
        	% 		loop(Chat);
        	% 	"2" ->
        	% 		case B of
        	% 			true ->
        	% 				self() ! {'ball move', "100", "100"},
        	% 				loop(Chat);
        	% 			false ->
        	% 				broadcast(Cs,["~s:~s:~s:~s:~s:~s\n"]),
        	% 				loop(Chat)
        	% 		end
        	% end;
            io:format("~p\n", [Position]),

            loop(Chat#chat{rooms=Rs1});
        refresh ->
            A ! refresh,
            lists:foreach(fun (#client{pid=CP}) -> CP ! refresh end, Cs),
            ?MODULE:loop(Chat)
    end.
 
accepter(Sock, Server) ->
    {ok, Client} = gen_tcp:accept(Sock),
    spawn(?MODULE, client, [Client, Server]),
    % accepter(Sock, Server)
    receive
        refresh -> ?MODULE:accepter(Sock, Server)
    after 0 -> accepter(Sock, Server)
    end.
 
client(Sock, Server) ->
    Server ! {'available rooms', Sock},

    {ok, N} = gen_tcp:recv(Sock,0),
    {ok, R} = gen_tcp:recv(Sock,0),

    % string:tokens - odwołanie do funkcji tokens dotyczącej string, dzieli N na tablice w zależności od drugiego algumentu,
    % np "ab\ncd" -> ["ab","cd"]
    % "czesc\n" -> ["czesc"]
    [Room] = string:tokens(R,"\n"),

    case string:tokens(N,"\n") of
        [Name] ->
            Client = #client{socket=Sock, name=Name, pid=self(), room=Room},
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


findRoomByClient(Client, Rs) ->
    case lists:keysearch(Client#client.room, #room.name, Rs) of
        false ->
            {room, ok};
        {value, Room} ->
            {room, Room}
    end.

updatePlayerPosition(Position, Client, Room) ->
    case Client == lists:nth(1, Room#room.clients) of
        true ->
            Room#room{pp1=Position};
        false ->
            Room#room{pp2=Position}
    end.

getRoomNames([]) -> "";
getRoomNames([#room{name=Name, clientCount=Count}|T]) -> Name ++ " - players: " ++ lists:flatten(io_lib:fwrite("~p",[Count])) ++ ";" ++ getRoomNames(T).