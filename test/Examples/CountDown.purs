module Test.Examples.CountDown where

import Prelude

import Control.Monad.State (class MonadState, get, put, state)
import Control.Plus (empty)
import Data.Maybe (Maybe, maybe)
import Data.Tuple (Tuple(..))
import Effect (Effect)
import Effect.Aff (Aff, Milliseconds(..))
import Effect.Aff as Aff
import Effect.Aff.Class (liftAff)
import Effect.Exception (throw)
import Marionette.Controllers.Monadic (MarionetteT, sendMsg)
import Marionette.Controllers.Monadic as Monadic
import Marionette.ReactBasic (useMarionette)
import React.Basic.DOM (text)
import React.Basic.DOM.Client (createRoot, renderRoot)
import React.Basic.DOM.Simplified.Generated as R
import React.Basic.Events (handler_)
import React.Basic.Hooks (Component, component, (/\))
import React.Basic.Hooks as React
import Unsafe.Coerce (unsafeCoerce)
import Web.DOM (Element)
import Web.DOM.NonElementParentNode (getElementById)
import Web.HTML (window)
import Web.HTML.HTMLDocument (toNonElementParentNode)
import Web.HTML.Window (document)

--------------------------------------------------------------------------------
--- Model
--------------------------------------------------------------------------------

data State
  = Init
  | CountingDown Int
  | LaunchSpaceShip

derive instance Eq State

data Msg
  = Start
  | Restart
  | Tick

--------------------------------------------------------------------------------
--- Control
--------------------------------------------------------------------------------

control :: Msg -> MarionetteT Msg State Aff Unit
control = case _ of
  Start -> do
    get >>= case _ of
      Init -> do
        put $ CountingDown 10
        sendMsg Tick

      _ -> pure unit

  Restart -> do
    modifyAnd case _ of
      LaunchSpaceShip -> CountingDown 10 /\ sendMsg Tick
      s -> s /\ pure unit

    -- get >>= case _ of
    --   LaunchSpaceShip -> do
    --     put $ CountingDown 10
        


  Tick -> do
    get >>= case _ of
      CountingDown 1 -> put LaunchSpaceShip

      CountingDown n -> do
        put $ CountingDown (n - 1)
        liftAff $ Aff.delay (Milliseconds 1000.0)
        sendMsg Tick

      _ -> pure unit

modifyAnd :: forall s m a. MonadState s m => (s -> Tuple s (m a)) -> m a  
modifyAnd f = state (\s -> let (Tuple s' ma) = f s in Tuple ma s')
  >>= identity

noOp :: forall m a. Applicative m => a -> Tuple a (m Unit)
noOp x = Tuple x (pure unit)

x :: forall m. Applicative m => m Unit
x = pure unit

--------------------------------------------------------------------------------
--- View
--------------------------------------------------------------------------------

mkApp :: Component {}
mkApp = component "App" \_ -> React.do
  state /\ act <- useMarionette
    { initialState: Init
    , controller: Monadic.mkController control
    }

  pure $
    R.div'
      [ R.h1' [ text "CountDown" ]

      , case state of
          Init -> R.div'
            [ R.div' [ text "ready to start?" ]
            , R.button { onClick: handler_ $ act Start }
                [ text "start" ]
            ]

          CountingDown n -> R.div'
            [ text ("Counting... " <> show n) ]

          LaunchSpaceShip -> R.div'
            [ R.div' [ text "boom!" ]
            , R.button { onClick: handler_ $ act Restart }
                [ text "restart" ]
            ]
      ]

--------------------------------------------------------------------------------
--- Main
--------------------------------------------------------------------------------

main :: Effect Unit
main = do
  elem <- elemById "root"
    >>= maybe (throw "Could not find container element") pure

  reactRoot <- createRoot elem
  app <- mkApp
  renderRoot reactRoot (app {})

--------------------------------------------------------------------------------
--- Util
--------------------------------------------------------------------------------

elemById :: String -> Effect (Maybe Element)
elemById id = do
  doc <- document =<< window
  getElementById id $ toNonElementParentNode doc