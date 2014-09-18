structure Clerk :> CLERK = struct 
  datatype vcs = Hg

  type path = string
  type blame = path * int * string

  datatype object = O of {
    store : Store.store,
    getBlame : object -> string -> int -> blame,
    getCurrentHash : object -> string
  }

  fun getStore (O record) = #store record
  fun getBlame (obj as (O record)) = #getBlame record obj
  fun getCurrentHash (obj as (O record)) = #getCurrentHash record obj
  
  fun get obj osPath lineNumber =
  let
    val (file, lineNumber, hash) = getBlame obj osPath lineNumber
    val store = getStore obj
    val storePath = Store.stringToPath store osPath
    val message = Store.get store storePath lineNumber hash
  in
    message
  end

  fun put obj osPath lineNumber message =
  let
    val hash = getCurrentHash obj
    val store = getStore obj
    val storePath = Store.stringToPath store osPath
  in
    Store.put store storePath lineNumber hash message
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
    fun getCurrentHash (O record) =
    let
      val { hash = hash, ... } = Hg.tip session
    in
      hash
    end
  in
    O { store = store, getBlame = getBlame, getCurrentHash = getCurrentHash }
  end

  fun new Hg repo = hg repo

end
