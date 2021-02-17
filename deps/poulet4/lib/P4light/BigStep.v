Require Export P4light.Check.
Require Export P4light.P4Arith.
Require Import Coq.Bool.Bool.
Require Import Coq.NArith.BinNatDef.
Require Import Coq.ZArith.BinIntDef.
Require Import Coq.NArith.BinNat.
Require Import Coq.ZArith.BinInt.

Module Value.
  Section Values.
    Variable (tags_t : Type).

    (** Values from expression evaluation. *)
    Inductive v : Type :=
    | VBool (b : bool)
    | VInt (w : positive) (n : Z)
    | VBit (w : positive) (n : N)
    | VRecord (fs : Field.fs tags_t v)
    | VHeader (fs : Field.fs tags_t v)
    | VError (err : string tags_t)
    | VMatchKind (mk : string tags_t).

    (** A custom induction principle for value. *)
    Section ValueInduction.
      Variable P : v -> Prop.

      Hypothesis HVBool : forall b, P (VBool b).

      Hypothesis HVBit : forall w n, P (VBit w n).

      Hypothesis HVInt : forall w n, P (VInt w n).

      Hypothesis HVRecord : forall fs,
          Field.predfs_data P fs -> P (VRecord fs).

      Hypothesis HVHeader : forall fs,
          Field.predfs_data P fs -> P (VHeader fs).

      Hypothesis HVError : forall err, P (VError err).

      Hypothesis HVMatchKind : forall mk, P (VMatchKind mk).

      Definition custom_value_ind : forall v' : v, P v' :=
        fix custom_value_ind (val : v) : P val :=
          let fix fields_ind
                  (flds : Field.fs tags_t v) : Field.predfs_data P flds :=
              match flds as fs return Field.predfs_data P fs with
              | [] => Forall_nil (Field.predf_data P)
              | (_, hfv) as hf :: tf =>
                Forall_cons hf (custom_value_ind hfv) (fields_ind tf)
              end in
          match val as v' return P v' with
          | VBool b  => HVBool b
          | VInt w n => HVInt w n
          | VBit w n => HVBit w n
          | VRecord vs     => HVRecord vs (fields_ind vs)
          | VHeader vs     => HVHeader vs (fields_ind vs)
          | VError err     => HVError err
          | VMatchKind mk  => HVMatchKind mk
          end.
    End ValueInduction.

    Section ValueEquality.
      (** Value equivalence relation. *)
      Inductive equivv : v -> v -> Prop :=
      | equivv_bool (b : bool) :
          equivv (VBool b) (VBool b)
      | equivv_int (w : positive) (n : Z) :
          equivv (VInt w n) (VInt w n)
      | equivv_bit (w : positive) (n : N) :
          equivv (VBit w n) (VBit w n)
      | equivv_record (fs1 fs2 : Field.fs tags_t v) :
          Field.relfs equivv fs1 fs2 ->
          equivv (VRecord fs1) (VRecord fs2)
      | equivv_header (fs1 fs2 : Field.fs tags_t v) :
          Field.relfs equivv fs1 fs2 ->
          equivv (VHeader fs1) (VHeader fs2)
      | equivv_error (err1 err2 : string tags_t) :
          P4String.equiv err1 err2 ->
          equivv (VError err1) (VError err2)
      | equivv_matchkind (mk1 mk2 : string tags_t) :
          P4String.equiv mk1 mk2 ->
          equivv (VMatchKind mk1) (VMatchKind mk2).
      (**[]*)

      Lemma equivv_reflexive : Reflexive equivv.
      Proof.
        intros v; induction v using custom_value_ind;
          constructor; try reflexivity;
        try (induction fs as [| [x v] vs];
             inversion H; subst; constructor;
             [ unfold Field.predf_data in H2;
               constructor; simpl; try reflexivity; auto
             | apply IHvs; auto]).
      Qed.

      Lemma equivv_symmetric : Symmetric equivv.
      Proof.
        intros v1; induction v1 using custom_value_ind;
          intros [] HEQ; inversion HEQ; clear HEQ; subst;
            constructor; try (symmetry; assumption);
              try (rename fs into fs1; rename fs0 into fs2;
                   generalize dependent fs2;
                   induction fs1 as [| [x1 v1] vs1 IHvs1];
                   intros [| [x2 v2] vs2] HSym;
                   inversion HSym; clear HSym; subst; constructor;
                   inversion H; clear H; subst;
                   [ unfold Field.relf in *; simpl in *;
                     destruct H3; split; try (symmetry; assumption);
                     apply H2; assumption
                   | apply IHvs1; auto ]).
      Qed.

      Lemma equivv_transitive : Transitive equivv.
      Proof.
        intros v1; induction v1 using custom_value_ind; intros v2 v3 H12 H23;
          inversion H12; subst; inversion H23; subst;
            clear H12 H23; constructor;
              try (transitivity err2; auto); try (transitivity mk2; auto);
        try (generalize dependent fs0; generalize dependent fs2;
             rename fs into fs1;
             induction fs1 as [| [x1 v1] vs1 IHvs1];
             intros [| [x2 v2] vs2] H12 [| [x3 v3] vs3] H23;
             inversion H12; subst; inversion H23; subst;
             clear H12 H23; constructor; inversion H; subst; clear H;
             [ unfold Field.relf in *; simpl in *;
               unfold Field.predf_data;
               destruct H3; destruct H4;
               pose proof (H2 v2 v3) as H23; try split; auto;
               transitivity x2; auto
             | apply IHvs1 with vs2; auto]).
      Qed.

      Instance ValueEquivalence : Equivalence equivv.
      Proof.
        constructor; [ apply equivv_reflexive
                     | apply equivv_symmetric
                     | apply equivv_transitive].
      Defined.

      Lemma equivv_dec : forall v1 v2 : v,
          equivv v1 v2 \/ ~ equivv v1 v2.
      Proof.
        induction v1 using custom_value_ind; intros [];
          try (right; intros H'; inversion H'; contradiction).
        - destruct (equiv_dec b b0) as [Hb | Hb];
            unfold equiv in *; unfold complement in *; subst;
              [ left; constructor
              | right; intros H'; inversion H'; contradiction ].
      Abort.
    End ValueEquality.
  End Values.

  Arguments VBool {_}.
  Arguments VInt {_}.
  Arguments VBit {_}.
  Arguments VRecord {_}.
  Arguments VHeader {_}.
  Arguments VError {_}.
  Arguments VMatchKind {_}.

  Module ValueNotations.
    Declare Custom Entry p4value.

    Notation "'*{' val '}*'" := val (val custom p4value at level 99).
    Notation "( x )" := x (in custom p4value, x at level 99).
    Notation "x" := x (in custom p4value at level 0, x constr at level 0).
    Notation "'TRUE'" := (VBool true) (in custom p4value at level 0).
    Notation "'FALSE'" := (VBool false) (in custom p4value at level 0).
    Notation "'VBOOL' b" := (VBool b) (in custom p4value at level 0).
    Notation "w 'VW' n" := (VBit w n) (in custom p4value at level 0).
    Notation "w 'VS' n" := (VInt w n) (in custom p4value at level 0).
    Notation "'REC' { fs }" := (VRecord fs)
                                 (in custom p4value at level 6,
                                     no associativity).
    Notation "'HDR' { fs }" := (VHeader fs)
                                 (in custom p4value at level 6,
                                     no associativity).
    Notation "'ERROR' x" := (VError x) (in custom p4value at level 0).
    Notation "'MATCHKIND' x" := (VMatchKind x) (in custom p4value at level 0).
  End ValueNotations.
