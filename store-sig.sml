signature STORE = sig
  type store
  type path

  val openStore : string -> store
  val locateStore : string -> store option

  val stringToPath : store -> string -> path

  val get : store -> path -> int -> string -> string
  val put : store -> path -> int -> string -> string -> unit
end
