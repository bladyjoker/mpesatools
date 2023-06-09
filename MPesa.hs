{-# LANGUAGE DeriveAnyClass #-}

module MPesa where

import Control.Monad.Identity (Identity, replicateM)
import Data.Aeson (ToJSON)
import Data.Aeson qualified as Aeson
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Lazy qualified as LBS
import Data.Csv (DefaultOrdered, ToNamedRecord, ToRecord, encode)
import Data.Csv qualified as Cassava
import Data.Text (Text)
import GHC.Generics (Generic)
import Options.Applicative (ParserInfo, command, customExecParser, fullDesc, help, helper, info, long, metavar, prefs, progDesc, short, showHelpOnEmpty, showHelpOnError, strOption, subparser, (<**>))
import Options.Applicative qualified as Cmd
import System.Directory.Internal.Prelude (exitFailure)
import System.Environment (getArgs)
import Text.Parsec qualified as Parsec

data Statement = Statement
    { customerName :: String
    , mobileNumber :: String
    , statementPeriod :: String
    , requestDate :: String
    , totalTransactions :: String
    , summary :: Summary
    , transactions :: [TransactionEntry]
    }
    deriving (Eq, Show, Ord, Generic, ToJSON)

type Summary = [SummaryEntry]

data SummaryEntry = SummaryEntry
    { transactionType :: String
    , paidIn :: String
    , paidOut :: String
    }
    deriving (Show, Eq, Ord, Generic, ToJSON, ToNamedRecord, DefaultOrdered)

data TransactionEntry = TransactionEntry
    { receiptNumber :: String
    , completionTime :: String
    , details :: String
    , txPaidIn :: String
    , withdrawn :: String
    , balance :: String
    }
    deriving (Show, Eq, Ord, Generic, ToJSON, ToNamedRecord, DefaultOrdered)

type Parser a = Parsec.Parsec ByteString () a

parseAmount :: Parser String
parseAmount = Parsec.many1 $ Parsec.choice [Parsec.digit, Parsec.char '.', Parsec.char ',', Parsec.char '-']

parseName :: Parser String
parseName = Parsec.many1 $ Parsec.choice [Parsec.letter, Parsec.char ' ']

parseMobile :: Parser String
parseMobile = Parsec.many1 Parsec.digit

parseStatement :: Parser Statement
parseStatement = do
    Parsec.string "M-PESA STATEMENT" >> Parsec.newline
    Parsec.string "SUMMARY" >> Parsec.newline
    Parsec.string "DETAILED STATEMENT" >> Parsec.newline

    totalTransactions <- Parsec.string "Total Transactions: " *> parseAmount <* Parsec.newline
    customerName <- Parsec.string "Customer Name: " *> parseName <* Parsec.newline
    mobileNumber <- Parsec.string "Mobile Number: " *> parseMobile <* Parsec.newline
    statementPeriod <- Parsec.string "Statement Period: " *> Parsec.many1 (Parsec.choice [Parsec.digit, Parsec.letter, Parsec.char ' ', Parsec.char '-']) <* Parsec.newline
    requestDate <- Parsec.string "Request Date: " *> Parsec.many1 (Parsec.choice [Parsec.digit, Parsec.letter, Parsec.char ' ']) <* Parsec.newline
    summary <- parseSummary
    transactions <- parseTransactions
    return $
        Statement
            { customerName
            , mobileNumber
            , statementPeriod
            , requestDate
            , totalTransactions
            , summary
            , transactions
            }

parseSummaryEntry :: Parser SummaryEntry
parseSummaryEntry = do
    transactionType <- Parsec.manyTill (Parsec.choice [Parsec.letter, Parsec.char ' ', Parsec.char '(', Parsec.char ')']) (Parsec.lookAhead Parsec.digit)
    paidIn <- parseAmount <* Parsec.char ' '
    paidOut <- parseAmount <* Parsec.newline
    return $ SummaryEntry{transactionType, paidIn, paidOut}

parseSummary :: Parser Summary
parseSummary = do
    Parsec.string "TRANSACTION TYPE PAID IN PAID OUT" >> Parsec.newline
    Parsec.manyTill parseSummaryEntry (Parsec.try $ Parsec.string "Receipt No. Completion Time Details Transaction Status Paid In Withdrawn Balance" >> Parsec.newline)

parseReceiptNumber :: Parser String
parseReceiptNumber = replicateM 10 (Parsec.choice [Parsec.letter, Parsec.digit])

parseDate :: Parser String
parseDate = replicateM 10 (Parsec.choice [Parsec.char '-', Parsec.digit])

parseTime :: Parser String
parseTime = replicateM 8 (Parsec.choice [Parsec.char ':', Parsec.digit])

parseTransactionEntry :: Parser TransactionEntry
parseTransactionEntry = do
    receiptNumber <- parseReceiptNumber <* Parsec.char ' '
    date <- parseDate <* Parsec.newline
    time <- parseTime <* Parsec.newline
    let completionTime = date <> " " <> time
    details <- Parsec.manyTill Parsec.anyChar (Parsec.try $ Parsec.string "Completed" >> Parsec.char ' ')
    txPaidIn <- parseAmount <* Parsec.char ' '
    withdrawn <- parseAmount <* Parsec.char ' '
    balance <- parseAmount <* Parsec.newline
    return $
        TransactionEntry
            { receiptNumber
            , completionTime
            , details
            , txPaidIn
            , withdrawn
            , balance
            }

parseTransactions :: Parser [TransactionEntry]
parseTransactions = Parsec.many1 parseTransactionEntry

-- | CLI
newtype Options = Options
    { inputTxt :: FilePath
    }

optionsParser :: Cmd.Parser Options
optionsParser =
    Options
        <$> strOption
            ( long "input"
                <> short 'i'
                <> metavar "TXT"
                <> help "Text file as outputted by mpesa-preprocess.sh tool"
            )

data Command
    = ToCsv Options
    | ToJson Options

commandP :: Cmd.Parser Command
commandP =
    subparser $
        command
            "to-csv"
            (info (ToCsv <$> optionsParser <* helper) (progDesc "Translate a .csv file from an M-PESA .pdf statement"))
            <> command
                "to-json"
                (info (ToJson <$> optionsParser <* helper) (progDesc "Translate a .json file from an M-PESA .pdf statement"))

parserInfo :: ParserInfo Command
parserInfo = info (commandP <**> helper) (fullDesc <> progDesc "M-PESA .pdf statement processing tool")

parseFromFile :: FilePath -> IO Statement
parseFromFile fp = do
    txt <- ByteString.readFile fp
    case Parsec.runParser parseStatement () fp txt of
        Left err -> print err >> exitFailure
        Right statement -> return statement

main :: IO ()
main = do
    cmd <- customExecParser (prefs (showHelpOnEmpty <> showHelpOnError)) parserInfo
    case cmd of
        ToJson opts -> do
            statement <- parseFromFile (inputTxt opts)
            LBS.putStr $ Aeson.encode statement
        ToCsv opts -> do
            statement <- parseFromFile (inputTxt opts)
            LBS.putStr $ Cassava.encodeDefaultOrderedByName (transactions statement)
