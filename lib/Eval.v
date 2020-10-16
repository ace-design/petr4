Require Import Coq.Bool.Bvector.
Require Import Coq.Lists.List.
Require Import Coq.NArith.BinNatDef.
Require Import Coq.Strings.String.

Require Import Monads.Monad.
Require Import Monads.Option.
Require Import Monads.State.

Require Import Value.
Require Import Environment.
Require Import Syntax.
Require Import Utils.

Require Import Platform.Packet.

Require Import BinIntDef.

Open Scope monad.

Definition defaultValue (A: type) : value.
Admitted.

Definition evalLvalue (expr: expression) : env_monad lvalue.
Admitted.

Definition evalMinus (v: value) : option value := 
  match v with
  | ValFixedBit width bits => Some (ValFixedInt width (Z.sub (powTwo width) (of_bvector bits)))
  | ValFixedInt width value => Some (ValFixedInt width (Z.sub (powTwo width) value))
  | ValInfInt n => Some (ValInfInt (Z.opp n))
  | _ => None
  end.

Fixpoint evalExpression (expr: expression) : env_monad value :=
  match expr with
  | BoolExpression value => mret (ValBool value)
  | IntExpression value => mret (ValInfInt value)
  | StringExpression value => mret (ValString value)
  | ArrayAccess array index =>
    let* index' := evalExpression index in
    let* array' := evalExpression array in
    match (array', index') with
    | (ValArray array'', ValInfInt index'') => lift_option (indexZError array'' index'')
    | _ => state_fail Internal
    end
  | BitStringAccess array hi lo =>
    let* array' := evalExpression array in
    let* hi'    := evalExpression hi in
    let* lo'    := evalExpression lo in
    match (array', hi', lo') with
    | (ValArray array'', ValInfInt hi'', ValInfInt lo'') => lift_option (option_map ValArray (listSliceZ array'' lo'' hi''))
    | _ => state_fail Internal
    end
  | List exprs => liftM ValArray (sequence (List.map evalExpression exprs))
  | Record entries => 
    let actions := List.map (fun x => match x with | MkKeyValue k e => v <- evalExpression e ;; mret (k, v) end) entries in
    liftM ValRecord (sequence actions)
  | UnaryOp op arg => 
    let* inner := evalExpression arg in
    match op with
    | Not => 
      match inner with
      | ValBool b => mret (ValBool (negb b))
      | _ => state_fail Internal
      end
    | BitNot => 
      match inner with
      | ValFixedBit w bits => mret (ValFixedBit w (Bneg w bits))
      | ValVarBit w bits => mret (ValVarBit w (Bneg w bits))
      | _ => state_fail Internal
      end
    | BitMinus => lift_option (evalMinus inner)
    end
  | _ => mret (ValBool false) (* TODO *)
  end.

Definition evalIsValid (obj: lvalue) : env_monad value :=
  let* result := findLvalue obj
  in match result with
  | ValHeader (MkHeader valid fields) => mret (ValBool valid)
  | _ => state_fail Internal
  end.

Definition evalSetBool (obj: lvalue) (valid: bool) : env_monad unit :=
  let* value := findLvalue obj in
  match value with
  | ValHeader (MkHeader _ fields) =>
    updateLvalue obj (ValHeader (MkHeader valid fields))
  | _ => state_fail Internal
  end.

Definition evalPopFront (obj: lvalue) (args: list (option value)) : env_monad unit :=
  match args with
  | Some (ValInfInt count) :: nil => 
      let* value := findLvalue obj in
      match value with
      | ValHeaderStack size nextIndex elements =>
        match rotateLeftZ elements count (MkHeader false (MStr.Raw.empty _)) with
        | None => state_fail Internal
        | Some elements' =>
          let value' := ValHeaderStack size (nextIndex - (Z.to_nat count)) elements' in
          updateLvalue obj value'
        end
      | _ => state_fail Internal
      end
  | _ => state_fail Internal
  end.

Definition evalPushFront (obj: lvalue) (args: list (option value)) : env_monad unit :=
  match args with
  | Some (ValInfInt count) :: nil => 
      let* value := findLvalue obj in
      match value with
      | ValHeaderStack size nextIndex elements =>
        match rotateRightZ elements count (MkHeader false (MStr.Raw.empty _)) with
        | None => state_fail Internal
        | Some elements' =>
          let nextIndex' := min size (nextIndex + (Z.to_nat count)) in
          let value' := ValHeaderStack size nextIndex' elements' in
          updateLvalue obj value'
        end
      | _ => state_fail Internal
      end
  | _ => state_fail Internal
  end.

Fixpoint evalArguments (args: list (option expression)) : env_monad (list (option value)) :=
  match args with
  | nil => mret nil
  | Some arg :: args' =>
    let* val := evalExpression arg in
    let* vals := evalArguments args' in
    mret (Some val :: vals)
  | None :: args' =>
    let* vals := evalArguments args' in
    mret (None :: vals)
  end.

Definition evalBuiltinFunc (name: string) (obj: lvalue) (args: list (option expression)) : env_monad value :=
  let* args' := evalArguments args in
  match name with
  | "isValid" => evalIsValid obj
  | "setValid" => dummyValue (evalSetBool obj true)
  | "setInvalid" => dummyValue (evalSetBool obj false)
  | "pop_front" => dummyValue (evalPopFront obj args')
  | "push_front" => dummyValue (evalPushFront obj args')
  | _ => state_fail Internal
  end.

Definition evalPacketFunc (obj: lvalue) (name: string) (bits: list bool) (args: list (option expression)) : env_monad unit :=
  match name with
  | "extract" =>
    match args with
    | (Some target_expr) :: nil =>
      let* target := evalLvalue target_expr in
      let* value := findLvalue target in
      match evalPacketExtractFixed value bits with
      | (inr error, bits') =>
        updateLvalue obj (ValExternObj (Packet bits')) ;;
        state_fail error
      | (inl value', bits') =>
        updateLvalue obj (ValExternObj (Packet bits')) ;;
        updateLvalue target value' ;;
        mret tt
      end
    | _ => state_fail Internal
    end
  | _ => state_fail Internal
  end.

Definition evalExternFunc (name: string) (obj: lvalue) (args: list (option expression)): env_monad value :=
  let* value := findLvalue obj in
  match value with
  | ValExternObj ext =>
    match ext with
    | Packet bits => dummyValue (evalPacketFunc obj name bits args)
    end
  | _ => state_fail Internal
  end.

Definition evalMethodCall (func: expression) (type_args: list type) (args: list (option expression)) : env_monad value :=
  let* func' := evalExpression func in
  match func' with
  | ValBuiltinFunc name obj => evalBuiltinFunc name obj args
  | ValExternFunc name obj => evalExternFunc name obj args
  | _ => state_fail Internal (* TODO: other function types *)
  end.

Fixpoint evalBlock (blk: block) : env_monad unit :=
  match blk with
  | BlockCons stmt rest =>
    evalStatement stmt;;
    evalBlock rest
  | BlockEmpty => mret tt
  end

with evalStatement (stmt: statement) : env_monad unit :=
  match stmt with
  | MethodCall func type_args args =>
    tossValue (evalMethodCall func type_args args)
  | Assignment lhs rhs =>
    let* lval := evalLvalue lhs in
    let* val := evalExpression rhs in
    updateLvalue lval val
  | BlockStatement block =>
    mapEnv pushScope;;
    evalBlock block;;
    liftEnvFn popScope
  | StatementConstant type name init =>
    let* value := evalExpression init in
    insertEnvironment name value
  | StatementVariable type name init =>
    let* value :=
       match init with
       | None => mret (defaultValue type)
       | Some expr => evalExpression expr
       end
    in
    insertEnvironment name value
  end.

  (* TODO: sophisticated pattern matching for the match expression as needed *)
Fixpoint evalMatchExpression (vals: list value) (matches: list match_expression) : env_monad bool :=
  match (vals, matches) with
  | (List.nil, List.nil) => mret true
  | (v :: vals', m :: matches') => 
    match m with
    | DontCare          => evalMatchExpression vals' matches'
    | MatchExpression e => 
      let* v' := evalExpression e in 
        if eq_value v v' then evalMatchExpression vals' matches' else mret false
    end
  | _ => mret false
  end.

Fixpoint evalCases (vals: list value) (cases: list Case.case) : env_monad string := 
  match cases with
  | List.nil    => state_fail Internal
  | c :: cases' => 
    let* passes := evalMatchExpression vals (Case.matches c) in
      if passes then mret (Case.next c) else evalCases vals cases'
  end.


Definition evalTransition (t: Transition.transition) : env_monad string := 
  let* vs := sequence (List.map evalExpression (Transition.exprs t)) in 
    evalCases vs (Transition.cases t).

