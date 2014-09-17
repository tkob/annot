structure Clerk = struct 
  type path = string
  type blame = path * int * string

  datatype object = O of {
    store : Store.store,
    getBlame : object -> string -> int -> blame
  }

  fun getStore (O record) = #store record
  fun getBlame (obj as (O record)) = #getBlame record obj
  
  fun get obj osPath lineNumber =
  let
    val (file, lineNumber, hash) = getBlame obj osPath lineNumber
    val store = getStore obj
    val storePath = Store.stringToPath store osPath
    val message = Store.get store storePath lineNumber hash
  in
    message
  end

  fun hg repo =
  let
    val store = Store.openStore repo
    val session = Hg.openSession repo
    fun getBlame (O record) osPath lineNumber =
    let
      val blames = Hg.annotate session [osPath]
      val blame = List.nth (blames, lineNumber - 1)
    in
      (#file blame, #lineNumber blame, #changeset blame)
    end
  in
    O { store = store, getBlame = getBlame }
  end
end

(*
fun test () = 
let
  val obj = Clerk.hg "test/fixture/repo1"
  val message = Clerk.get obj "test/fixture/repo1/a.txt" 1
in
  print message;
  print "\n"
end
  
val _ = test ()
*)
