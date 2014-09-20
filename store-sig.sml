signature STORE = sig
  type store
  type path

  val openStore : string -> store
  val locateStore : string -> store option
  val rootDirOf : store -> string

  val stringToPath : store -> string -> path

  val get : store -> path -> int -> string -> string option
  val put : store -> path -> int -> string -> string -> unit
end
