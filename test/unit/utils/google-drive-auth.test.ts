import { describe, it, expect, vi, beforeEach } from "vitest";
import {
  isDriveAuthorizedUser,
  assertDriveAuthorized,
  AUTHORIZED_DRIVE_EMAIL,
  AUTHORIZED_DRIVE_USER_ID,
} from "../../../server/utils/google-drive-auth";
import { encryptSecret, decryptSecret } from "../../../server/utils/vault";

// Mock useRuntimeConfig for vault
vi.stubGlobal("useRuntimeConfig", () => ({
  supabaseJwtSecret: "test-super-secret-jwt-key-minimum-32-chars-long!",
}));

describe("google-drive-auth", () => {
  describe("authorization checks", () => {
    it("should authorize Cristian by email", () => {
      const user = { email: AUTHORIZED_DRIVE_EMAIL, id: "some-other-id" };
      expect(isDriveAuthorizedUser(user)).toBe(true);
    });

    it("should authorize Cristian by user id", () => {
      const user = { email: "other@gmail.com", id: AUTHORIZED_DRIVE_USER_ID };
      expect(isDriveAuthorizedUser(user)).toBe(true);
    });

    it("should authorize Cristian by sub claim", () => {
      const user = { sub: AUTHORIZED_DRIVE_USER_ID };
      expect(isDriveAuthorizedUser(user)).toBe(true);
    });

    it("should reject unauthorized users", () => {
      const unauthorizedUser = { email: "attacker@gmail.com", id: "random-uuid" };
      expect(isDriveAuthorizedUser(unauthorizedUser)).toBe(false);
      expect(isDriveAuthorizedUser(null)).toBe(false);
      expect(isDriveAuthorizedUser(undefined)).toBe(false);
    });

    it("assertDriveAuthorized should succeed for authorized user", () => {
      const user = { email: AUTHORIZED_DRIVE_EMAIL };
      expect(() => assertDriveAuthorized(user)).not.toThrow();
    });

    it("assertDriveAuthorized should throw 401 if user is not logged in", () => {
      expect(() => assertDriveAuthorized(null)).toThrowError();
    });

    it("assertDriveAuthorized should throw 403 for unauthorized users", () => {
      const intruder = { email: "stranger@gmail.com", id: "stranger-id" };
      expect(() => assertDriveAuthorized(intruder)).toThrowError();
    });
  });

  describe("token encryption / decryption in vault", () => {
    it("should encrypt and correctly decrypt Google Drive token payload", () => {
      const sampleTokens = {
        accessToken: "ya29.sample-google-access-token",
        refreshToken: "1//sample-google-refresh-token",
        expiryDate: Date.now() + 3600000,
        updatedAt: new Date().toISOString(),
      };

      const serialized = JSON.stringify(sampleTokens);
      const encrypted = encryptSecret(serialized);

      expect(encrypted.encrypted).toBeDefined();
      expect(encrypted.iv).toHaveLength(24); // 12 bytes = 24 hex chars
      expect(encrypted.tag).toHaveLength(32); // 16 bytes = 32 hex chars

      const decryptedString = decryptSecret(encrypted);
      const parsed = JSON.parse(decryptedString);

      expect(parsed.accessToken).toBe(sampleTokens.accessToken);
      expect(parsed.refreshToken).toBe(sampleTokens.refreshToken);
      expect(parsed.expiryDate).toBe(sampleTokens.expiryDate);
    });
  });
});
