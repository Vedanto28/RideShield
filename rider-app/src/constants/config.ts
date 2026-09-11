// ============================================================
// RideShield — Environment Configuration
// ============================================================
// Change API_BASE_URL and SOCKET_URL when pointing to a real backend.
// On physical device, replace with your machine's local IP.
// e.g. http://192.168.1.100:4000


import Constants from 'expo-constants';

// Automatically detect host IP from Expo Metro bundler
const getDevHostIp = (): string => {
  try {
    const hostUri = Constants.expoConfig?.hostUri || (Constants as any).manifest2?.extra?.expoGo?.debuggerHost;
    if (hostUri) {
      const ip = hostUri.split(':')[0];
      if (ip && ip !== 'localhost' && ip !== '127.0.0.1') {
        return ip;
      }
    }
  } catch (err) {
    // Fallback if Constants is unavailable
  }
  return '192.168.1.7';
};

export function getApiBaseUrl(): string {
  if (Config.OVERRIDE_BASE_URL) return Config.OVERRIDE_BASE_URL.replace(/\/+$/, '');
  return `http://${getDevHostIp()}:8000`;
}

export function getSocketUrl(): string {
  if (Config.OVERRIDE_BASE_URL) return Config.OVERRIDE_BASE_URL.replace(/\/+$/, '');
  return `http://${getDevHostIp()}:8000`;
}

export const Config = {
  // Optional override URL (e.g. tunnel URL like 'https://xxx.loca.lt' or specific backend host)
  // Leave empty to auto-detect Metro host IP or fallback to local IP
  OVERRIDE_BASE_URL: '',

  get API_BASE_URL(): string {
    return getApiBaseUrl();
  },

  get SOCKET_URL(): string {
    return getSocketUrl();
  },

  // Feature flags
  USE_MOCK_AUTH: false,        // set false when real auth backend is ready
  USE_MOCK_PAYMENT: false,     // set false when UPI provider is integrated
  USE_MOCK_RIDES: false,       // set false when rides API is ready
  ENABLE_DEV_CRASH_TRIGGER: true, // dev-only: simulate CRASH_DETECTED event

  // Telemetry
  TELEMETRY_EMIT_INTERVAL_MS: 1000, // how often to emit telemetry to backend
  TELEMETRY_SENSOR_INTERVAL_MS: 200, // how often sensors update internally

  // Shift premium
  DAILY_PREMIUM_INR: 5,

  // Shift premium tiers
  PREMIUM_TIERS: [
    { premium: 3, coverage: 10000, label: 'Starter' },
    { premium: 5, coverage: 25000, label: 'Standard' },
    { premium: 7, coverage: 50000, label: 'Plus' },
    { premium: 10, coverage: 100000, label: 'Premium' },
  ],

  // WhatsApp Bot number (E.164 format without '+' or spaces for wa.me URL compatibility)
  WHATSAPP_BOT_PHONE_NUMBER: '15550101234',
};
