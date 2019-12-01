%%%-------------------------------------------------------------------
%% @doc pulserl public API
%% @end
%%%-------------------------------------------------------------------

-module(pulserl).

-include("pulserl.hrl").

-behaviour(application).

-export([start/2, stop/1]).

%% API
-export([await/1, await/2]).
-export([produce/2, produce/3]).
-export([sync_produce/2, sync_produce/3]).
-export([new_producer/1, new_producer/2]).


await(ClientRef) ->
	await(ClientRef, 10000).

await(ClientRef, Timeout) ->
	receive
		{Reply, ClientRef} ->
			Reply
	after Timeout ->
		{error, timeout}
	end.


%% @doc
%%  Asynchronously produce
%% @end
produce(PidOrTopic, Value) when is_binary(Value); is_list(Value) ->
	produce(PidOrTopic, undefined, Value, ?PRODUCE_TIMEOUT);

produce(PidOrTopic, #prod_message{} = Msg) ->
	produce(PidOrTopic, Msg, ?PRODUCE_TIMEOUT).

produce(PidOrTopic, #prod_message{} = Msg, Timeout) when
	is_integer(Timeout) orelse Timeout == undefined ->
	if is_pid(PidOrTopic) ->
		pulserl_producer:produce(PidOrTopic, Msg, Timeout);
		true ->
			case get_producer(PidOrTopic, []) of
				{ok, Pid} -> produce(Pid, Msg, Timeout);
				Other -> Other
			end
	end;

produce(PidOrTopic, Key, Value) when is_binary(Value); is_list(Value) ->
	produce(PidOrTopic, Key, Value, ?PRODUCE_TIMEOUT).

produce(PidOrTopic, Key, Value, Timeout) ->
	Key2 = case Key of undefined -> <<>>; _ -> iolist_to_binary(Key) end,
	produce(PidOrTopic, #prod_message{key = Key2, value = iolist_to_binary(Value)}, Timeout).


%% @doc
%%  Synchronously produce
%% @end
sync_produce(PidOrTopic, Value) when is_binary(Value); is_list(Value) ->
	sync_produce(PidOrTopic, undefined, Value, ?PRODUCE_TIMEOUT);

sync_produce(Pid, #prod_message{} = Msg) ->
	sync_produce(Pid, Msg, ?PRODUCE_TIMEOUT).

sync_produce(PidOrTopic, #prod_message{} = Msg, Timeout) when
	is_integer(Timeout) orelse Timeout == undefined ->
	if is_pid(PidOrTopic) ->
		pulserl_producer:sync_produce(PidOrTopic, Msg, Timeout);
		true ->
			case get_producer(PidOrTopic, []) of
				{ok, Pid} -> produce(Pid, Msg, Timeout);
				Other -> Other
			end
	end;

sync_produce(PidOrTopic, Key, Value) ->
	sync_produce(PidOrTopic, Key, Value, ?PRODUCE_TIMEOUT).

sync_produce(PidOrTopic, Key, Value, Timeout) ->
	Key2 = case Key of undefined -> <<>>; _ -> iolist_to_binary(Key) end,
	sync_produce(PidOrTopic, #prod_message{key = Key2, value = iolist_to_binary(Value)}, Timeout).


%% @doc
%%  Create a producer
%% @end
new_producer(TopicName) ->
	new_producer(TopicName, []).

new_producer(TopicName, Options) ->
	Topic = topic_utils:parse(TopicName),
	pulserl_producer:create(Topic, Options).


get_producer(TopicName, Options) ->
	Topic = topic_utils:parse(TopicName),
	case ets:lookup(producers, topic_utils:to_string(Topic)) of
		[] -> pulserl_producer:create(Topic, Options);
		[{_, Pid}] -> {ok, Pid};
		Prods ->
			Pos = rand:uniform(length(Prods)),
			{_, Pid} = lists:nth(Pos, Prods),
			{ok, Pid}
	end.

%%%===================================================================
%%% application callbacks
%%%===================================================================

start(_StartType, _StartArgs) ->
	pulserl_sup:start_link().


stop(_State) ->
	ok.