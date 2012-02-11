(** The DOT calculus -- Syntax. *)

Require Export Dot_Labels.
Require Import Metatheory.

Definition loc := var.

Inductive tp : Set :=                         (* Type *)                 (* S, T, U, V *)
  | tp_sel : tm -> label -> tp                  (* type selection *)       (* p.L *)
  | tp_rfn : tp -> list (label * decl) -> tp    (* refinement *)           (* T { z => _D_ } *)
  | tp_fun : tp -> tp -> tp                     (* function type *)        (* T -> T *)
  | tp_and : tp -> tp -> tp                     (* intersection type *)    (* T /\ T *)
  | tp_or  : tp -> tp -> tp                     (* union type *)           (* T \/ T *)
  | tp_top : tp                                 (* top type *)             (* ⊤ *)
  | tp_bot : tp                                 (* bottom type *)          (* ⊥ *)

with tm : Set :=                              (* Term *)                 (* t *)
                                                (* Variables *)            (* x, y, z *)
  | bvar : nat -> tm                            (* bound variable *)
  | fvar : var -> tm                            (* free variable *)
  | ref  : loc -> tm                            (* object reference *)
  | lam  : tp -> tm -> tm                       (* function *)             (* λx:T.t *)
  | app  : tm -> tm -> tm                       (* application *)          (* t t *)
  | new  : tp -> list (label * tm) -> tm -> tm  (* new instance *)         (* val x = new c; t *)
  | sel  : tm -> label -> tm                    (* selection *)            (* t.l *)

with decl : Set :=                            (* Declaration *)
  | decl_tp : tp -> tp -> decl                  (* type declaration *)     (* L : S .. U *)
  | decl_tm : tp -> decl                        (* value declaration *)    (* l : T *)
.

Inductive path : tm -> Prop :=
  | path_bvar : forall a, path (bvar a)
  | path_fvar : forall a, path (fvar a)
  | path_ref  : forall a, path (ref a)
  | path_sel  : forall p l, value_label l -> path (sel p l)
.

Inductive concrete : tp -> Prop :=
  | concrete_sel : forall p lc,
      path p -> concrete_label lc -> concrete (tp_sel p lc)
  | concrete_rfn : forall tc ds,
      concrete tc -> concrete (tp_rfn tc ds)
  | concrete_and : forall t1 t2,
      concrete t1 -> concrete t2 -> concrete (tp_and t1 t2)
  | concrete_top :
      concrete (tp_top)
.

Definition args := list (label * tm).
Definition decls := list (label * decl).

Definition ctx : Set := list (var * tp).
Definition store : Set := list (loc * (tp * args)).
Definition env : Set := (ctx * store)%type.
Definition ctx_bind (E: env) (x: var) (T: tp) : env := ((x ~ T) ++ (fst E), snd E).

Coercion bvar : nat >-> tm.
Coercion fvar : var >-> tm.

(** * Automation *)
Hint Constructors tp decl tm path concrete.