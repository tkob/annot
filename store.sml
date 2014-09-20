structure Store :> STORE = struct
  type store = string * string (* absolute path of root and .annot dir *)
  type path = string (* path to file relative to root *)
  type hash = string

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
  let
    val rootDir =
      OS.Path.mkAbsolute {path = rootDir, relativeTo = OS.FileSys.getDir ()}
  in
    case getStoreDir rootDir of
         NONE => raise Fail (rootDir ^ " is not annot project dir")
       | SOME storeDir => (rootDir, storeDir)
  end

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
               (OS.Path.mkAbsolute {path = OS.Path.parentArc, relativeTo = dir})
  in
    locateAnnot
      (OS.Path.mkAbsolute {path = dir, relativeTo = OS.FileSys.getDir ()})
  end

  fun rootDirOf (root, _) = root
  fun storeDirOf (_, store) = store

  fun closeStore store = ()

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

  fun exists path = OS.FileSys.access (path, [])

  fun get store path lineNumber hash =
  let
    val storeDir = storeDirOf store
    val line = Int.toString lineNumber
    val messageFileAbs =
      List.foldr OS.Path.concat "" [storeDir, "tree", path, ".annot", line, hash]
  in
    if exists messageFileAbs then
      let
        val ins = TextIO.openIn messageFileAbs
      in
        SOME (TextIO.inputAll ins) before TextIO.closeIn ins
      end
    else NONE
  end

  fun put store path lineNumber hash message =
  let
    val storeDir = storeDirOf store
    val line = Int.toString lineNumber
    val messageFileRel = (* path to message file relative to store dir *)
      List.foldr OS.Path.concat "" ["tree", path, ".annot", line, hash]
    val messageFileAbs = OS.Path.concat (storeDir, messageFileRel)
    val {dir = dir, ...} = OS.Path.splitDirFile messageFileRel
    val {arcs = arcs, ...} = OS.Path.fromString dir
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
      val outs = TextIO.openOut messageFileAbs
    in
      TextIO.output (outs, message);
      TextIO.closeOut outs
    end
  end
end
