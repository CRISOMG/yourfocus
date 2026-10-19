/**
 * Audio Converter Utility
 *
 * Converts recorded audio blobs (WebM/Opus, OGG, WAV, etc.) to MP3 in the browser
 * using the native Web Audio API (for hardware-accelerated decoding) and
 * @breezystack/lamejs (for fast pure-JS/WASM MP3 encoding).
 *
 * Designed with a strict fallback guarantee: if conversion fails or if the environment
 * does not support decoding, it gracefully returns the original audio blob without breaking the flow.
 */

export interface ConvertedAudio {
  blob: Blob;
  mimeType: string;
  extension: string;
  isMp3: boolean;
}

/**
 * Converts any audio Blob to an MP3 Blob with fallback to original on error.
 *
 * @param originalBlob The source audio blob (typically audio/webm from MediaRecorder)
 * @param kbps Bitrate for MP3 encoding (default 128 kbps for clear voice quality)
 */
export async function convertBlobToMp3(
  originalBlob: Blob,
  kbps = 128,
): Promise<ConvertedAudio> {
  // 1. If it's already an MP3, no conversion needed
  if (
    originalBlob.type === "audio/mp3" ||
    originalBlob.type === "audio/mpeg"
  ) {
    return {
      blob: originalBlob,
      mimeType: "audio/mpeg",
      extension: "mp3",
      isMp3: true,
    };
  }

  // 2. Check for browser Web Audio API support
  if (
    typeof window === "undefined" ||
    (!window.AudioContext && !(window as any).webkitAudioContext)
  ) {
    console.warn(
      "[AudioConverter] AudioContext not available in this environment. Falling back to original audio format.",
    );
    return getFallbackAudio(originalBlob);
  }

  let audioContext: AudioContext | null = null;
  try {
    const AudioContextClass =
      window.AudioContext || (window as any).webkitAudioContext;
    audioContext = new AudioContextClass();

    const arrayBuffer = await originalBlob.arrayBuffer();
    // decodeAudioData consumes the ArrayBuffer, so use slice to be safe
    const audioBuffer = await audioContext.decodeAudioData(
      arrayBuffer.slice(0),
    );

    const { Mp3Encoder } = await import("@breezystack/lamejs");

    const channels = audioBuffer.numberOfChannels;
    const sampleRate = audioBuffer.sampleRate;
    const mp3encoder = new Mp3Encoder(channels, sampleRate, kbps);

    const left = floatTo16BitPCM(audioBuffer.getChannelData(0));
    const right =
      channels > 1 ? floatTo16BitPCM(audioBuffer.getChannelData(1)) : undefined;

    const mp3Data: Uint8Array[] = [];
    const sampleBlockSize = 1152;

    for (let i = 0; i < left.length; i += sampleBlockSize) {
      const leftChunk = left.subarray(i, i + sampleBlockSize);
      const rightChunk = right
        ? right.subarray(i, i + sampleBlockSize)
        : undefined;
      const mp3buf = mp3encoder.encodeBuffer(leftChunk, rightChunk);
      if (mp3buf && mp3buf.length > 0) {
        mp3Data.push(new Uint8Array(mp3buf));
      }
    }

    const flushBuf = mp3encoder.flush();
    if (flushBuf && flushBuf.length > 0) {
      mp3Data.push(new Uint8Array(flushBuf));
    }

    const mp3Blob = new Blob(mp3Data, { type: "audio/mpeg" });
    console.info(
      `[AudioConverter] Successfully converted ${originalBlob.size} bytes (${originalBlob.type}) to MP3: ${mp3Blob.size} bytes`,
    );

    return {
      blob: mp3Blob,
      mimeType: "audio/mpeg",
      extension: "mp3",
      isMp3: true,
    };
  } catch (error) {
    console.warn(
      "[AudioConverter] MP3 conversion failed, falling back to original format:",
      error,
    );
    return getFallbackAudio(originalBlob);
  } finally {
    if (audioContext && audioContext.state !== "closed") {
      try {
        await audioContext.close();
      } catch {}
    }
  }
}

function getFallbackAudio(blob: Blob): ConvertedAudio {
  const type = blob.type || "audio/webm";
  let extension = "webm";
  if (type.includes("mp4") || type.includes("m4a")) extension = "m4a";
  else if (type.includes("ogg")) extension = "ogg";
  else if (type.includes("wav")) extension = "wav";

  return {
    blob,
    mimeType: type,
    extension,
    isMp3: false,
  };
}

function floatTo16BitPCM(input: Float32Array): Int16Array {
  const output = new Int16Array(input.length);
  for (let i = 0; i < input.length; i++) {
    const s = Math.max(-1, Math.min(1, input[i]));
    output[i] = s < 0 ? s * 0x8000 : s * 0x7fff;
  }
  return output;
}
