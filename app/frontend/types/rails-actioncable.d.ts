declare module "@rails/actioncable" {
  export interface Subscription {
    unsubscribe(): void
  }

  export interface Consumer {
    subscriptions: {
      create(
        params: Record<string, unknown>,
        callbacks: { received?(data: unknown): void; connected?(): void; disconnected?(): void }
      ): Subscription
    }
  }

  export function createConsumer(url?: string): Consumer
}
