package scala.dot
 
import scala.util.parsing.combinator.syntactical.StdTokenParsers
import scala.util.parsing.combinator.lexical.StdLexical
import scala.collection.immutable._
 
import scala.util.binding.frescala
import util.parsing.combinator.{PackratParsers, ImplicitConversions}
 
class Parsing extends StdTokenParsers with frescala.BindingParsers with PackratParsers with NominalBindingSyntax with ImplicitConversions {
	theParser =>
	
  type Tokens = StdLexical; val lexical = new StdLexical
  lexical.delimiters ++= List("\\",".",":","=","{","}","(", ")","=>",";","&","|","..","()")
  lexical.reserved ++= List("val", "new", "type", "trait","Any","Nothing")
 
  type P[T] = PackratParser[T]

  val logging = true;

  private var indent = ""
  def l[T](p: => P[T])(name: String): P[T] = Parser{ in =>
   if (logging) println(indent +"trying "+ name +" at:\n"+ in.pos.longString)
    val old = indent; indent += " "
    val r = p(in)
    indent = old

    if (logging) println(indent+name +" --> "+ r)
    r
  }

  def chainl2[T, U](first: => Parser[T], p: => Parser[U], q: => Parser[(T, U) => T]): Parser[T] 
    = first ~ rep1(q ~ p) ^^ {
        case x ~ xs => xs.foldLeft(x){(_, _) match {case (a, f ~ b) => f(a, b)}}
      }
 
  import Terms._
  import Types.{Sel=>TSel, Fun=>FunT, _}
 
  def BindingParser(env: Map[String, Name]): BindingParser = new BindingParser(env)
  class BindingParser(env: Map[String, Name]) extends BindingParserCore(env) {
    lazy val value: P[Value] =
      ( bound(ident) ^^ {case x => Var(x)}
      | "\\" ~> "(" ~> bind(ident) >> {x => (":" ~> tpe <~ ")" <~ "=>") ~ under(x)(_.term)} ^^ {case tpe ~ body => Fun(tpe, body) }
      | "()" ^^^ Unit
      ) 
 
    lazy val term: P[Term] =
      l( chainl2(term0, term, success(App(_: Term, _: Term)))
       | chainl2(term0, termLabelRef, "." ^^^ (Sel(_, _)))
       | "(" ~> term <~")"
       | term0
       ) ("term")
 
    lazy val term0: P[Term] = (
				l( value ) ("value")
      | l ("val" ~> bind(ident) >> {x => ("=" ~> "new" ~> tpe) ~ under[(Members.ValDefs, Term)](x)(_.ctor)(pairBinders(listBinders(memDefHasBinders), termHasBinders))} ^^ {case tpe ~ args_scope /*if tpe.isConcrete*/ => New(tpe, args_scope)}) ("ctor" ) 
		)
    
    lazy val path: P[Term] = term //^? {case p if p.isPath => p}
 
    lazy val ctor: P[(Members.ValDefs, Term)] = ("{" ~> valMems <~ "}") ~ (";" ~> term) ^^ {case ms ~ sc => (ms, sc)}
 
    lazy val labelV: P[TermLabel] = "val" ~> termLabelRef
		def termLabelRef: P[TermLabel] = ident ^^ TermLabel
		def typeLabelRef: P[TypeLabel] = ident ^^ TypeLabel

    lazy val valMems: P[Members.ValDefs] = repsep[Members.ValueDef]((labelV <~ "=") ~ value ^^ {case l ~ v => Members.ValueDef(l, v)}, ";")
 
		// lazy val valDecl: P[Members.TypeDecl] = 
		//       l( (("val" ~> termLabelRef <~ ":") ~ tpe) ^^ {case l ~ cls => Members.TypeDecl(l, cls)} )("valDecl")
		// 
		//     lazy val typeDecl: P[Members.TypeBoundsDecl] =
		//       l( (("type" ~> typeLabelRef <~ ":") ~ typeBounds) ^^ {case l ~ cls => Members.TypeBoundsDecl(l, cls)})("typeDecl")

//    lazy val memDecls: P[List[Members.Decl[Level, Entity]]] = repsep[Members.Decl[Entity, Level]](memDecl, ";")

    lazy val memDecl: P[Members.Decl[Level, Entity]] =
			l((("type" ~> typeLabelRef <~ "=") ~ typeSugar) ^^ {case l ~ cls => Members.TypeBoundsDecl(l, cls)}
      | (("type" ~> typeLabelRef <~ ":") ~ typeBounds) ^^ {case l ~ cls => Members.TypeBoundsDecl(l, cls)}
//			| (( "type" ~> labelRef[Levels.Type] <~ "=" ~ typeSugar) ^^ { case bound => Members.Decl[TypeBounds](bound, bound)})
      | (("val" ~> termLabelRef <~ ":") ~ tpe) ^^ {case l ~ cls => Members.TypeDecl(l, cls)}
      )("memDecl")

    lazy val memDecls: P[Members.Decls] = repsep[Members.Decl[Level, Entity]](memDecl, ";")
		

		// lazy val valDecls = repsep(valDecl, ";")		
		// lazy val typeDecls = repsep(typeDecl, ";")
 
    lazy val tpe: P[Type] =
    l( l(chainl2(tpe0, refinement, success(Refine(_, _))) )("trefine")
     | l(chainl2(tpe0, tpe, "=>" ^^^ (FunT(_, _))) )("tfun")
     | l(chainl2(tpe0, tpe, "&" ^^^ (Intersect(_, _))) )("tand")
     | l(chainl2(tpe0, tpe, "|" ^^^ (Union(_, _))) )("tor")
     | tpe0
     )("tpe")
 
    lazy val tpe0: P[Type] =
    l(l(path ^^ {case Terms.Sel(tgt, TermLabel(l)) => TSel(tgt, TypeLabel(l))} )("tsel")
     | l("Any" ^^^ Top )("top")
     | l("Nothing" ^^^ Bottom )("bot")
     | "(" ~> tpe <~")"
     )("tpe0")
 
    lazy val refinement: P[\\[Members.Decls]] = 
			l("{" ~> bind(ident) >> {x => "=>" ~> under[Members.Decls](x)(_.memDecls) <~ "}"})("refinement") // (Parsing.this.listBinders(memDeclHasBinders))
 
    lazy val typeBounds: P[TypeBounds] = l((tpe <~ "..") ~ tpe ^^ {case lo ~ hi => TypeBounds(lo, hi)})("typeBounds")

		lazy val typeSugar: P[TypeBounds] = l((tpe ^^ {(x: Type) => TypeBounds(x, x)} ))("typeBoundsSugar")
  }
  
  object Parser extends BindingParser(HashMap.empty)
}
 
object TestParser extends Parsing with PrettyPrinting with Application {
  def parse(in: String) = phrase(Parser.term)(new lexical.Scanner(in))

  import scala.io.Source

  val source = Source.fromPath("../dot.txt")
  val lines = source.getLines().mkString
  println("parsing: " + lines)
  println("******************")
	val result = parse(lines).get;
	println(result);
  println(result.prettyPrint)
}