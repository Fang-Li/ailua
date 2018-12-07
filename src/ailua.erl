-module(ailua).
-on_load(init/0).

-export([
		new/0,
		dofile/2,
		async_dofile/4,
		call/3,
		async_call/5,

		dofile_and_wait/2,
		call_and_wait/3
    ]).

-define(APPNAME,ailua).
-define(LIBNAME,ailua).
-define(MAX_UINT64,18446744073709551615).

wait(Ref, Timeout) ->
  receive
    {ailua, Ref, Res} -> Res
  after Timeout ->
      throw({error, timeout, Ref})
  end.


dofile_and_wait(L,FilePath) ->
  Ref = make_ref(),
  ok = dofile_async(L,Ref,self(),FilePath),
  wait(Ref, 100000).


call_and_wait(L,Func,Args) ->
  Ref = make_ref(),
  NewArgs = process_list(Args,[]),
  ok = gencall_async(L,Ref,self(),Func,NewArgs),
  wait(Ref, 100000).

dofile(L,FilePath)-> dofile_sync(L,FilePath).
async_dofile(L,Ref,Pid,FilePath) -> dofile_async(L,Ref,Pid,FilePath).
call(L,FunName,Args)->
	NewArgs = process_list(Args,[]),
	gencall_sync(L,FunName,NewArgs).
async_call(L,Ref,Pid,FunName,Args)->
	NewArgs = process_list(Args,[]),
	gencall_async(L,Ref,Pid,FunName,NewArgs).

init() ->
  LibName =
  	case code:priv_dir(?APPNAME) of
    	{error,bad_name} ->
            case filelib:is_dir(filename:join(["..",priv])) of
            	true -> filename:join(["..",priv,?LIBNAME]);
            	_ -> filename:join([priv,?LIBNAME])
            end;
        Dir -> filename:join(Dir,?LIBNAME)
    end,
  erlang:load_nif(LibName,0).

not_loaded(Line) ->
  exit({not_loaded,[{module,?MODULE},{line,Line}]}).


%% some lua api
new() ->
  not_loaded(?LINE).

dofile_sync(_L,_FilePath) ->
  not_loaded(?LINE).
dofile_async(_L,_Ref,_Dest,_FilePath) ->
  not_loaded(?LINE).

gencall_sync(_L,_Func,_InArgs) ->
  not_loaded(?LINE).
gencall_async(_L,_Ref,_Dest,_Func,_InArgs) ->
  not_loaded(?LINE).

process_list([],Acc)->lists:reverse(Acc);
process_list([H|T],Acc) when erlang:is_integer(H)->
	H0 = process_item(H),
	process_list(T,[H0|Acc]);
process_list([H|T],Acc) when erlang:is_list(H)->
	H0 = process_item(H),
	process_list(T,[H0|Acc]);
process_list([H|T],Acc) when erlang:is_map(H)->
	H0 = process_item(H),
process_list(T,[H0|Acc]);
process_list([H|T],Acc)-> process_list(T,[H|Acc]).

process_item(Item) when erlang:is_integer(Item)->
	if 
		Item > ?MAX_UINT64 -> erlang:integer_to_binary(Item);
		true ->Item
	end;
process_item(Item) when erlang:is_list(Item)->
	case io_lib:printable_list(Item)  of 
		true -> Item;
		false -> process_list(Item,[])
	end;
process_item(Item) when erlang:is_map(Item)->
	I = maps:iterator(Item),
	process_map(maps:next(I),#{});
process_item(Item)-> Item.

process_map(none,Acc)-> Acc;
process_map({K, V, I},Acc)->
	K0 = process_item(K),
	V0 = process_item(V),
	process_map(maps:next(I),maps:put(K0,V0,Acc)).

