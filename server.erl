-module(server).
-export([start/1]).
-export([init/1,loop/1,accepter/2,client/2,client_loop/2,ballMovement/10]).
 
-record(chat,{socket,accepter,clients,rooms}).
-record(client,{socket,name,pid,room,seat}).
-record(room,{name,clientCount,clients,pp1,pp2,p,p1score,p2score}).
 
start(Port) -> spawn(?MODULE, init, [Port]).
 
init(Port) ->
    {ok,S} = gen_tcp:listen(Port, [{packet,0},{active,false}]),
    A = spawn_link(?MODULE, accepter, [S, self()]), 
    loop(#chat{socket=S, accepter=A, clients=[], rooms=[]}).
    % #room{name="pokoj1", clientCount=0, clients=[], pp1=0, pp2=0},#room{name="pokoj2", clientCount=0, clients=[], pp1=0, pp2=0, p}

% #chat{accepter=A,clients=Cs} = #chat{socket=S, accepter=A, clients=[]}

% [X,Y] = [5,6]
% X = 5
% Y = 6

loop(Chat=#chat{accepter=A, clients=Cs, rooms=Rs}) ->
    receive
        {'players coords', RoomName, From} ->
             case lists:keysearch(RoomName, #room.name, Rs) of
                false ->
                    From ! {'players coords', 0, 0, undefined};
                {value, Room} ->
                    From ! {'players coords', Room#room.pp1, Room#room.pp2, Room}
            end,
            loop(Chat);
        {'available rooms', Sock} ->
            gen_tcp:send(Sock, getRoomNames(Rs) ++ "\n"),
            loop(Chat);
        % {'join room', Client} ->
            
            % loop(Chat);
        {'player scored', N, Room} ->
            WhereIs = whereis(list_to_atom(Room#room.name)),
                case WhereIs of
                    undefined ->
                        io:format("whereis undefined");
                    _ ->
                        WhereIs ! {'reset position'}
                end,
            case N of
                1 ->
                    broadcast(Room#room.clients, ["score;~p;~p\n", Room#room.p1score + 1, Room#room.p2score]),
                    Rs1 = lists:keyreplace(Room#room.name, #room.name, Rs, #room{name=Room#room.name, clientCount=Room#room.clientCount, clients=Room#room.clients, pp1=Room#room.pp1, pp2=Room#room.pp2, p=Room#room.p, p1score=Room#room.p1score + 1, p2score=Room#room.p2score});
                2 ->
                    broadcast(Room#room.clients, ["score;~p;~p\n", Room#room.p1score, Room#room.p2score + 1]),
                    Rs1 = lists:keyreplace(Room#room.name, #room.name, Rs, #room{name=Room#room.name, clientCount=Room#room.clientCount, clients=Room#room.clients, pp1=Room#room.pp1, pp2=Room#room.pp2, p=Room#room.p, p1score=Room#room.p1score, p2score=Room#room.p2score + 1})
            end,
            loop(Chat#chat{rooms=Rs1});
        {'new client', Client2} ->
            erlang:monitor(process,Client2#client.pid),
            
            case lists:keysearch(Client2#client.room, #room.name, Rs) of
                false ->
                    io:format("nie znalazlem"),
                    Client = Client2#client{seat = 1},
                    Cs1 = [Client|Cs],
                    % Cs2 = lists:keyreplace(Client#client.room, #room.name, Rs, #room{name=Client#client.room, clientCount=NewClientCount, clients=NewClients, pp1=0, pp2=0, p=Room#room.p}),
                    Rs1 = [#room{name=Client#client.room, clientCount=1, clients=[Client], pp1=0, pp2=0, p=2, p1score=0, p2score=0}|Rs],
                    gen_tcp:send(Client#client.socket, "1\n"),
                    loop(Chat#chat{clients=Cs1, rooms=Rs1});
                {value, Room} ->
                    io:format("znalazlem"),
                    Client = Client2#client{seat = Room#room.p},
                    Cs1 = [Client|Cs],

                    NewClientCount = Room#room.clientCount + 1,
                    NewClients = [Client|Room#room.clients],
                    
                    % Ball = spawn_link(?MODULE, ballMovement, [0, 3, 1, -1, 200, 400, 400, 800, #room{name=Client#client.room, clients=NewClients}, self()]),
                    if
                        NewClientCount == 2 ->
                            Ball = spawn_link(?MODULE, ballMovement, [0, 3, 1, -1, 300, 350, 600, 700, #room{name=Client#client.room, clients=NewClients}, self()]),
                            register(list_to_atom(Room#room.name), Ball);
                        true ->
                            io:format("to sie nie powinno zdarzyc")
                    end,

                    Rs1 = lists:keyreplace(Client#client.room, #room.name, Rs, #room{name=Client#client.room, clientCount=NewClientCount, clients=NewClients, pp1=0, pp2=0, p=Room#room.p, p1score=0, p2score=0}),
                    gen_tcp:send(Client#client.socket, lists:flatten(io_lib:fwrite("~p\n",[Room#room.p]))),
                    loop(Chat#chat{clients=Cs1, rooms=Rs1})
            end;

            % loop(Chat#chat{clients=Cs1});
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
            

            case lists:keysearch(Client#client.room, #room.name, Rs) of
                false ->
                    io:format("nie znalazlem"),
                    loop(Chat#chat{clients=lists:delete(Client,Cs)});
                    % Rs1 = [#room{name=Client#client.room, clientCount=1, clients=[Client], pp1=0, pp2=0}|Rs],
                    % gen_tcp:send(Client#client.socket, "1\n"),
                    % loop(Chat#chat{rooms=Rs1});
                {value, Room} ->
                    io:format("znalazlem"),
                    NewClientCount = Room#room.clientCount - 1,
                    NewClients = lists:delete(Client, Room#room.clients),
                    % broadcast(Room#room.clients, ["ball;~p;~p\n", 200, 400]),
                    % Client#client.pid ! {stop},
                    WhereIs = whereis(list_to_atom(Room#room.name)),
                    case WhereIs of
                        undefined ->
                            io:format("whereis undefined");
                        _ ->
                            WhereIs ! {stop},
                            unregister(list_to_atom(Room#room.name))
                    end,

                    % Ball = spawn_link(?MODULE, ballMovement, [0, 3, 1, -1, 200, 400, 400, 800, #room{name=Client#client.room, clients=NewClients}, self()]),
                    Rs1 = lists:keyreplace(Client#client.room, #room.name, Rs, #room{name=Client#client.room, clientCount=NewClientCount, clients=NewClients, pp1=0, pp2=0, p=Client#client.seat, p1score=0, p2score=0}),
                    % gen_tcp:send(Client#client.socket, "2\n"),
                    if 
                        NewClientCount == 0 ->
                            {value, RoomToDelete} = lists:keysearch(Client#client.room, #room.name, Rs1),
                            Rs2 = lists:delete(RoomToDelete, Rs1),
                            % io:format("~p nie powinno sie równać ~p",[Rs2, Rs1]),
                            loop(Chat#chat{clients=lists:delete(Client,Cs), rooms=Rs2});
                        true ->
                            loop(Chat#chat{clients=lists:delete(Client,Cs), rooms=Rs1})
                    end
            end;
        {message, Client2, Position} ->
            {room, Room} = findRoomByClient(Client2, Rs),
            {value, Client} = lists:keysearch(Client2#client.name, #client.name, Room#room.clients),
            UpdatedRoom = updatePlayerPosition(Position, Client, Room),
            case lists:keytake(Client#client.name, #client.name, Room#room.clients) of
                false ->
                    broadcast(Room#room.clients, ["position;~s\n", Position]);
                 {value, _, TupleList2} ->
                    broadcast(TupleList2, ["position;~s\n", Position])
             end,

            Rs1 = lists:keyreplace(Client#client.room, #room.name, Rs, UpdatedRoom),

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
            Client = #client{socket=Sock, name=Name, pid=self(), room=Room, seat=0},
            Server ! {'new client', Client},
            client_loop(Client, Server);
        _ ->
            gen_tcp:send(Sock, "Try again"),
            gen_tcp:close(Sock)
    end.
 
client_loop(Client, Server) ->
    % {ok,Recv} = 
    case gen_tcp:recv(Client#client.socket,0) of
        {ok, Recv} ->
            lists:foreach(fun (S) -> 
                                Server ! {message,Client,S} 
                            end, string:tokens(Recv,"\n")),
                receive
                    refresh -> 
                        ?MODULE:client_loop(Client, Server)
                    after 0 -> 
                        client_loop(Client, Server)
                end;
        {error, Reason} ->
        	io:format("Error: Reason: ~p~n", [Reason])
            % lists:foreach - wykonuje fun(S) na każdym elemencie listy podanej jako argument
            % "siema\n" -> ["siema"] -> 
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
    case Client#client.seat == 1 of
        true ->
            {PP1,[]} = string:to_integer(Position),
            Room#room{pp1=PP1};
        false ->
            {PP2,[]} = string:to_integer(Position),
            Room#room{pp2=PP2}
    end.

getRoomNames([]) -> "";
getRoomNames([#room{name=Name, clientCount=Count}|T]) -> Name ++ " - players: " ++ lists:flatten(io_lib:fwrite("~p",[Count])) ++ ";" ++ getRoomNames(T).

ballMovement(L, S, WX, WY, X, Y, WIDTH, HEIGHT, Room, Server) ->
    receive
        {stop} -> 
            io:format("stop\n"),
            broadcast(Room#room.clients, ["ball;~p;~p\n", WIDTH/2, HEIGHT/2]);
        {'reset position'} ->
            broadcast(Room#room.clients, ["ball;~p;~p\n", WIDTH/2, HEIGHT/2]),
            ballMovement(L, S, WX, WY, WIDTH/2, HEIGHT/2, WIDTH, HEIGHT, Room, Server)
        after 16 ->
            Server ! {'players coords', Room#room.name, self()},
            receive
                {'players coords', PP1, PP2, RoomC} ->
                    case X >= WIDTH - 25 of
                        true ->
                            WX1 = -1 * WX,
                            Server ! {'player scored', 1, RoomC},
                            PlayerScored = true;
                        false ->
                            case X =< 0 of
                                true ->
                                    WX1 = -1 * WX,
                                    Server ! {'player scored', 2, RoomC},
                                    PlayerScored = true;
                                false ->
                                    PlayerScored = false,
                                    if
                                        (X >= 10 + 35 - S) and (X =< 10 + 35) and (Y >= PP2 - 25) and (Y =< PP2 + 200) ->
                                            io:format("dziala"),
                                            WX1 = -1 * WX;
                                        true ->
                                            if
                                                (X + 25 >= WIDTH - 10 - 35) and (X + 25 =< WIDTH - 10 - 35 + S) and (Y >= PP1 - 25) and (Y =< PP1 + 200) ->
                                                    io:format("dziala"),
                                                    WX1 = -1 * WX;
                                                true ->
                                                    WX1 = WX
                                            end
                                    end
                            end
                    end,

                    case Y >= HEIGHT - 25 of
                        true ->
                            WY1 = -1 * WY;
                        false ->
                            case Y =< 0 of
                                true ->
                                    WY1 = -1 * WY;
                                false ->
                                    WY1 = WY
                            end
                    end,

                    X1 = X + WX1 * S,
                    Y1 = Y + WY1 * S,


                    io:format("X:~p  Y:~p  WX:~p  WY:~p  PP1:~p  PP2:~p\n", [X1, Y1, WX1, WY1, PP1, PP2]),
                    broadcast(Room#room.clients, ["ball;~p;~p\n", X1, Y1]),
                    if 
                        (PlayerScored == true) ->
                            ballMovement(0, 3, WX1, WY1, X1, Y1, WIDTH, HEIGHT, Room, Server);
                        (L > 300) ->
                            ballMovement(0, S + trunc(L/300), WX1, WY1, X1, Y1, WIDTH, HEIGHT, Room, Server);
                        true ->
                            ballMovement(L+1, S, WX1, WY1, X1, Y1, WIDTH, HEIGHT, Room, Server)
                    end
            end
    end.