exception NotImplemented

(* Variables *)
type name = string

(* Primitive operations *)
type primop =
  | Equals        (* v1 = v2 *)
  | NotEquals     (* v1 != v2 *)
  | LessThan      (* i1 < i2 *)
  | LessEqual     (* i1 <= i2 *)
  | GreaterThan   (* i1 > i2 *)
  | GreaterEqual  (* i1 >= i2 *)
  | And           (* b1 && b2 *)
  | Or            (* b1 || b2 *)
  | Plus          (* i1 + i2 *)
  | Minus         (* i1 - i2 *)
  | Times         (* i1 * i2 *)
  | Div           (* i1 / i2 *)
  | Negate        (* ~ i *)

(* type exception *)
exception TypeError of string

let type_fail message = raise (TypeError message)

type typ =
  | TArrow   of typ * typ         (* a -> b *)
  | TProduct of typ list          (* a * b *)
  | TInt                          (* int *)
  | TBool                         (* bool *)
  | TVar     of (typ option) ref  (* Only used for Q6 and Q7 *)

let fresh_tvar () = TVar (ref None)

(* type equality ignoring TVar *)
let rec typ_eq t1 e2 =
  match (t1, e2) with
  | (TArrow (domain1, range1), TArrow (domain2, range2)) ->
     typ_eq domain1 domain2 && typ_eq range1 range2
  | (TProduct ts1, TProduct ts2) ->
     List.length ts1 = List.length ts2 && List.for_all2 typ_eq ts1 ts2
  | (TInt, TInt) -> true
  | (TBool, TBool) -> true
  | _ -> false

(* general exception *)
exception Stuck of string

let stuck message = raise (Stuck message)

type exp =
  | Int    of int                        (* 0 | 1 | 2 | ... *)
  | Bool   of bool                       (* true | false *)
  | If     of exp * exp * exp            (* if e then e1 else e2 *)
  | Primop of primop * exp list          (* e1 <op> e2  or  <op> e *)
  | Tuple  of exp list                   (* (e1, ..., eN) *)
  | Fn     of (name * typ option * exp)  (* fn x => e *)
  | Rec    of name * typ * exp           (* rec f => e *)
  | Let    of dec list * exp             (* let decs in e end *)
  | Apply  of exp * exp                  (* e1 e2 *)
  | Var    of name                       (* x *)
  | Anno   of exp * typ                  (* e : t *)

and dec =
  | Val      of exp * name               (* val x = e *)
  | Valtuple of exp * name list          (* val (x1,...,xN) = e *)
  | ByName   of exp * name               (* name x = e1 *)

let eval_op op args =
  match (op, args) with
  | (Equals,       [Int i1; Int i2])   -> Some (Bool (i1 = i2))
  | (NotEquals,    [Int i1; Int i2])   -> Some (Bool (i1 <> i2))
  | (LessThan,     [Int i1; Int i2])   -> Some (Bool (i1 < i2))
  | (LessEqual,    [Int i1; Int i2])   -> Some (Bool (i1 <= i2))
  | (GreaterThan,  [Int i1; Int i2])   -> Some (Bool (i1 > i2))
  | (GreaterEqual, [Int i1; Int i2])   -> Some (Bool (i1 >= i2))
  | (Plus,         [Int i1; Int i2])   -> Some (Int (i1 + i2))
  | (Minus,        [Int i1; Int i2])   -> Some (Int (i1 - i2))
  | (Times,        [Int i1; Int i2])   -> Some (Int (i1 * i2))
  | (Div,          [Int i1; Int i2])   -> Some (Int (i1 / i2))
  | (Negate,       [Int i])            -> Some (Int (-i))
  | _                                  -> None

type context = Ctx of (name * typ) list

(* Context manipulation helpers *)
exception NotFound

let ctx_lookup ctx x =
  let rec assoc x y =
    match y with
    | [] -> raise NotFound
    | (y, r) :: rest ->
       if x = y then
         r
       else
         assoc x rest
  in
  let Ctx list = ctx in assoc x list

let extend ctx (x, v) = let Ctx list = ctx in Ctx ((x,v)::list)

let rec extend_list ctx l =
  match l with
  | [] -> ctx
  | (x, y) :: pairs -> extend_list (extend ctx (x, y)) pairs

(* Replacement for the standard "result" type *)
type ('a, 'b) either =
  | Left of 'a
  | Right of 'b

(* Set helper functions. You might find them useful *)
let member = List.mem

let rec union xs ys =
  match xs with
  | [] -> ys
  | x :: xs ->
     if member x ys then
       union xs ys
     else
       x :: union xs ys

let union_list sets = List.fold_right union sets []

let rec delete ds set =
  match set with
  | [] -> []
  | h :: t ->
     if member h ds then
       delete ds t
     else
       h :: delete ds t


