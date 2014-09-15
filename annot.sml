fun locateProjectRoot () =
let
  fun locateAnnot dir =
    if OS.Path.isRoot dir then
      NONE
    else
      let
        val annot = OS.Path.concat (dir, ".annot")
      in
        if OS.FileSys.isDir annot handle SysErr => false then
          SOME dir
        else
          locateAnnot
            (OS.Path.mkAbsolute {path=OS.Path.parentArc, relativeTo=dir})
      end
in
  locateAnnot (OS.FileSys.getDir ())
end
