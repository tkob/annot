signature HG = sig
  type session
  type blame = {
    user : string,
    number : int,
    changeset : string,
    date : Date.date,
    file : string,
    lineNumber : int,
    text : string }

  val openSession : string -> session
  val closeSession : session -> unit
  val getRepo : session -> string
  val getEncoding : session -> string
  val annotate : session -> string list -> blame list
end
