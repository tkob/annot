fun locateProjectRoot repo =
let
  fun isAnnotRoot dir =
  let
    val annotDir = OS.Path.concat (dir, ".annot")
  in
    OS.FileSys.isDir annotDir handle SysErr => false
  end

  fun locateAnnot dir =
    if OS.Path.isRoot dir then
      NONE
    else
      if isAnnotRoot dir then SOME dir
      else
        locateAnnot
          (OS.Path.mkAbsolute {path=OS.Path.parentArc, relativeTo=dir})
in
  case repo of
       NONE => locateAnnot (OS.FileSys.getDir ())
     | SOME dir =>
         if isAnnotRoot dir then SOME dir 
         else NONE
end

fun println s = (print s; print "\n")

fun usage () = (
  println "usage: annot [-R <path>] <command> [<args>]";
  println "";
  println "subcommands:";
  println "  annot put file:line message";
  println "  annot get file:line";
  println "  annot get file:start-end";
  ())

fun main () =
let
  val opts = [GetOpt.StrOpt #"R"]
  fun f (value, acc) =
    case value of
         GetOpt.Str(#"R", repo) => SOME repo 
       | _ => raise Fail "unexpeected error"
  val (repo, args) = GetOpt.getopt opts f NONE (CommandLine.arguments ())
in
  case args of
       [] => usage ()
     | "get"::args => raise Fail "get unimplemented"
     | "put"::args => raise Fail "put unimplemented"
     | subcmd::args => raise Fail ("unknown command " ^ subcmd)
end
