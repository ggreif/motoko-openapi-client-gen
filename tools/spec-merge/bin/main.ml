open Cmdliner

let run config_path out_path =
  let config_dir = Filename.dirname config_path in
  let cfg = Spec_merge.Merge.parse_config ~config_dir
              ~config_filename:config_path
              (Spec_merge.Merge.read_file config_path) in
  let merged = Spec_merge.Merge.run cfg in
  Spec_merge.Merge.write_file out_path (Spec_merge.Merge.emit_json merged);
  `Ok ()

let config_arg =
  let doc = "Path to the merge-config JSON file describing inputs + transforms." in
  Arg.(required & opt (some file) None
         & info ["c"; "config"] ~docv:"MERGE_CONFIG" ~doc)

let out_arg =
  let doc = "Path to write the merged OpenAPI spec (JSON)." in
  Arg.(required & opt (some string) None
         & info ["o"; "output"] ~docv:"OUTPUT" ~doc)

let cmd =
  let doc = "Merge multiple OpenAPI 3 specs into one." in
  let info = Cmd.info "spec-merge" ~version:"0.1.0" ~doc in
  Cmd.v info Term.(ret (const run $ config_arg $ out_arg))

let () = exit (Cmd.eval cmd)
