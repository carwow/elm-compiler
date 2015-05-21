{-# OPTIONS_GHC -Wall #-}
{-# LANGUAGE OverloadedStrings #-}
module Reporting.Report
    ( Report(Report)
    , simple
    , toString
    , toJson
    ) where

import Data.Aeson ((.=))
import qualified Data.Aeson.Types as Json

import qualified Reporting.Region as R


data Report = Report
    { _title :: String
    , _highlight :: Maybe R.Region
    , _preHint :: String
    , _postHint :: String
    }


simple :: String -> String -> String -> Report
simple title pre post =
  Report title Nothing pre post


toString :: String -> R.Region -> Report -> String -> String
toString location region (Report title highlight pre post) source =
  concat
    [ messageBar title location
    , pre ++ "\n\n"
    , grabRegion highlight region source ++ "\n"
    , if null post then "\n" else post ++ "\n\n\n"
    ]


toJson :: [Json.Pair] -> Report -> (Maybe R.Region, [Json.Pair])
toJson extraFields (Report title subregion pre post) =
  let
    fields =
      [ "tag" .= title
      , "overview" .= pre
      , "details" .= post
      ]
  in
    (subregion, fields ++ extraFields)


-- REPORT HEADER

messageBar :: String -> String -> String
messageBar tag location =
  let usedSpace = 4 + length tag + 1 + length location
  in
      "-- " ++ tag ++ " "
      ++ replicate (max 1 (80 - usedSpace)) '-'
      ++ " " ++ location ++ "\n\n"


-- REGIONS

grabRegion :: Maybe R.Region -> R.Region -> String -> String
grabRegion maybeSubRegion (R.Region start end) source =
  let
    (R.Position startLine startColumn) = start
    (R.Position endLine endColumn) = end

    (|>) = flip ($)

    relevantLines =
        lines source
          |> drop (startLine - 1)
          |> take (endLine - startLine + 1)
  in
  case relevantLines of
    [] ->
        ""

    [sourceLine] ->
        singleLineRegion startLine sourceLine $
          case maybeSubRegion of
            Nothing ->
                (0, startColumn, endColumn, length sourceLine)

            Just (R.Region s e) ->
                (startColumn, R.column s, R.column e, endColumn)

    firstLine : rest ->
        let
          filteredFirstLine =
              replicate (startColumn - 1) ' '
              ++ drop (startColumn - 1) firstLine

          filteredLastLine =
              take (endColumn) (last rest)

          focusedRelevantLines =
              filteredFirstLine : init rest ++ [filteredLastLine]

          lineNumbersWidth =
              length (show (endLine + 1))

          numberedLines =
              zipWith
                (addLineNumber maybeSubRegion lineNumbersWidth)
                [startLine - 1 .. endLine + 1]
                ("" : focusedRelevantLines ++ [""])
        in
            unlines numberedLines


addLineNumber :: Maybe R.Region -> Int -> Int -> String -> String
addLineNumber maybeSubRegion width n line =
  let
    number =
        if n < 0 then " " else show n

    spacer (R.Region start end) =
        if R.line start <= n && n <= R.line end
          then ">"
          else " "
  in
    replicate (width - length number) ' ' ++ number
    ++ "|" ++ maybe " " spacer maybeSubRegion
    ++ line


singleLineRegion :: Int -> String -> (Int, Int, Int, Int) -> String
singleLineRegion lineNum sourceLine (start, innerStart, innerEnd, end) =
  let
    w = length (show (lineNum + 1))

    number =
        addLineNumber Nothing w

    underline =
        replicate (innerStart - 1) ' '
        ++ replicate (max 1 (innerEnd - innerStart)) '^'

    (|>) = flip ($)

    trimmedSourceLine =
        sourceLine
          |> drop (start - 1)
          |> take (end - start + 1)
          |> (++) (replicate (start - 1) ' ')
  in
      unlines
        [ number (lineNum-1) ""
        , number lineNum trimmedSourceLine
        , number (lineNum+1) underline
        ]