End Value.

Module Step.
  Module P := P4light.
  Module E := P.Expr.
  Module ST := P.Stmt.
  Module F := P.F.
  Module V := Value.

  Import E.TypeNotations.
  Import E.ExprNotations.
  Import ST.StmtNotations.
  Import V.ValueNotations.

  (** Statement signals. *)
  Inductive signal (tags_t : Type) : Type :=
  | SIG_Cont                           (* continue *)
  | SIG_Exit                           (* exit *)
  | SIG_Rtrn (v : option (V.v tags_t)) (* return *).

  Arguments SIG_Cont {_}.
  Arguments SIG_Exit {_}.
  Arguments SIG_Rtrn {_}.

  Declare Custom Entry p4evalsignal.

  Notation "x"
    := x (in custom p4evalsignal at level 0, x constr at level 0).
  Notation "'C'" := SIG_Cont (in custom p4evalsignal at level 0).
  Notation "'X'" := SIG_Exit (in custom p4evalsignal at level 0).
  Notation "'R' 'of' v ?"
    := (SIG_Rtrn v) (in custom p4evalsignal at level 0).
  Notation "'Void'" := (SIG_Rtrn None) (in custom p4evalsignal at level 0).
  Notation "'Fruit' v" := (SIG_Rtrn (Some v)) (in custom p4evalsignal at level 0).

  Reserved Notation "⟨ ϵ , e ⟩ ⇓ v"
           (at level 40, e custom p4expr, v custom p4value).

  Import Env.EnvNotations.

  Reserved Notation "⟪ fenv , ϵ1 , s ⟫ ⤋ ⟪ ϵ2 , sig ⟫"
           (at level 40, s custom p4stmt,
            ϵ2 custom p4env, sig custom p4evalsignal).
  (**[]*)

  Section Step.
    Context {tags_t : Type}.

    (** Unsigned integer binary operations. *)
    Definition eval_bit_binop
               (op : E.bop) (w : positive)
               (n1 n2 : N) : option (V.v tags_t) :=
      match op with
      | E.Plus     => Some (V.VBit w (BitArith.plus_mod w n1 n2))
      | E.PlusSat  => Some (V.VBit w (BitArith.plus_sat w n1 n2))
      | E.Minus    => Some (V.VBit w (BitArith.minus_mod w n1 n2))
      | E.MinusSat => Some (V.VBit w (N.sub n1 n2))
      | E.Shl      => Some (V.VBit w (N.shiftl n1 n2))
      | E.Shr      => Some (V.VBit w (BitArith.shift_right w n1 n2))
      | E.Le       => Some (V.VBool (N.leb n1 n2))
      | E.Ge       => Some (V.VBool (N.leb n2 n1))
      | E.Lt       => Some (V.VBool (N.ltb n1 n2))
      | E.Gt       => Some (V.VBool (N.ltb n2 n1))
      | E.Eq       => Some (V.VBool (N.eqb n1 n2))
      | E.NotEq    => Some (V.VBool (negb (N.eqb n1 n2)))
      | E.BitAnd   => Some (V.VBit w (BitArith.bit_and w n1 n2))
      | E.BitXor   => Some (V.VBit w (BitArith.bit_xor w n1 n2))
      | E.BitOr    => Some (V.VBit w (BitArith.bit_or  w n1 n2))
      | E.PlusPlus
      | E.And
      | E.Or       => None
      end.
    (**[]*)

    (** Signed integer binary operations. *)
    Definition eval_int_binop
               (op : E.bop) (w : positive)
               (z1 z2 : Z) : option (V.v tags_t) :=
      match op with
      | E.Plus     => Some (V.VInt w (IntArith.plus_mod w z1 z2))
      | E.PlusSat  => Some (V.VInt w (IntArith.plus_sat w z1 z2))
      | E.Minus    => Some (V.VInt w (IntArith.minus_mod w z1 z2))
      | E.MinusSat => Some (V.VInt w (IntArith.minus_sat w z1 z2))
      | E.Shl      => Some (V.VInt w (IntArith.shift_left w z1 z2))
      | E.Shr      => Some (V.VInt w (IntArith.shift_right w z1 z2))
      | E.Le       => Some (V.VBool (Z.leb z1 z2))
      | E.Ge       => Some (V.VBool (Z.leb z2 z1))
      | E.Lt       => Some (V.VBool (Z.ltb z1 z2))
      | E.Gt       => Some (V.VBool (Z.ltb z2 z1))
      | E.Eq       => Some (V.VBool (Z.eqb z1 z2))
      | E.NotEq    => Some (V.VBool (negb (Z.eqb z1 z2)))
      | E.BitAnd   => Some (V.VInt w (IntArith.bit_and w z1 z2))
      | E.BitXor   => Some (V.VInt w (IntArith.bit_xor w z1 z2))
      | E.BitOr    => Some (V.VInt w (IntArith.bit_or  w z1 z2))
      | E.PlusPlus
      | E.And
      | E.Or       => None
      end.
    (**[]*)

    (** Boolean binary operations. *)
    Definition eval_bool_binop (op : E.bop) (b1 b2 : bool) : option bool :=
      match op with
      | E.Eq    => Some (eqb b1 b2)
      | E.NotEq => Some (negb (eqb b1 b2))
      | E.And   => Some (b1 && b2)
      | E.Or    => Some (b1 || b2)
      | _       => None
      end.

    (** Variable to Value mappings. *)
    Definition epsilon : Type := Env.t (name tags_t) (V.v tags_t).

    (* TODO: Handle Errors! *)
    Inductive expr_big_step (ϵ : epsilon) : E.e tags_t -> V.v tags_t -> Prop :=
    (* Literals. *)
    | ebs_bool (b : bool) (i : tags_t) :
        ⟨ ϵ, BOOL b @ i ⟩ ⇓ VBOOL b
    | ebs_bit (w : positive) (n : N) (i : tags_t) :
        ⟨ ϵ, w W n @ i ⟩ ⇓ w VW n
    | ebs_int (w : positive) (z : Z) (i : tags_t) :
        ⟨ ϵ, w S z @ i ⟩ ⇓ w VS z
    | ebs_var (x : name tags_t) (τ : E.t tags_t) (i : tags_t) (v : V.v tags_t) :
        ϵ x = Some v ->
        ⟨ ϵ, Var x :: τ @ i end ⟩ ⇓ v
    | ebs_error (err : string tags_t) (i : tags_t) :
        ⟨ ϵ, Error err @ i ⟩ ⇓ ERROR err
    | ebs_matchkind (mk : string tags_t) (i : tags_t) :
        ⟨ ϵ, Matchkind mk @ i ⟩ ⇓ MATCHKIND mk
    (* Unary Operations. *)
    | ebs_not (e : E.e tags_t) (i : tags_t) (b b' : bool) :
        negb b = b' ->
        ⟨ ϵ, e ⟩ ⇓ VBOOL b ->
        ⟨ ϵ, ! e :: Bool @ i end ⟩ ⇓ VBOOL b'
    (* TODO: bitnot case is incorrect,
       need to define negation for [N]. *)
    | ebs_bitnot (e : E.e tags_t) (i : tags_t)
                 (w : positive) (n n' : N) :
        ⟨ ϵ, e ⟩ ⇓ w VW n ->
        ⟨ ϵ, ~ e :: bit<w> @ i end ⟩ ⇓ w VW n
    (* TODO: uminus case is incorrect,
       need to define proper negation for [Z]. *)
    | ebs_uminus (e : E.e tags_t) (i : tags_t)
                 (w : positive) (z z' : Z) :
        Z.opp z = z' ->
        ⟨ ϵ, e ⟩ ⇓ w VS z ->
        ⟨ ϵ, ~ e :: int<w> @ i end ⟩ ⇓ w VS z'
    (* Binary Operations. *)
    | ebs_bop_bit (e1 e2 : E.e tags_t) (op : E.bop) (v : V.v tags_t)
                  (i : tags_t) (w : positive) (n1 n2 : N) :
        eval_bit_binop op w n1 n2 = Some v ->
        ⟨ ϵ, e1 ⟩ ⇓ w VW n1 ->
        ⟨ ϵ, e2 ⟩ ⇓ w VW n2 ->
        expr_big_step ϵ (E.EBop op {{bit<w>}} {{bit <w>}} e1 e2 i) v
    | ebs_plusplus (e1 e2 : E.e tags_t) (i : tags_t)
                   (w w1 w2 : positive) (n n1 n2 : N) :
        (w1 + w2)%positive = w ->
        BitArith.bit_concat w2 n1 n2 = n ->
        ⟨ ϵ, e1 ⟩ ⇓ w1 VW n1 ->
        ⟨ ϵ, e2 ⟩ ⇓ w2 VW n2 ->
        ⟨ ϵ, ++ e1 :: bit<w1> e2 :: bit<w2> @ i end ⟩ ⇓ w VW n
    | ebs_bop_int (e1 e2 : E.e tags_t) (op : E.bop) (v : V.v tags_t)
                  (i : tags_t) (w : positive) (z1 z2 : Z) :
        eval_int_binop op w z1 z2 = Some v ->
        ⟨ ϵ, e1 ⟩ ⇓ w VS z1 ->
        ⟨ ϵ, e2 ⟩ ⇓ w VS z2 ->
        expr_big_step ϵ (E.EBop op {{int<w>}} {{int <w>}} e1 e2 i) v
    | ebs_bop_bool (e1 e2 : E.e tags_t) (op : E.bop)
                   (i : tags_t) (b b1 b2 : bool) :
        eval_bool_binop op b1 b2 = Some b ->
        ⟨ ϵ, e1 ⟩ ⇓ VBOOL b1 ->
        ⟨ ϵ, e2 ⟩ ⇓ VBOOL b2 ->
        expr_big_step ϵ (E.EBop op {{ Bool }} {{ Bool }} e1 e2 i) *{VBOOL b}*
    | ebs_eq_true (e1 e2 : E.e tags_t) (τ1 τ2 : E.t tags_t)
                  (i : tags_t) (v1 v2 : V.v tags_t) :
        V.equivv tags_t v1 v2 ->
        ⟨ ϵ, e1 ⟩ ⇓ v1 ->
        ⟨ ϵ, e2 ⟩ ⇓ v2 ->
        ⟨ ϵ, == e1 :: τ1 e2 :: τ2 @ i end ⟩ ⇓ TRUE
    | ebs_eq_false (e1 e2 : E.e tags_t) (τ1 τ2 : E.t tags_t)
                   (i : tags_t) (v1 v2 : V.v tags_t) :
        ~ V.equivv tags_t v1 v2 ->
        ⟨ ϵ, e1 ⟩ ⇓ v1 ->
        ⟨ ϵ, e2 ⟩ ⇓ v2 ->
        ⟨ ϵ, == e1 :: τ1 e2 :: τ2 @ i end ⟩ ⇓ FALSE
    | ebs_neq_true (e1 e2 : E.e tags_t) (τ1 τ2 : E.t tags_t)
                   (i : tags_t) (v1 v2 : V.v tags_t) :
        ~ V.equivv tags_t v1 v2 ->
        ⟨ ϵ, e1 ⟩ ⇓ v1 ->
        ⟨ ϵ, e2 ⟩ ⇓ v2 ->
        ⟨ ϵ, != e1 :: τ1 e2 :: τ2 @ i end ⟩ ⇓ TRUE
    | ebs_neq_false (e1 e2 : E.e tags_t) (τ1 τ2 : E.t tags_t)
                    (i : tags_t) (v1 v2 : V.v tags_t) :
        V.equivv tags_t v1 v2 ->
        ⟨ ϵ, e1 ⟩ ⇓ v1 ->
        ⟨ ϵ, e2 ⟩ ⇓ v2 ->
        ⟨ ϵ, != e1 :: τ1 e2 :: τ2 @ i end ⟩ ⇓ FALSE
    (* Structs *)
    | ebs_rec_mem (e : E.e tags_t) (x : string tags_t) (i : tags_t)
                  (tfs : F.fs tags_t (E.t tags_t))
                  (vfs : F.fs tags_t (V.v tags_t)) (v : V.v tags_t) :
        F.get x vfs = Some v ->
        ⟨ ϵ, e ⟩ ⇓ REC { vfs } ->
        ⟨ ϵ, Mem e :: rec { tfs } dot x @ i end ⟩ ⇓ v
    | ebs_hdr_mem (e : E.e tags_t) (x : string tags_t) (i : tags_t)
                  (tfs : F.fs tags_t (E.t tags_t))
                  (vfs : F.fs tags_t (V.v tags_t)) (v : V.v tags_t) :
        F.get x vfs = Some v ->
        ⟨ ϵ, e ⟩ ⇓ HDR { vfs } ->
        ⟨ ϵ, Mem e :: hdr { tfs } dot x @ i end ⟩ ⇓ v
    | ebs_rec_lit (efs : F.fs tags_t (E.t tags_t * E.e tags_t))
                  (i : tags_t) (vfs : F.fs tags_t (V.v tags_t)) :
        F.relfs
          (fun te v =>
             let e := snd te in ⟨ ϵ, e ⟩ ⇓ v) efs vfs ->
        ⟨ ϵ, rec { efs } @ i ⟩ ⇓ REC { vfs }
    | ebs_hdr_lit (efs : F.fs tags_t (E.t tags_t * E.e tags_t))
                  (i : tags_t) (vfs : F.fs tags_t (V.v tags_t)) :
        F.relfs
          (fun te v =>
             let e := snd te in ⟨ ϵ, e ⟩ ⇓ v) efs vfs ->
        ⟨ ϵ, hdr { efs } @ i ⟩ ⇓ HDR { vfs }
    where "⟨ ϵ , e ⟩ ⇓ v" := (expr_big_step ϵ e v).

    Inductive fbody : Type :=
    | FBody (signature : E.arrowT tags_t) (body : ST.s tags_t).

    Definition fenv : Type := Env.t (name tags_t) fbody.

    Definition bare (x : string tags_t) : name tags_t :=
      Typed.BareName x.
    (**[]*)

    Instance P4NameEquivalence : Equivalence (equivn tags_t) :=
      NameEquivalence tags_t.
    (**[]*)

    Instance P4NameEqDec : EqDec (name tags_t) (equivn tags_t) :=
      NameEqDec tags_t.
    (**[]*)

    (** Create a new environment where
        values of [In] args are substituted
        into the function parameters. *)
    Definition copy_in
               (fs : F.fs tags_t
                          (P.paramarg (V.v tags_t) (name tags_t)))
               (ϵcall : epsilon) : epsilon :=
      F.fold (fun x arg ϵ =>
                let x' := bare x in
                match arg with
                | P.PAIn v    => !{ x' ↦ v ;; ϵ }!
                | P.PAInOut y => match ϵcall y with
                                | None   => ϵ
                                | Some v => !{ x' ↦ v ;; ϵ }!
                                end
                | P.PAOut _   => ϵ
                end) fs (Env.empty (name tags_t) (V.v tags_t)).
    (**[]*)

    (** Update current environment with
        out variables from function call evaluation. *)
    Definition copy_out
               (fs : F.fs tags_t
                          (P.paramarg (E.t tags_t * E.e tags_t)
                                      (E.t tags_t * name tags_t)))
               (ϵf : epsilon) : epsilon -> epsilon :=
      F.fold (fun _ arg ϵ =>
                match arg with
                | P.PAIn _ => ϵ
                | P.PAOut (_,x)
                | P.PAInOut (_,x) =>
                  match ϵf x with
                  | None   => ϵ
                  | Some v => !{ x ↦ v ;; ϵ }!
                  end
                end) fs.
    (**[]*)

    (** Evidence that control-flow
        is interrupted by an exit or return statement. *)
    Inductive interrupt : signal tags_t -> Prop :=
    | interrupt_exit : interrupt SIG_Exit
    | interrupt_rtrn (vo : option (V.v tags_t)) : interrupt (SIG_Rtrn vo).

    Inductive stmt_big_step (fs : fenv) (ϵ : epsilon) :
      ST.s tags_t -> epsilon -> signal tags_t -> Prop :=
    | sbs_skip (i : tags_t) :
        ⟪ fs, ϵ, skip @ i ⟫ ⤋ ⟪ ϵ, C ⟫
    | sbs_seq_cont (s1 s2 : ST.s tags_t) (i : tags_t)
                   (ϵ' ϵ'' : epsilon) (sig : signal tags_t) :
        ⟪ fs, ϵ,  s1 ⟫ ⤋ ⟪ ϵ',  C ⟫ ->
        ⟪ fs, ϵ', s2 ⟫ ⤋ ⟪ ϵ'', sig ⟫ ->
        ⟪ fs, ϵ,  s1 ; s2 @ i ⟫ ⤋ ⟪ ϵ'', sig ⟫
    | sbs_seq_interrupt (s1 s2 : ST.s tags_t) (i : tags_t)
                           (ϵ' : epsilon) (sig : signal tags_t) :
        interrupt sig ->
        ⟪ fs, ϵ, s1 ⟫ ⤋ ⟪ ϵ', sig ⟫ ->
        ⟪ fs, ϵ, s1 ; s2 @ i ⟫ ⤋ ⟪ ϵ', sig ⟫
    | sbs_assign (τ : E.t tags_t) (x : name tags_t)
                 (e : E.e tags_t) (v : V.v tags_t) (i : tags_t) :
        ⟨ ϵ, e ⟩ ⇓ v ->
        ⟪ fs, ϵ, asgn x := e :: τ @ i fin ⟫ ⤋ ⟪ x ↦ v ;; ϵ, C ⟫
    | sbs_exit (i : tags_t) :
        ⟪ fs, ϵ, exit @ i ⟫ ⤋ ⟪ ϵ, X ⟫
    | sbs_retvoid (i : tags_t) :
        ⟪ fs, ϵ, returns @ i ⟫ ⤋ ⟪ ϵ, Void ⟫
    | sbs_retfruit (τ : E.t tags_t) (e : E.e tags_t)
                   (i : tags_t) (v : V.v tags_t) :
        ⟨ ϵ, e ⟩ ⇓ v ->
        ⟪ fs, ϵ, return e :: τ @ i fin ⟫ ⤋ ⟪ ϵ, Fruit v ⟫
    | sbs_cond_true (guard : E.e tags_t)
                    (tru fls : ST.s tags_t) (i : tags_t)
                    (ϵ' : epsilon) (sig : signal tags_t) :
        ⟨ ϵ, guard ⟩ ⇓ TRUE ->
        ⟪ fs, ϵ, tru ⟫ ⤋ ⟪ ϵ', sig ⟫ ->
        ⟪ fs, ϵ, if guard :: Bool then tru else fls @ i fin ⟫
          ⤋ ⟪ ϵ', sig ⟫
    | sbs_cond_false (guard : E.e tags_t)
                     (tru fls : ST.s tags_t) (i : tags_t)
                     (ϵ' : epsilon) (sig : signal tags_t) :
        ⟨ ϵ, guard ⟩ ⇓ FALSE ->
        ⟪ fs, ϵ, fls ⟫ ⤋ ⟪ ϵ', sig ⟫ ->
        ⟪ fs, ϵ, if guard :: Bool then tru else fls @ i fin ⟫
          ⤋ ⟪ ϵ', sig ⟫
    | sbs_methodcall (params : F.fs tags_t
                                    (P.paramarg (E.t tags_t)
                                                (E.t tags_t)))
                     (args :
                        F.fs tags_t
                             (P.paramarg (E.t tags_t * E.e tags_t)
                                         (E.t tags_t * name tags_t)))
                     (argsv :
                        F.fs tags_t
                             (P.paramarg (V.v tags_t) (name tags_t)))
                     (f : name tags_t) (i : tags_t)
                     (body : ST.s tags_t) (ϵ' ϵ'' ϵ''' : epsilon) :
        (* Looking up function. *)
        fs f = Some (FBody (P.Arrow params None) body) ->
        (* Argument evaluation. *)
        F.relfs
          (P.rel_paramarg
             (fun te v => let e := snd te in ⟨ ϵ, e ⟩ ⇓ v)
             (fun tx y => equivn tags_t (snd tx) y)) args argsv ->
        (* Copy-in. *)
        copy_in argsv ϵ = ϵ' ->
        (* Function evaluation
           TODO: closures for epsilon and function environment. *)
        ⟪ fs, ϵ', body ⟫ ⤋ ⟪ ϵ'', Void ⟫ ->
        (* Copy-out *)
        copy_out args ϵ'' ϵ = ϵ''' ->
        ⟪ fs, ϵ, call f with args @ i fin ⟫ ⤋ ⟪ ϵ''', C ⟫
    | sbs_fruitcall (params : F.fs tags_t
                                    (P.paramarg (E.t tags_t)
                                                (E.t tags_t)))
                     (args :
                        F.fs tags_t
                             (P.paramarg (E.t tags_t * E.e tags_t)
                                         (E.t tags_t * name tags_t)))
                     (argsv :
                        F.fs tags_t
                             (P.paramarg (V.v tags_t) (name tags_t)))
                     (f x : name tags_t) (τ : E.t tags_t)
                     (i : tags_t) (v : V.v tags_t)
                     (body : ST.s tags_t) (ϵ' ϵ'' ϵ''' : epsilon) :
        (* Looking up function. *)
        fs f = Some (FBody (P.Arrow params (Some τ)) body) ->
        (* Argument evaluation. *)
        F.relfs
          (P.rel_paramarg
             (fun te v => let e := snd te in ⟨ ϵ, e ⟩ ⇓ v)
             (fun tx y => equivn tags_t (snd tx) y)) args argsv ->
        (* Copy-in. *)
        copy_in argsv ϵ = ϵ' ->
        (* Function evaluation
           TODO: closures for epsilon and function environment. *)
        ⟪ fs, ϵ', body ⟫ ⤋ ⟪ ϵ'', Fruit v ⟫ ->
        (* Copy-out *)
        copy_out args ϵ'' ϵ = ϵ''' ->
        ⟪ fs, ϵ, let x :: τ := call f with args @ i fin ⟫
          ⤋ ⟪ x ↦ v ;; ϵ''', C ⟫
    where "⟪ fs , ϵ , s ⟫ ⤋ ⟪ ϵ' , sig ⟫" := (stmt_big_step fs ϵ s ϵ' sig).
  End Step.
End Step.
