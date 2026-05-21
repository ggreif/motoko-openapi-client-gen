(* OpenAPI 3 spec merger.

   The on-disk AST is just JSON, which is a subset of YAML; both `yaml`
   and `ezjsonm` use the same value shape, so we can parse with whichever
   matches the file extension and emit with `ezjsonm` for stable JSON
   output.  See the README for the merge-config schema and semantics. *)

type value = Ezjsonm.value

(* ----- IO ----- *)

let read_file path =
  let ic = open_in path in
  let len = in_channel_length ic in
  let buf = Bytes.create len in
  really_input ic buf 0 len;
  close_in ic;
  Bytes.unsafe_to_string buf

let write_file path s =
  let oc = open_out path in
  output_string oc s;
  close_out oc

(* Real-world OpenAPI specs use JSON-specific Unicode-escape sequences
   that libyaml's strict YAML parser rejects (it expects only `\xNN`-style
   escapes, not JSON's `\uXXXX`).  Dispatch on file extension instead of
   trying to treat one parser as the universal donor. *)
let parse_by_ext ~filename s : value =
  let ext = String.lowercase_ascii (Filename.extension filename) in
  match ext with
  | ".json" -> (Ezjsonm.value_from_string s :> value)
  | ".yml" | ".yaml" ->
    (match Yaml.of_string s with
     | Ok v -> (v :> value)
     | Error (`Msg m) -> failwith ("YAML parse error in " ^ filename ^ ": " ^ m))
  | _ ->
    (* Best-effort: try JSON first, fall back to YAML. *)
    (try (Ezjsonm.value_from_string s :> value)
     with _ ->
       match Yaml.of_string s with
       | Ok v -> (v :> value)
       | Error (`Msg m) -> failwith ("parse error in " ^ filename ^ ": " ^ m))

let emit_json (v : value) : string =
  (* Pretty-print with 2-space indent, trailing newline.  Ezjsonm.to_string
     wraps a top-level value as `O / `A only; OpenAPI roots are always
     objects so the cast is safe. *)
  match v with
  | (`O _ | `A _) as v -> Ezjsonm.to_string ~minify:false v ^ "\n"
  | _ -> failwith "OpenAPI spec must be a JSON object at the root"

(* ----- AST helpers ----- *)