(* free name generator *)
let (fresh_var, reset_ctr) =
  let counter = ref 0 in
  ((fun x ->
    counter := !counter+1;
    string_of_int (!counter) ^ x),
   fun () ->
   counter := 0)

(* Update this to 1 or higher to get debug messages *)
let debug = ref 0

(* example valid MiniML programs *)

let valid_program_1 = "
let fun apply (f : int -> int) : int -> int =
          fn x : int => f(x)
in
  apply (fn x => x * 3) 100
end;
"

let valid_program_2 = "10 * 10 + 33;"

let valid_program_3 = "
let fun fact (x : int) : int =
  if x = 0 then 1
  else x * fact(x - 1)
in
  fact 5
end;
"

let valid_program_4 = "(if true then 3 else 5) : int;"

let valid_program_5 = "
let val x = 1
in
  x + 5
end;
"

let valid_program_6 = "
let val x = true
in
  let val x = 1
  in
    x + 5
  end
end;
"

let valid_program_7 = "
let name x = 3
in
  x + 1
end;
"

let valid_program_8 = "
let val (x,y) = (2 + 1, 2 * 50) in x * x * y end;
"

let valid_program_9 = "
let fun repeat (n : int) : (int -> int) -> int -> int =
          fn f : (int -> int) => fn x : int =>
            if n = 0 then x
            else repeat (n - 1) f (f(x))
in
 repeat 4 (fn z : int => z * 2) 100
 (* expected result: 100 * 2 * 2 * 2 * 2 = 1600 *)
end;
"

let valid_program_10 = "
let val f = let val ten = 10 in (fn y => ten) : int -> int end
in
  f 55
end;
"

(* Q0  : Get familiar with the external syntax of MiniML *)
let parse_tests : (string * (string, exp) either) list = [
    (* Provide your tests for the parser *)
  ("1;", Right (Int 1));
  ( "10 * 10 + 33;", 
    Right (
      Primop (Plus, [Primop (Times, [Int 10; Int 10]); Int 33])
    ) 
  );
  ( "(if true then 3 else 5) : int;",
    Right (
      Anno (If (Bool true, Int 3, Int 5), TInt)
    ) );
  ( "let val x = 1 in x + 5 end;",
    Right ( 
      Let (
        [ Val (Int 1, "x") ], 
        Primop (Plus, [Var "x"; Int 5])
      )
    )
  );
  ( "let val x = true in let val x = 1 in x + 5 end end;",
    Right (
      Let ( [Val (Bool true, "x")], 
            Let ( [Val (Int 1, "x")], Primop (Plus, [Var "x"; Int 5]))
          )
    )
  );
  ( "let name x = 3 in x + 1 end;",
    Right (
      Let ([ByName (Int 3, "x")], Primop (Plus, [Var "x"; Int 1]))
    )
  );
  ( "let val (x,y) = (2 + 1, 2 * 50) in x * x * y end;",
    Right (
      Let (
        [Valtuple (
            Tuple ([Primop (Plus, [Int 2; Int 1]); Primop (Times, [Int 2; Int 50])]),
            ["x"; "y"]
          )],
        Primop(Times, [Primop (Times, [Var "x"; Var "x"]); Var "y"])
      )
    )
  );
]


let free_vars_tests : (exp * name list) list = [ 
  (Int 10, [])
]

(* Q1  : Find the free variables in an expression *)
let rec free_vars (e : exp) : name list = raise NotImplemented


let unused_vars_tests : (exp * name list) list = [
]

(* Q2  : Check variables are in use *)
let rec unused_vars (e : exp) : name list = raise NotImplemented


let subst_tests : (((exp * name) * exp) * exp) list = [
]

