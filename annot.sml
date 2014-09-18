fun println s = (print s; print "\n")

fun split ch s =
  let
    val s = Substring.full s
    val (prefix, remainder) = Substring.splitl (fn ch' => ch <> ch') s
  in
    (Substring.string prefix, Substring.string (Substring.triml 1 remainder))
  end

fun usage () = (
  println "usage: annot [-R <path>] <command> [<args>]";
  println "";
  println "subcommands:";
  println "  annot put [-m <message>|-f <file>] <file>:<line>";
  println "  annot get <file>:<line>";
  println "  annot get <file>:<start>-<end>";
  ())

fun main () =
let
  val opts = [GetOpt.StrOpt #"R"]
  fun f (value, acc) =
    case value of
         GetOpt.Str(#"R", repo) => SOME repo 
       | _ => raise Fail "unexpected error"
  val (repo, args) = GetOpt.getopt opts f NONE (CommandLine.arguments ())
in
  case args of
       [] => usage ()
     | "get"::args =>
         if List.length args = 0 then usage ()
         else
           let
             val (file, line) = split #":" (List.hd args)
             val line = Option.valOf (Int.fromString line)
             val obj = Clerk.new Clerk.Hg (Option.getOpt (repo, "."))
           in
             case Clerk.get obj file line of
                  NONE => OS.Process.exit OS.Process.failure
                | SOME message => print message
           end
     | "put"::args => raise Fail "put unimplemented"
     | subcmd::args => raise Fail ("unknown command " ^ subcmd)
end
