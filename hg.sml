(* Client library for Mercurial's Command Server API *)

structure Hg :> HG = struct
  type greeting = { capabilities : string list, encoding : string }

  type session = {
    instream : BinIO.instream,
    outstream : BinIO.outstream,
    greeting : greeting,
    repo : string }

  datatype datum = Input of int 
                 | Line of int 
                 | Output of Word8Vector.vector
                 | Error of Word8Vector.vector
                 | Result of Word8Vector.vector
                 | Debug of Word8Vector.vector

  type chunk = (string * string) list

  type blame = {
    user : string,
    number : int,
    changeset : string,
    date : Date.date,
    file : string,
    lineNumber : int,
    text : string }

  type changeset = {
    number : int,
    hash : string,
    tag : string,
    user : string,
    date : Date.date,
    summary : string }

  fun mkInstream fd =
  let
    val reader = Posix.IO.mkBinReader
        {fd = fd, name = "", initBlkMode = true}
    val instream = BinIO.StreamIO.mkInstream
        (reader, Word8Vector.fromList [])
  in
    BinIO.mkInstream instream
  end

  fun mkOutstream fd =
  let
    val writer = Posix.IO.mkBinWriter
        {fd = fd, name = "",
         appendMode = true,
         initBlkMode = true,
         chunkSize = 1024}
    val outstream = BinIO.StreamIO.mkOutstream
        (writer, IO.NO_BUF)
  in
    BinIO.mkOutstream outstream
  end

  (* convert bigendian bytes to integer *)
  fun scan bytes = 
  let 
    fun f (byte, int) = int * 256 + Word8.toInt byte
  in 
    Word8Vector.foldl f 0 bytes 
  end 

  local
    open Word
    infix >>
    infix andb
    val word8 = Word8.fromLarge o Word.toLarge
  in
    fun outputInt (outs, int) =
    let
      val word = Word.fromInt int
      val ll = word8 (word andb 0wxff)
      val lh = word8 ((word >> 0w8) andb 0wxff)
      val hl = word8 ((word >> 0w16) andb 0wxff)
      val hh = word8 ((word >> 0w24) andb 0wxff)
    in
      BinIO.output1 (outs, hh);
      BinIO.output1 (outs, hl);
      BinIO.output1 (outs, lh);
      BinIO.output1 (outs, ll)
    end
  end

  fun readChannel' ins =
  let
    val ch = Byte.bytesToString (BinIO.inputN (ins, 1))
    val len = scan (BinIO.inputN (ins, 4))
  in
    case ch of 
         "I" => Input len
       | "L" => Line len
       | "o" => Output (BinIO.inputN (ins, len))
       | "r" => Result (BinIO.inputN (ins, len))
       | "d" => Debug (BinIO.inputN (ins, len))
       | _ => raise Fail ("unknown channel: " ^ ch)
  end

  fun appChannel' f ins =
    case readChannel' ins of
         Output bytes => (f bytes; appChannel' f ins)
       | datum => datum

  fun foldChannel' f init ins =
  let
    fun fold acc =
      case readChannel' ins of
           Output bytes => fold (f (bytes, acc))
         | datum => (datum, acc)
  in
    fold init
  end

  fun writeChannel' (outs, commandName, payload) =
  let
    val () = BinIO.output (outs, Byte.stringToBytes commandName)
    val () = BinIO.output (outs, Byte.stringToBytes "\n")
    val len = Word8Vector.length payload
  in
    if len > 0 then (
      outputInt (outs, len);
      BinIO.output (outs, payload))
    else ()
  end

  fun split ch s =
    let
      val (prefix, remainder) = Substring.splitl (fn ch' => ch <> ch') s
    in
      (Substring.string prefix, Substring.triml 1 remainder)
    end
  fun trimWS s = Substring.dropl (fn ch => ch = #" ") s

  fun parseChunk bytes =
  let
    val s = Substring.full (Byte.bytesToString bytes)
    val lines = Substring.tokens (fn ch => ch = #"\n") s
    fun splitKV line =
    let
      val (prefix, remainder) = split #":" line
      val value = trimWS remainder
    in
      (prefix, Substring.string value)
    end
  in
    map splitKV lines
  end

  fun lookupChunk (key, []) = raise Fail ("key " ^ key ^ " not found")
    | lookupChunk (key, (k, v)::kvs) =
      if k = key then v
      else lookupChunk (key, kvs)

  fun showChunk chunk =
    String.concatWith "\n" (List.map (fn (k, v) => k ^ ": " ^ v) chunk)

  fun readGreeting ins =
    case readChannel' ins of
         Output bytes =>
         let
           val chunk = parseChunk bytes
           (* val _ = print (showChunk chunk) *)
           val capabilities = lookupChunk ("capabilities", chunk)
           val encoding = lookupChunk ("encoding", chunk)
         in
           { capabilities = String.tokens (fn ch => ch = #" ") capabilities,
             encoding = encoding }
         end
       | _ => raise Fail ("unexpected output from server")

  fun showGreeting { capabilities = capabilities, encoding = encoding } =
    "capabilities: " ^ String.concatWith " " capabilities ^ "\n" ^
    "encoding: " ^ encoding ^ "\n"

  fun openSession repo : session =
  let
    val c2p = Posix.IO.pipe ()
    val p2c = Posix.IO.pipe ()
  in
    case Posix.Process.fork () of
         NONE => (* child *)
           let
             val args =
               ["env", "HGPLAIN=1",
                "hg", "serve",
                "--cmdserver", "pipe",
                "-R", repo]
           in
             Posix.IO.dup2 {old = #outfd c2p, new = Posix.FileSys.stdout};
             Posix.IO.dup2 {old = #infd p2c, new = Posix.FileSys.stdin};
             Posix.IO.close (#infd c2p);
             Posix.IO.close (#outfd p2c);
             Posix.Process.execp ("env", args)
           end
       | SOME pid => (* parent *)
           let
             val ins = mkInstream (#infd c2p)
             val outs = mkOutstream (#outfd p2c)
             val greeting = readGreeting ins
           in
             Posix.IO.close (#infd p2c);
             Posix.IO.close (#outfd c2p);
             { instream = ins,
               outstream = outs,
               greeting = greeting,
               repo = repo }
           end
  end

  fun closeSession ({instream = ins, outstream = outs, ...} : session) = (
    BinIO.closeIn ins;
    BinIO.closeOut outs)

  fun getRepo (session : session) = #repo session

  fun getEncoding ({instream = ins, outstream = outs, ...} : session) = (
    writeChannel' (outs, "getencoding", Word8Vector.fromList []);
    case readChannel' ins of
         Result bytes => Byte.bytesToString bytes
       | _ => raise Fail ("unexpected output from server")
    )

  fun runCommand ({instream = ins, outstream = outs, ...} : session) args =
  let
    val payload = Byte.stringToBytes (String.concatWith "\000" args)
  in
    writeChannel' (outs, "runcommand", payload)
  end

  fun annotate (session : session as {instream = ins, outstream = outs, ...}) args = 
  let
    (*
       Output of annotate is something like the following.
       Each column (including line-number) may be left-padded with spaces.

       tkob 0 7cc451647616 Sun Sep 14 21:28:39 2014 +0900 a.txt:1: hello
    *)
    fun parseBlame bytes =
    let
      val rest = Substring.full (Byte.bytesToString bytes)
      val (user, rest) = split #" " (trimWS rest)
      val (number, rest) = split #" " (trimWS rest)
      val (changeset, rest) = split #" " (trimWS rest)
      val date =
        (Option.valOf o Date.fromString o Substring.string)
        (Substring.slice (trimWS rest, 0, SOME 24))
      val rest = Substring.triml 24 rest
      val (tz, rest) = split #" " (trimWS rest)
      val (file, rest) = split #":" (trimWS rest)
      val (lineNumber, rest) = split #":" (trimWS rest)
      val text = Substring.string (Substring.triml 1 rest)
    in
      { user = user,
        number = Option.valOf (Int.fromString number),
        changeset = changeset,
        date = date,
        file = file,
        lineNumber = Option.valOf (Int.fromString lineNumber),
        text = text }
    end
    fun showBlame (annot : blame) =
      "user = " ^ #user annot ^ "\n" ^
      "number = " ^ Int.toString (#number annot) ^ "\n" ^
      "changeset = " ^ #changeset annot ^ "\n" ^
      "date = " ^ Date.toString (#date annot) ^ "\n" ^
      "file = " ^ #file annot ^ "\n" ^
      "lineNumber = " ^ Int.toString (#lineNumber annot) ^ "\n" ^
      "text = " ^ #text annot ^ "\n"
    val () = runCommand
               session
               (["annotate", "-u", "-n", "-c", "-d", "-f", "-l"] @ args)
    val (datum, acc) = 
      foldChannel' (fn (bytes, acc) => (parseBlame bytes)::acc) [] ins
  in 
    case datum of
         Result bytes =>
           let val ret = scan bytes in
             if ret = 0 then rev acc
             else
               raise
                 Fail ("annotate failed with return code " ^ Int.toString ret)
           end
       | _ => raise Fail "unexpected output from server"
  end

  fun tip (session as (ins, outs, greeting)) =
  let
    val () = runCommand session ["tip"]
    fun f (bytes, chunk) =
    let
      val kvs = parseChunk bytes
    in
      kvs @ chunk
    end
    val (datum, chunk) = foldChannel' f [] ins
  in
    case datum of
         Result bytes =>
           let val ret = scan bytes in
             if ret = 0 then
               let
                 val changeset = lookupChunk ("changeset", chunk)
                 val (prefix, remainder) = split #":" (Substring.full changeset)
                 val number = (Option.valOf o Int.fromString) prefix
                 val hash = Substring.string remainder
                 val tag = lookupChunk ("tag", chunk)
                 val user = lookupChunk ("user", chunk)
                 val date =
                   (Option.valOf o Date.fromString o lookupChunk) ("date", chunk)
                 val summary = lookupChunk ("summary", chunk)
               in
                 { number = number,
                   hash = hash,
                   tag = tag,
                   user = user,
                   date = date,
                   summary = summary }
               end
             else
               raise
                 Fail ("tip failed with return code " ^ Int.toString ret)
           end
       | _ => raise Fail "unexpected output from server"
  end
end
