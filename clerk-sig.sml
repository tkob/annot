signature CLERK = sig
  datatype vcs = Hg
  type object

  val new : vcs -> string -> object
  val get : object -> string -> int -> string
  val put : object -> string -> int -> string -> unit
end
