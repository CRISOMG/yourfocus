import { describe, it, expect } from "vitest";
import { calculatePomodoroTimelapse } from "../../../app/utils/pomodoro-domain";

describe("calculatePomodoroTimelapse", () => {
  it("should return 0 if startedAt is null", () => {
    expect(calculatePomodoroTimelapse([], 1500)).toBe(0);
  });

  it("should calculate elapsed time correctly without pauses", () => {
    const now = new Date("2023-01-01T10:00:10Z").getTime();
    const start = new Date("2023-01-01T10:00:00Z").toISOString();

    // 10 seconds elapsed
    const timeline = [{ at: start, type: "start" as const }];
    expect(calculatePomodoroTimelapse(timeline, 1500, now)).toBe(10);
  });

  it("should subtract pause duration correctly", () => {
    // Start at 10:00:00
    // Pause at 10:00:05 (Run 5s)
    // Play at 10:00:10 (Paused 5s)
    // Now at 10:00:15 (Run 5s more)
    // Total Run: 10s

    const start = "2023-01-01T10:00:00Z";
    const pause = "2023-01-01T10:00:05Z";
    const play = "2023-01-01T10:00:10Z";
    const now = new Date("2023-01-01T10:00:15Z").getTime();

    const timeline = [
      { at: start, type: "start" as const },
      { at: pause, type: "pause" as const },
      { at: play, type: "play" as const },
    ];

    expect(calculatePomodoroTimelapse(timeline, 1500, now)).toBe(10);
  });

  it("should respect expectedDuration cap", () => {
    // Start at 10:00:00
    // Now is 10:00:20 (20s elapsed)
    // Expected Duration is 10s
    // Should return 10
    const start = "2023-01-01T10:00:00Z";
    const now = new Date("2023-01-01T10:00:20.000Z").getTime();

    const timeline = [{ at: start, type: "start" as const }];
    expect(calculatePomodoroTimelapse(timeline, 10, now)).toBe(10);
  });

  it("should handle millisecond precision consistently (floor)", () => {
    // 9.9 seconds elapsed -> should be 9
    const start = "2023-01-01T10:00:00.000Z";
    const now = new Date("2023-01-01T10:00:09.999Z").getTime();
    const timeline = [{ at: start, type: "start" as const }];
    expect(calculatePomodoroTimelapse(timeline, 1500, now)).toBe(9);
  });

  it("should handle millisecond precision with pauses", () => {
    // Start 0
    // Pause 1000ms (1s run)
    // Play 2000ms
    // Now 2500ms (0.5s run)
    // Total 1.5s -> floor -> 1

    const start = new Date(0).toISOString();
    const timeline = [
      { at: start, type: "start" as const },
      { at: new Date(1000).toISOString(), type: "pause" as const },
      { at: new Date(2000).toISOString(), type: "play" as const },
    ];

    const now = 2500;
    expect(calculatePomodoroTimelapse(timeline, 1500, now)).toBe(1);
  });
});
