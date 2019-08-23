[![Build Status](https://travis-ci.org/tkyshm/esnowflake.svg?branch=master)](https://travis-ci.org/tkyshm/esnowflake)

esnowflake
=====

esnowflake is Erlang/OTP application to generate uniq ID.  
Original design: [Twitter IDs (snowflake)](https://github.com/twitter/snowflake).  
[Documentation](https://hexdocs.pm/esnowflake/0.1.0/)

Usage
=====

```erlang
> application:start(esnowflake).
ok

> Id = esnowflake:generate_id().
896221795344384

> esnowflake:generate_ids(2).
[896498611015681,896498611015680]

> esnowflake:to_unixtime(Id).
1509193995927

> esnowflake:stats().
[{version, undefined},
 {worker_num,10},
 {worker_ids,[0,1,2,3,4,5,6,7,8,9]}]

1> {Start, End} = {os:system_time(seconds)-3600*24, os:system_time(seconds)}.
{1528603140,1528689540}
2> esnowflake:range_ids(Start,End, seconds).
[82304072417280000,82666460287074303]

```

Config
=====

## worker id

### application environment variable

This must be specified as not to duplicate worker ids if you use multi nodes.

params            | default       | explain
----------------- | ------------- | ---------------------------------------------------------
worker_num        | 2             | number of generate id workers
worker_min_max_id | [0, 1]        | worker ids
redis             | -             | eredis config for assigning worker ids automatically
twepoch           | 1508980320000 | start unix time to number id (default: 2017-10-26 01:12:00 (UTC))


- redis config

params          | default
--------------- | ----------------------------------
host            | localhost
port            | 6379
database        | 0
password        | (empty)
reconnect_sleep | please check `eredis:start_link/1`
connect_timeout | please check `eredis:start_link/1`


- app.conf

```erlang
[
 {esnowflake, [
               {worker_min_max_id, [0, 1]}
              ]}
].
```

```erlang
[
 {esnowflake, [
               {redis, [{host, "localhost"}, {port, 26379}]},
               {worker_num, 2}
              ]}
].
```

Bench
=====

```
----------------------------------------------------
2017-10-29 16:03:27.671
b_generate_id	100000	4564.13864 ns/op


----------------------------------------------------
2017-10-29 16:03:28.703
b_generate_id	232502 op/sec

%%% esnowflake_SUITE ==> bench.b_generate_id: OK

----------------------------------------------------
2017-10-29 16:03:29.700
b_generate_ids_100	10000	96834.8342 ns/op


----------------------------------------------------
2017-10-29 16:03:30.702
b_generate_ids_100	686 op/sec

%%% esnowflake_SUITE ==> bench.b_generate_ids: OK
```
