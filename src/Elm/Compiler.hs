{-# OPTIONS_GHC -Wall #-}
module Elm.Compiler
    ( version, rawVersion
    , parseDependencies, compile
    , Error, errorToString
    , Warning
    ) where

import qualified Data.Map as Map

import qualified AST.Module as Module
import qualified Compile
import qualified Elm.Compiler.Module as PublicModule
import qualified Elm.Compiler.Version as Version
import qualified Generate.JavaScript as JS
import qualified Parse.Module as Parse
import qualified Parse.Parse as Parse
import qualified Reporting.Annotation as A
import qualified Reporting.Error as Error
import qualified Reporting.Result as Result
import qualified Reporting.Warning as Warning


-- VERSION

version :: String
version =
    Version.version


rawVersion :: [Int]
rawVersion =
    Version.rawVersion


-- DEPENDENCIES

parseDependencies
    :: String
    -> Either [Error] (PublicModule.Name, [PublicModule.Name])
parseDependencies sourceCode =
  let
    (Result.Result _warnings rawResult) =
      Parse.parse sourceCode Parse.header
  in
    case rawResult of
      Result.Err msgs ->
          Left $ map (Error . A.map Error.Syntax) msgs

      Result.Ok (Module.Header names _exports imports) ->
          Right
            ( PublicModule.Name names
            , map (PublicModule.Name . fst . A.drop) imports
            )


-- COMPILATION

{-| Compiles Elm source code to JavaScript. -}
compile
    :: String
    -> String
    -> String
    -> Map.Map PublicModule.Name PublicModule.Interface
    -> ([Warning], Either [Error] (PublicModule.Interface, String))
compile user packageName source interfaces =
  let unwrappedInterfaces =
          Map.mapKeysMonotonic (\(PublicModule.Name name) -> name) interfaces

      (Result.Result warnings rawResult) =
          Compile.compile user packageName unwrappedInterfaces source
  in
      (,) (map Warning warnings) $
      case rawResult of
        Result.Ok modul ->
            Right (Module.toInterface modul, JS.generate modul)

        Result.Err errors ->
            Left (map Error errors)


-- ERRORS

newtype Error = Error (A.Located Error.Error)


errorToString :: String -> String -> Error -> String
errorToString location source (Error err) =
    Error.toString location source err


-- WARNINGS

newtype Warning = Warning (A.Located Warning.Warning)
