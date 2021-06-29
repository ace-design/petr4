Require Import Coq.Lists.List.
Require Import Coq.Classes.EquivDec.
Require Import Poulet4.FinType.
Require Poulet4.P4automata.Syntax.
Module P4A := Poulet4.P4automata.Syntax.
Require Import Poulet4.P4automata.PreBisimulationSyntax.
Import ListNotations.

Section WeakestPre.
  Set Implicit Arguments.
  
  (* State identifiers. *)
  Variable (S1: Type).
  Context `{S1_eq_dec: EquivDec.EqDec S1 eq}.
  Context `{S1_finite: @Finite S1 _ S1_eq_dec}.

  Variable (S2: Type).
  Context `{S2_eq_dec: EquivDec.EqDec S2 eq}.
  Context `{S2_finite: @Finite S2 _ S2_eq_dec}.

  Definition S: Type := S1 + S2.

  (* Header identifiers. *)
  Variable (H: Type).
  Context `{H_eq_dec: EquivDec.EqDec H eq}.
  Context `{H_finite: @Finite H _ H_eq_dec}.

  Variable (a: P4A.t S H).

  Definition expr_to_bit_expr {c} (s: side) (e: P4A.expr H) : bit_expr H c :=
    match e with
    | P4A.EHdr h => BEHdr c s h
    | P4A.ELit _ bs => BELit _ c bs
    end.

  Definition val_to_bit_expr {c} (value: P4A.v) : bit_expr H c :=
    match value with
    | P4A.VBits bs => BELit _ c bs
    end.

  Fixpoint be_subst {c} (be: bit_expr H c) (e: bit_expr H c) (x: bit_expr H c) : bit_expr H c :=
    match be with
    | BELit _ _ l => BELit _ _ l
    | BEBuf _ _ _
    | BEHdr _ _ _
    | BEVar _ _ =>
      if bit_expr_eq_dec a be x then e else be
    | BESlice be hi lo => BESlice (be_subst be e x) hi lo
    | BEConcat e1 e2 => BEConcat (be_subst e1 e x) (be_subst e2 e x)
    end.

  Fixpoint sr_subst {c} (sr: store_rel H c) (e: bit_expr H c) (x: bit_expr H c) : store_rel H c :=
  match sr with
  | BRTrue _ _
  | BRFalse _ _ => sr
  | BREq e1 e2 => BREq (be_subst e1 e x) (be_subst e2 e x)
  | BRNotEq e1 e2 => BRNotEq (be_subst e1 e x) (be_subst e2 e x)
  | BRAnd r1 r2 => BRAnd (sr_subst r1 e x) (sr_subst r2 e x)
  | BROr r1 r2 => BROr (sr_subst r1 e x) (sr_subst r2 e x)
  | BRImpl r1 r2 => BRImpl (sr_subst r1 e x) (sr_subst r2 e x)
  end.

  Definition case_cond {c} (cond: bit_expr H c) (st': P4A.state_ref S) (s: P4A.sel_case S) :=
    if st' == P4A.sc_st s
    then BREq cond (val_to_bit_expr (P4A.sc_val s))
    else BRFalse _ _.

  Definition cases_cond {c} (cond: bit_expr H c) (st': P4A.state_ref S) (s: list (P4A.sel_case S)) :=
    List.fold_right (@BROr _ _) (BRFalse _ _) (List.map (case_cond cond st') s).

  Fixpoint case_negated_conds {c} (cond: bit_expr H c) (s: list (P4A.sel_case S)) : store_rel H c :=
    match s with
    | nil => BRTrue _ _
    | s :: rest =>
      BRAnd
        (BRNotEq cond (val_to_bit_expr (P4A.sc_val s)))
        (case_negated_conds cond rest)
    end.

  Definition trans_cond
             {c: bctx}
             (s: side)
             (t: P4A.transition S H)
             (st': P4A.state_ref S)
    : store_rel H c :=
    match t with
    | P4A.TGoto _ r =>
      if r == st'
      then BRTrue _ _
      else BRFalse _ _
    | P4A.TSel cond cases default =>
      let be_cond := expr_to_bit_expr s cond in
      BROr (cases_cond be_cond st' cases)
           (if default == st'
            then case_negated_conds be_cond cases
            else BRFalse _ _)
    end.

  Fixpoint wp_op' {c} (s: side) (o: P4A.op H) : nat * store_rel H c -> nat * store_rel H c :=
    fun '(buf_idx, phi) =>
      match o with
      | P4A.OpNil _ => (buf_idx, phi)
      | P4A.OpSeq o1 o2 =>
        wp_op' s o1 (wp_op' s o2 (buf_idx, phi))
      | P4A.OpExtract width hdr =>
        let new_idx := buf_idx + width - 1 in
        let slice := BESlice (BEBuf _ _ s) new_idx buf_idx in
        (new_idx, sr_subst phi (BEHdr _ s hdr) slice)
      | P4A.OpAsgn lhs rhs =>
        (buf_idx, sr_subst phi (BEHdr _ s lhs) (expr_to_bit_expr s rhs))
      end.

  Definition wp_op {c} (s: side) (o: P4A.op H) (phi: store_rel H c) : store_rel H c :=
    snd (wp_op' s o (0, phi)).

  Inductive pred (c: bctx) :=
  | PredRead (s: state_template S)
  | PredJump (cond: store_rel H c) (s: S).

  Definition pick_template (s: side) (c: conf_state S) : state_template S :=
    match s with
    | Left => c.(cs_st1)
    | Right => c.(cs_st2)
    end.

  Definition preds {c} (si: side) (candidates: list S) (s: state_template S) : list (pred c) :=
    if s.(st_buf_len) == 0
    then [PredRead _ {| st_state := s.(st_state); st_buf_len := s.(st_buf_len) - 1 |}]
    else List.map (fun candidate =>
                     let st := a.(P4A.t_states) candidate in
                     PredJump (trans_cond si (P4A.st_trans st) s.(st_state)) candidate)
                  candidates.

  Definition wp_pred {c: bctx} (si: side) (b: bool) (p: pred c) (phi: store_rel H c) : store_rel H c :=
    let phi' := sr_subst phi (BEConcat (BEBuf _ _ si) (BELit _ _ [b])) (BEBuf _ _ si) in
    match p with
    | PredRead _ s =>
      phi'
    | PredJump cond s =>
      BRImpl cond
             (wp_op si (a.(P4A.t_states) s).(P4A.st_op) phi')
    end.

  Definition st_pred {c} (p: pred c) :=
    match p with
    | PredRead _ s => s
    | PredJump _ s => {| st_state := inl s; st_buf_len := 0 |}
    end.

  Definition wp_pred_pair {c} (phi: conf_rel S H c) (preds: pred c * pred c) : list (conf_rel S H c) :=
    let '(sl, sr) := preds in
    [{| cr_st := {| cs_st1 := st_pred sl;
                    cs_st2 := st_pred sr |};
        cr_rel := wp_pred Left false sl (wp_pred Right false sr phi.(cr_rel)) |};
     {| cr_st := {| cs_st1 := st_pred sl;
                    cs_st2 := st_pred sr |};
        cr_rel := wp_pred Left true sl (wp_pred Right true sr phi.(cr_rel)) |}].
     
  Definition wp {c} (phi: conf_rel S H c) : list (conf_rel S H c) :=
    let cur_st_left  := phi.(cr_st).(cs_st1) in
    let cur_st_right := phi.(cr_st).(cs_st2) in
    let pred_pairs := list_prod (preds Left (List.map inl (enum S1)) cur_st_left)
                                (preds Right (List.map inr (enum S2)) cur_st_right) in
    List.concat (List.map (wp_pred_pair phi) pred_pairs).

End WeakestPre.
