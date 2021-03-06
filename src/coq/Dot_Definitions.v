(** The DOT calculus -- Definitions *)

Require Export Dot_Labels.
Require Import Metatheory.
Require Export Dot_Syntax.

(* ********************************************************************** *)
(** * #<a name="decls"></a># Declarations *)

Inductive decls : Set :=
  | decls_fin : decls_lst -> decls
  | decls_inf : decls_lst -> decls
.

Inductive decls_binds (l: label) (d: decl) (ds: decls) : Prop :=
  | decls_binds_fin : forall dsl, decls_fin dsl = ds \/ decls_inf dsl = ds ->
    lbl.binds l d dsl -> decls_binds l d ds
  | decls_binds_inf : forall dsl, decls_inf dsl = ds ->
    ~(lbl.binds l d dsl) ->
    (type_label l /\ decl_tp tp_top tp_bot = d) \/ (value_label l /\ decl_tm tp_bot = d) \/ (method_label l /\ decl_mt tp_top tp_bot = d) ->
    decls_binds l d ds
.

Definition decls_dom_subset (ds1: decls) (ds2: decls) : Prop :=
  match ds1, ds2 with
    | decls_fin dsl1, decls_fin dsl2 => lbl.dom dsl1 [<l=] lbl.dom dsl2
    | decls_inf _, decls_fin _ => False
    | _, _ => True
  end.

Definition decls_uniq (ds: decls) : Prop :=
  forall dsl, decls_fin dsl = ds \/ decls_inf dsl = ds -> lbl.uniq dsl.

Definition decls_map (f: decl -> decl) (ds: decls) :=
  match ds with
    | decls_fin dsl => decls_fin (lbl.map f dsl)
    | decls_inf dsl => decls_inf (lbl.map f dsl)
  end.

Definition decls_lift {B: Type} (f: decls_lst -> B) (ds: decls) :=
  match ds with
    | decls_fin dsl => f dsl
    | decls_inf dsl => f dsl
  end.

Definition forall_decls (E: env) (DS1: decls) (DS2: decls) (P: env -> decl -> decl -> Prop) :=
  forall l d1 d2, decls_binds l d2 DS2 -> decls_binds l d1 DS1 -> P E d1 d2.

Inductive valid_label : label -> decl -> Prop :=
  | valid_label_type : forall L S U, type_label L -> valid_label L (decl_tp S U)
  | valid_label_value : forall l T, value_label l -> valid_label l (decl_tm T)
  | valid_label_method : forall m S U, method_label m -> valid_label m (decl_mt S U)
.

Definition decls_ok (ds: decls) := decls_uniq ds /\ (forall l d, decls_binds l d ds -> valid_label l d).

Inductive and_decl : decl -> decl -> decl -> Prop :=
  | and_decl_tm : forall T1 T2,
      and_decl (decl_tm T1) (decl_tm T2) (decl_tm (tp_and T1 T2))
  | and_decl_tp : forall S1 U1 S2 U2,
      and_decl (decl_tp S1 U1) (decl_tp S2 U2) (decl_tp (tp_or S1 S2) (tp_and U1 U2))
  | and_decl_mt : forall S1 U1 S2 U2,
      and_decl (decl_mt S1 U1) (decl_mt S2 U2) (decl_mt (tp_or S1 S2) (tp_and U1 U2))
.

Inductive or_decl : decl -> decl -> decl -> Prop :=
  | or_decl_tm : forall T1 T2,
      or_decl (decl_tm T1) (decl_tm T2) (decl_tm (tp_or T1 T2))
  | or_decl_tp : forall S1 U1 S2 U2,
      or_decl (decl_tp S1 U1) (decl_tp S2 U2) (decl_tp (tp_and S1 S2) (tp_or U1 U2))
  | or_decl_mt : forall S1 U1 S2 U2,
      or_decl (decl_mt S1 U1) (decl_mt S2 U2) (decl_mt (tp_and S1 S2) (tp_or U1 U2))
.

Inductive bot_decl : decl -> Prop :=
  | bot_decl_tm : bot_decl (decl_tm tp_bot)
  | bot_decl_tp : bot_decl (decl_tp tp_top tp_bot)
  | bot_decl_mt : bot_decl (decl_mt tp_top tp_bot)
.

Definition and_decls (ds1: decls) (ds2: decls) (dsm: decls) :=
  decls_ok dsm /\ decls_ok ds1 /\ decls_ok ds2 /\ (forall l d,
    decls_binds l d dsm <-> (
      (exists d1, exists d2, decls_binds l d1 ds1 /\ decls_binds l d2 ds2 /\ and_decl d1 d2 d)
      \/ decls_binds l d ds1 \/ decls_binds l d ds2)).

Definition or_decls (ds1: decls) (ds2: decls) (dsm: decls) :=
  decls_ok dsm /\ decls_ok ds1 /\ decls_ok ds2 /\ (forall l d,
    decls_binds l d dsm <-> (
      exists d1, exists d2, decls_binds l d1 ds1 /\ decls_binds l d2 ds2 /\ or_decl d1 d2 d)).

Definition bot_decls (dsm: decls) :=
  decls_ok dsm /\ forall l d, decls_binds l d dsm <-> (bot_decl d /\ valid_label l d).

(* ********************************************************************** *)
(** * #<a name="open"></a># Opening terms *)

Require Import Classes.EquivDec.

Fixpoint open_rec_pt (k : nat) (u : pt) (e : pt) {struct e} : pt :=
  match e with
    | bvar i => if k == i then u else (bvar i)
    | fvar x => fvar x
    | ref x => ref x
    | sel e1 l => sel (open_rec_pt k u e1) l
  end
.

Fixpoint open_rec_tp (k : nat) (u : pt) (t : tp) {struct t} : tp :=
  match t with
    | tp_sel e1 l => tp_sel (open_rec_pt k u e1) l
    | tp_rfn parent decls => tp_rfn (open_rec_tp k u parent) (lbl.map (open_rec_decl (k+1) u) decls)
    | tp_and t1 t2 => tp_and (open_rec_tp k u t1) (open_rec_tp k u t2)
    | tp_or t1 t2 => tp_or (open_rec_tp k u t1) (open_rec_tp k u t2)
    | tp_top => tp_top
    | tp_bot => tp_bot
  end
with open_rec_decl (k : nat) (u : pt) (d : decl) {struct d} : decl :=
  match d with
    | decl_tp tl tu => decl_tp (open_rec_tp k u tl) (open_rec_tp k u tu)
    | decl_tm t => decl_tm (open_rec_tp k u t)
    | decl_mt t1 t2 => decl_mt (open_rec_tp k u t1) (open_rec_tp k u t2)
  end.

Fixpoint open_rec_tm (k : nat) (u : pt) (e : tm) {struct e} : tm :=
  match e with
    | path p => path (open_rec_pt k u p)
    | new T args b => new (open_rec_tp k u T) (List.map (fun a => match a with (l, a) => (l, open_rec_tm (k+(match l with | lm _ => 2 | _ => 1 end)) u a) end) args) (open_rec_tm (k+1) u b)
    | msg p1 m p2 b => msg (open_rec_pt k u p1) m (open_rec_pt k u p2) (open_rec_tm (k+1) u b)
    | exe o m bm b => exe o m (open_rec_tm k u bm) (open_rec_tm (k+1) u b)
  end.

Notation "{ k ~pt> u } t" := (open_rec_pt k u t) (at level 67).
Notation "{ k ~> u } t" := (open_rec_tm k u t) (at level 67).
Notation "{ k ~tp> u } t" := (open_rec_tp k u t) (at level 67).
Notation "{ k ~d> u } d" := (open_rec_decl k u d) (at level 67).
Definition open_rec_decls k u (ds: decls) := decls_map (open_rec_decl k u) ds.
Notation "{ k ~ds> u } ds" := (open_rec_decls k u ds) (at level 67).
Definition open_rec_decls_lst k u (dsl: decls_lst) := lbl.map (open_rec_decl k u) dsl.
Notation "{ k ~dsl> u } dsl" := (open_rec_decls_lst k u dsl) (at level 67).

Definition open_pt e u := open_rec_pt 0 u e.
Definition open e u := open_rec_tm 0 u e.
Definition open_tp e u := open_rec_tp 0 u e.
Definition open_decl d u := open_rec_decl 0 u d.
Definition open_decls ds u := open_rec_decls 0 u ds.
Definition open_decls_lst dsl u := open_rec_decls_lst 0 u dsl.
Definition open_args (ags: args) u := lbl.map (open_rec_tm 0 u) ags.

Notation "ags ^args^ u" := (open_args ags u) (at level 67).
Notation "d ^d^ u" := (open_decl d u) (at level 67).
Notation "ds ^ds^ u" := (open_decls ds u) (at level 67).
Notation "dsl ^dsl^ u" := (open_decls_lst dsl u) (at level 67).
Notation "t ^^ u" := (open t u) (at level 67).
Notation "t ^tp^ u" := (open_tp t u) (at level 67).
Notation "t ^ x" := (open t (fvar x)).

(* ********************************************************************** *)
(** * #<a name="lc"></a># Local closure *)

Inductive  lc_tp : tp -> Prop :=
  | lc_tp_sel : forall tgt l,
      lc_pt tgt ->
      lc_tp (tp_sel tgt l)
  | lc_tp_rfn : forall L parent ds,
      lc_tp parent ->
      (forall x: atom, x \notin L -> lc_decls_lst (ds ^dsl^ x)) ->
      lc_tp (tp_rfn parent ds)
  | lc_tp_and : forall t1 t2,
      lc_tp t1 ->
      lc_tp t2 ->
      lc_tp (tp_and t1 t2)
  | lc_tp_or : forall t1 t2,
      lc_tp t1 ->
      lc_tp t2 ->
      lc_tp (tp_or t1 t2)
  | lc_tp_top : lc_tp (tp_top)
  | lc_tp_bot : lc_tp (tp_bot)

with lc_decl : decl -> Prop :=
  | lc_decl_tp : forall t1 t2,
      lc_tp t1 ->
      lc_tp t2 ->
      lc_decl (decl_tp t1 t2)
  | lc_decl_tm : forall t1,
      lc_tp t1 ->
      lc_decl (decl_tm t1)
  | lc_decl_mt : forall t1 t2,
      lc_tp t1 ->
      lc_tp t2 ->
      lc_decl (decl_mt t1 t2)

with lc_pt : pt -> Prop :=
  | lc_var : forall x,
      lc_pt (fvar x)
  | lc_ref : forall x,
      lc_pt (ref x)
  | lc_sel : forall tgt l,
      lc_pt tgt ->
      lc_pt (sel tgt l)

with lc_tm : tm -> Prop :=
  | lc_path : forall p,
      lc_pt p ->
      lc_tm (path p)
  | lc_new : forall L t cas b,
      lc_tp t ->
      (forall x:var, x \notin L -> lc_args (cas ^args^ x) /\ lc_tm (b ^^ x)) ->
      lc_tm (new t cas b)
  | lc_msg : forall L a m b t,
      lc_pt a ->
      lc_pt b ->
      (forall x:var, x \notin L -> lc_tm (t ^^ x)) ->
      lc_tm (msg a m b t)
  | lc_exe : forall L o m b t,
      lc_tm b ->
      (forall x:var, x \notin L -> lc_tm (t ^^ x)) ->
      lc_tm (exe o m b t)

with lc_decls_lst : decls_lst -> Prop :=
  | lc_decl_nil :
      lc_decls_lst (nil)
  | lc_decl_cons : forall l d ds,
      lc_decl d -> lc_decls_lst ds -> lc_decls_lst ((l, d) :: ds)

with lc_args : args -> Prop :=
  | lc_args_nil :
      lc_args (nil)
  | lc_args_cons_value : forall l t cs,
      lc_tm t -> lc_args cs -> value_label l -> lc_args ((l, t) :: cs)
  | lc_args_cons_method : forall L l t cs,
      (forall x:var, x \notin L -> lc_tm (t ^^ x)) -> lc_args cs -> method_label l ->
      lc_args ((l, t) :: cs)
.

Inductive value : pt -> Prop :=
  | value_ref : forall v,
    value (ref v)
.

Inductive value_tm : tm -> Prop :=
  | value_tm_path : forall p,
    value p ->
    value_tm (path p)
.

(* ********************************************************************** *)
(** * #<a name="env"></a># Environments *)

(* Locally closed, and free variables are bound in the environment/store. *)
Inductive  vars_ok_tp : env -> tp -> Prop :=
  | vars_ok_tp_sel : forall E tgt l,
      vars_ok_pt E tgt ->
      vars_ok_tp E (tp_sel tgt l)
  | vars_ok_tp_rfn : forall E L t ds,
      vars_ok_tp E t ->
      (forall x: atom, x \notin L -> vars_ok_decls_lst (ctx_bind E x t) (ds ^dsl^ x)) ->
      vars_ok_tp E (tp_rfn t ds)
  | vars_ok_tp_and : forall E t1 t2,
      vars_ok_tp E t1 ->
      vars_ok_tp E t2 ->
      vars_ok_tp E (tp_and t1 t2)
  | vars_ok_tp_or : forall E t1 t2,
      vars_ok_tp E t1 ->
      vars_ok_tp E t2 ->
      vars_ok_tp E (tp_or t1 t2)
  | vars_ok_tp_top : forall E, vars_ok_tp E (tp_top)
  | vars_ok_tp_bot : forall E, vars_ok_tp E (tp_bot)

with vars_ok_decl : env -> decl -> Prop :=
  | vars_ok_decl_tp : forall E t1 t2,
      vars_ok_tp E t1 ->
      vars_ok_tp E t2 ->
      vars_ok_decl E (decl_tp t1 t2)
  | vars_ok_decl_tm : forall E t1,
      vars_ok_tp E t1 ->
      vars_ok_decl E (decl_tm t1)

with vars_ok_pt : env -> pt -> Prop :=
  | vars_ok_var : forall G P x t,
      binds x t G ->
      vars_ok_pt (G, P) (fvar x)
  | vars_ok_ref : forall G P a obj,
      binds a obj P ->
      vars_ok_pt (G, P) (ref a)
  | vars_ok_sel : forall E tgt l,
      vars_ok_pt E tgt ->
      vars_ok_pt E (sel tgt l)

with vars_ok_tm : env -> tm -> Prop :=
  | vars_ok_path : forall E p,
      vars_ok_pt E p ->
      vars_ok_tm E (path p)
  | vars_ok_new : forall E L t cas b,
      vars_ok_tp E t ->
      (forall x: var, x \notin L -> vars_ok_args (ctx_bind E x t) (cas ^args^ x)) ->
      (forall x: var, x \notin L -> vars_ok_tm (ctx_bind E x t) (b ^^ x)) ->
      vars_ok_tm E (new t cas b)
  | vars_ok_msg : forall E L a m b t tp,
      vars_ok_tp E tp ->
      vars_ok_pt E a ->
      vars_ok_pt E b ->
      (forall x: var, x \notin L -> vars_ok_tm (ctx_bind E x tp) (t ^^ x)) ->
      vars_ok_tm E (msg a m b t)
  | vars_ok_exe : forall E L a m b t tp,
      vars_ok_tp E tp ->
      vars_ok_pt E (ref a) ->
      vars_ok_tm E b ->
      (forall x: var, x \notin L -> vars_ok_tm (ctx_bind E x tp) (t ^^ x)) ->
      vars_ok_tm E (exe a m b t)

with vars_ok_decls_lst : env -> decls_lst -> Prop :=
  | vars_ok_decl_nil : forall E,
      vars_ok_decls_lst E (nil)
  | vars_ok_decl_cons : forall E l d ds,
      vars_ok_decl E d -> vars_ok_decls_lst E ds -> vars_ok_decls_lst E ((l, d) :: ds)

with vars_ok_args : env -> args -> Prop :=
  | vars_ok_args_nil : forall E,
      vars_ok_args E (nil)
  | vars_ok_args_cons_value : forall E l t cs,
      vars_ok_tm E t -> vars_ok_args E cs -> value_label l -> vars_ok_args E ((l, t) :: cs)
  | vars_ok_args_cons_method : forall E L l T t cs,
      (forall x: var, x \notin L -> vars_ok_tm (ctx_bind E x T) (t ^^ x)) ->
      vars_ok_args E cs -> method_label l -> vars_ok_args E ((l, t) :: cs)
.

(* ********************************************************************** *)
(** * #<a name="fv"></a># Free variables *)

Fixpoint fv_pt (e : pt) {struct e} : vars :=
  match e with
    | bvar i => {}
    | fvar x => {{x}}
    | ref x => {}
    | sel e1 l => fv_pt e1
  end

with fv_tm (e : tm) {struct e} : vars :=
  match e with
    | path p => fv_pt p
    | new T args b => (fv_tp T) \u (fold_left (fun (ats: vars) (l_a :  label * tm) => match l_a with (l, t) => ats \u (fv_tm t) end) args {}) \u (fv_tm b)
    | msg e1 m e2 t => (fv_pt e1) \u (fv_pt e2) \u (fv_tm t)
    | exe o m b t => (fv_tm b) \u (fv_tm t)
  end

with fv_tp (t : tp) {struct t} : vars :=
  match t with
    | tp_sel e1 l => fv_pt e1
    | tp_rfn parent decls => (fv_tp parent) \u (fold_left (fun (ats: vars) (d : (label * decl)) => ats \u (fv_decl (snd d))) decls {})
    | tp_and t1 t2 => (fv_tp t1) \u (fv_tp t2)
    | tp_or t1 t2 => (fv_tp t1) \u (fv_tp t2)
    | tp_top => {}
    | tp_bot => {}
  end

with fv_decl (d : decl) {struct d} : vars :=
  match d with
    | decl_tp tl tu => (fv_tp tl) \u (fv_tp tu)
    | decl_tm t => fv_tp t
    | decl_mt t1 t2 => (fv_tp t1) \u (fv_tp t2)
  end.

Definition fv_decls_lst (decls: decls_lst) := (fold_left (fun (ats: vars) (d : (label * decl)) => ats \u (fv_decl (snd d))) decls {}).

(* ********************************************************************** *)
(** * #<a name="subst"></a># Substitution *)

Fixpoint subst_pt (z : atom) (u : pt) (e : pt) {struct e} : pt :=
  match e with
    | bvar i => bvar i
    | ref x => ref x
    | fvar x => if x == z then u else (fvar x)
    | sel e1 l => sel (subst_pt z u e1) l
  end

with subst_tm (z : atom) (u : pt) (e : tm) {struct e} : tm :=
  match e with
    | path p => path (subst_pt z u p)
    | new T args b => new (subst_tp z u T) (lbl.map (subst_tm z u) args) (subst_tm z u b)
    | msg e1 m e2 t => msg (subst_pt z u e1) m (subst_pt z u e2) (subst_tm z u t)
    | exe o m b t => exe o m (subst_tm z u b) (subst_tm z u t)
  end

with subst_tp (z : atom) (u : pt) (t : tp) {struct t} : tp :=
  match t with
    | tp_sel e1 l => tp_sel (subst_pt z u e1) l
    | tp_rfn parent decls => tp_rfn (subst_tp z u parent) (lbl.map (subst_decl z u) decls)
    | tp_and t1 t2 => tp_and (subst_tp z u t1) (subst_tp z u t2)
    | tp_or t1 t2 => tp_or (subst_tp z u t1) (subst_tp z u t2)
    | tp_top => tp_top
    | tp_bot => tp_bot
  end

with subst_decl (z : atom) (u : pt) (d : decl) {struct d} : decl :=
  match d with
    | decl_tp tl tu => decl_tp (subst_tp z u tl) (subst_tp z u tu)
    | decl_tm t => decl_tm (subst_tp z u t)
    | decl_mt t1 t2 => decl_mt (subst_tp z u t1) (subst_tp z u t2)
  end
.

(* ********************************************************************** *)
(** * Automation *)
Hint Constructors value.

(** * #<a name="gather_atoms"></a># The "[gather_atoms]" tactic *)
Ltac gather_atoms ::=
  let A := gather_atoms_with (fun x : atoms => x) in
  let B := gather_atoms_with (fun x : atom => singleton x) in
  let C := gather_atoms_with (fun x : tm => fv_tm x) in
  let D := gather_atoms_with (fun x : tp => fv_tp x) in
  let E := gather_atoms_with (fun x : decl => fv_decl x) in
  let F := gather_atoms_with (fun x : decls => decls_lift fv_decls_lst x) in
  let G := gather_atoms_with (fun x : env => dom x) in
  let H := gather_atoms_with (fun x : store => dom x) in
  constr:(A `union` B `union` C `union` D `union` E `union` F `union` G `union` H).
