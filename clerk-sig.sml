signature CLERK = sig
  datatype vcs = Hg
  type object

  val new : vcs -> string option -> object
  val delete : object -> unit
  val get : object -> string -> int -> string option
  val put : object -> string -> int -> string -> unit
  val list : object -> string -> (int * string) list
end
