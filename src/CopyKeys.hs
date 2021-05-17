{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE TypeApplications #-}

module CopyKeys
  ( -- Effects
    Librarian (..),
    readInventory,
    -- Interpreters
    librarianIO,
    librarianFake,
    -- Types
    Args (..),
    Hosts (..),
    -- Run Interpreter
    main,
  )
where

import Data.Aeson
import Data.Aeson.Types
import qualified Data.ByteString.Lazy as BSL
import qualified Data.ByteString.Lazy.Char8 as C
import Data.Coerce
import Data.Proxy
import qualified Data.Text as T
import GHC.TypeLits
import Options.Generic (Generic, ParseRecord, getRecord)
import Polysemy (Embed, Member, Members, Sem, embed, interpret, makeSem, run, runM)
import Polysemy.Internal (send)
import Polysemy.Internal.Union (MemberWithError)
import Shower (printer)
import System.IO (hGetContents, stdin)
import System.Process.Typed (proc, readProcess)

-- | The Librarian Effect, for interacting with Ansible Inventories
data Librarian m a where
  ReadInventory :: FilePath -> Librarian m BSL.ByteString

-- | Hosts returned from an Inventory
-- | `pat` is the host pattern
data Hosts pat where
  Hosts :: KnownSymbol pat => {hosts :: Maybe [Value]} -> Hosts pat

deriving instance KnownSymbol pat => Show (Hosts pat)

-- | When parsing JSON from ansible-inventory output,
-- | use the `pat` symbol as a host pattern
instance KnownSymbol p => FromJSON (Hosts p) where
  parseJSON = withObject "output" $ \o -> do
    maybeGroup <- o .:? T.pack (symbolVal (Proxy :: Proxy p))
    case maybeGroup of
      Just group -> do
        hosts <- group .: "hosts"
        return $ Hosts {hosts}
      Nothing -> return $ Hosts Nothing

-- | Execute "ansible-inventory --list" with an inventory path
runAnsibleInventory :: FilePath -> IO BSL.ByteString
runAnsibleInventory path = do
  (code, stdout, stderr) <- readProcess $ proc "ansible-inventory" ["-i", path, "--list"]
  return stdout

-- | Read an Ansible inventory.
readInventory :: MemberWithError Librarian r => FilePath -> Sem r BSL.ByteString
readInventory path = send (ReadInventory path :: Librarian (Sem r) BSL.ByteString)

-- | Interpreter for Librarian in IO
librarianIO :: Member (Embed IO) r => Sem (Librarian ': r) a -> Sem r a
librarianIO = interpret $ \case
  -- just read the file!
  ReadInventory path -> embed $ runAnsibleInventory path

-- | Interpreter for Librarian that lies
librarianFake :: Sem (Librarian ': r) a -> Sem r a
librarianFake = interpret $ \case
  -- what? a banana?
  ReadInventory _ -> pure "banana"

-- | Argument Parser
data Args where
  Args ::
    -- | inventory
    FilePath ->
    -- | group
    T.Text ->
    Args
  deriving (Generic, Show)

instance ParseRecord Args

main :: IO ()
main = do
  -- read password
  hGetContents stdin >>= printer
  -- parse arguments
  Args path group <- getRecord "copy-keys"
  -- io interpreter
  ioResult <- runM . librarianIO $ readInventory path
  case someSymbolVal $ T.unpack group of
    SomeSymbol (_ :: Proxy groupProxy) ->
      let error = print "failed"
          hosts = decode @(Hosts groupProxy) ioResult
       in maybe error printer hosts
  -- "mock" interpreter
  let pureResult = run . librarianFake $ readInventory path
   in printer pureResult
