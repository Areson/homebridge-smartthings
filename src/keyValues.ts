export const WEBHOOK_URL = process.env.WEBHOOK_URL ? process.env.WEBHOOK_URL : 'https://stwh.kleinstudios.net/api/';
export const WH_CONNECT_RETRY_MINUTES = 1;

// Default discovery retry settings (used for initial device discovery and location ignore lists).
// These can be overridden in the platform config via:
//   DiscoveryRetryAttempts (use -1 for infinite retries)
//   DiscoveryRetryInitialDelaySeconds
//   DiscoveryRetryMaxDelaySeconds
export const DISCOVERY_RETRY_ATTEMPTS = 6;
export const DISCOVERY_RETRY_INITIAL_DELAY_SECONDS = 5;
export const DISCOVERY_RETRY_MAX_DELAY_SECONDS = 60;

export async function wait(seconds):Promise<void> {
  return new Promise(resolve => {
    setTimeout(() => resolve(), seconds * 1000);
  });
}