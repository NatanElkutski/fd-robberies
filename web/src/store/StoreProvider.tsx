import { createContext, useContext, useReducer, type Dispatch, type ReactNode } from 'react';
import { reducer } from './reducer';
import { initialState, type Action, type State } from './state';

const StateContext = createContext<State>(initialState);
const DispatchContext = createContext<Dispatch<Action>>(() => undefined);

export function StoreProvider({ children }: { children: ReactNode }) {
  const [state, dispatch] = useReducer(reducer, initialState);
  return (
    <StateContext.Provider value={state}>
      <DispatchContext.Provider value={dispatch}>{children}</DispatchContext.Provider>
    </StateContext.Provider>
  );
}

export const useStore = (): State => useContext(StateContext);
export const useDispatch = (): Dispatch<Action> => useContext(DispatchContext);
