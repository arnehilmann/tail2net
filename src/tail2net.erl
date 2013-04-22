-module(tail2net).
-export([run/0]).

-define(TCP_OPTIONS, [binary, {packet, line}, {active, false}, {reuseaddr, true}]).
-define(PORT, tail2net_env:get_env(listen_port, 8081)).
-define(FILE2TAIL, tail2net_env:get_env(file_to_tail, "/dev/random")).
-define(FILE_POLLINTERVALL, tail2net_env:get_env(file_pollintervall, 1000)).

run() ->
    register(filelistener, spawn_link(fun() -> open_file() end)),
    register(portlistener, spawn_link(fun() -> open_port() end)),
    portlistener ! accept_connection,
    % TODO how to do it better than this?!
    receive
        _ -> ok
    end.

open_file() ->
    error_logger:info_report("trying to open", ?FILE2TAIL),
    io:format("trying to open ~p\n", [?FILE2TAIL]),
    case file:open(?FILE2TAIL, [read, raw, read_ahead]) of
        {ok, IoDevice} ->
            listen_on_file(IoDevice);
        {error, enoent} ->
            % TODO extract function, see line 44 also
            receive
            after ?FILE_POLLINTERVALL ->
                open_file()
            end
    end.

listen_on_file(IoDevice) ->
    case file:read_line(IoDevice) of
        {ok, Data} ->
            io:format("~s", [Data]),
            portlistener ! {broadcast, Data},
            listen_on_file(IoDevice);
        eof ->
            receive
            after ?FILE_POLLINTERVALL ->
                listen_on_file(IoDevice)
            end
    end.

open_port() ->
    io:format("trying to listen on port ~B\n", [?PORT]),
    {ok, LSocket} = gen_tcp:listen(?PORT, ?TCP_OPTIONS),
    process_flag(trap_exit, true),
    listen_on_port(LSocket, []).

listen_on_port(LSocket, Worker) ->
    receive
        accept_connection ->
            Pid = spawn(fun() -> accept_connection(LSocket) end),
            link(Pid),
            listen_on_port(LSocket, [Pid|Worker]);
        {broadcast, Data} ->
            [Kid ! {broadcast, Data} || Kid  <- Worker ],
            listen_on_port(LSocket, Worker);
        {'EXIT', SomePid, normal} ->
            listen_on_port(LSocket, lists:delete(SomePid, Worker))
    end.

accept_connection(LSocket) ->
    io:format("Socket ~p waiting for connections\n", [LSocket]),
    case gen_tcp:accept(LSocket) of
        {ok, Socket} ->
            portlistener ! accept_connection,
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
        {tcp, Socket, _Data} ->
            io:format("socket ~p: incoming communication, aborting connection!", [Socket]),
            gen_tcp:closed(Socket),
            exit("incoming communication on write-only port!");
        {tcp_closed, Socket} ->
            io:format("Socket ~p closed\n", [Socket]);
        {tcp_error, Socket, Reason} ->
            io:format("Error on socket ~p reason: ~p\n", [Socket, Reason])
    end.
