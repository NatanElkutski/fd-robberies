import { Component, type ErrorInfo, type ReactNode } from 'react';

interface Props {
  onError: (error: Error) => void;
  children: ReactNode;
}

/**
 * Catches render errors so a UI bug never leaves the player with an invisible, focused page:
 * the error is reported (Lua releases focus) and the UI remounts on the next message.
 */
export class ErrorBoundary extends Component<Props, { failed: boolean }> {
  state = { failed: false };

  static getDerivedStateFromError() {
    return { failed: true };
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    console.error('[fd-robberies] UI error', error, info.componentStack);
    this.props.onError(error);
    // try rendering again (the next Lua message usually carries fresh state)
    window.setTimeout(() => this.setState({ failed: false }), 0);
  }

  render() {
    return this.state.failed ? null : this.props.children;
  }
}
