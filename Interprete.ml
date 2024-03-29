type ide = string;;
type exp = Eint of int | Ebool of bool | EString of string | Den of ide | Prod of exp * exp | Sum of exp * exp | Diff of exp * exp |
	Eq of exp * exp | Minus of exp | IsZero of exp | Or of exp * exp | And of exp * exp | Not of exp |
	Ifthenelse of exp * exp * exp | Let of ide * exp * exp | Fun of ide * exp | FunCall of exp * exp |
	Letrec of ide * exp * exp | Dictionary of dict | Select of ide * exp | Insert of ide * exp * exp |
	Remove of exp * ide | Clear of exp | ApplyOver of exp * exp
and dict = Empty | Item of ide * exp * dict;;

(*ambiente polimorfo*)
type 't env = ide -> 't;;
let emptyenv (v : 't) = function x -> v;;
let applyenv (r : 't env) (i : ide) = r i;;
let bind (r : 't env) (i : ide) (v : 't) = function x -> if x = i then v else applyenv r x;;

(*tipi esprimibili*)
type evT = Int of int | Bool of bool | String of string | Unbound | FunVal of evFun | RecFunVal of ide * evFun | DictionaryVal of (ide * evT) list
and evFun = ide * exp * evT env

(*rts*)
(*type checking*)
let typecheck (s : string) (v : evT) : bool = match s with
	"int" -> (match v with
		Int(_) -> true |
		_ -> false) |
	"bool" -> (match v with
		Bool(_) -> true |
		_ -> false) |
	"string" -> (match v with
		String(_) -> true |
		_ -> false) |
	_ -> failwith("not a valid type");;

(*funzioni primitive*)
let prod x y = if (typecheck "int" x) && (typecheck "int" y)
	then (match (x,y) with
		(Int(n),Int(u)) -> Int(n*u))
	else failwith("Type error");;

let sum x y = if (typecheck "int" x) && (typecheck "int" y)
	then (match (x,y) with
		(Int(n),Int(u)) -> Int(n+u))
	else failwith("Type error");;

let diff x y = if (typecheck "int" x) && (typecheck "int" y)
	then (match (x,y) with
		(Int(n),Int(u)) -> Int(n-u))
	else failwith("Type error");;

let eq x y = if (typecheck "int" x) && (typecheck "int" y)
	then (match (x,y) with
		(Int(n),Int(u)) -> Bool(n=u))
	else failwith("Type error");;

let minus x = if (typecheck "int" x) 
	then (match x with
	   	Int(n) -> Int(-n))
	else failwith("Type error");;

let iszero x = if (typecheck "int" x)
	then (match x with
		Int(n) -> Bool(n=0))
	else failwith("Type error");;

let vel x y = if (typecheck "bool" x) && (typecheck "bool" y)
	then (match (x,y) with
		(Bool(b),Bool(e)) -> (Bool(b||e)))
	else failwith("Type error");;

let et x y = if (typecheck "bool" x) && (typecheck "bool" y)
	then (match (x,y) with
		(Bool(b),Bool(e)) -> Bool(b&&e))
	else failwith("Type error");;

let non x = if (typecheck "bool" x)
	then (match x with
		Bool(true) -> Bool(false) |
		Bool(false) -> Bool(true))
	else failwith("Type error");;

(*interprete*)
let rec eval (e : exp) (r : evT env) : evT = match e with
	Eint n -> Int n |
	Ebool b -> Bool b |
	EString s -> String s |
	IsZero a -> iszero (eval a r) |
	Den i -> applyenv r i |
	Eq(a, b) -> eq (eval a r) (eval b r) |
	Prod(a, b) -> prod (eval a r) (eval b r) |
	Sum(a, b) -> sum (eval a r) (eval b r) |
	Diff(a, b) -> diff (eval a r) (eval b r) |
	Minus a -> minus (eval a r) |
	And(a, b) -> et (eval a r) (eval b r) |
	Or(a, b) -> vel (eval a r) (eval b r) |
	Not a -> non (eval a r) |
	Ifthenelse(a, b, c) -> 
		let g = (eval a r) in
			if (typecheck "bool" g) 
				then (if g = Bool(true) then (eval b r) else (eval c r))
				else failwith ("nonboolean guard") |
	Let(i, e1, e2) -> eval e2 (bind r i (eval e1 r)) |
	Fun(i, a) -> FunVal(i, a, r) |
	Dictionary(d) -> DictionaryVal(evalDict d r) |	
	Select(field, dict) -> 
				(match eval dict r with
					DictionaryVal(dic) -> select field dic |
					_ -> failwith("Not a dictionary")) |
	Insert(field, e1, dict) -> 
				(match eval dict r with
					DictionaryVal(dic) -> if memberDict field dic
											then failwith("this field already exists") 
										    else DictionaryVal((field, (eval e1 r))::dic) |
					_ -> failwith("Not a dictionary")) |
	Remove(dict, field) -> 
				(match eval dict r with
					DictionaryVal(dic) -> DictionaryVal(removeFromDic field dic) |
					_ -> failwith("Not a dictionary")) |
	Clear(e1) ->
				(match eval e1 r with
					DictionaryVal(dic) -> DictionaryVal([]) |
					_ -> failwith("Not a dictionary")) |
	ApplyOver(f, d) ->
				(match d with
					Dictionary(dic) -> DictionaryVal(mapDic f dic r) |
					_ -> failwith("Not a dictionary")) |
	FunCall(f, eArg) -> 
		let fClosure = (eval f r) in
			(match fClosure with
				FunVal(arg, fBody, fDecEnv) -> 
					eval fBody (bind fDecEnv arg (eval eArg r)) |
				RecFunVal(g, (arg, fBody, fDecEnv)) -> 
					let aVal = (eval eArg r) in
						let rEnv = (bind fDecEnv g fClosure) in
							let aEnv = (bind rEnv arg aVal) in
								eval fBody aEnv |
				_ -> failwith("non functional value")) |
    Letrec(f, funDef, letBody) ->
        	(match funDef with
        		Fun(i, fBody) -> let r1 = (bind r f (RecFunVal(f, (i, fBody, r)))) in
                     			                eval letBody r1 |
        		_ -> failwith("non functional def"))
	and evalDict (dc: dict) (r: evT env) : (ide * evT) list =
		match dc with
			Empty -> [] |
			Item(id, e1, tl) -> (id, (eval e1 r))::evalDict tl r
	and select (field: ide) (dc: (ide * evT) list) : evT =
		match dc with
			[] -> Unbound |
			(i, v)::tl -> if field = i then v else select field tl
	and memberDict (field: ide) (dc: (ide * evT) list) : bool =
		match dc with
			[] -> false |
			(i, v)::tl -> if i = field then true else memberDict field tl
	and mapDic (f: exp) (dc: dict) (r: evT env) : (ide * evT) list =
		match dc with
			Empty -> [] |
			Item(id, v, tl) -> let newVal = eval (FunCall(f, v)) r in (id, newVal)::(mapDic f tl r)
	and removeFromDic (field: ide) (dc: (ide * evT) list) : (ide * evT) list =
			match dc with
				[] -> [] |
				(i, v)::tl -> if field = i then tl else (i,v)::(removeFromDic field tl);;