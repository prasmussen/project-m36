{-# LANGUAGE GADTs #-}
module TutorialD.Interpreter.TransactionGraphOperator where
import TutorialD.Interpreter.Base
import Text.Megaparsec.Text
import Text.Megaparsec
import ProjectM36.TransactionGraph hiding (autoMergeToHead)
import ProjectM36.Client
import ProjectM36.Base
import Data.Functor

data ConvenienceTransactionGraphOperator = AutoMergeToHead MergeStrategy HeadName
                                         deriving (Show)

convenienceTransactionGraphOpP :: Parser ConvenienceTransactionGraphOperator
convenienceTransactionGraphOpP = autoMergeToHeadP

autoMergeToHeadP :: Parser ConvenienceTransactionGraphOperator
autoMergeToHeadP = do
  reserved ":automergetohead"
  AutoMergeToHead <$> mergeTransactionStrategyP <*> identifier

jumpToHeadP :: Parser TransactionGraphOperator
jumpToHeadP = do
  reservedOp ":jumphead"
  JumpToHead <$> identifier

jumpToTransactionP :: Parser TransactionGraphOperator
jumpToTransactionP = do
  reservedOp ":jump"
  JumpToTransaction <$> uuidP
  
walkBackToTimeP :: Parser TransactionGraphOperator  
walkBackToTimeP = do
  reservedOp ":walkbacktotime"
  WalkBackToTime <$> utcTimeP

branchTransactionP :: Parser TransactionGraphOperator
branchTransactionP = do
  reservedOp ":branch"
  Branch <$> identifier

deleteBranchP :: Parser TransactionGraphOperator
deleteBranchP = do
  reserved ":deletebranch"
  DeleteBranch <$> identifier

commitTransactionP :: Parser TransactionGraphOperator
commitTransactionP = do
  reservedOp ":commit"
  pure Commit 

rollbackTransactionP :: Parser TransactionGraphOperator
rollbackTransactionP = do
  reservedOp ":rollback"
  return Rollback

showGraphP :: Parser ROTransactionGraphOperator
showGraphP = do
  reservedOp ":showgraph"
  return ShowGraph
  
mergeTransactionStrategyP :: Parser MergeStrategy
mergeTransactionStrategyP = (reserved "union" $> UnionMergeStrategy) <|>
                            (do
                                reserved "selectedbranch"
                                branch <- identifier
                                pure (SelectedBranchMergeStrategy branch)) <|>
                            (do
                                reserved "unionpreferbranch"
                                branch <- identifier
                                pure (UnionPreferMergeStrategy branch))
  
mergeTransactionsP :: Parser TransactionGraphOperator
mergeTransactionsP = do
  reservedOp ":mergetrans"
  strategy <- mergeTransactionStrategyP
  headA <- identifier
  headB <- identifier
  pure (MergeTransactions strategy headA headB)

transactionGraphOpP :: Parser TransactionGraphOperator
transactionGraphOpP = 
  jumpToHeadP
  <|> jumpToTransactionP
  <|> walkBackToTimeP
  <|> branchTransactionP
  <|> deleteBranchP
  <|> commitTransactionP
  <|> rollbackTransactionP
  <|> mergeTransactionsP

roTransactionGraphOpP :: Parser ROTransactionGraphOperator
roTransactionGraphOpP = showGraphP



{-
-- for interpreter-specific operations
interpretOps :: U.UUID -> DisconnectedTransaction -> TransactionGraph -> String -> (DisconnectedTransaction, TransactionGraph, TutorialDOperatorResult)
interpretOps newUUID trans@(DisconnectedTransaction _ context) transGraph instring = case parse interpreterOps "" instring of
  Left _ -> (trans, transGraph, NoActionResult)
  Right ops -> case ops of
    Left contextOp -> (trans, transGraph, (evalContextOp context contextOp))
    Right graphOp -> case evalGraphOp newUUID trans transGraph graphOp of
      Left err -> (trans, transGraph, DisplayErrorResult $ T.pack (show err))
      Right (newDiscon, newGraph, result) -> (newDiscon, newGraph, result)
-}

evalROGraphOp :: SessionId -> Connection -> ROTransactionGraphOperator -> IO (Either RelationalError Relation)
evalROGraphOp sessionId conn ShowGraph = transactionGraphAsRelation sessionId conn

evalConvenienceGraphOp :: SessionId -> Connection -> ConvenienceTransactionGraphOperator -> IO (Either RelationalError ())
evalConvenienceGraphOp sessionId conn (AutoMergeToHead strat head') = autoMergeToHead sessionId conn strat head'