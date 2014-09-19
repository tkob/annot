signature HG = sig
  type session
  type path
  type blame = {
    user : string,
    number : int,
    changeset : string,
    date : Date.date,
    file : path,
    lineNumber : int,
    text : string }
  type changeset = {
    number : int,
    hash : string,
    tag : string,
    user : string,
    date : Date.date,
    summary : string }

  val openSession : string -> session
  val closeSession : session -> unit
  val getRepo : session -> string
  val getEncoding : session -> string
  val annotate : session -> string list -> blame list
  val tip : session -> changeset
  val pathToString : session -> path -> string
end