(* Q3  : Substitute a variable *)
let rec subst ((e', x) : exp * name) (e : exp) : exp =
  match e with
  | Var y ->
      if x = y then
        e'
      else
        Var y

  | Int _ | Bool _ -> e
  | Primop (po, es) -> Primop (po, List.map (subst (e', x)) es)
  | If (e1, e2, e3) -> If (subst (e', x) e1, subst (e', x) e2, subst (e', x) e3)
  | Tuple es -> Tuple (List.map (subst (e', x)) es)
  | Anno (e, t) -> Anno (subst (e', x) e, t)

  | Let (ds, e2) -> raise NotImplemented
  | Apply (e1, e2) -> raise NotImplemented
  | Fn (y, t, e) -> raise NotImplemented
  | Rec (y, t, e) -> raise NotImplemented


let eval_tests : (exp * exp) list = [
]

(* Q4  : Evaluate an expression in big-step *)
let rec eval : exp -> exp =
  (* do not change the code from here *)
  let bigstep_depth = ref 0 in
  fun e ->
    if !debug >= 1 then
      print_endline
        (String.make (!bigstep_depth) ' '
         ^ "eval (" ^ Print.exp_to_string e ^ ")\n");
    incr bigstep_depth;
  (* to here *)
    let result =
      match e with
      | Int _ | Bool _ -> e
      | Tuple es -> Tuple (List.map eval es)
      | If (e1, e2, e3) ->
          begin match eval e1 with
            | Bool b ->
                if b then
                  eval e2
                else
                  eval e3
            | _ -> stuck "Condition for if expression should be of the type bool"
          end
      | Anno (e, _) -> eval e     (* types are ignored in evaluation *)
      | Var x -> stuck ("Free variable \"" ^ x ^ "\" during evaluation")

      | Fn (x, t, e) -> raise NotImplemented
      | Apply (e1, e2) -> raise NotImplemented
      | Rec (f, t, e) -> raise NotImplemented

      | Primop (And, es) ->
          raise NotImplemented
      | Primop (Or, es) ->
          raise NotImplemented
      | Primop (op, es) ->
          let vs = List.map eval es in
          begin match eval_op op vs with
            | None -> stuck "Bad arguments to primitive operation"
            | Some v -> v
          end

      | Let (ds, e) -> raise NotImplemented
    in
  (* do not change the code from here *)
    decr bigstep_depth;
    if !debug >= 1 then
      print_endline
        (String.make (!bigstep_depth) ' '
         ^ "result of eval (" ^ Print.exp_to_string e ^ ") = "
         ^ Print.exp_to_string result ^ "\n");
  (* to here *)
    result


let infer_tests : ((context * exp) * typ) list = [
]

(* Q5  : Type an expression *)
(* Q7* : Implement the argument type inference
         For this question, move this function below the "unify". *)
let infer (ctx : context) (e : exp) : typ = raise NotImplemented


let unify_tests : ((typ * typ) * unit) list = [
]

(* find the next function for Q5 *)
(* Q6  : Unify two types *)
let unify (ty1 : typ) (ty2 : typ) : unit = raise NotImplemented


(* Now you can play with the language that you've implemented! *)
let execute (s: string) : unit =
  match P.parse s with
  | Left s -> print_endline ("parsing failed: " ^ s)
  | Right e ->
      try
       (* first we type check the program *)
        ignore (infer (Ctx []) e);
        let result = eval e in
        print_endline ("program is evaluated to: " ^ Print.exp_to_string result)
      with
      | NotImplemented -> print_endline "code is not fully implemented"
      | Stuck s -> print_endline ("evaluation got stuck: " ^ s)
      | NotFound -> print_endline "variable lookup failed"
      | TypeError s -> print_endline ("type error: " ^ s)
      | e -> print_endline ("unknown failure: " ^ Printexc.to_string e)


(************************************************************
 *                     Tester template:                     *
 *         Codes to test your interpreter by yourself.      *
 *         You can change these to whatever you want.       *
 *                We won't grade these codes                *
 ************************************************************)
let list_to_string el_to_string l : string =
  List.fold_left
    begin fun acc el ->
      if acc = "" then
        el_to_string el
      else
        acc ^ "; " ^ el_to_string el
    end
    ""
    l
  |> fun str -> "[" ^ str ^ "]"

let run_test name f ts stringify : unit =
  List.iteri
    begin fun idx (input, expected_output) ->
      try
        let output = f input in
        if output <> expected_output then
          begin
            print_string (name ^ " test #" ^ string_of_int idx ^ " failed\n");
            print_string (stringify output ^ " <> " ^ stringify expected_output);
            print_newline ()
          end
      with
      | exn ->
          print_string (name ^ " test #" ^ string_of_int idx ^ " raised an exception:\n");
          print_string (Printexc.to_string exn);
          print_newline ()
    end
    ts

let run_free_vars_tests () : unit =
  run_test "free_vars" free_vars free_vars_tests (list_to_string (fun x -> x))

let run_unused_vars_tests () : unit =
  run_test "unused_vars" unused_vars unused_vars_tests (list_to_string (fun x -> x))

let run_subst_tests () : unit =
  run_test "subst" (fun (s, e) -> subst s e) subst_tests Print.exp_to_string

let run_eval_tests () : unit =
  run_test "eval" eval eval_tests Print.exp_to_string

(* You may want to change this to use the unification (unify) instead of equality (<>) *)
let run_infer_tests () : unit =
  run_test "infer" (fun (ctx, e) -> infer ctx e) infer_tests Print.typ_to_string

let run_unify_tests () : unit =
  run_test "unify" (fun (ty1, ty2) -> unify ty1 ty2) unify_tests (fun () -> "()")

let run_all_tests () : unit =
  run_free_vars_tests ();
  run_unused_vars_tests ();
  run_subst_tests ();
  run_eval_tests ();
  run_infer_tests ();
  run_unify_tests ()
