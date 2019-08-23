%%%-------------------------------------------------------------------
%%% @author tkyshm
%%% @copyright (C) 2017, tkyshm
%%% @doc
%%%
%%% @end
%%% Created : 2017-10-27 02:58:00.860266
%%%-------------------------------------------------------------------
-module(esnowflake_SUITE).


%% API
-export([all/0,
         suite/0,
         groups/0,
         group/1,
         init_per_suite/1,
         end_per_suite/1,
         init_per_testcase/2,
         end_per_testcase/2]).

%% test cases
-export([
         t_generate_id/1,
         t_too_many_generate_same_time/1,
         t_generate_ids/1,
         t_to_unixtime/1,
         t_unixtime_to_id/1,
         t_decode_id/1,
         t_stats/1,
         t_not_use_redis/1,
         t_over_worker_ids_limit/1,
         t_range_ids/1,
         t_change_twepoch/1,
         b_generate_id/1,
         b_generate_ids/1
        ]).

-include("esnowflake.hrl").
-include_lib("common_test/include/ct.hrl").
-include_lib("eunit/include/eunit.hrl").

all() ->
    [
     {group, test},
     {group, bench}
    ].

groups() ->
    [
     {test, [], [
        t_generate_id,
        t_generate_ids,
        t_stats,
        t_to_unixtime,
        t_unixtime_to_id,
        t_decode_id,
        t_not_use_redis,
        t_over_worker_ids_limit,
        t_range_ids,
        t_change_twepoch]},

     {bench, [], [
        b_generate_id,
        b_generate_ids]}
    ].

suite() ->
    [{ct_hooks, [cth_surefire]}, {timetrap, {seconds, 30}}].

group(_Groupname) ->
    [].

%%%===================================================================
%%% Overall setup/teardown
%%%===================================================================
init_per_suite(Config) ->
    Config.

end_per_suite(_Config) ->
    ok.

%%%===================================================================
%%% Testcase specific setup/teardown
%%%===================================================================
init_per_testcase(t_not_use_redis, Config) ->
    {ok, OldRedisConf} = application:get_env(esnowflake, redis),
    application:unset_env(esnowflake, redis),
    application:set_env(esnowflake, worker_min_max_id, [20, 24]),
    {ok, [esnowflake]} = application:ensure_all_started(esnowflake),
    [{esnowflake_redis, OldRedisConf}|Config];
init_per_testcase(t_over_worker_ids_limit, Config) ->
    application:set_env(esnowflake, worker_num, 1025),
    {ok, [esnowflake]} = application:ensure_all_started(esnowflake),
    Config;
init_per_testcase(t_change_twepoch, Config) ->
    application:unset_env(esnowflake, twepoch),
    application:set_env(esnowflake, twepoch, 1513258020000),
    {ok, [esnowflake]} = application:ensure_all_started(esnowflake),
    Config;
init_per_testcase(_TestCase, Config) ->
    {ok, [esnowflake]} = application:ensure_all_started(esnowflake),
    Config.

end_per_testcase(t_not_use_redis, Config) ->
    flushdb(),
    OldRedisConf = proplists:get_value(esnowflake_redis, Config),
    application:unset_env(esnowflake, worker_min_max_id),
    application:set_env(esnowflake, redis, OldRedisConf),
    application:stop(esnowflake);
end_per_testcase(t_over_worker_ids_limit, _Config) ->
    flushdb(),
    application:set_env(esnowflake, worker_num, 5),
    application:stop(esnowflake);
end_per_testcase(t_change_twepoch, _Config) ->
    flushdb(),
    application:unset_env(esnowflake, twepoch),
    application:stop(esnowflake);
end_per_testcase(_TestCase, _Config) ->
    flushdb(),
    application:stop(esnowflake).

%%%===================================================================
%%% Individual Test Cases (from groups() definition)
%%%===================================================================

t_generate_id(Config) ->
    Id = esnowflake:generate_id(),
    true = is_integer(Id),
    Config.

t_too_many_generate_same_time(Config) ->
    Num = 20000,
    Self = self(),
    [spawn(fun() ->
                   Self ! esnowflake:generate_id()
           end)||_ <- lists:seq(1, Num)],

    Ids = catch_ids([], Num),
    Num = length(Ids),
    Num = length(lists:usort(Ids)),

    Config.

t_generate_ids(Config) ->
    Num = 10000,
    Ids = esnowflake:generate_ids(Num),
    Num = length(Ids),
    Num = length(lists:usort(Ids)),
    Config.

t_stats(Config) ->
    [{version, _},
     {worker_num, 5},
     {worker_ids, _TODO_FOR_TEST_}] = esnowflake:stats(),

    Config.

t_to_unixtime(Config) ->
    % Thu Dec 14 22:27:08 JST 2017
    Id = 17942010698698752,
    1513258028697 = esnowflake:to_unixtime(Id),
    1513258028 = esnowflake:to_unixtime(Id, seconds),
    Config.

