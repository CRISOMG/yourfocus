import { describe, it, expect, vi } from "vitest";
import { convertBlobToMp3 } from "../../../app/utils/audio-converter";

describe("audio-converter", () => {
  it("should return the original blob if it is already an MP3", async () => {
    const fakeMp3Blob = new Blob(["mp3data"], { type: "audio/mpeg" });
    const result = await convertBlobToMp3(fakeMp3Blob);

    expect(result.isMp3).toBe(true);
    expect(result.extension).toBe("mp3");
    expect(result.mimeType).toBe("audio/mpeg");
    expect(result.blob).toBe(fakeMp3Blob);
  });

  it("should return fallback webm if AudioContext is not supported", async () => {
    const originalAudioContext = (globalThis as any).window?.AudioContext;
    if ((globalThis as any).window) {
      delete (globalThis as any).window.AudioContext;
      delete (globalThis as any).window.webkitAudioContext;
    }

    const fakeWebmBlob = new Blob(["webmdata"], { type: "audio/webm" });
    const result = await convertBlobToMp3(fakeWebmBlob);

    expect(result.isMp3).toBe(false);
    expect(result.extension).toBe("webm");
    expect(result.mimeType).toBe("audio/webm");
    expect(result.blob).toBe(fakeWebmBlob);

    if ((globalThis as any).window && originalAudioContext) {
      (globalThis as any).window.AudioContext = originalAudioContext;
    }
  });

  it("should gracefully fallback to original blob on decode error", async () => {
    class MockFailingAudioContext {
      state = "running";
      async decodeAudioData() {
        throw new Error("Corrupt audio stream");
      }
      async close() {}
    }

    (globalThis as any).window = (globalThis as any).window || {};
    (globalThis as any).window.AudioContext = MockFailingAudioContext;

    const fakeOggBlob = new Blob(["corrupt"], { type: "audio/ogg" });
    const result = await convertBlobToMp3(fakeOggBlob);

    expect(result.isMp3).toBe(false);
    expect(result.extension).toBe("ogg");
    expect(result.mimeType).toBe("audio/ogg");
    expect(result.blob).toBe(fakeOggBlob);
  });

  it("should successfully convert decoded PCM audio buffer into MP3", async () => {
    const sampleRate = 44100;
    const channelData = new Float32Array(2048);
    // Fill with a sine wave
    for (let i = 0; i < channelData.length; i++) {
      channelData[i] = Math.sin((i / sampleRate) * 440 * 2 * Math.PI);
    }

    class MockSuccessAudioContext {
      state = "running";
      async decodeAudioData() {
        return {
          numberOfChannels: 1,
          sampleRate,
          getChannelData: () => channelData,
        };
      }
      async close() {}
    }

    (globalThis as any).window = (globalThis as any).window || {};
    (globalThis as any).window.AudioContext = MockSuccessAudioContext;

    const fakeWebmBlob = new Blob(["validpcmdata"], { type: "audio/webm;codecs=opus" });
    const result = await convertBlobToMp3(fakeWebmBlob);

    expect(result.isMp3).toBe(true);
    expect(result.extension).toBe("mp3");
    expect(result.mimeType).toBe("audio/mpeg");
    expect(result.blob.size).toBeGreaterThan(0);
    expect(result.blob.type).toBe("audio/mpeg");
  });
});
