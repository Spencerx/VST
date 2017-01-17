Require Import aes.aes_spec_ll.
Require Import aes.spec_AES256_HL.
Require Import aes.aesutils.
Require Import List. Import ListNotations.

Definition state_to_list (s : state) : list int :=
  match s with
  | ((b11, b12, b13, b14), (b21, b22, b23, b24), (b31, b32, b33, b34), (b41, b42, b43, b44)) =>
    [ b11; b12; b13; b14 ;  b21; b22; b23; b24 ;  b31; b32; b33; b34 ;  b41; b42; b43; b44 ]
  end.

Definition list_to_state (l : list int) : state :=
  match l with
  | [ b11; b12; b13; b14 ;  b21; b22; b23; b24 ;  b31; b32; b33; b34 ;  b41; b42; b43; b44 ] =>
    ((b11, b12, b13, b14), (b21, b22, b23, b24), (b31, b32, b33, b34), (b41, b42, b43, b44))
  (* should not happen: *)
  | _ => let z4 := (Int.zero, Int.zero, Int.zero, Int.zero) in
         (z4, z4, z4, z4)
  end.

Definition int_to_word (x : int) : word := (
  (Int.and           x                (Int.repr 255)),
  (Int.and (Int.shru x (Int.repr  8)) (Int.repr 255)),
  (Int.and (Int.shru x (Int.repr 16)) (Int.repr 255)),
  (Int.and (Int.shru x (Int.repr 24)) (Int.repr 255))
).

(*
Definition four_ints_to_state (s : four_ints) : state :=
  list_to_state (output_four_ints_as_bytes s).
*)

Definition four_ints_to_state (s : four_ints) : state := match s with
| (c0, (c1, (c2, c3))) => (int_to_word c0, int_to_word c1, int_to_word c2, int_to_word c3)
end.

Definition state_to_four_ints (s : state) : four_ints := match s with
| (c0, c1, c2, c3) => (word_to_int c0, (word_to_int c1, (word_to_int c2, word_to_int c3)))
end.

Definition blocks_to_Zwords (blocks : list block) : list Z := map Int.unsigned (blocks_to_ints blocks).

Definition mbed_tls_aes_enc' (exp_key : list block) (plaintext : state) : state :=
  list_to_state (mbed_tls_aes_enc 
     (map Int.unsigned (state_to_list plaintext))
     ((blocks_to_Zwords exp_key) ++ (list_repeat (8%nat) 0))
  ).

Definition mbed_tls_final_fround' (S13 : state) (last_exp_key_block : block) : state :=
  four_ints_to_state (mbed_tls_final_fround
    (state_to_four_ints S13)
    (map Int.unsigned (block_to_ints last_exp_key_block))
    0
  ).

Lemma final_round_equiv: forall S K,
  mbed_tls_final_fround' S K = last_round S K.
Admitted.

Lemma split_quad_eq: forall {T : Type} (c0 c1 c2 c3 c0' c1' c2' c3' : T),
  c0 = c0' -> c1 = c1' -> c2 = c2' -> c3 = c3' -> (c0, c1, c2, c3) = (c0', c1', c2', c3').
Proof.
  intros. congruence.
Qed.

Lemma split_4eq: forall (T : Type) (c0 c1 c2 c3 c0' c1' c2' c3' : T),
  (c0, c1, c2, c3) = (c0', c1', c2', c3') ->
  c0 = c0' /\ c1 = c1' /\ c2 = c2' /\ c3 = c3'.
Proof.
  intros. inversion H. subst. auto.
Qed.

Lemma word_to_int_int_to_word: forall i,
  word_to_int (int_to_word i) = i.
Proof.
  intros. unfold int_to_word. unfold word_to_int. unfold SHA256.little_endian_integer.
  (* Yay, TODO *)
Admitted.

Ltac eta5 HH :=
  let Hnew := fresh in match type of HH with
  | ?f = (fun a1 a2 a3 a4 a5 => ?e) =>
    assert (forall a1 a2 a3 a4 a5, f a1 a2 a3 a4 a5 = e) as Hnew by (intro; rewrite HH; reflexivity)
  end;
  clear HH; rename Hnew into HH.

Lemma HL_equiv_LL_encryption: forall exp_key plaintext,
  Zlength exp_key = 15 ->
  mbed_tls_aes_enc' exp_key plaintext = Cipher exp_key plaintext.
Proof.
  intros.
  do 15 (destruct exp_key as [ | [[[?k0 ?k0] ?k0] ?k0]  exp_key]; [ inversion H | ]).
  destruct exp_key.
  - clear H. destruct plaintext as [[[w0 w1] w2] w3].
    destruct w0 as [[[?p0 ?p0] ?p0] ?p0].
    destruct w1 as [[[?p0 ?p0] ?p0] ?p0].
    destruct w2 as [[[?p0 ?p0] ?p0] ?p0].
    destruct w3 as [[[?p0 ?p0] ?p0] ?p0].

    (* unfold last round of LHS (low level): *)
    unfold mbed_tls_aes_enc'. rewrite mbed_tls_aes_enc_def.
    rewrite output_four_ints_as_bytes_def. rewrite put_uint32_le_def. simpl.
    match goal with
    | |- context [ mbed_tls_final_fround ?S ?l ?i ] =>
      remember (mbed_tls_final_fround S l i) as S14;
      remember S as S13
    end.
    rewrite mbed_tls_final_fround_def in HeqS14.
    rewrite mbed_tls_final_fround_col_def in HeqS14.
    rewrite (split_four_ints S13) in HeqS14.
    match goal with
    | H : context [ Znth 56 ?l ?d ] |- _ => 
      change (Znth 56 l d) with (Int.unsigned (word_to_int k56)) in H
    end.
    match goal with
    | H : context [ Znth (56 + 1) ?l ?d ] |- _ => 
      change (Znth (56 + 1) l d) with (Int.unsigned (word_to_int k57)) in H
    end.
    match goal with
    | H : context [ Znth (56 + 2) ?l ?d ] |- _ => 
      change (Znth (56 + 2) l d) with (Int.unsigned (word_to_int k58)) in H
    end.
    match goal with
    | H : context [ Znth (56 + 3) ?l ?d ] |- _ => 
      change (Znth (56 + 3) l d) with (Int.unsigned (word_to_int k59)) in H
    end.
    pose proof mbed_tls_final_fround_col_def as E.
    eta5 E. do 4 rewrite <- E in HeqS14. clear E.
    apply split_four_ints_eq in HeqS14. unfold col in HeqS14.
    destruct HeqS14 as [E0 [E1 [E2 E3]]].
    rewrite <- E0, <- E1, <- E2, <- E3; clear E0 E1 E2 E3.

    (* unfold last round of RHS (high level): *)
    match goal with
    | |- context [ last_round ?s ?k ] => remember s as S13'
    end.

    pose proof (final_round_equiv S13' (k56, k57, k58, k59)) as F.
    rewrite <- F. clear F.

    assert (four_ints_to_state S13 = S13') as E13 by admit.
    destruct S13' as [[[c1 c2] c3] c4].
    rewrite (split_four_ints S13) in E13. simpl in E13.
    apply split_4eq in E13. destruct E13 as [? [? [? ?]]]. subst c1 c2 c3 c4.

    unfold mbed_tls_final_fround'.
    unfold four_ints_to_state. rewrite mbed_tls_final_fround_def.
    unfold state_to_four_ints.

    repeat rewrite word_to_int_int_to_word.
    unfold int_to_word.
    reflexivity.
  - exfalso. do 16 rewrite Zlength_cons in H.
    pose proof (Zlength_nonneg exp_key). omega.
Qed.
