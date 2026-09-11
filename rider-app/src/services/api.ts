// ============================================================
// RideShield — API Service (axios base instance)
// ============================================================
// All backend HTTP calls go through this instance.
// Set Config.API_BASE_URL in src/constants/config.ts to point at your backend.

import { Config, getApiBaseUrl } from '../constants/config';
import { storage } from '../utils/storage';

const TOKEN_KEY = 'rideshield_auth_token';

// Minimal fetch-based API client (no axios to keep dependencies lean)
class ApiClient {
  private get baseURL(): string {
    return getApiBaseUrl();
  }

  private handleNetworkError(err: any): Error {
    const rawMsg = err?.message || String(err);
    if (
      rawMsg.includes('fetch failed') ||
      rawMsg.includes('ConnectException') ||
      rawMsg.includes('Network request failed') ||
      rawMsg.includes('Failed to connect') ||
      rawMsg.includes('NetworkError')
    ) {
      return new Error(`Unable to connect to backend server at ${this.baseURL}. Please ensure backend is running and reachable on your network.`);
    }
    return err instanceof Error ? err : new Error(rawMsg);
  }

  private async getHeaders(): Promise<Record<string, string>> {
    const token = await storage.getItem(TOKEN_KEY);
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      Accept: 'application/json',
      'bypass-tunnel-reminder': 'true',
    };
    if (token) {
      headers['Authorization'] = `Bearer ${token}`;
    }
    return headers;
  }

  async get<T>(path: string): Promise<T> {
    try {
      const headers = await this.getHeaders();
      const response = await fetch(`${this.baseURL}${path}`, {
        method: 'GET',
        headers,
      });
      if (!response.ok) {
        const err = await response.json().catch(() => ({}));
        const msg = err?.detail 
          ? (typeof err.detail === 'object' ? JSON.stringify(err.detail) : err.detail)
          : (err?.message ? (typeof err.message === 'object' ? JSON.stringify(err.message) : err.message) : `HTTP ${response.status}`);
        throw new Error(msg);
      }
      return response.json();
    } catch (err: any) {
      throw this.handleNetworkError(err);
    }
  }

  async post<T>(path: string, body?: unknown, timeoutMs?: number): Promise<T> {
    const headers = await this.getHeaders();
    const controller = timeoutMs ? new AbortController() : undefined;
    const timer = timeoutMs
      ? setTimeout(() => controller!.abort(), timeoutMs)
      : undefined;
    let response: Response;
    try {
      try {
        response = await fetch(`${this.baseURL}${path}`, {
          method: 'POST',
          headers,
          body: body ? JSON.stringify(body) : undefined,
          signal: controller?.signal,
        });
      } catch (err: any) {
        throw this.handleNetworkError(err);
      }
    } finally {
      if (timer) clearTimeout(timer);
    }
    if (!response.ok) {
      const err = await response.json().catch(() => ({}));
      const msg = err?.detail 
        ? (typeof err.detail === 'object' ? JSON.stringify(err.detail) : err.detail)
        : (err?.message ? (typeof err.message === 'object' ? JSON.stringify(err.message) : err.message) : `HTTP ${response.status}`);
      throw new Error(msg);
    }
    return response.json();
  }

  async postForm<T>(path: string, form: FormData): Promise<T> {
    // Deliberately NOT reusing getHeaders() — Content-Type must be left
    // for fetch/the browser to set itself (multipart/form-data; boundary=...),
    // setting it manually breaks the multipart body.
    try {
      const token = await storage.getItem(TOKEN_KEY);
      const headers: Record<string, string> = { Accept: 'application/json' };
      if (token) headers['Authorization'] = `Bearer ${token}`;

      const response = await fetch(`${this.baseURL}${path}`, {
        method: 'POST',
        headers,
        body: form,
      });
      if (!response.ok) {
        const err = await response.json().catch(() => ({}));
        throw new Error(err?.detail ?? err?.message ?? `HTTP ${response.status}`);
      }
      return response.json();
    } catch (err: any) {
      throw this.handleNetworkError(err);
    }
  }

  async put<T>(path: string, body?: unknown): Promise<T> {
    try {
      const headers = await this.getHeaders();
      const response = await fetch(`${this.baseURL}${path}`, {
        method: 'PUT',
        headers,
        body: body ? JSON.stringify(body) : undefined,
      });
      if (!response.ok) {
        const err = await response.json().catch(() => ({}));
        const msg = err?.detail 
          ? (typeof err.detail === 'object' ? JSON.stringify(err.detail) : err.detail)
          : (err?.message ? (typeof err.message === 'object' ? JSON.stringify(err.message) : err.message) : `HTTP ${response.status}`);
        throw new Error(msg);
      }
      return response.json();
    } catch (err: any) {
      throw this.handleNetworkError(err);
    }
  }
}

export const TOKEN_STORAGE_KEY = TOKEN_KEY;
export const apiClient = new ApiClient();
