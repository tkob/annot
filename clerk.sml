structure Clerk :> CLERK = struct 
  datatype vcs = Hg

  type path = string
  type blame = path * int * string

  datatype object = O of {
    store : Store.store,
    getBlame : object -> string -> int -> blame,
    getAllBlames : object -> string -> blame list,
    getCurrentHash : object -> string
  }

  fun getStore (O record) = #store record
  fun getBlame (obj as (O record)) = #getBlame record obj
  fun getAllBlames (obj as (O record)) = #getAllBlames record obj
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

  fun list obj osPath =
  let
    val blames = getAllBlames obj osPath
    val store = getStore obj
    fun get (file, lineNumber, hash) =
    let
      val storePath = Store.stringToPath store osPath
      val message = Store.get store storePath lineNumber hash
    in
      Option.map (fn message => (lineNumber, message)) message
    end
  in
    List.mapPartial get blames
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
    fun getAllBlames (O record) osPath =
    let
      val blames = Hg.annotate session [osPath]
      fun adapt blame =
        (#file blame, #lineNumber blame, #changeset blame)
    in
      List.map adapt blames
    end
    fun getCurrentHash (O record) =
    let
      val { hash = hash, ... } = Hg.tip session
    in
      hash
    end
  in
    O { store = store,
        getBlame = getBlame,
        getAllBlames = getAllBlames,
        getCurrentHash = getCurrentHash }
  end

  fun new Hg repo = hg repo

end