let as_obj = function `O kvs -> kvs | _ -> failwith "expected object"
let as_arr = function `A xs -> xs | _ -> failwith "expected array"
let as_str = function `String s -> s | _ -> failwith "expected string"

let find_opt k kvs = List.assoc_opt k kvs

let obj_set k v kvs =
  let replaced = ref false in
  let kvs' = List.map (fun (k', v') ->
    if k = k' then (replaced := true; (k', v)) else (k', v')) kvs
  in
  if !replaced then kvs' else kvs' @ [(k, v)]

let obj_update k f kvs =
  match find_opt k kvs with
  | Some v -> obj_set k (f v) kvs
  | None -> kvs

(* ----- Per-input transforms ----- *)

type transform = {
  tag_prefix : string option;
  schema_prefix : string option;
  operation_id_prefix : string option;
  server_override : string option;
}

let no_transform =
  { tag_prefix = None; schema_prefix = None;
    operation_id_prefix = None; server_override = None }

let schema_ref_prefix = "#/components/schemas/"

(* Walk the whole spec and rewrite every "$ref" string that points at
   "#/components/schemas/X" to "#/components/schemas/<prefix>X". *)
let rec rewrite_schema_refs prefix (v : value) : value =
  match v with
  | `O kvs ->
    `O (List.map (fun (k, v') ->
      match k, v' with
      | "$ref", `String s when String.starts_with ~prefix:schema_ref_prefix s ->
        let name = String.sub s (String.length schema_ref_prefix)
                     (String.length s - String.length schema_ref_prefix) in
        (k, `String (schema_ref_prefix ^ prefix ^ name))
      | _ -> (k, rewrite_schema_refs prefix v')) kvs)
  | `A xs -> `A (List.map (rewrite_schema_refs prefix) xs)
  | other -> other

(* Apply schemaPrefix:  rename keys in components.schemas, then rewrite
   every $ref pointing at them. *)
let apply_schema_prefix prefix (spec : value) : value =
  let renamed_schemas v =
    `O (List.map (fun (k, sch) -> (prefix ^ k, sch)) (as_obj v))
  in
  let kvs = as_obj spec in
  let kvs =
    obj_update "components"
      (fun c -> `O (obj_update "schemas" renamed_schemas (as_obj c)))
      kvs
  in
  rewrite_schema_refs prefix (`O kvs)

(* Apply tagPrefix:  rename each tag at the top-level `tags` array AND
   rewrite each operation's "tags" array elements that match. *)
let apply_tag_prefix prefix (spec : value) : value =
  let bump_tag = function
    | `String s -> `String (prefix ^ s)
    | other -> other
  in
  let bump_tag_obj = function
    | `O o -> `O (obj_update "name" bump_tag o)
    | other -> other
  in
  let rec walk_ops_tags v =
    match v with
    | `O kvs ->
      `O (List.map (fun (k, v') ->
        if k = "tags" then match v' with
          | `A items -> (k, `A (List.map bump_tag items))
          | _ -> (k, v')
        else (k, walk_ops_tags v')) kvs)
    | `A xs -> `A (List.map walk_ops_tags xs)
    | other -> other
  in
  let kvs = as_obj spec in
  let kvs =
    obj_update "tags"
      (fun t -> `A (List.map bump_tag_obj (as_arr t)))
      kvs
  in
  walk_ops_tags (`O kvs)

(* Apply operationIdPrefix:  rewrite every operationId inside paths.* *)
let apply_operation_id_prefix prefix (spec : value) : value =
  let bump_op op =
    `O (obj_update "operationId" (function
      | `String s -> `String (prefix ^ s)
      | other -> other) (as_obj op))
  in
  let bump_path_item pi =
    `O (List.map (fun (k, v) ->
      match k with
      | "get" | "put" | "post" | "delete" | "options"
      | "head" | "patch" | "trace" -> (k, bump_op v)
      | _ -> (k, v)) (as_obj pi))
  in
  let kvs = as_obj spec in
  let kvs =
    obj_update "paths"
      (fun p -> `O (List.map (fun (k, pi) -> (k, bump_path_item pi)) (as_obj p)))
      kvs
  in
  `O kvs

(* Apply serverOverride:  set a per-operation `servers` array so each
   operation pins to the right host (this is the OpenAPI-standard way),
   AND also stamp an `x-server-override` vendor extension so the Motoko
   api.mustache template can read the same value directly (the standard
   `servers` field isn't surfaced to operation templates by
   openapi-generator's default Java side, but vendorExtensions are). *)
let apply_server_override url (spec : value) : value =
  let server_arr = `A [`O [("url", `String url)]] in
  let stamp_op op =
    as_obj op
    |> obj_set "servers" server_arr
    |> obj_set "x-server-override" (`String url)
    |> fun kvs -> `O kvs
  in
  let stamp_path_item pi =
    `O (List.map (fun (k, v) ->
      match k with
      | "get" | "put" | "post" | "delete" | "options"
      | "head" | "patch" | "trace" -> (k, stamp_op v)
      | _ -> (k, v)) (as_obj pi))
  in
  let kvs = as_obj spec in
  let kvs =
    obj_update "paths"
      (fun p -> `O (List.map (fun (k, pi) -> (k, stamp_path_item pi)) (as_obj p)))
      kvs
  in
  `O kvs

let apply_transform (t : transform) (spec : value) : value =
  let spec = match t.schema_prefix with
    | Some p when p <> "" -> apply_schema_prefix p spec
    | _ -> spec in
  let spec = match t.tag_prefix with
    | Some p when p <> "" -> apply_tag_prefix p spec
    | _ -> spec in
  let spec = match t.operation_id_prefix with
    | Some p when p <> "" -> apply_operation_id_prefix p spec
    | _ -> spec in
  let spec = match t.server_override with
    | Some u when u <> "" -> apply_server_override u spec
    | _ -> spec in
  spec

(* ----- Merging ----- *)

(* Union of two objects keyed by name.  Strict mode (~lenient:false) hard-
   fails on any key collision — appropriate for components.schemas where
   silent dedup of "same name, different shape" would be a bug.  Lenient
   mode (~lenient:true) lets collisions through when the two values are
   structurally equal (deep-equal via OCaml `=`), which is how identical
   securitySchemes / parameters from two specs of the same vendor
   correctly dedup. *)
let union_objects ?(lenient=false) ~where a b =
  let conflicts = ref [] in
  let from_b_kept = List.filter (fun (k, v) ->
    match List.assoc_opt k a with
    | None -> true
    | Some v_a when lenient && v_a = v -> false
    | Some _ -> conflicts := k :: !conflicts; false
  ) b in
  (match !conflicts with
   | [] -> ()
   | xs ->
     failwith (Printf.sprintf "collision in %s: %s — add a prefix to one of \
                               the input transforms to disambiguate"
                 (where : string) (String.concat ", " xs)));
  a @ from_b_kept

(* Dedup tag-array by tag.name, keeping first occurrence. *)
let dedup_tags arr =
  let seen = Hashtbl.create 16 in
  List.filter (fun t ->
    match t with
    | `O kvs ->
      (match find_opt "name" kvs with
       | Some (`String name) ->
         if Hashtbl.mem seen name then false
         else (Hashtbl.add seen name (); true)
       | _ -> true)
    | _ -> true) arr

(* Merge two specs into one.  First spec contributes its `info` and
   `openapi` version; per-input transforms have already been applied
   before this point. *)
let merge_two (a : value) (b : value) : value =
  let ao = as_obj a and bo = as_obj b in
  let paths_a = match find_opt "paths" ao with Some (`O o) -> o | _ -> [] in
  let paths_b = match find_opt "paths" bo with Some (`O o) -> o | _ -> [] in
  let merged_paths = `O (union_objects ~where:"paths" paths_a paths_b) in

  let get_schemas obj =
    match find_opt "components" obj with
    | Some (`O comp) ->
      (match find_opt "schemas" comp with
       | Some (`O s) -> s | _ -> [])
    | _ -> []
  in
  let schemas_a = get_schemas ao and schemas_b = get_schemas bo in
  let merged_schemas = `O (union_objects ~where:"components.schemas"
                             schemas_a schemas_b) in

  let merged_components =
    let comp_a = match find_opt "components" ao with Some (`O o) -> o | _ -> [] in
    let comp_b = match find_opt "components" bo with Some (`O o) -> o | _ -> [] in
    (* Each sub-key of components (securitySchemes, parameters, requestBodies,
       responses, ...) is itself a map; we merge them per-sub-key with the
       lenient policy: keys that appear in both with structurally equal
       values dedup silently, otherwise hard-fail.  schemas is overridden
       further down with strict-collision semantics. *)
    let all_keys =
      List.sort_uniq compare
        (List.map fst comp_a @ List.map fst comp_b)
      |> List.filter (fun k -> k <> "schemas")
    in
    let merged_subkeys = List.map (fun k ->
      match List.assoc_opt k comp_a, List.assoc_opt k comp_b with
      | Some (`O oa), Some (`O ob) ->
        (k, `O (union_objects ~lenient:true ~where:("components." ^ k) oa ob))
      | Some v, None | None, Some v -> (k, v)
      | Some _, Some _ ->
        failwith ("components." ^ k ^ ": both inputs declare this key with \
                  non-object values — unsupported")
      | None, None -> assert false
    ) all_keys in
    `O (obj_set "schemas" merged_schemas merged_subkeys)
  in

  let merged_tags =
    let ta = match find_opt "tags" ao with Some (`A a) -> a | _ -> [] in
    let tb = match find_opt "tags" bo with Some (`A b) -> b | _ -> [] in
    `A (dedup_tags (ta @ tb))
  in

  (* Build result from `a`, overwriting paths / components / tags. *)
  let out = ao in
  let out = obj_set "paths" merged_paths out in
  let out = obj_set "components" merged_components out in
  let out = obj_set "tags" merged_tags out in
  `O out

(* ----- Top-level config + driver ----- *)

type input = {
  path : string;          (* resolved relative to merge-config dir *)
  transform : transform;
}

type config = {
  inputs : input list;
  info_override : value option;     (* optional `info` block to splat onto output *)
}

let str_opt v = match v with `String s -> Some s | _ -> None

let parse_transform kvs : transform =
  let g k = Option.bind (find_opt k kvs) str_opt in
  { tag_prefix          = g "tagPrefix";
    schema_prefix       = g "schemaPrefix";
    operation_id_prefix = g "operationIdPrefix";
    server_override     = g "serverOverride"; }

let parse_config ~config_dir ~config_filename s : config =
  let v = parse_by_ext ~filename:config_filename s in
  let root = as_obj v in
  let inputs =
    match find_opt "inputs" root with
    | Some (`A arr) ->
      List.map (fun item ->
        let kvs = as_obj item in
        let rel = match find_opt "path" kvs with
          | Some (`String s) -> s
          | _ -> failwith "each input needs a \"path\" string" in
        let path = if Filename.is_relative rel
                   then Filename.concat config_dir rel
                   else rel in
        { path; transform = parse_transform kvs }) arr
    | _ -> failwith "merge-config: missing or non-array \"inputs\""
  in
  let info_override = find_opt "info" root in
  { inputs; info_override }

let run (cfg : config) : value =
  match cfg.inputs with
  | [] -> failwith "merge-config: \"inputs\" array is empty"
  | first :: rest ->
    let load i =
      let raw = read_file i.path in
      apply_transform i.transform (parse_by_ext ~filename:i.path raw)
    in
    let merged = List.fold_left (fun acc inp -> merge_two acc (load inp))
                   (load first) rest
    in
    match cfg.info_override with
    | None -> merged
    | Some info ->
      `O (obj_set "info" info (as_obj merged))
