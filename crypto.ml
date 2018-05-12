open Yojson.Basic.Util
open Map
open Cryptokit

module BlockChain = struct

  type hash = int



  module Chainmap = Map.Make(String)



  type block = {
      prev_hash:hash;
      time_stamp:int;
      source:string; (*Public Key*)
      dest:string;
      signature:string;
      nonce:int;
      amount:float;
      genesis:bool;
      miner:string;
      n:string;
      d:string;
      msg:string;
    }

  type blockchain = {
    chain:(block list);
    reward:float;
    bits:int;
    complexity:int;
    }


  let empty:blockchain = {
      chain = [];
      reward = 10.0;
      bits = 2048;
      complexity = 1000000;
    }



  let block_of_json j = {
    prev_hash= j |> member "prev_hash" |> to_int;
    time_stamp = j |> member "time_stamp" |> to_int;
    source = j |> member "source" |> to_string;
    dest = j |> member "dest" |> to_string;
    signature = j |> member "signature" |> to_string;
    nonce = j |> member "nonce" |> to_int;
    amount = j |> member "amount" |> to_float;
    genesis = j |> member "genesis" |> to_bool;
    miner = j |> member "miner" |> to_string;
    n = j |> member "n" |> to_string;
    d = j |> member "d" |> to_string;
    msg = j |> member "msg" |> to_string;
  }

  let blockchain_of_json j = {
    chain = j |> member "chain" |> to_list |> List.map block_of_json;
    reward = j |> member "reward" |> to_float ;
    bits = j |> member "bits" |> to_int;
    complexity = j |> member "complexity" |> to_int;
  }

  let json_of_block block =
    `Assoc[
      ("prev_hash", `Int block.prev_hash);
      ("time_stamp", `Int block.time_stamp);
      ("source", `String block.source);
      ("dest", `String block.dest);
      ("signature", `String block.signature);
      ("nonce", `Int block.nonce);
      ("amount", `Float block.amount);
      ("genesis", `Bool block.genesis);
      ("miner", `String block.miner);
      ("msg", `String block.msg);
      ("n", `String block.n);
      ("d", `String block.d);
    ]

  let json_of_blockchain blockchain =
    `Assoc [
      ("chain", `List(List.map json_of_block blockchain.chain));
      ("reward", `Float blockchain.reward);
      ("bits", `Int blockchain.bits);
      ("complexity", `Int blockchain.complexity);
    ]


  let block_to_string block =
    let j = json_of_block block in
    Yojson.to_string j

  let block_chain_to_string block_chain =
    let j = json_of_blockchain block_chain in
    Yojson.to_string j


  let hash_block (b:block) =
    Hashtbl.hash b

  let valid_block (b:block) =
    true

  let valid_hash (b:block) (blks:block list) =
    match blks with
    | b'::_ ->
      hash_block b' = b.prev_hash
    | [] ->
      b.prev_hash = 0

  let rec is_valid_chain (ch:blockchain) =
    match (ch.chain) with
    | b::chain' ->
      if valid_block b && valid_hash b chain' then
        is_valid_chain {ch with chain=chain'}
      else false
    | [] -> true


  let rec tail_complexity ch s =
    match ch.chain with
    | b::chain' ->
      tail_complexity {ch with chain=chain'} (s+b.prev_hash)
    | [] -> s


  let rec measure_complexity ch =
    match ch.chain with
    | b::chain' ->
      tail_complexity ch (b.prev_hash)
    | [] -> 0

  let add_block (b:block) (ch:blockchain) =
    if hash_block b < ch.complexity && valid_block b then
      {ch with chain = b::ch.chain},true
    else
      ch,false


  let rec check_transaction (b:block) (ch:blockchain) =
    match (b.amount, ch.chain) with
    | (a,_) when a <= 0. -> true
    | (_,[]) -> false
    | (a,b'::chain') ->
       let minerew = if b'.miner = b.source then ch.reward else 0. in
       let destrew = if b'.dest = b.source then b'.amount else 0. in
       let sourcepen = if b'.source = b.source then b'.amount else 0. in
       let a' = a -. minerew -. destrew +. sourcepen in
       check_transaction {b with amount=a'} {ch with chain=chain'}

  let rec check_chain_values (ch:blockchain) (mapo:float Chainmap.t option) =
    let map = (match mapo with
      | None -> Chainmap.empty
      | Some x -> x) in
    match ch.chain with
    | [] ->
       Chainmap.fold (fun _ d b -> (d >= 0.) && b) map true
    | b::chain' ->
       let srctot = if Chainmap.mem b.source map then
                      Chainmap.find b.source map else 0. in
       let ntot = srctot -. b.amount in
       let map' = Chainmap.add b.source ntot map in

       let mintot = if Chainmap.mem b.miner map then
                      Chainmap.find b.miner map else 0. in
       let nmtot = mintot +. ch.reward in
       let map2 = Chainmap.(map' |> add b.miner nmtot) in

       let desttot = if Chainmap.mem b.dest map then
                       Chainmap.find b.dest map else 0. in
       let ndtot = desttot +. b.amount in
       let map3 = Chainmap.(map2 |> add b.dest ndtot) in

       check_chain_values {ch with chain=chain'} (Some map3)


  let rec check_balance (id:string) (acc:float) (ch:blockchain)  =
    match ch.chain with
    | [] -> acc
    | b'::chain' ->
       let minerew = if b'.miner = id then ch.reward else 0. in
       let destrew = if b'.dest = id then b'.amount else 0. in
       let sourcepen = if b'.source = id then b'.amount else 0. in
       let a' = minerew +. destrew -. sourcepen in
       check_balance id (acc+.a') {ch with chain=chain'}



  let set_miner (b:block) id =
    {b with miner = id}

  let incr_nonce (b:block) =
    {b with nonce = b.nonce+1}


  (*let sign_block blk priv_key msg =
    failwith "unimplemented"
  let check_sig blk =
    failwith "unimplemnted"*)


  (*type user = {pubk: string; privk: string; c: string}
   *)

  let nonnegmod a b =
      let c = a mod b in
      if c < 0 then
        c + b
      else
        c
          (*
  (* [sign_block] let the sender with private key [privk] sign the block
   * [blk] *)
    let sign_block blk pubk privk c block_chain =
      let b_list = List.filter (fun b -> blk.source = pubk) block_chain in
      let msg = (List.length b_list) + 2 in
      let raisepriv = int_of_float(((float_of_int msg)**(float_of_string privk))) in
      let sgn = nonnegmod raisepriv c in
      let sign = string_of_int sgn in
      {blk with signature = sign; msg = string_of_int msg}



  (* *)
    let check_block blk block_chain =
      let f_pubk = float_of_string blk.source in
      (* get the public key *)
      let f_sig = float_of_string blk.signature in
      (* get the signiture *)
      let msg = nonnegmod (int_of_float (f_sig**f_pubk)) (int_of_string blk.n) in
      (* decrypt the message *)
      if msg = int_of_string blk.msg
      then true
      else false
*)

type user = {pubk: string; privk: string; c: string}

(* [sign_block] let the sender with private key [privk] sign the block
 * [blk] *)
let sign_block blk key user block_chain =
  let b_list = List.filter (fun b -> blk.source = user.pubk) block_chain in
  let msg = (List.length b_list) + 2 in
  let raisepriv = Cryptokit.RSA.encrypt key (string_of_int msg) in
  (*  let sgn = nonnegmod raisepriv (int_of_string user.c) in *) (*cannot use since raisepriv is hex now*)
  (*let sign = string_of_int sgn in*)
  {blk with signature = raisepriv; msg = string_of_int msg}

(* *)
let check_block key blk block_chain =
  (*let f_pubk = float_of_string blk.source in
  (* get the public key *)
  let f_sig = float_of_string blk.signature in
    (* get the signiture *)*)
  let decryption = Cryptokit.RSA.decrypt key blk.signature in
  let length_msg = String.length blk.msg in
  let length_decryp = String.length decryption in
  let recover = String.sub decryption (length_decryp - 1 -length_msg) length_msg in
  (* decrypt the message *)
  if recover = blk.msg
    then true
    else false

  let make_block source dest amount n = {
      source = source;
      dest = dest;
      amount = amount;
      time_stamp = int_of_float (Unix.time ());
      nonce = 0;
      prev_hash = 0;
      miner = "";
      n = n;
      d = "0";
      genesis = false;
      signature = "";
      msg = "";
    }


end
