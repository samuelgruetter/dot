(** The DOT calculus -- Preservation. *)

Set Implicit Arguments.
Require Import List.
Require Export Dot_Labels.
Require Import Metatheory LibTactics_sf.
Require Export Dot_Syntax Dot_Definitions Dot_Rules Dot_Lemmas Dot_Transitivity.
Require Import Coq.Program.Equality.
Require Import Coq.Classes.Equivalence.
Require Import Coq.Classes.EquivDec.
Require Import Coq.Logic.Decidable.

Definition typing_store G s :=
  wf_store s
  /\ (forall a Tc argsRT, binds a (Tc, argsRT) s ->
       wfe_tp (G,s) Tc
    /\ exists args, argsRT = args ^args^ (ref a)
    /\ concrete Tc
    /\ lbl.uniq args
    /\ exists ds, (G, s) |= Tc ~< ds
    /\ (forall l v, lbl.binds l v args -> (value_label l \/ method_label l) /\ (exists d, decls_binds l d ds))
    /\ (exists L L', (forall x, x \notin L -> (forall l d, decls_binds l d ds ->
       (forall S U, d ^d^ x = decl_tp S U -> (ctx_bind (G,s) x Tc) |= S ~<: U) /\
       (forall S U, d ^d^ x = decl_mt S U -> (exists v, lbl.binds l v args /\ (forall y, y \notin L' -> (exists U', (ctx_bind (ctx_bind (G,s) x Tc) y S) |= ((v ^ x) ^ y) ~: U' /\ (ctx_bind (ctx_bind (G,s) x Tc) y S) |= U' ~=: U)))) /\
       (forall V, d ^d^ x = decl_tm V -> (exists v, lbl.binds l v args /\ syn_value(v ^ x) /\ (exists V', (ctx_bind (G,s) x Tc) |= (v ^ x) ~: V' /\ (ctx_bind (G,s) x Tc) |= V' ~=: V))))))).

Notation "G |== s" := (typing_store G s) (at level 68).

Definition ok_env G_s :=
  wf_env G_s /\ (forall x T, binds x T (fst G_s) -> wfe_tp G_s T).

Notation "G_s |= 'ok'" := (ok_env G_s) (at level 69).

Lemma env_weakening_notin_wfe_tp: forall L E S T x t,
  x `notin` L -> ctx_bind E x S |= t ^ x ~: T -> wfe_tp (ctx_bind E x S) T ->
  wfe_tp E T.
Proof. (* TODO *) Admitted.

Lemma ok_env_plus: forall E s x S,
  (E,s) |= ok -> E |== s -> 
  ((x, S) :: E, s) |= ok.
Proof. (* TODO *) Admitted.

Lemma typing_store_plus: forall E s x S,
  (E,s) |= ok -> E |== s ->
  ((x, S) :: E) |== s.
Proof. (* TODO *) Admitted.

Lemma wf_env_gamma_uniq : forall E G P,
  wf_env E -> E = (G,P) -> uniq G.
Proof.
  introv Hwf Heq. gen G.
  induction Hwf. introv Heq. inversion Heq. subst. auto.
  introv Heq. inversion Heq. subst. auto.
Qed.

Lemma wf_store_uniq : forall P,
  wf_store P -> uniq P.
Proof.
  introv Hwf.
  induction Hwf. auto. auto.
Qed.

Lemma wf_env_store_uniq : forall E G P,
  wf_env E -> E = (G,P) -> uniq P.
Proof.
  introv Hwf Heq. gen P.
  inversion Hwf; introv Heq; inversion Heq; subst; apply wf_store_uniq; assumption.
Qed.

Scheme tp_mem_typing_indm := Induction for typing Sort Prop
  with tp_mem_mem_indm    := Induction for mem Sort Prop
.

Combined Scheme tp_mem_mutind from tp_mem_typing_indm, tp_mem_mem_indm.

Ltac mutind_tp_mem Ptyp Pmem :=
  cut ((forall E t T (H: E |= t ~: T), (Ptyp E t T H)) /\
    (forall E t l d (H: E |= t ~mem~ l ~: d), (Pmem E t l d H))); [try tauto; Case "IH" |
      apply (tp_mem_mutind Ptyp Pmem); try unfold Ptyp, Pmem in *; try clear Ptyp Pmem; [Case "typing_var" | Case "typing_ref" | Case "typing_wid" | Case "typing_sel" | Case "typing_msel" | Case "typing_new" | Case "mem_path" | Case "mem_term"]; introv; eauto ].

Lemma tp_unique : forall E t T T',
  E |= t ~: T -> E |= t ~: T' -> T = T'.
Proof.
  mutind_tp_mem (fun E t T (H: E |= t ~: T) => forall T', E |= t ~: T' -> T = T')
                (fun E t l d (H: E |= t ~mem~ l ~: d) => forall d', E |= t ~mem~ l ~: d' -> d = d').
  Case "IH".
    introv H. inversion H as [H1 H2]. introv HT HT'.
    eauto.
  Case "typing_var".
    introv Hwf Hlc Hbinds. introv HT'. inversion HT'. subst.
    assert (uniq G). apply wf_env_gamma_uniq with (E:=(G,P)) (P:=P). assumption. reflexivity.
    apply binds_unique with (x:=x) (E:=G); assumption.
  Case "typing_ref".
    introv Hwf Hbinds. introv HT'. inversion HT'. subst.
    assert (uniq P). apply wf_env_store_uniq with (E:=(G,P)) (G:=G). assumption. reflexivity.
    assert ((T, args) = (T', args0)) as Heq. apply binds_unique with (x:=a) (E:=P); assumption.
    inversion Heq. subst. reflexivity.
  Case "typing_wid".
    introv HT' IH Hsub Hwid. inversion Hwid. reflexivity.
  Case "typing_sel".
    introv Hlv Hmem IHmem Hwfe. intros T''. introv Hsel. inversion Hsel. subst.
    assert (decl_tm T' = decl_tm T'') as Heq. apply IHmem. assumption.
    inversion Heq. subst. reflexivity.
  Case "typing_msel".
    introv Hlm Hmem IHmem Ht'T' IHtyp Hsame Hwfe. intros T''. introv Hmsel. inversion Hmsel. subst.
    assert (decl_mt S T = decl_mt S0 T'') as Heq. apply IHmem. assumption.
    inversion Heq. subst. reflexivity.
  Case "typing_new".
    intros. inversion H0. subst.
    pick fresh x for (union L L0). eauto.
  Case "mem_path".
    (* rely on uniqueness of expansion *) skip.
  Case "mem_term".
    (* rely on uniqueness of expansion *) skip.
Qed.

Lemma tp_regular : forall E s t T,
  (E,s) |= ok -> E |== s ->
  (E,s) |= t ~: T ->
  wfe_tp (E,s) T.
Proof.
  introv Hok Hes H. dependent induction H.
  Case "var".
    inversion Hok as [Hwf_env Hbinds].
    apply (Hbinds x T). simpl. assumption.
  Case "ref".
    inversion Hes as [Hwf_store Hcond].
    apply (proj1 (Hcond a T args H0)).
  Case "wid".
    auto.
  Case "sel".
    assumption.
  Case "msel".
    assumption.
  Case "new".
    pick fresh x.
    assert (wfe_tp (ctx_bind (E,s) x Tc) T') as Hwfe_tp.
      apply H6 with (x:=x). apply notin_union_1 in Fr. assumption.
      simpl. apply ok_env_plus; assumption.
      simpl. apply typing_store_plus; assumption.
      simpl. reflexivity.
    apply env_weakening_notin_wfe_tp with (L:=L) (S:=Tc) (x:=x) (t:=t).
    apply notin_union_1 in Fr. assumption. 
    apply H5. apply notin_union_1 in Fr. assumption.
    assumption.
Qed.

Lemma preserved_env_nil_ok : forall s t s' t',
  (nil,s) |= ok ->
  s |~ t ~~> t' ~| s' ->
  (nil,s') |= ok.
Proof.
  introv Hok Hr. induction Hr; try solve [assumption | apply IHHr; assumption].
  Case "red_new".
  inversion H0. subst. inversion Hok as [Henv Hbinds].
  split.
  apply wf_env_nil. apply wf_store_cons_tp; assumption.
  introv Hbinds_nil. inversion Hbinds_nil.
Qed.

Lemma preserved_env_nil_typing : forall s t s' t' T,
  nil |== s ->
  s |~ t ~~> t' ~| s' ->
  (nil,s) |= t ~: T ->
  nil |== s'.
Proof.
  introv Hc Hr. gen T. dependent induction Hr; introv Ht.
  Case "red_msel".
    assumption.
  Case "red_msel_tgt1".
    inversion Ht. inversion H3; subst; apply IHHr with (T:=T1); assumption.
  Case "red_msel_tgt2".
    inversion Ht. apply IHHr with (T:=T'); assumption.
  Case "red_sel".
    assumption.
  Case "red_sel_tgt".
    inversion Ht. inversion H3; subst; apply IHHr with (T:=T0); assumption.
  Case "red_wid_tgt".
    inversion Ht. subst. apply IHHr with (T:=T'); assumption.
  Case "red_new".
    (* TODO *) skip.
Qed.

Lemma preserved_env_ok : forall G s t s' t',
  (G,s) |= ok ->
  s |~ t ~~> t' ~| s' ->
  (G,s') |= ok.
Proof. (* TODO *) Admitted.

Lemma preserved_env_typing : forall G s t s' t' T,
  G |== s ->
  s |~ t ~~> t' ~| s' ->
  (G,s) |= t ~: T ->
  G |== s'.
Proof. (* TODO *) Admitted.

Lemma preserved_wfe : forall G s t  s' t' T,
  (G,s) |= ok ->
  G |== s ->
  s |~ t ~~> t' ~| s' ->
  wfe_tp (G,s) T ->
  wfe_tp (G,s') T.
Proof. (* TODO *) Admitted.

Lemma preserved_subtype : forall G s t s' t' S T,
  (G,s) |= ok ->
  G |== s ->
  s |~ t ~~> t' ~| s' ->
  (G,s) |= S ~<: T ->
  (G,s') |= S ~<: T.
Proof. (* TODO *) Admitted.

Lemma preserved_tp : forall G s t s' t' tt T,
  (G,s) |= ok ->
  G |== s ->
  s |~ t ~~> t' ~| s' ->
  (G,s) |= tt ~: T ->
  (G,s') |= tt ~: T.
Proof. (* TODO *) Admitted.

Lemma preserved_mem : forall G s t s' t' e l d,
  (G,s) |= ok ->
  G |== s ->
  s |~ t ~~> t' ~| s' ->
  (G,s) |= e ~mem~ l ~: d ->
  (G,s') |= e ~mem~ l ~: d.
Proof. (* TODO *) Admitted.

Lemma preserved_same_tp : forall G s t s' t' T T',
  (G,s) |= ok ->
  G |== s ->
  s |~ t ~~> t' ~| s' ->
  (G,s) |= T' ~=: T ->
  (G,s') |= T' ~=: T.
Proof.
  introv Hok Hc Hr Hs. inversion Hs. subst.
  apply same_tp_any; apply preserved_subtype with (s:=s) (t:=t) (t':=t'); assumption.
Qed.

Lemma membership_value_same_tp : forall E t1 T1 t1' T1' l T,
  E |= t1 ~: T1 ->
  E |= t1' ~: T1' ->
  E |= T1' ~=: T1 ->
  E |= t1 ~mem~ l ~: decl_tm T ->
  exists T', E |= t1' ~mem~ l ~: decl_tm T' /\ E |= T' ~=: T.
Proof. (* TODO *) Admitted.

Lemma membership_method_same_tp : forall E t1 T1 t1' T1' l S T,
  E |= t1 ~: T1 ->
  E |= t1' ~: T1' ->
  E |= T1' ~=: T1 ->
  E |= t1 ~mem~ l ~: decl_mt S T ->
  exists S' T', E |= t1' ~mem~ l ~: decl_mt S' T' /\ E |= S ~=: S' /\ E |= T' ~=: T.
Proof. (* TODO *) Admitted.

Lemma same_tp_transitive : forall TMid E T T',
  E |= T ~=: TMid -> E |= TMid ~=: T' -> E |= T ~=: T'.
Proof.
  introv HT HT'. inversion HT. inversion HT'. subst.
  apply same_tp_any; apply sub_tp_transitive with (TMid:=TMid); assumption.
Qed.

Lemma same_tp_reflexive : forall E T T',
  E |= T ~=: T' -> E |= T' ~=: T.
Proof.
  introv H. inversion H. subst. apply same_tp_any; assumption.
Qed.

Definition preservation := forall G s t T s' t',
  (G,s) |= ok ->
  G |== s ->
  (G,s) |= t ~: T ->
  s |~ t ~~> t' ~| s' ->
  exists T',
  (G,s') |= t' ~: T' /\
  (G,s') |= T' ~=: T.

Theorem preservation_holds : preservation.
Proof. unfold preservation.
  introv Hok Hc Ht Hr. gen T. induction Hr.
  Case "red_msel".  (* TODO *) skip.
  Case "red_msel_tgt1".
    introv Ht. inversion Ht. subst.
    inversion H3. subst.
    specialize (IHHr Hok Hc T0 H1). inversion IHHr as [Th' IHHr']. inversion IHHr' as [Hc' Hs'].
    assert (exists S' T', (G,s') |= e1' ~mem~ l ~: decl_mt S' T' /\ (G,s') |= S ~=: S' /\ (G,s') |= T' ~=: T) as Hmem'.
      apply membership_method_same_tp with (t1:=e1) (T1:=T0) (T1':=Th'); try assumption.
      apply preserved_tp with (s:=s) (t:=e1) (t':=e1'); assumption.
      apply preserved_mem with (s:=s) (t:=e1) (t':=e1'); assumption.
    inversion Hmem' as [S'' Hmem'']. inversion Hmem'' as [T'' Hmem''']. inversion Hmem''' as [Hmem_ Hsame_]. inversion Hsame_ as [HsameS HsameT].
    exists T''. split.
    apply typing_msel with (S:=S'') (T':=T'); try assumption.
      apply preserved_tp with (s:=s) (t:=e1) (t':=e1'); assumption.
      apply same_tp_transitive with (TMid:=S); try assumption.
      apply preserved_same_tp with (s:=s) (t:=e1) (t':=e1'); assumption.
      inversion HsameT. subst. auto. assumption.
    subst.
    specialize (IHHr Hok Hc T0 H). inversion IHHr as [Th' IHHr']. inversion IHHr' as [Hc' Hs'].
    assert (exists S' T', (G,s') |= e1' ~mem~ l ~: decl_mt S' T' /\ (G,s') |= S ~=: S' /\ (G,s') |= T' ~=: T) as Hmem'.
      apply membership_method_same_tp with (t1:=e1) (T1:=T0) (T1':=Th'); try assumption.
      apply preserved_tp with (s:=s) (t:=e1) (t':=e1'); assumption.
      apply preserved_mem with (s:=s) (t:=e1) (t':=e1'); assumption.
    inversion Hmem' as [S'' Hmem'']. inversion Hmem'' as [T'' Hmem''']. inversion Hmem''' as [Hmem_ Hsame_]. inversion Hsame_ as [HsameS HsameT].
    exists T''. split.
    apply typing_msel with (S:=S'') (T':=T'); try assumption.
      apply preserved_tp with (s:=s) (t:=e1) (t':=e1'); assumption.
      apply same_tp_transitive with (TMid:=S); try assumption.
      apply preserved_same_tp with (s:=s) (t:=e1) (t':=e1'); assumption.
      inversion HsameT. subst. auto. assumption.
  Case "red_msel_tgt2".
    introv Ht. inversion Ht. subst.
    assert ((G, s') |= ok) as Hok'. apply preserved_env_ok with (s:=s) (t:=e2) (t':=e2'); assumption.
    inversion Hok' as [Henv' Hbinds'].
    specialize (IHHr Hok Hc T' H6). inversion IHHr as [Th' IHHr']. inversion IHHr' as [Hc' Hs'].
    exists T. split.
      apply typing_msel with (S:=S) (T':=Th'); try assumption.
      apply preserved_mem with (s:=s) (t:=e2) (t':=e2'); assumption.
      apply same_tp_transitive with (TMid:=T'); try assumption.
      apply preserved_same_tp with (s:=s) (t:=e2) (t':=e2'); assumption.
      apply preserved_wfe with (s:=s) (t:=e2) (t':=e2'); assumption.
      apply same_tp_any; apply sub_tp_refl; try assumption; apply preserved_wfe with (s:=s) (t:=e2) (t':=e2'); assumption.
  Case "red_sel". (* TODO *) skip.
  Case "red_sel_tgt".
    introv Ht. inversion Ht. subst.
    inversion H3. subst.
    specialize (IHHr Hok Hc T0 H2). inversion IHHr as [Th' IHHr']. inversion IHHr' as [Hc' Hs'].
    assert (exists T', (G,s') |= e' ~mem~ l ~: decl_tm T' /\ (G,s') |= T' ~=: T) as Hmem'.
      apply membership_value_same_tp with (t1:=e) (T1:=T0) (T1':=Th'); try assumption.
      apply preserved_tp with (s:=s) (t:=e) (t':=e'); assumption.
      apply preserved_mem with (s:=s) (t:=e) (t':=e'); assumption.
    inversion Hmem' as [T' Hmem'']. inversion Hmem'' as [Hmem''' HT'eqT].
    exists T'. split.
    apply typing_sel; try assumption.
      inversion HT'eqT. subst. auto.
    assumption.
    subst.
    specialize (IHHr Hok Hc T0 H). inversion IHHr as [Th' IHHr']. inversion IHHr' as [Hc' Hs'].
    assert (exists T', (G,s') |= e' ~mem~ l ~: decl_tm T' /\ (G,s') |= T' ~=: T) as Hmem'.
      apply membership_value_same_tp with (t1:=e) (T1:=T0) (T1':=Th'); try assumption.
      apply preserved_tp with (s:=s) (t:=e) (t':=e'); assumption.
      apply preserved_mem with (s:=s) (t:=e) (t':=e'); assumption.
    inversion Hmem' as [T' Hmem'']. inversion Hmem'' as [Hmem''' HT'eqT].
    exists T'. split.
    apply typing_sel; try assumption.
      inversion HT'eqT. subst. auto.
    assumption.
  Case "red_wid_tgt".
    introv Ht. inversion Ht. subst.
    assert ((G, s') |= ok) as Hok'. apply preserved_env_ok with (s:=s) (t:=e) (t':=e'); assumption.
    inversion Hok' as [Henv' Hbinds'].
    specialize (IHHr Hok Hc T' H2). inversion IHHr as [Th' IHHr']. inversion IHHr' as [Hc' Hs']. inversion Hs' as [Hs1 Hs2]. subst.
    exists T. splits.
    apply typing_wid with (T':=Th'). assumption.
    apply sub_tp_transitive with (TMid:=T').
    assumption. apply preserved_subtype with (s:=s) (t:=e) (t':=e'); assumption.
    apply same_tp_any.
      apply sub_tp_refl. assumption. apply preserved_wfe with (s:=s) (t:=e) (t':=e'); auto.
      apply sub_tp_refl. assumption. apply preserved_wfe with (s:=s) (t:=e) (t':=e'); auto.
  Case "red_new". (* TODO *) skip.
Qed.