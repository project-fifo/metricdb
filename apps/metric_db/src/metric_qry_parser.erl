-module(metric_qry_parser).

-export([parse/1, unparse/1, execute/1]).
-ignore_xref([parse/1, unparse/1, execute/1]).

date(L) ->
    i(L).

i(L) ->
    list_to_integer(L).

f(L) ->
    list_to_float(L).

b(L) ->
    list_to_binary(L).

parse(B) when is_binary(B) ->
    parse(binary_to_list(B));

parse(L) when is_list(L) ->
    Tokens = string:tokens(L, " "),
    initial(Tokens).

initial(["SELECT" | L]) ->
    range(L).

range(["BETWEEN", A, "AND", B | L]) ->
    Ad = date(A),
    metric(L, {range, Ad, date(B) - Ad}).

metric(["FROM", M | L], Acc) ->
    aggregate(L, {get, b(M), Acc}).

aggregate([], Acc) ->
    Acc;
aggregate(["DERIVATE" | L], Acc) ->
    aggregate(L, {derivate, Acc});
aggregate(["SCALE", "BY", S | L], Acc) ->
    aggregate(L, {scale, f(S), Acc});

aggregate(["MIN", "OF", N | L], Acc) ->
    aggregate(L, {min, i(N), Acc});
aggregate(["MAX", "OF", N | L], Acc) ->
    aggregate(L, {max, i(N), Acc});

aggregate(["AVG", "OVER", N | L], Acc) ->
    aggregate(L, {avg, i(N), Acc});
aggregate(["SUM", "OVER", N | L], Acc) ->
    aggregate(L, {sum, i(N), Acc}).

unparse(T) ->
    unparse(T, []).

unparse({range, A, B}, Acc) ->
    lists:flatten(["SELECT BETWEEN ", integer_to_list(A), " AND ",
                   integer_to_list(A+B), " " | Acc]);

unparse({get, M, C}, Acc) ->
    unparse(C, ["FROM ", binary_to_list(M), " " | Acc]);

unparse({derivate, C}, Acc) ->
    unparse(C, ["DERIVATE " | Acc]);
unparse({scale, S, C}, Acc) ->
    unparse(C, ["SCALE BY ", float_to_list(S), " " | Acc]);

unparse({min, N, C}, Acc) ->
    unparse(C, ["MIN OF ", integer_to_list(N), " " | Acc]);
unparse({max, N, C}, Acc) ->
    unparse(C, ["MAX OF ", integer_to_list(N), " " | Acc]);

unparse({avg, N, C}, Acc) ->
    unparse(C, ["AVG OVER ", integer_to_list(N), " " | Acc]);
unparse({sum, N, C}, Acc) ->
    unparse(C, ["SUM OVER ", integer_to_list(N), " " | Acc]).


execute({get, M, {range, A, B}}) ->
    {ok, V} = metric:get(M, A, B),
    V;
execute({derivate, C}) ->
    mstore_aggr:derivate(execute(C));
execute({scale, S, C}) ->
    mstore_aggr:scale(execute(C), S);
execute({min, N, C}) ->
    mstore_aggr:min(execute(C), N);
execute({max, N, C}) ->
    mstore_aggr:max(execute(C), N);
execute({avg, N, C}) ->
    mstore_aggr:avg(execute(C), N);
execute({sum, N, C}) ->
    mstore_aggr:sum(execute(C), N).
