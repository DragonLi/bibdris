module Bibtex

import Control.Monad.Identity

import Lightyear.Core
import Lightyear.Combinators
import Lightyear.Strings

import Utils

record Item : Type where
  It
    :  (name : String)
    -> (value : String)
    -> Item

record Entry : Type where
  En
    :  (type : String)
    -> (ident : String)
    -> (items : List Item)
    -> Entry

lit : Char -> Char -> Parser String
lit l r = char l $> (map {f = Parser} pack . many $ satisfy (/= r)) <$ char r

quotedLiteral : Parser String
quotedLiteral = lit '"' '"' <?> "quoted literal"

bracedLiteral : Int -> Parser String
bracedLiteral n = do
    char '{'
    strings <- alternating unbraced $ bracedLiteral (n+1)
    char '}'
    return $ case n of
      0 =>        cat strings
      _ => "{" ++ cat strings ++ "}"
  where
    unbraced : Parser String
    unbraced = pack <@> many (satisfy $ \x => x /= '{' && x /= '}')

bareWord : Parser String
bareWord = pack <@> some (satisfy isAlpha) <?> "bare word"

literal : Parser String
literal = quotedLiteral <|> bracedLiteral 0 <|> bareWord

item : Parser Item
item = do
  name <- literal
  space
  char '='
  space
  value <- literal
  space
  return $ It name value

comma : Parser ()
comma = char ',' <$ space

entry : Parser Entry
entry = do
  char '@'
  type <- pack <@> some (satisfy (/= '{'))
  char '{'
  ident <- pack <@> some (satisfy (/= ','))
  char ','
  space
  items <- item `sepBy` comma
  char '}'
  space
  return $ En type ident items

bibtex : Parser (List Entry)
bibtex = space $> many entry

quote : String -> String
quote s = "\"" ++ s ++ "\""

brace : String -> String
brace s = "{" ++ s ++ "}"

unitems : String -> String -> List String -> String
unitems pre sep       []  = ""
unitems pre sep (x :: []) = pre ++ x
unitems pre sep (x :: xs) = pre ++ x ++ sep ++ unitems pre sep xs

instance Show Item where
  show (It n v) = n ++ " = " ++ brace v

instance Show Entry where
  show (En ty id xs)
    = "@" ++ ty ++ "{" ++ id ++ ",\n" ++ (unitems "  " ",\n" . map show) xs ++ "\n}\n"

format : List Entry -> String
format = unitems "" "\n" . map show

update : String -> String -> List Item -> List Item
update k v [] = It k v :: []
update k v (It k' v' :: xs) with (k == k')
  | True  = It k  v  :: xs
  | False = It k' v' :: update k v xs

find : String -> String -> List Item -> String
find k def [] = def
find k def (It k' v' :: xs) with (k == k')
  | True  = v'
  | False = find k def xs
