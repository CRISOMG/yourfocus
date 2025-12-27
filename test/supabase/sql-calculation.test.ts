import { describe, it, expect } from "vitest";
import { createClient } from "@supabase/supabase-js";

// Load environment variables (Vitest usually handles this with vitest.config.ts or .env)
const supabaseUrl = process.env.SUPABASE_URL || "http://127.0.0.1:54321";
const supabaseKey =
  process.env.SUPABASE_SERVICE_KEY || process.env.SUPABASE_ANON_KEY || "";

if (!supabaseKey) {
  console.warn(
    "SUPABASE_SERVICE_KEY or SUPABASE_ANON_KEY not found. Tests might fail if not authenticated properly."
  );
}

describe("SQL Function: calculate_pomodoro_timelapse_sql", () => {
  const supabase = createClient(supabaseUrl, supabaseKey);

  it("should calculate simple elapsed time (RPC)", async () => {
    const start = new Date("2023-01-01T10:00:00Z").toISOString();
    const now = new Date("2023-01-01T10:00:10Z").toISOString();

    // RPC call: We cast payload to any to bypass potential TS type mismatch if types aren't updated
    const { data, error } = await supabase.rpc(
      "calculate_pomodoro_timelapse_sql",
      {
        p_toggle_timeline: [{ at: start, type: "start" }],
        p_expected_duration: 1500,
        p_now: now,
      } as any
    );

    if (error) console.error("RPC Error:", error);
    expect(error).toBeNull();
    expect(data).toBe(10);
  });

  it("should respect expected_duration cap", async () => {
    const start = new Date("2023-01-01T10:00:00Z").toISOString();
    // 20 seconds later
    const now = new Date("2023-01-01T10:00:20Z").toISOString();

    // Cap at 10 seconds
    const { data, error } = await supabase.rpc(
      "calculate_pomodoro_timelapse_sql",
      {
        p_toggle_timeline: [{ at: start, type: "start" }],
        p_expected_duration: 10,
        p_now: now,
      } as any
    );

    expect(error).toBeNull();
    expect(data).toBe(10);
  });

  it("should handle pauses with millisecond precision", async () => {
    // Start 10:00:00.000
    // Pause 10:00:01.500 (1.5s run)
    // Play  10:00:02.000
    // Now   10:00:02.600 (+0.6s run)
    // Total 2.1s -> floor -> 2

    const start = "2023-01-01T10:00:00.000Z";
    const events = [
      { at: start, type: "start" },
      { at: "2023-01-01T10:00:01.500Z", type: "pause" },
      { at: "2023-01-01T10:00:02.000Z", type: "play" },
    ];
    const now = "2023-01-01T10:00:02.600Z";

    const { data, error } = await supabase.rpc(
      "calculate_pomodoro_timelapse_sql",
      {
        p_toggle_timeline: events,
        p_expected_duration: 1500,
        p_now: now,
      } as any
    );

    expect(error).toBeNull();
    expect(data).toBeCloseTo(2.1, 5);
  });

  it("should handle floating point drift/precision correctly", async () => {
    // 9.999 seconds elapsed should be 9
    const start = "2023-01-01T10:00:00.000Z";
    const now = "2023-01-01T10:00:09.999Z";

    const { data, error } = await supabase.rpc(
      "calculate_pomodoro_timelapse_sql",
      {
        p_toggle_timeline: [{ at: start, type: "start" }],
        p_expected_duration: 1500,
        p_now: now,
      } as any
    );

    expect(error).toBeNull();
    expect(data).toBeCloseTo(9.999, 5);
  });
});
