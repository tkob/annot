structure Store :> STORE = struct
  type store = string * string (* absolute path of root and .annot dir *)
  type path = string (* path to file relative to root *)
  type hash = string

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

  fun getStoreDir dir =
  let
    val storeDir = OS.Path.concat (dir, ".annot")
  in
    if OS.FileSys.isDir storeDir handle SysErr => false then
      SOME storeDir
    else
      NONE
  end

  fun openStore rootDir =
    case getStoreDir rootDir of
         NONE => raise Fail (rootDir ^ " is not annot project dir")
       | SOME storeDir => (rootDir, storeDir)

  fun locateStore dir =
  let
    fun locateAnnot dir =
      if OS.Path.isRoot dir then
        NONE
      else
        case getStoreDir dir of
             SOME storeDir => SOME (dir, storeDir) 
           | NONE =>
               locateAnnot
               (OS.Path.mkAbsolute {path=OS.Path.parentArc, relativeTo=dir})
  in
    locateAnnot dir
  end

  fun rootDirOf (root, _) = root
  fun storeDirOf (_, store) = store

  fun stringToPath store osPath =
  let
    val pwd = OS.FileSys.getDir ()
    val abs = OS.Path.mkAbsolute {path = osPath, relativeTo = pwd}
    val rel = OS.Path.mkRelative {path = abs, relativeTo = rootDirOf store}
    val {arcs = arcs, ...} = OS.Path.fromString rel
  in
    if List.exists (fn arc => arc = OS.Path.parentArc) arcs then
      raise Fail (osPath ^ "is not a project file")
    else rel
  end

  fun get store path lineNumber hash =
  let
    val storeDir = storeDirOf store
    val line = Int.toString lineNumber
    val messageFile =
      List.foldr OS.Path.concat "" [storeDir, path, ".annot", line, hash]
    val ins = TextIO.openIn messageFile
  in
    TextIO.inputAll ins before TextIO.closeIn ins
  end

  fun put store path lineNumber hash message =
  let
    val storeDir = storeDirOf store
    val line = Int.toString lineNumber
    val messageFile =
      List.foldr OS.Path.concat "" [storeDir, path, ".annot", line, hash]
    val {dir = dir, file = file} = OS.Path.splitDirFile messageFile
    val {arcs = arcs, ...} = OS.Path.fromString dir
    fun exists path = OS.FileSys.access (path, [])
    fun mkdirs (parent, []) = ()
      | mkdirs (parent, arc::arcs) =
        let val path = OS.Path.concat (parent, arc) in
          if exists path then
            if OS.FileSys.isDir path then
              mkdirs (path, arcs)
            else
              raise Fail ""
          else
            (OS.FileSys.mkDir path; mkdirs (path, arcs))
        end
  in
    mkdirs (storeDir, arcs);
    let
      val outs = TextIO.openOut messageFile
    in
      TextIO.output (outs, message);
      TextIO.closeOut outs
    end
  end
end