t_unixtime_to_id(Config) ->
    % Thu Dec 14 22:27:08 JST 2017
    UnixTime = 1513258028697,
    UnixTimeSec = 1513258028,
    17942010698661888 = esnowflake:unixtime_to_id(UnixTime),
    17942007775232000 = esnowflake:unixtime_to_id(UnixTimeSec, seconds),
    Config.

t_decode_id(Config) ->
    % timestamp: Thu Dec 14 22:27:08 JST 2017
    % machine_id:9
    % worker_id:0
    Id = 17942010698698752,
    {Timestamp, 9, 0} = esnowflake:decode_id(Id),
    1513258028697 = Timestamp + ?TWEPOCH,

    Config.

t_not_use_redis(Config) ->
    Id = esnowflake:generate_id(),
    true = is_integer(Id),

    [{version, _},
     {worker_num, 5},
     {worker_ids, IDs}] = esnowflake:stats(),

    ?assert(lists:subtract(IDs, [20, 21, 22, 23, 24]) =:= []),

    Config.

t_over_worker_ids_limit(Config) ->

    [{version, _},
     {worker_num, 1024},
     {worker_ids, IDs}] = esnowflake:stats(),

    ?assert(length(IDs) =:= 1024),

    Config.

t_range_ids(Config) ->
    % timestamp: Thu Dec 14 22:27:08 JST 2017
    StartTime = 1513258028697,
    StartTimeSec = 1513258028,

    % timestamp: Thu Dec 21 22:27:08 JST 2017
    EndTime = 1513862828697,
    EndTimeSec = 1513862828,

    ?assert([17942010698661888, 20478725762056191] =:= esnowflake:range_ids(StartTime, EndTime)),
    ?assert([17942007775232000, 20478722838626303] =:= esnowflake:range_ids(StartTimeSec, EndTimeSec, seconds)),

    Config.

t_change_twepoch(Config) ->
    % timestamp: Thu Dec 14 22:27:08 JST 2017
    StartTime = 1513258028697,
    StartTimeSec = 1513258028,

    % timestamp: Thu Dec 21 22:27:08 JST 2017
    EndTime = 1513862828697,
    EndTimeSec = 1513862828,

    ?assert([36477861888, 2536751541256191] =:= esnowflake:range_ids(StartTime, EndTime)),
    ?assert([33554432000, 2536748617826303] =:= esnowflake:range_ids(StartTimeSec, EndTimeSec, seconds)),

    Config.

%% benchmark
b_generate_id(Config) ->
    Cnt = 100000,
    Results = [bench_generate_id_ns_per_op()|| _ <- lists:seq(1,Cnt)],
    Avg = lists:sum(Results) / Cnt,
    ct:print("b_generate_id\t~p\t~p ns/op", [Cnt, Avg]),

    OpCnt = bench_generate_id_op_per_sec(0, 0),
    ct:print("b_generate_id\t~p op/sec", [OpCnt]),
    Config.

b_generate_ids(Config) ->
    Cnt = 10000,
    Num = 100,
    Results = [bench_generate_ids_ns_per_op(Num)|| _ <- lists:seq(1, Cnt)],
    Avg = lists:sum(Results) / Cnt,
    ct:print("b_generate_ids_~p\t~p\t~p ns/op", [Num, Cnt, Avg]),

    OpCnt = bench_generate_ids_op_per_sec(0, 0),
    ct:print("b_generate_ids_~p\t~p op/sec", [Num, OpCnt]),
    Config.

%% private
catch_ids(Ids, 0) ->
    Ids;
catch_ids(Ids, Num) ->
    receive
        Id -> catch_ids([Id|Ids], Num-1)
    end.

bench_generate_id_ns_per_op() ->
    S = erlang:system_time(nano_seconds),
    esnowflake:generate_id(),
    E = erlang:system_time(nano_seconds),
    E-S.

bench_generate_ids_ns_per_op(N) ->
    S = erlang:system_time(nano_seconds),
    esnowflake:generate_ids(N),
    E = erlang:system_time(nano_seconds),
    E-S.

bench_generate_id_op_per_sec(Diff, Cnt) when Diff > 1000000000 ->
    Cnt;
bench_generate_id_op_per_sec(Diff, Cnt) ->
    S = erlang:system_time(nano_seconds),
    esnowflake:generate_id(),
    E = erlang:system_time(nano_seconds),
    bench_generate_id_op_per_sec(Diff+(E-S), Cnt+1).

bench_generate_ids_op_per_sec(Diff, Cnt) when Diff > 1000000000 ->
    Cnt;
bench_generate_ids_op_per_sec(Diff, Cnt) ->
    S = erlang:system_time(nano_seconds),
    esnowflake:generate_ids(1000),
    E = erlang:system_time(nano_seconds),
    bench_generate_ids_op_per_sec(Diff+(E-S), Cnt+1).


% private
flushdb() ->
    {ok, C} = eredis:start_link([{port, 26379}]),
    eredis:q(C, ["FLUSHDB"]).
