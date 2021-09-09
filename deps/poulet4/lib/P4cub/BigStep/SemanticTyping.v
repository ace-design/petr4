Set Warnings "-custom-entry-overridden".
Require Import Coq.micromega.Lia
        Poulet4.P4cub.Syntax.Syntax.
Require Import Poulet4.P4cub.Envn
        Poulet4.P4cub.BigStep.Value.Value
        Poulet4.P4cub.BigStep.Semantics
        Poulet4.P4cub.Static.Static
        Poulet4.P4cub.BigStep.TypeSoundness.

Module P := Poulet4.P4cub.Syntax.AST.P4cub.
Module E := P.Expr.
Module ST := P.Stmt.
Module PR := P.Parser.
Module V := Val.
Import Step P.P4cubNotations
       V.ValueNotations V.LValueNotations
       F.FieldTactics ProperType.

(** Semantic expression typing. *)
Reserved Notation "'⟦⟦' ers , gm '⟧⟧' ⊨ e ∈ t"
         (at level 40, e custom p4expr, t custom p4type,
          gm custom p4env, ers custom p4env).

(** An expression [e] evaluates in a "well-typed" way.
    Progress & preservation included all in one. *)
Definition semantic_expr_typing
           {tags_t : Type} (errs : errors) (Γ : gamma)
           (e: E.e tags_t) (t: E.t) : Prop :=
  forall ϵ : epsilon,
    envs_sound Γ ϵ errs ->
    (exists v : V.v, ⟨ ϵ, e ⟩ ⇓ v) /\
    (forall v : V.v, ⟨ ϵ, e ⟩ ⇓ v -> ∇ errs ⊢ v ∈ t).

Notation "'⟦⟦' ers , gm '⟧⟧' ⊨ e ∈ t"
  := (semantic_expr_typing ers gm e t).

Ltac unfold_sem_typ_expr_goal :=
  match goal with
  | |- ⟦⟦ _, _ ⟧⟧ ⊨ _ ∈ _
    => unfold semantic_expr_typing,
      envs_sound, envs_type, envs_subset;
      intros ϵ [Het Hes]; split;
      [| intros v Hv; inv Hv]
  end.

Ltac unfold_sem_typ_expr_hyp :=
  match goal with
  | H: ⟦⟦ _, _ ⟧⟧ ⊨ _ ∈ _ |- _
    => unfold semantic_expr_typing,
      envs_sound, envs_type, envs_subset in H
  end.

Ltac unfold_sem_typ_expr :=
  repeat unfold_sem_typ_expr_hyp;
  unfold_sem_typ_expr_goal.

(** Typing Derivations. *)
Section Rules.
  Context {tags_t : Type}.
  Variable Γ : gamma.
  Variable errs : errors.
  Variable i : tags_t.

  Local Hint Constructors expr_big_step : core.
  Local Hint Constructors type_value : core.
  
  Lemma sem_typ_bool : forall b,
      ⟦⟦ errs, Γ ⟧⟧ ⊨ BOOL b @ i ∈ Bool.
  Proof.
    intros b; unfold_sem_typ_expr; eauto.
  Qed.
  
  Lemma sem_typ_uop : forall (op : E.uop) (τ τ' : E.t) (e : E.e tags_t),
      uop_type op τ τ' ->
      ⟦⟦ errs, Γ ⟧⟧ ⊨ e ∈ τ ->
      ⟦⟦ errs, Γ ⟧⟧ ⊨ UOP op e:τ @ i ∈ τ'.
  Proof.
    intros op t t' e Huop He; unfold_sem_typ_expr.
    (* Tedious proof... *)
  Abort.

  Local Hint Resolve expr_big_step_preservation : core.
  Local Hint Resolve expr_big_step_progress : core.
  
  Lemma soundness : forall (e : E.e tags_t) τ,
      ⟦ errs, Γ ⟧ ⊢ e ∈ τ -> ⟦⟦ errs, Γ ⟧⟧ ⊨ e ∈ τ.
  Proof.
    intros e t Ht; intros ϵ H; split; eauto;
      destruct H as (? & ?); eauto.
  Qed.

  Local Hint Constructors check_expr : core.
  
  Lemma completeness : forall (e : E.e tags_t) τ,
      ⟦⟦ errs, Γ ⟧⟧ ⊨ e ∈ τ -> ⟦ errs, Γ ⟧ ⊢ e ∈ τ.
  Proof.
    intro e; induction e using custom_e_ind;
      intros t Hsem; unfold_sem_typ_expr_hyp.
    - specialize Hsem with (ϵ := !{∅}!); simpl in *.
      (* hmmmm... *)
  Abort.
End Rules.
