structure Clerk :> CLERK = struct 
  datatype vcs = Hg

  type blame = {
    originalPath : string,
    originalLineNumber : int,
    hash : string
  }

  datatype object = O of {
    store : Store.store,
    delete : object -> unit,
    getBlame : object -> string -> int -> blame,
    getAllBlames : object -> string -> blame list,
    getCurrentHash : object -> string
  }

  fun getStore (O record) = #store record
  fun getBlame (obj as (O record)) = #getBlame record obj
  fun getAllBlames (obj as (O record)) = #getAllBlames record obj
  fun getCurrentHash (obj as (O record)) = #getCurrentHash record obj

  fun delete (obj as (O record)) = (#delete record) obj
  
  fun get obj osPath lineNumber =
  let
    val {originalPath, originalLineNumber, hash} = getBlame obj osPath lineNumber
    val store = getStore obj
    val storePath = Store.stringToPath store originalPath
    val message = Store.get store storePath originalLineNumber hash
  in
    message
  end

  fun put obj osPath lineNumber message =
  let
    val {originalPath, originalLineNumber, hash} = getBlame obj osPath lineNumber
    val store = getStore obj
    val storePath = Store.stringToPath store originalPath
  in
    Store.put store storePath originalLineNumber hash message
  end

  fun numberList l start =
  let
    fun loop [] n acc = List.rev acc
      | loop (x::xs) n acc =
        loop xs (n + 1) ((n, x)::acc)
  in
    loop l start []
  end

  fun list obj osPath =
  let
    val blames = getAllBlames obj osPath
    val numberedBlames = numberList blames 1
    val store = getStore obj
    fun get (lineNumber, {originalPath, originalLineNumber, hash}) =
    let
      val storePath = Store.stringToPath store originalPath
      val message = Store.get store storePath originalLineNumber hash
    in
      Option.map (fn message => (lineNumber, message)) message
    end
  in
    List.mapPartial get numberedBlames
  end

  fun hg dirOpt =
  let
    val store =
      case dirOpt of
           SOME dir => Store.openStore dir
         | NONE =>
             let val storeOpt = Store.locateStore "." in
               case storeOpt of
                    SOME store => store
                  | NONE => raise Fail "annot project dir not found"
             end
    val session = Hg.openSession (Store.rootDirOf store)
    fun delete (O object) =
      (Store.closeStore (#store object); Hg.closeSession session)
    fun getBlame (O record) osPath lineNumber : blame =
    let
      val blames = Hg.annotate session [osPath]
      val blame = List.nth (blames, lineNumber - 1)
    in
      { originalPath = Hg.pathToString session (#file blame),
        originalLineNumber = #lineNumber blame,
        hash = #changeset blame }
    end
    fun getAllBlames (O record) osPath : blame list =
    let
      val blames = Hg.annotate session [osPath]
      fun adapt blame =
        { originalPath = Hg.pathToString session (#file blame),
          originalLineNumber = #lineNumber blame,
          hash = #changeset blame }
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
        delete = delete,
        getBlame = getBlame,
        getAllBlames = getAllBlames,
        getCurrentHash = getCurrentHash }
  end

  fun new Hg repo = hg repo

end
