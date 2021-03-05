Require Import Coq.micromega.Lia.
Require Import P4cub.Value.
Require Import P4cub.BigStep.
Module P := P4cub.AST.P4cub.
Module E := P.Expr.
Module S := P.Stmt.
Module V := Val.

Import Typecheck.
Import Step.
Import P.P4cubNotations.
Import V.ValueNotations.
Import V.ValueTyping.
Import F.FieldTactics.

Section BigStepTheorems.
  Context {tags_t : Type}.

  (** Epsilon's values type's agree with Gamma. *)
  Definition envs_type (errs : errors) (Γ : gamma) (ϵ : epsilon) : Prop :=
    forall (x : name tags_t) (τ : E.t tags_t) (v : V.v tags_t),
      Γ x = Some τ -> ϵ x = Some v -> ∇ errs ⊢ v ∈ τ.
  (**[]*)

  Theorem big_step_preservation :
    forall (errs : errors) (Γ : gamma) (e : E.e tags_t)
      (τ : E.t tags_t) (ϵ : epsilon) (v : V.v tags_t),
      envs_type errs Γ ϵ ->
      ⟨ ϵ, e ⟩ ⇓ v ->
      ⟦ errs, Γ ⟧ ⊢ e ∈ τ ->
      ∇ errs ⊢ v ∈ τ.
  Proof.
    intros errs Γ e τ ϵ v Het Hev.
    generalize dependent τ.
    unfold envs_type in Het.
    induction Hev using custom_expr_big_step_ind;
      intros t Ht; inv Ht; try constructor; eauto.
    - inv H2; auto.
    - unfold BitArith.neg;  unfold BitArith.bound;
        unfold BitArith.maxN; unfold BitArith.upper_bound. admit.
    - unfold IntArith.bound; unfold IntArith.neg;
      unfold IntArith.return_bound; unfold IntArith.maxZ;
        unfold IntArith.minZ. admit.
    - apply IHHev1 in H10; auto; clear IHHev1.
      apply IHHev2 in H11; auto; clear IHHev2.
      destruct op; unfold eval_bit_binop in *;
        inv H; inv H9; constructor; admit.
    - destruct op; unfold eval_bool_binop in *;
        inv H; inv H9; constructor.
    - unfold eval_bit_binop in *; inv H; constructor.
    - unfold eval_bit_binop in *; inv H; constructor.
    - unfold eval_bit_binop in *; inv H; constructor.
    - inv H10.
    - inv H10.
    - inv H8; constructor. admit.
    - apply IHHev1 in H10; auto; clear IHHev1.
      apply IHHev2 in H11; auto; clear IHHev2.
      destruct op; unfold eval_bit_binop in *;
        inv H; inv H9; constructor; admit.
    - destruct op; unfold eval_bool_binop in *;
        inv H; inv H9; constructor.
    - inv H; constructor.
    - inv H; constructor.
    - inv H9.
    - inv H9.
    - pose proof IHHev Het _ H6 as IH; clear IHHev.
      inv IH. Search (In _ ?l -> Forall2 _ ?l _ -> _).
      (** TODO: Need lemma:
          [forall R x1 l1 l2, In x1 l1 -> Forall2 R l1 l2 -> exists x2, In x2 l2 /\ R x1 x2],
          and some Field-specific lemma:
          [forall x a1 a2 l1 l2 R, F.get x l1 = Some a1 -> F.get x l2 = a2 ->]
          [F.relfs R l1 l2 -> R a1 a2] *) admit.
    - admit.
    - generalize dependent tfs; rename H0 into Hesvs.
      induction H; inv Hesvs;
        intros ts Hests; inv Hests; constructor.
      destruct x as [x [τ e]]; destruct y as [y v];
        destruct y0 as [z t]; repeat invert_relf; simpl in *.
      + split; simpl;
          try (transitivity x; auto; symmetry; assumption);
          destruct H2; auto.
      + apply IHForall2; auto.
    - clear e H6 IHHev Hev.
      generalize dependent tfs; rename H0 into Hesvs.
      induction H; inv Hesvs;
        intros ts Hests; inv Hests; constructor.
      destruct x as [x [τ e]]; destruct y as [y v];
        destruct y0 as [z t]; repeat invert_relf; simpl in *.
      + split; simpl;
          try (transitivity x; auto; symmetry; assumption);
          destruct H2; auto.
      + apply IHForall2; auto.
    - destruct op; simpl in *; constructor;
        pose proof IHHev Het _ H5 as IH; clear IHHev; inv IH; auto.
    - admit.
    - clear n ni H5 H7 H8.
      rename H0 into Hhsvss; rename H9 into Hhs.
      induction H; inv Hhsvss; inv Hhs; constructor;
        destruct y as [b vs]; eauto.
    - (* TODO: about a specific header in the header stack. *) admit.
  Abort.
End BigStepTheorems.
