fun println s = (print s; print "\n")

fun split ch s =
  let
    val s = Substring.full s
    val (prefix, remainder) = Substring.splitl (fn ch' => ch <> ch') s
  in
    (Substring.string prefix, Substring.string (Substring.triml 1 remainder))
  end

fun fromFile file =
let
  val ins = TextIO.openIn file
in
  TextIO.inputAll ins before TextIO.closeIn ins
end

fun toFile (file, text) =
let
  val outs = TextIO.openOut file
in
  TextIO.output (outs, text);
  TextIO.closeOut outs
end

fun usage () = (
  println "usage: annot [-R <path>] [-C <path>] <command> [<args>]";
  println "";
  println "subcommands:";
  println "  annot put [-m <message>|-f <file>] <file>:<line>";
  println "  annot get <file>:<line>";
  println "  annot edit <file>:<line>";
  println "  annot list <file>";
  ())

fun main () =
let
  val opts = [GetOpt.StrOpt #"R", GetOpt.StrOpt #"C"]
  fun f (value, acc) =
    case value of
         GetOpt.Str(#"R", repo) => SOME repo 
       | GetOpt.Str(#"C", dir) => (OS.FileSys.chDir dir; acc)
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
             val obj = Clerk.new Clerk.Hg repo
           in
             case Clerk.get obj file line of
                  NONE => OS.Process.exit OS.Process.failure
                | SOME message => print message
           end
     | "list"::args =>
         if List.length args = 0 then usage ()
         else
            let
              val obj = Clerk.new Clerk.Hg repo
              val file = List.hd args
              val annots = Clerk.list obj file
              fun show (lineNumber, message) = 
              let
                val lines = String.tokens (fn ch => ch = #"\n") message
                fun showLine line = (
                print file;
                print ":";
                print (Int.toString lineNumber);
                print ":";
                print line;
                print "\n")
              in
                List.app showLine lines
              end
            in
              List.app show annots
            end
     | "put"::args =>
         let
           datatype source = StdIn | Arg of string | File of string
           val opts = [GetOpt.StrOpt #"m", GetOpt.StrOpt #"f"]
           fun f (GetOpt.Str (#"m", message), acc) = Arg message
             | f (GetOpt.Str (#"f", file), acc) = File file
             | f _ = raise Fail "unexpected error"
           val (source, args) = GetOpt.getopt opts f StdIn args
         in
           if List.length args = 0 then usage ()
           else
             let
               val (file, line) = split #":" (List.hd args)
               val line = Option.valOf (Int.fromString line)
               val message =
                 case source of
                      StdIn => TextIO.inputAll TextIO.stdIn
                    | Arg message => message
                    | File file =>
                        let
                          val ins = TextIO.openIn file
                        in
                          TextIO.inputAll ins before TextIO.closeIn ins
                        end
               val obj = Clerk.new Clerk.Hg repo
             in
               Clerk.put obj file line message
             end
         end
     | "edit"::args =>
         if List.length args = 0 then usage ()
         else
           let
             val (file, line) = split #":" (List.hd args)
             val line = Option.valOf (Int.fromString line)
             val obj = Clerk.new Clerk.Hg repo
             val messageBefore = Option.getOpt (Clerk.get obj file line, "")
             val tmp = OS.FileSys.tmpName ()
           in
             toFile (tmp, messageBefore);
             OS.Process.system ("$EDITOR " ^ tmp);
             let
               val messageAfter = fromFile tmp
             in
               if messageAfter = messageBefore then ()
               else Clerk.put obj file line messageAfter;
               OS.FileSys.remove tmp
             end
           end
     | subcmd::args => raise Fail ("unknown command " ^ subcmd)
end
