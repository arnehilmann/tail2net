-module(tail2net).
-export([run/0]).

-define(TCP_OPTIONS, [binary, {packet, line}, {active, false}, {reuseaddr, true}]).
% TODO configurable
-define(PORT, 8081).
% TODO configurable
-define(FILE2TAIL, "aha").
% TODO configurable
-define(FILE_POLLINTERVALL, 1000).

run() ->
    register(filelistener, spawn(fun() -> listen_on_file() end)),
    register(portlistener, spawn(fun() -> listen_on_port() end)),
    portlistener ! spawn,
    % TODO how to do it better than this?!
    receive
        _ -> ok
    end.

listen_on_file() ->
    case file:open(?FILE2TAIL, [read, raw, read_ahead]) of
        {ok, IoDevice} -> 
            listen_on_file(IoDevice);
        % TODO real error handling!
        {error, Reason} ->
            io:format("cannot open file: ~p\n", [Reason])
    end.

listen_on_file(IoDevice) ->
    case file:read_line(IoDevice) of
        {ok, Data} ->
            io:format("new data: ~p\n", [Data]),
            portlistener ! {broadcast, Data},
            listen_on_file(IoDevice);
        eof ->
            receive
            after ?FILE_POLLINTERVALL ->
                listen_on_file(IoDevice)
            end;
        % TODO real error handling! 
        {error, Reason} ->
            io:format("error: ~p\n", [Reason]),
            coordinator ! finished
    end.

listen_on_port() ->
    io:format("trying to listen on port ~B\n", [?PORT]),
    {ok, LSocket} = gen_tcp:listen(?PORT, ?TCP_OPTIONS),
    process_flag(trap_exit, true),
    listen_on_port(LSocket, []).

listen_on_port(LSocket, Worker) ->
    receive
        spawn ->
            Pid = spawn(fun() -> accept(LSocket) end),
            link(Pid),
            listen_on_port(LSocket, [Pid|Worker]);
        {broadcast, Data} ->
            [Kid ! {broadcast, Data} || Kid  <- Worker ],
            listen_on_port(LSocket, Worker);
        {'EXIT', SomePid, normal} ->
            listen_on_port(LSocket, lists:delete(SomePid, Worker));
        {'EXIT', SomePid, Reason} ->
            io:format("child with pid ~p exited, reason ~p\n", [SomePid, Reason]),
            listen_on_port(LSocket, lists:delete(SomePid, Worker))
    end.

accept(LSocket) ->
    io:format("Socket ~p waiting for connections\n", [LSocket]),
    case gen_tcp:accept(LSocket) of
        {ok, Socket} ->
            portlistener ! spawn,
            gen_tcp:controlling_process(Socket, self()),
            io:format("Socket ~p accepted\n", [Socket]),
            loop(Socket);
        % TODO real error handling!
        {error, Reason} ->
            io:format("CRITICAL - cannot accept connections! reason: ~p\n", [Reason]),
            self() ! finished
    end.

loop(Sock) ->
    inet:setopts(Sock, [{active, once}]),
    receive
        {broadcast, Data} ->
            gen_tcp:send(Sock, Data),
            loop(Sock);
        {tcp, Socket, Data} ->
            io:format("Got packet: ~p\n", [Data]),
            gen_tcp:send(Socket, Data),
            loop(Socket);
        {tcp_closed, Socket} ->
            io:format("Socket ~p closed\n", [Socket]);
        {tcp_error, Socket, Reason} ->
            io:format("Error on socket ~p reason: ~p\n", [Socket, Reason])
    end.
